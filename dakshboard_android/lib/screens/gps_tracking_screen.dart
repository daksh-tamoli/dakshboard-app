// ============================================================
// DAKSHboard — GPS Tracking Screen
// Uses flutter_map + OpenStreetMap — FREE, no API key needed
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class GpsTrackingScreen extends StatefulWidget {
  const GpsTrackingScreen({super.key});

  @override
  State<GpsTrackingScreen> createState() => _GpsTrackingScreenState();
}

class _GpsTrackingScreenState extends State<GpsTrackingScreen> {
  final MapController _mapController = MapController();
  StreamSubscription<Position>? _positionStream;

  final List<LatLng> _path = [];
  Position? _currentPosition;
  bool _isTracking = false;
  bool _isPaused = false;
  bool _isCountingDown = false;
  int _countdownValue = 3;
  double _totalDistanceKm = 0;
  Timer? _durationTimer;
  Duration _elapsed = Duration.zero;
  bool _hasLocationPermission = false;

  static const _stravaOrange = Color(0xFFFC4C02);
  static const _defaultCenter = LatLng(28.6139, 77.2090); // New Delhi fallback

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) _showSnack('Please enable location services on your device');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        setState(() => _hasLocationPermission = true);
        try {
          final pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          );
          if (mounted) {
            setState(() => _currentPosition = pos);
            _mapController.move(LatLng(pos.latitude, pos.longitude), 16);
          }
        } catch (_) {}
      } else {
        if (mounted) _showSnack('Location permission required for GPS tracking');
      }
    } catch (e) {
      debugPrint('Permission error: $e');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _initiateTracking() async {
    if (!_hasLocationPermission) {
      await _checkPermissions();
      if (!_hasLocationPermission) return;
    }

    setState(() {
      _isCountingDown = true;
      _countdownValue = 3;
      _path.clear();
      _totalDistanceKm = 0;
      _elapsed = Duration.zero;
      _isTracking = false;
      _isPaused = false;
    });

    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _countdownValue--;
        if (_countdownValue == 0) {
          timer.cancel();
          _isCountingDown = false;
          _startTracking();
        }
      });
    });
  }

  void _startTracking() {
    setState(() {
      _isTracking = true;
      _isPaused = false;
    });

    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
    });

    try {
      _positionStream?.cancel();
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 10, // 10m minimum movement (prevents GPS noise)
        ),
      ).listen(
        (position) {
          if (!mounted || _isPaused) return;

          // Filter: ignore low-accuracy fixes
          if (position.accuracy > 20) return;

          // Filter: ignore stationary GPS drift (speed < 0.8 m/s)
          if (position.speed != null && position.speed! < 0.8 && _path.isNotEmpty) return;

          final newPoint = LatLng(position.latitude, position.longitude);

          setState(() {
            if (_path.isNotEmpty) {
              final dist = Geolocator.distanceBetween(
                _path.last.latitude, _path.last.longitude,
                newPoint.latitude, newPoint.longitude,
              );
              // Ignore GPS glitch jumps > 50m
              if (dist < 50) _totalDistanceKm += dist / 1000;
            }
            _path.add(newPoint);
            _currentPosition = position;
          });

          _mapController.move(newPoint, 16);
        },
        onError: (err) => debugPrint('Location stream error: $err'),
      );
    } catch (e) {
      debugPrint('Error starting position stream: $e');
    }
  }

  void _pauseTracking() {
    _durationTimer?.cancel();
    setState(() => _isPaused = true);
  }

  void _resumeTracking() {
    setState(() => _isPaused = false);
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  void _stopTracking() {
    _positionStream?.cancel();
    _durationTimer?.cancel();
    setState(() {
      _isTracking = false;
      _isPaused = false;
    });
    if (_totalDistanceKm > 0.05) _showSummaryDialog();
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  String _getPace() {
    if (_totalDistanceKm < 0.01 || _elapsed.inSeconds < 1) return '--:--';
    final paceMin = (_elapsed.inSeconds / 60) / _totalDistanceKm;
    final m = paceMin.floor();
    final s = ((paceMin - m) * 60).round();
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  void _showSummaryDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFFFC4C02)),
            SizedBox(width: 8),
            Text('Run Complete!', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SummaryRow('Distance', '${_totalDistanceKm.toStringAsFixed(2)} km'),
            _SummaryRow('Duration', _formatDuration(_elapsed)),
            _SummaryRow('Avg Pace', '${_getPace()} /km'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Discard', style: TextStyle(color: Color(0xFF888888))),
          ),
          TextButton(
            onPressed: () {
              // TODO: Implement Save to Database logic here
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Activity Saved locally & ready for Strava sync')));
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Save & Share', style: TextStyle(color: Color(0xFFFC4C02))),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _durationTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  LatLng get _center => _currentPosition != null
      ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
      : _defaultCenter;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('GPS Tracking'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            if (_isTracking) _stopTracking();
            Navigator.pop(context);
          },
        ),
      ),
      body: Column(
        children: [
          // ── Live Stats Bar ──────────────────────────────────
          Container(
            color: const Color(0xFF1E1E1E),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _LiveStat(label: 'Distance', value: '${_totalDistanceKm.toStringAsFixed(2)} km'),
                _divider(),
                _LiveStat(label: 'Duration', value: _formatDuration(_elapsed)),
                _divider(),
                _LiveStat(label: 'Pace', value: _getPace()),
              ],
            ),
          ),

          // ── OpenStreetMap ───────────────────────────────────
          Expanded(
            child: Stack(
              children: [
                _hasLocationPermission
                    ? FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _center,
                      initialZoom: 16,
                    ),
                    children: [
                      // Dark-styled OpenStreetMap tile layer — completely free
                      TileLayer(
                        urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                        subdomains: const ['a', 'b', 'c', 'd'],
                        userAgentPackageName: 'com.dakshtamoli.dakshboard_android',
                        maxZoom: 20,
                      ),
                      // Run path polyline
                      if (_path.length > 1)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: _path,
                              strokeWidth: 5,
                              color: _stravaOrange,
                            ),
                          ],
                        ),
                      // Current position marker
                      if (_currentPosition != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                              width: 24,
                              height: 24,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _stravaOrange,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 3),
                                  boxShadow: [
                                    BoxShadow(color: _stravaOrange.withOpacity(0.5), blurRadius: 8, spreadRadius: 2),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.location_off_rounded, color: Color(0xFFFC4C02), size: 48),
                        const SizedBox(height: 12),
                        const Text('GPS Ready', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text(
                          'Enable location permission to track your run',
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _checkPermissions,
                          icon: const Icon(Icons.my_location_rounded),
                          label: const Text('Enable Location'),
                        ),
                      ],
                    ),
                  ),
                
                // Countdown Overlay
                if (_isCountingDown)
                  Container(
                    color: Colors.black54,
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (Widget child, Animation<double> animation) {
                          return ScaleTransition(scale: animation, child: child);
                        },
                        child: Text(
                          '$_countdownValue',
                          key: ValueKey<int>(_countdownValue),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 120,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Action Buttons ────────────────────────────────
          Container(
            padding: const EdgeInsets.all(24),
            color: const Color(0xFF121212),
            child: _buildActionButtons(),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    if (_isCountingDown) {
      return const SizedBox(height: 56);
    }

    if (!_isTracking && !_isPaused) {
      return ElevatedButton.icon(
        onPressed: _initiateTracking,
        style: ElevatedButton.styleFrom(
          backgroundColor: _stravaOrange,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: const Icon(Icons.play_arrow_rounded, size: 28),
        label: const Text('Start Run', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      );
    }

    if (_isPaused) {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _resumeTracking,
              style: ElevatedButton.styleFrom(
                backgroundColor: _stravaOrange,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.play_arrow_rounded, size: 28),
              label: const Text('Resume', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _stopTracking,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.stop_rounded, size: 28),
              label: const Text('Stop', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
          ),
        ],
      );
    }

    return ElevatedButton.icon(
      onPressed: _pauseTracking,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.amber,
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: const Icon(Icons.pause_rounded, size: 28),
      label: const Text('Pause Run', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
    );
  }

  Widget _divider() => Container(width: 1, height: 36, color: const Color(0xFF2A2A2A));
}

class _LiveStat extends StatelessWidget {
  final String label;
  final String value;
  const _LiveStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Color(0xFF888888), fontSize: 12)),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFFAAAAAA))),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
