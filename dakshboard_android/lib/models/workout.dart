// ============================================================
// DAKSHboard — Workout Model
// ============================================================

class Workout {
  final int? id;
  final String title;
  final String? type;
  final double distanceKm;
  final int movingTimeSec;
  final double? avgPace;
  final int? avgHeartrate;
  final int? maxHeartrate;
  final double? elevationGain;
  final DateTime? date;
  final String? paceStream;
  final String? heartrateStream;
  final String? laps;

  Workout({
    this.id,
    required this.title,
    this.type,
    required this.distanceKm,
    required this.movingTimeSec,
    this.avgPace,
    this.avgHeartrate,
    this.maxHeartrate,
    this.elevationGain,
    this.date,
    this.paceStream,
    this.heartrateStream,
    this.laps,
  });

  factory Workout.fromJson(Map<String, dynamic> json) {
    // Backend uses SQLAlchemy column names — must match exactly
    final distanceKm = (json['total_distance'] ?? json['distance_km'] ?? 0.0).toDouble();
    final movingTimeSec = (json['moving_time'] ?? json['moving_time_sec'] ?? 0).toInt();

    // Compute pace (min/km) from distance + time since backend doesn't store it
    double? computedPace;
    if (distanceKm > 0 && movingTimeSec > 0) {
      computedPace = (movingTimeSec / 60.0) / distanceKm;
    }

    return Workout(
      id: json['id'],
      // Backend has no 'title' column — derive from type
      title: json['title'] ?? json['type'] ?? 'Workout',
      type: json['type'],
      distanceKm: distanceKm,
      movingTimeSec: movingTimeSec,
      avgPace: json['avg_pace']?.toDouble() ?? computedPace,
      // Backend stores average_heartrate (float), not avg_heartrate
      avgHeartrate: json['average_heartrate']?.toInt() ?? json['avg_heartrate']?.toInt(),
      maxHeartrate: json['max_heartrate']?.toInt(),
      // Backend stores total_elevation_gain, not elevation_gain
      elevationGain: (json['total_elevation_gain'] ?? json['elevation_gain'])?.toDouble(),
      date: json['date'] != null ? DateTime.tryParse(json['date'].toString()) : null,
      paceStream: json['pace_stream'],
      heartrateStream: json['heartrate_stream'],
      // Backend stores laps_data, not laps
      laps: json['laps_data'] ?? json['laps'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'type': type,
    'distance_km': distanceKm,
    'moving_time_sec': movingTimeSec,
    'avg_pace': avgPace,
    'avg_heartrate': avgHeartrate,
    'max_heartrate': maxHeartrate,
    'elevation_gain': elevationGain,
    'date': date?.toIso8601String(),
    'pace_stream': paceStream,
    'heartrate_stream': heartrateStream,
    'laps': laps,
  };

  // Category matching (same logic as web)
  String get category {
    final t = (type ?? '').toLowerCase();
    if (['run', 'walk', 'hike'].any((k) => t.contains(k))) return 'Run';
    if (['ride', 'cycle', 'virtual'].any((k) => t.contains(k))) return 'Ride';
    if (t.contains('swim')) return 'Swim';
    return 'Other';
  }

  // Display category icon
  String get categoryIcon {
    switch (category) {
      case 'Run': return '🏃';
      case 'Ride': return '🚴';
      case 'Swim': return '🏊';
      default: return '💪';
    }
  }

  // Formatted duration
  String get formattedDuration {
    final h = movingTimeSec ~/ 3600;
    final m = (movingTimeSec % 3600) ~/ 60;
    final s = movingTimeSec % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }

  // Formatted pace (min/km)
  String get formattedPace {
    if (avgPace == null || avgPace == 0) return '--';
    final total = avgPace!;
    final m = total.floor();
    final s = ((total - m) * 60).round();
    return '$m:${s.toString().padLeft(2, '0')} /km';
  }

  // Formatted date
  String get formattedDate {
    if (date == null) return '--';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date!.day} ${months[date!.month - 1]} ${date!.year}';
  }
}
