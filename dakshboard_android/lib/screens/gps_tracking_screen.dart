// ============================================================
// DAKSHboard — GPS Tracking Screen
// Live run tracking with map, pace, distance, duration
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class GpsTrackingScreen extends StatefulWidget {
  const GpsTrackingScreen({super.key});

  @override
  State<GpsTrackingScreen> createState() => _GpsTrackingScreenState();
}

class _GpsTrackingScreenState extends State<GpsTrackingScreen> {
  GoogleMapController? _mapController;
  StreamSubscription<Position>? _positionStream;

  final List<LatLng> _path = [];
  Position? _currentPosition;
  DateTime? _startTime;
  bool _isTracking = false;
  double _totalDistanceKm = 0;
  Timer? _durationTimer;
  Duration _elapsed = Duration.zero;

  static const _stravaOrange = Color(0xFFFC4C02);

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission required for GPS tracking')),
        );
      }
    }
  }

  void _startTracking() async {
    final hasPermission = await Geolocator.isLocationServiceEnabled();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enable location services')),
        );
      }
      return;
    }

    setState(() {
      _isTracking = true;
      _path.clear();
      _totalDistanceKm = 0;
      _startTime = DateTime.now();
      _elapsed = Duration.zero;
    });

    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
    });

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5,
      ),
    ).listen((position) {
      if (!mounted) return;
      final newPoint = LatLng(position.latitude, position.longitude);

      setState(() {
        if (_path.isNotEmpty) {
          final dist = Geolocator.distanceBetween(
            _path.last.latitude, _path.last.longitude,
            newPoint.latitude, newPoint.longitude,
          );
          _totalDistanceKm += dist / 1000;
        }
        _path.add(newPoint);
        _currentPosition = position;
      });

      _mapController?.animateCamera(CameraUpdate.newLatLng(newPoint));
    });
  }

  void _stopTracking() {
    _positionStream?.cancel();
    _durationTimer?.cancel();
    setState(() => _isTracking = false);

    if (_totalDistanceKm > 0.05) {
      _showSummaryDialog();
    }
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
    _mapController?.dispose();
    super.dispose();
  }

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
          // ── Live Stats Bar ────────────────────────────────
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

          // ── Map ───────────────────────────────────────────
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _currentPosition != null
                    ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                    : const LatLng(28.6139, 77.2090), // Default: New Delhi
                zoom: 16,
              ),
              onMapCreated: (controller) => _mapController = controller,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              mapType: MapType.normal,
              polylines: _path.length > 1
                  ? {
                      Polyline(
                        polylineId: const PolylineId('run_path'),
                        points: _path,
                        color: _stravaOrange,
                        width: 5,
                      ),
                    }
                  : {},
              style: _darkMapStyle,
            ),
          ),

          // ── Start/Stop Button ─────────────────────────────
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

  Widget _divider() => Container(
    width: 1,
    height: 36,
    color: const Color(0xFF2A2A2A),
  );
}

class _LiveStat extends StatelessWidget {
  final String label;
  final String value;

  const _LiveStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
        ),
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

// Dark map style for Google Maps
const String _darkMapStyle = '''
[
  {"elementType": "geometry", "stylers": [{"color": "#1d2c4d"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#8ec3b9"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#1a3646"}]},
  {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#304a7d"}]},
  {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#2c6675"}]},
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#0e1626"}]},
  {"featureType": "poi", "stylers": [{"visibility": "off"}]}
]
''';
