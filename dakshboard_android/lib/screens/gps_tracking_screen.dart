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

  void _startTracking() async {
    if (!_hasLocationPermission) {
      await _checkPermissions();
      if (!_hasLocationPermission) return;
    }

    setState(() {
      _isTracking = true;
      _path.clear();
      _totalDistanceKm = 0;
      _elapsed = Duration.zero;
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
          if (!mounted) return;

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

  void _stopTracking() {
    _positionStream?.cancel();
    _durationTimer?.cancel();
    setState(() => _isTracking = false);
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
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done', style: TextStyle(color: Color(0xFFFC4C02))),
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
            child: _hasLocationPermission
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
          ),

          // ── Start/Stop Button ───────────────────────────────
          Container(
            padding: const EdgeInsets.all(24),
            color: const Color(0xFF121212),
            child: ElevatedButton.icon(
              onPressed: _isTracking ? _stopTracking : _startTracking,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isTracking ? Colors.redAccent : _stravaOrange,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: Icon(_isTracking ? Icons.stop_rounded : Icons.play_arrow_rounded, size: 28),
              label: Text(
                _isTracking ? 'Stop Run' : 'Start Run',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ),
        ],
      ),
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
