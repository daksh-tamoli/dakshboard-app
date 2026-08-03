// ============================================================
// DAKSHboard — Workout Detail Screen
// Pace & HR charts, laps table, share workout
// ============================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:dakshboard_android/models/workout.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class WorkoutDetailScreen extends StatefulWidget {
  final Workout workout;

  const WorkoutDetailScreen({super.key, required this.workout});

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();

  Future<void> _shareWorkout() async {
    try {
      final image = await _screenshotController.capture();
      if (image == null) return;
      final dir = await getTemporaryDirectory();
      final file = await File('${dir.path}/dakshboard_workout.png').writeAsBytes(image);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '🏃 ${widget.workout.title} — ${widget.workout.distanceKm.toStringAsFixed(2)}km in ${widget.workout.formattedDuration} | Tracked with DAKSHboard',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share failed: $e')),
        );
      }
    }
  }

  List<Map<String, dynamic>> _parseLaps() {
    if (widget.workout.laps == null) return [];
    try {
      return List<Map<String, dynamic>>.from(jsonDecode(widget.workout.laps!));
    } catch (_) {
      return [];
    }
  }

  List<FlSpot> _parsePaceStream() {
    if (widget.workout.paceStream == null) return [];
    try {
      final raw = List<dynamic>.from(jsonDecode(widget.workout.paceStream!));
      return raw.asMap().entries
          .where((e) => e.value != null && e.value > 0 && e.value < 20)
          .map((e) => FlSpot(e.key.toDouble(), (e.value as num).toDouble()))
          .toList();
    } catch (_) {
      return [];
    }
  }

  List<FlSpot> _parseHrStream() {
    if (widget.workout.heartrateStream == null) return [];
    try {
      final raw = List<dynamic>.from(jsonDecode(widget.workout.heartrateStream!));
      return raw.asMap().entries
          .where((e) => e.value != null && e.value > 0)
          .map((e) => FlSpot(e.key.toDouble(), (e.value as num).toDouble()))
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.workout;
    final laps = _parseLaps();
    final paceSpots = _parsePaceStream();
    final hrSpots = _parseHrStream();

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text(w.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Share Workout',
            icon: const Icon(Icons.share_rounded, color: Color(0xFFFC4C02)),
            onPressed: _shareWorkout,
          ),
        ],
      ),
      body: Screenshot(
        controller: _screenshotController,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Hero Stats Card ───────────────────────────
              _heroCard(w),
              const SizedBox(height: 16),

              // ── Pace Chart ────────────────────────────────
              if (paceSpots.isNotEmpty) ...[
                _sectionTitle('Pace Stream'),
                const SizedBox(height: 8),
                _lineChart(paceSpots, const Color(0xFF4488FF), 'min/km', reversed: true),
                const SizedBox(height: 16),
              ],

              // ── HR Chart ──────────────────────────────────
              if (hrSpots.isNotEmpty) ...[
                _sectionTitle('Heart Rate Stream'),
                const SizedBox(height: 8),
                _lineChart(hrSpots, Colors.redAccent, 'bpm', reversed: false),
                const SizedBox(height: 16),
              ],

              // ── Laps Table ───────────────────────────────
              if (laps.isNotEmpty) ...[
                _sectionTitle('Lap Splits'),
                const SizedBox(height: 8),
                _lapsTable(laps),
                const SizedBox(height: 24),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _heroCard(Workout w) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(w.formattedDate, style: const TextStyle(color: Color(0xFF888888), fontSize: 13)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${w.categoryIcon} ${w.type ?? w.category}',
                  style: const TextStyle(color: Color(0xFF888888), fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statItem('Distance', '${w.distanceKm.toStringAsFixed(2)} km'),
              _vDivider(),
              _statItem('Duration', w.formattedDuration),
              _vDivider(),
              _statItem('Pace', w.formattedPace),
            ],
          ),
          if (w.avgHeartrate != null) ...[
            const SizedBox(height: 16),
            const Divider(color: Color(0xFF2A2A2A), height: 1),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statItem('Avg HR', '${w.avgHeartrate} bpm', color: Colors.redAccent),
                if (w.maxHeartrate != null) ...[
                  _vDivider(),
                  _statItem('Max HR', '${w.maxHeartrate} bpm', color: Colors.redAccent),
                ],
                if (w.elevationGain != null && w.elevationGain! > 0) ...[
                  _vDivider(),
                  _statItem('Elevation', '${w.elevationGain!.toStringAsFixed(0)}m'),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, {Color? color}) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color ?? Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Color(0xFF888888), fontSize: 12)),
      ],
    );
  }

  Widget _vDivider() => Container(width: 1, height: 36, color: const Color(0xFF2A2A2A));

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(color: Color(0xFFAAAAAA), fontWeight: FontWeight.w600, fontSize: 14),
    );
  }

  Widget _lineChart(List<FlSpot> spots, Color color, String unit, {required bool reversed}) {
    return Container(
      height: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: color,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: color.withOpacity(0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lapsTable(List<Map<String, dynamic>> laps) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF2A2A2A))),
            ),
            child: const Row(
              children: [
                Expanded(child: Text('Lap', style: TextStyle(color: Color(0xFF888888), fontSize: 12))),
                Expanded(child: Text('Distance', style: TextStyle(color: Color(0xFF888888), fontSize: 12))),
                Expanded(child: Text('Time', style: TextStyle(color: Color(0xFF888888), fontSize: 12))),
                Expanded(child: Text('Avg HR', style: TextStyle(color: Color(0xFF888888), fontSize: 12))),
              ],
            ),
          ),
          // Rows
          ...laps.asMap().entries.map((entry) {
            final i = entry.key;
            final lap = entry.value;
            final distKm = ((lap['distance'] ?? 0) / 1000).toStringAsFixed(2);
            final time = lap['moving_time'] ?? 0;
            final m = (time ~/ 60).toString().padLeft(2, '0');
            final s = (time % 60).toString().padLeft(2, '0');
            final hr = lap['average_heartrate'];

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                border: i < laps.length - 1
                    ? const Border(bottom: BorderSide(color: Color(0xFF2A2A2A)))
                    : null,
              ),
              child: Row(
                children: [
                  Expanded(child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 13))),
                  Expanded(child: Text('$distKm km', style: const TextStyle(color: Colors.white, fontSize: 13))),
                  Expanded(child: Text('$m:$s', style: const TextStyle(color: Colors.white, fontSize: 13))),
                  Expanded(
                    child: Text(
                      hr != null ? '${hr.round()} bpm' : '--',
                      style: TextStyle(color: hr != null ? Colors.redAccent : const Color(0xFF666666), fontSize: 13),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
