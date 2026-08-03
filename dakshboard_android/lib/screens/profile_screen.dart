// ============================================================
// DAKSHboard — Profile Screen
// Athlete info + all-time stats
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dakshboard_android/providers/providers.dart';
import 'package:dakshboard_android/models/workout.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final athleteAsync = ref.watch(athleteProvider);
    final workoutsAsync = ref.watch(workoutsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(athleteProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
            child: const Text('Logout', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
      body: athleteAsync.when(
        data: (athlete) {
          if (athlete == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/login'));
            return const SizedBox.shrink();
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 16),

                // ── Avatar ────────────────────────────────
                CircleAvatar(
                  radius: 52,
                  backgroundColor: const Color(0xFF2A2A2A),
                  backgroundImage: athlete.profileUrl != null
                      ? CachedNetworkImageProvider(athlete.profileUrl!)
                      : null,
                  child: athlete.profileUrl == null
                      ? Text(
                          athlete.initials,
                          style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
                        )
                      : null,
                ),
                const SizedBox(height: 16),

                // ── Name ──────────────────────────────────
                Text(
                  athlete.fullName,
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                if (athlete.city != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.location_on_outlined, color: Color(0xFF888888), size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '${athlete.city}, ${athlete.country ?? ''}',
                        style: const TextStyle(color: Color(0xFF888888), fontSize: 13),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 32),

                // ── All-Time Stats ────────────────────────
                workoutsAsync.when(
                  data: (workouts) => _AllTimeStats(workouts: workouts),
                  loading: () => const CircularProgressIndicator(color: Color(0xFFFC4C02)),
                  error: (_, __) => const SizedBox.shrink(),
                ),

                const SizedBox(height: 24),

                // ── Settings Link ─────────────────────────
                ListTile(
                  tileColor: const Color(0xFF1E1E1E),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  leading: const Icon(Icons.settings_rounded, color: Color(0xFFAAAAAA)),
                  title: const Text('Settings', style: TextStyle(color: Colors.white)),
                  trailing: const Icon(Icons.chevron_right, color: Color(0xFF666666)),
                  onTap: () => context.push('/settings'),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFFC4C02))),
        error: (_, __) => const Center(child: Text('Failed to load profile', style: TextStyle(color: Colors.white))),
      ),
    );
  }
}

class _AllTimeStats extends StatelessWidget {
  final List<Workout> workouts;

  const _AllTimeStats({required this.workouts});

  @override
  Widget build(BuildContext context) {
    final totalKm = workouts.fold<double>(0, (s, w) => s + w.distanceKm);
    final totalSec = workouts.fold<int>(0, (s, w) => s + w.movingTimeSec);
    final totalHours = (totalSec / 3600).toStringAsFixed(1);
    final runs = workouts.where((w) => w.category == 'Run').length;
    final rides = workouts.where((w) => w.category == 'Ride').length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'All-Time Stats',
            style: TextStyle(color: Color(0xFF888888), fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _Stat(label: 'Total km', value: totalKm.toStringAsFixed(0)),
              _vDivider(),
              _Stat(label: 'Total Hours', value: totalHours),
              _vDivider(),
              _Stat(label: 'Activities', value: '${workouts.length}'),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFF2A2A2A)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _Stat(label: '🏃 Runs', value: '$runs'),
              _vDivider(),
              _Stat(label: '🚴 Rides', value: '$rides'),
              _vDivider(),
              _Stat(label: '💪 Other', value: '${workouts.length - runs - rides}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _vDivider() => Container(width: 1, height: 40, color: const Color(0xFF2A2A2A));
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;

  const _Stat({required this.label, required this.value});

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
