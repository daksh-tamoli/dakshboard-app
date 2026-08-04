// ============================================================
// DAKSHboard — Workout Detail Screen
// Beautiful charts with avg lines, HR zones, proper scale
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

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> with SingleTickerProviderStateMixin {
  final ScreenshotController _screenshotController = ScreenshotController();
  late TabController _tabController;

  static const _orange = Color(0xFFFC4C02);
  static const _blue = Color(0xFF4488FF);
  static const _red = Color(0xFFFF4466);
  static const _card = Color(0xFF1E1E1E);
  static const _border = Color(0xFF2A2A2A);

  // HR Zone colors and thresholds (% of max HR)
  static const _hrZones = [
    {'name': 'Z1 Rest', 'color': Color(0xFF4488FF), 'maxPct': 0.60},
    {'name': 'Z2 Fat Burn', 'color': Color(0xFF44BB88), 'maxPct': 0.70},
    {'name': 'Z3 Aerobic', 'color': Color(0xFFFFBB33), 'maxPct': 0.80},
    {'name': 'Z4 Threshold', 'color': Color(0xFFFF7733), 'maxPct': 0.90},
    {'name': 'Z5 Max', 'color': Color(0xFFFF3355), 'maxPct': 1.00},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _shareWorkout() async {
    try {
      final image = await _screenshotController.capture();
      if (image == null) return;
      final dir = await getTemporaryDirectory();
      final file = await File('${dir.path}/dakshboard_workout.png').writeAsBytes(image);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '🏃 ${widget.workout.title} — ${widget.workout.distanceKm.toStringAsFixed(2)}km in ${widget.workout.formattedDuration} | DAKSHboard',
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Share failed: $e')));
    }
  }

  List<Map<String, dynamic>> _parseLaps() {
    if (widget.workout.laps == null) return [];
    try { return List<Map<String, dynamic>>.from(jsonDecode(widget.workout.laps!)); } catch (_) { return []; }
  }

  // Parse velocity_smooth (m/s) → convert to pace (min/km)
  List<double> _parsePaceValues() {
    if (widget.workout.paceStream == null) return [];
    try {
      final raw = List<dynamic>.from(jsonDecode(widget.workout.paceStream!));
      return raw
          .where((v) => v != null && (v as num) > 0.5)
          .map((v) {
            // v is m/s from Strava; convert to min/km
            final mps = (v as num).toDouble();
            return (1000 / mps) / 60; // minutes per km
          })
          .where((p) => p > 2 && p < 20) // valid pace range
          .toList();
    } catch (_) { return []; }
  }

  List<double> _parseHrValues() {
    if (widget.workout.heartrateStream == null) return [];
    try {
      final raw = List<dynamic>.from(jsonDecode(widget.workout.heartrateStream!));
      return raw
          .where((v) => v != null && (v as num) > 30)
          .map((v) => (v as num).toDouble())
          .toList();
    } catch (_) { return []; }
  }

  // Build FlSpot list sampled to max 300 points for performance
  List<FlSpot> _toSpots(List<double> values) {
    if (values.isEmpty) return [];
    final step = (values.length / 300).ceil().clamp(1, 999);
    final sampled = <double>[];
    for (int i = 0; i < values.length; i += step) sampled.add(values[i]);
    return sampled.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList();
  }

  // Compute % time in each HR zone
  List<double> _hrZonePcts(List<double> hrValues, double maxHr) {
    if (hrValues.isEmpty || maxHr == 0) return List.filled(5, 0);
    final counts = List<int>.filled(5, 0);
    for (final hr in hrValues) {
      final pct = hr / maxHr;
      if (pct < 0.60) counts[0]++;
      else if (pct < 0.70) counts[1]++;
      else if (pct < 0.80) counts[2]++;
      else if (pct < 0.90) counts[3]++;
      else counts[4]++;
    }
    return counts.map((c) => c / hrValues.length * 100).toList();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.workout;
    final paceValues = _parsePaceValues();
    final hrValues = _parseHrValues();
    final paceSpots = _toSpots(paceValues);
    final hrSpots = _toSpots(hrValues);
    final laps = _parseLaps();

    final avgPace = paceValues.isNotEmpty ? paceValues.reduce((a, b) => a + b) / paceValues.length : null;
    final avgHr = hrValues.isNotEmpty ? hrValues.reduce((a, b) => a + b) / hrValues.length : null;
    final hrStreamMax = hrValues.isEmpty ? 0.0 : hrValues.fold<double>(0.0, (m, v) => v > m ? v : m);
    final maxHrRaw = w.maxHeartrate?.toDouble() ?? hrStreamMax;
    final effectiveMaxHr = maxHrRaw > 0 ? maxHrRaw : 190.0; // 190 default if unknown

    final zonePcts = _hrZonePcts(hrValues, effectiveMaxHr);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text(w.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Share Workout',
            icon: const Icon(Icons.share_rounded, color: _orange),
            onPressed: _shareWorkout,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _orange,
          labelColor: _orange,
          unselectedLabelColor: const Color(0xFF666666),
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Charts'),
            Tab(text: 'Laps'),
          ],
        ),
      ),
      body: Screenshot(
        controller: _screenshotController,
        child: TabBarView(
          controller: _tabController,
          children: [
            // ── Tab 1: Overview ──────────────────────────────
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _heroCard(w),
                  if (hrValues.isNotEmpty && effectiveMaxHr > 0) ...[
                    const SizedBox(height: 16),
                    _hrZonesCard(zonePcts, effectiveMaxHr),
                  ],
                ],
              ),
            ),

            // ── Tab 2: Charts ────────────────────────────────
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hrSpots.isNotEmpty) ...[
                    _chartHeader('Heart Rate', '${avgHr?.round() ?? '--'} bpm avg', _red),
                    const SizedBox(height: 8),
                    _hrChart(hrSpots, avgHr, effectiveMaxHr),
                    const SizedBox(height: 24),
                  ],
                  if (paceSpots.isNotEmpty) ...[
                    _chartHeader('Pace', avgPace != null ? _fmtPace(avgPace) : '--', _blue),
                    const SizedBox(height: 8),
                    _paceChart(paceSpots, avgPace),
                    const SizedBox(height: 24),
                  ],
                  if (hrSpots.isEmpty && paceSpots.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          children: [
                            Icon(Icons.bar_chart_rounded, size: 56, color: Colors.white.withOpacity(0.15)),
                            const SizedBox(height: 12),
                            Text('No stream data', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 16)),
                            const SizedBox(height: 6),
                            Text('Sync more recent activities to see charts', style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 13), textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Tab 3: Laps ──────────────────────────────────
            laps.isNotEmpty
                ? SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: _lapsTable(laps),
                  )
                : Center(
                    child: Text('No lap data available', style: TextStyle(color: Colors.white.withOpacity(0.4))),
                  ),
          ],
        ),
      ),
    );
  }

  // ── Hero Stats Card ─────────────────────────────────────────
  Widget _heroCard(Workout w) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(w.formattedDate, style: const TextStyle(color: Color(0xFF888888), fontSize: 13)),
              _typePill(w),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _bigStat('Distance', '${w.distanceKm.toStringAsFixed(2)}', 'km'),
              _vDivider(),
              _bigStat('Duration', w.formattedDuration, ''),
              _vDivider(),
              _bigStat('Pace', w.avgPace != null ? _fmtPace(w.avgPace!) : '--', '/km'),
            ],
          ),
          if (w.avgHeartrate != null || w.elevationGain != null) ...[
            const SizedBox(height: 16),
            const Divider(color: _border, height: 1),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                if (w.avgHeartrate != null) _bigStat('Avg HR', '${w.avgHeartrate}', 'bpm', color: _red),
                if (w.maxHeartrate != null) ...[_vDivider(), _bigStat('Max HR', '${w.maxHeartrate}', 'bpm', color: _red)],
                if (w.elevationGain != null && w.elevationGain! > 0) ...[
                  _vDivider(),
                  _bigStat('Elevation', '${w.elevationGain!.toStringAsFixed(0)}', 'm', color: const Color(0xFF44BB88)),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _typePill(Workout w) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: _orange.withOpacity(0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: _orange.withOpacity(0.3))),
    child: Text('${w.categoryIcon} ${w.type ?? w.category}', style: const TextStyle(color: _orange, fontSize: 12, fontWeight: FontWeight.w600)),
  );

  Widget _bigStat(String label, String value, String unit, {Color? color}) => Column(
    children: [
      RichText(
        text: TextSpan(
          children: [
            TextSpan(text: value, style: TextStyle(color: color ?? Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            if (unit.isNotEmpty)
              TextSpan(text: ' $unit', style: TextStyle(color: (color ?? Colors.white).withOpacity(0.6), fontSize: 12)),
          ],
        ),
      ),
      const SizedBox(height: 3),
      Text(label, style: const TextStyle(color: Color(0xFF888888), fontSize: 12)),
    ],
  );

  Widget _vDivider() => Container(width: 1, height: 40, color: _border);

  // ── HR Zones Card ───────────────────────────────────────────
  Widget _hrZonesCard(List<double> zonePcts, double maxHr) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('HR Zones', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              Text('Max HR: ${maxHr.round()} bpm', style: const TextStyle(color: Color(0xFF888888), fontSize: 12)),
            ],
          ),
          const SizedBox(height: 16),
          ...List.generate(5, (i) {
            final zone = _hrZones[i];
            final pct = zonePcts[i];
            final prevMax = i == 0 ? 0.0 : (_hrZones[i - 1]['maxPct'] as double);
            final thisMax = zone['maxPct'] as double;
            final minBpm = (prevMax * maxHr).round();
            final maxBpm = i == 4 ? maxHr.round() : (thisMax * maxHr).round();
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  // Zone label
                  SizedBox(
                    width: 90,
                    child: Text(zone['name'] as String, style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 12)),
                  ),
                  // BPM range
                  SizedBox(
                    width: 60,
                    child: Text('$minBpm-${maxBpm}bpm', style: const TextStyle(color: Color(0xFF666666), fontSize: 10)),
                  ),
                  // Bar
                  Expanded(
                    child: Stack(
                      children: [
                        Container(height: 18, decoration: BoxDecoration(color: const Color(0xFF2A2A2A), borderRadius: BorderRadius.circular(4))),
                        FractionallySizedBox(
                          widthFactor: (pct / 100).clamp(0.0, 1.0),
                          child: Container(
                            height: 18,
                            decoration: BoxDecoration(
                              color: zone['color'] as Color,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Pct label
                  SizedBox(
                    width: 40,
                    child: Text('  ${pct.toStringAsFixed(0)}%', style: TextStyle(color: (zone['color'] as Color), fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Chart Header ────────────────────────────────────────────
  Widget _chartHeader(String title, String avgLabel, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
        Row(
          children: [
            Container(width: 12, height: 2, color: color.withOpacity(0.6), margin: const EdgeInsets.only(right: 6)),
            Text('Avg: $avgLabel', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }

  // ── HR Chart ─────────────────────────────────────────────────
  Widget _hrChart(List<FlSpot> spots, double? avgHr, double maxHr) {
    if (spots.isEmpty) return const SizedBox.shrink();

    final values = spots.map((s) => s.y).toList();
    final minY = (values.reduce((a, b) => a < b ? a : b) - 10).clamp(40.0, 200.0);
    final maxY = (values.reduce((a, b) => a > b ? a : b) + 10).clamp(60.0, 220.0);

    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14), border: Border.all(color: _border)),
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          clipData: const FlClipData.all(),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 20,
            getDrawingHorizontalLine: (_) => const FlLine(color: Color(0xFF2A2A2A), strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                interval: 20,
                getTitlesWidget: (v, _) => Text('${v.toInt()}', style: const TextStyle(color: Color(0xFF666666), fontSize: 10)),
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          extraLinesData: avgHr != null
              ? ExtraLinesData(horizontalLines: [
                  HorizontalLine(
                    y: avgHr,
                    color: _red.withOpacity(0.7),
                    strokeWidth: 1.5,
                    dashArray: [6, 4],
                    label: HorizontalLineLabel(
                      show: true,
                      alignment: Alignment.topRight,
                      padding: const EdgeInsets.only(right: 4, bottom: 2),
                      style: const TextStyle(color: _red, fontSize: 10, fontWeight: FontWeight.bold),
                      labelResolver: (line) => 'avg ${avgHr.round()}',
                    ),
                  ),
                ])
              : null,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.3,
              color: _red,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_red.withOpacity(0.25), _red.withOpacity(0.0)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Pace Chart ───────────────────────────────────────────────
  Widget _paceChart(List<FlSpot> spots, double? avgPace) {
    if (spots.isEmpty) return const SizedBox.shrink();

    final values = spots.map((s) => s.y).toList();
    final minY = (values.reduce((a, b) => a < b ? a : b) - 0.5).clamp(2.0, 15.0);
    final maxY = (values.reduce((a, b) => a > b ? a : b) + 0.5).clamp(3.0, 18.0);

    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14), border: Border.all(color: _border)),
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          clipData: const FlClipData.all(),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 1.0,
            getDrawingHorizontalLine: (_) => const FlLine(color: Color(0xFF2A2A2A), strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: 1.0,
                getTitlesWidget: (v, _) => Text(_fmtPace(v), style: const TextStyle(color: Color(0xFF666666), fontSize: 9)),
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          extraLinesData: avgPace != null
              ? ExtraLinesData(horizontalLines: [
                  HorizontalLine(
                    y: avgPace,
                    color: _blue.withOpacity(0.7),
                    strokeWidth: 1.5,
                    dashArray: [6, 4],
                    label: HorizontalLineLabel(
                      show: true,
                      alignment: Alignment.topRight,
                      padding: const EdgeInsets.only(right: 4, bottom: 2),
                      style: const TextStyle(color: _blue, fontSize: 10, fontWeight: FontWeight.bold),
                      labelResolver: (line) => 'avg ${_fmtPace(avgPace)}',
                    ),
                  ),
                ])
              : null,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.3,
              color: _blue,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_blue.withOpacity(0.25), _blue.withOpacity(0.0)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Laps Table ───────────────────────────────────────────────
  Widget _lapsTable(List<Map<String, dynamic>> laps) {
    return Container(
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14), border: Border.all(color: _border)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _border))),
            child: const Row(
              children: [
                Expanded(child: Text('Lap', style: TextStyle(color: Color(0xFF888888), fontSize: 12, fontWeight: FontWeight.w600))),
                Expanded(child: Text('Distance', style: TextStyle(color: Color(0xFF888888), fontSize: 12, fontWeight: FontWeight.w600))),
                Expanded(child: Text('Time', style: TextStyle(color: Color(0xFF888888), fontSize: 12, fontWeight: FontWeight.w600))),
                Expanded(child: Text('Avg HR', style: TextStyle(color: Color(0xFF888888), fontSize: 12, fontWeight: FontWeight.w600))),
                Expanded(child: Text('Pace', style: TextStyle(color: Color(0xFF888888), fontSize: 12, fontWeight: FontWeight.w600))),
              ],
            ),
          ),
          ...laps.asMap().entries.map((entry) {
            final i = entry.key;
            final lap = entry.value;
            final distKm = ((lap['distance'] ?? 0) / 1000);
            final time = lap['moving_time'] ?? 0;
            final m = (time ~/ 60).toString().padLeft(2, '0');
            final s = (time % 60).toString().padLeft(2, '0');
            final hr = lap['average_heartrate'];
            // Compute lap pace
            final lapPace = distKm > 0.01 && time > 0 ? _fmtPace((time / 60.0) / distKm) : '--';

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                border: i < laps.length - 1 ? const Border(bottom: BorderSide(color: _border)) : null,
              ),
              child: Row(
                children: [
                  Expanded(child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))),
                  Expanded(child: Text('${distKm.toStringAsFixed(2)} km', style: const TextStyle(color: Colors.white, fontSize: 13))),
                  Expanded(child: Text('$m:$s', style: const TextStyle(color: Colors.white, fontSize: 13))),
                  Expanded(child: Text(hr != null ? '${(hr as num).round()} bpm' : '--', style: TextStyle(color: hr != null ? _red : const Color(0xFF666666), fontSize: 13))),
                  Expanded(child: Text(lapPace, style: const TextStyle(color: _blue, fontSize: 13))),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String _fmtPace(double paceMinPerKm) {
    final m = paceMinPerKm.floor();
    final s = ((paceMinPerKm - m) * 60).round();
    return '$m:${s.toString().padLeft(2, '0')}/km';
  }
}
