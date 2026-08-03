// ============================================================
// DAKSHboard — Workout Card Widget
// ============================================================

import 'package:flutter/material.dart';
import 'package:dakshboard_android/models/workout.dart';

class WorkoutCard extends StatelessWidget {
  final Workout workout;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const WorkoutCard({
    super.key,
    required this.workout,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2A2A2A)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Row: title + delete ───────────────────────
            Row(
              children: [
                Expanded(
                  child: Text(
                    workout.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (onDelete != null)
                  GestureDetector(
                    onTap: _confirmDelete(context),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 16),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              workout.formattedDate,
              style: const TextStyle(color: Color(0xFF888888), fontSize: 13),
            ),
            const SizedBox(height: 14),

            // ── Metric Pills ──────────────────────────────────
            Row(
              children: [
                _MetricPill(
                  icon: Icons.straighten_rounded,
                  value: '${workout.distanceKm.toStringAsFixed(2)} km',
                ),
                const SizedBox(width: 8),
                _MetricPill(
                  icon: Icons.timer_outlined,
                  value: workout.formattedDuration,
                ),
                if (workout.avgPace != null && workout.avgPace != 0) ...[
                  const SizedBox(width: 8),
                  _MetricPill(
                    icon: Icons.speed_rounded,
                    value: workout.formattedPace,
                  ),
                ],
              ],
            ),

            if (workout.avgHeartrate != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  _MetricPill(
                    icon: Icons.favorite_rounded,
                    value: '${workout.avgHeartrate} bpm avg',
                    color: Colors.redAccent,
                  ),
                  if (workout.maxHeartrate != null) ...[
                    const SizedBox(width: 8),
                    _MetricPill(
                      icon: Icons.favorite_rounded,
                      value: '${workout.maxHeartrate} bpm max',
                      color: Colors.redAccent.withOpacity(0.6),
                    ),
                  ],
                ],
              ),
            ],

            // ── Bottom: activity type badge ───────────────────
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.bottomRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${workout.categoryIcon} ${workout.type ?? workout.category}',
                  style: const TextStyle(color: Color(0xFF888888), fontSize: 11),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  VoidCallback? _confirmDelete(BuildContext context) {
    return () => showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Delete Workout', style: TextStyle(color: Colors.white)),
        content: Text(
          'Delete "${workout.title}"? This cannot be undone.',
          style: const TextStyle(color: Color(0xFFAAAAAA)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFFAAAAAA))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onDelete?.call();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color? color;

  const _MetricPill({required this.icon, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color ?? const Color(0xFFFC4C02)),
          const SizedBox(width: 5),
          Text(
            value,
            style: TextStyle(
              color: color ?? Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
