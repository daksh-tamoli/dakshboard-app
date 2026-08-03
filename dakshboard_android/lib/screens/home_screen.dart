// ============================================================
// DAKSHboard — Home Screen
// Workout feed with Run/Ride/Swim/Other tab filters
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dakshboard_android/providers/providers.dart';
import 'package:dakshboard_android/models/workout.dart';
import 'package:dakshboard_android/widgets/workout_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isSyncing = false;

  Future<void> _triggerSync() async {
    setState(() => _isSyncing = true);
    try {
      await ref.read(workoutsProvider.notifier).syncAndRefresh();
    } catch (_) {}
    if (mounted) setState(() => _isSyncing = false);
  }

  @override
  Widget build(BuildContext context) {
    final athleteAsync = ref.watch(athleteProvider);
    final workoutsAsync = ref.watch(workoutsProvider);
    final selectedTab = ref.watch(selectedTabProvider);
    final filteredWorkouts = ref.watch(filteredWorkoutsProvider);
    final counts = ref.watch(categoryCountsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('DAKSHboard'),
        actions: [
          // Sync button
          IconButton(
            tooltip: 'Sync from Strava',
            onPressed: _isSyncing ? null : _triggerSync,
            icon: _isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFC4C02)),
                  )
                : const Icon(Icons.sync_rounded),
          ),
          // GPS Tracking
          IconButton(
            tooltip: 'Start GPS Run',
            onPressed: () => context.push('/gps'),
            icon: const Icon(Icons.gps_fixed_rounded, color: Color(0xFFFC4C02)),
          ),
          // Athlete avatar
          athleteAsync.when(
            data: (athlete) {
              if (athlete == null) return const SizedBox.shrink();
              return GestureDetector(
                onTap: () => context.push('/profile'),
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFF2A2A2A),
                    backgroundImage: athlete.profileUrl != null
                        ? CachedNetworkImageProvider(athlete.profileUrl!)
                        : null,
                    child: athlete.profileUrl == null
                        ? Text(athlete.initials, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))
                        : null,
                  ),
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(workoutsProvider.notifier).refresh(),
        color: const Color(0xFFFC4C02),
        child: CustomScrollView(
          slivers: [
            // ─── Stats Summary Header ─────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: workoutsAsync.when(
                  data: (workouts) => _StatsHeader(workouts: workouts),
                  loading: () => const SizedBox(height: 80),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ),
            ),

            // ─── Tab Filter Row ───────────────────────────────
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabHeaderDelegate(
                child: Container(
                  color: const Color(0xFF121212),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        _buildTab('All', counts['All']!, selectedTab, ref),
                        const SizedBox(width: 8),
                        _buildTab('Run', counts['Run']!, selectedTab, ref),
                        const SizedBox(width: 8),
                        _buildTab('Ride', counts['Ride']!, selectedTab, ref),
                        const SizedBox(width: 8),
                        _buildTab('Swim', counts['Swim']!, selectedTab, ref),
                        const SizedBox(width: 8),
                        _buildTab('Other', counts['Other']!, selectedTab, ref),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ─── Workout Cards List ───────────────────────────
            workoutsAsync.when(
              data: (_) {
                if (filteredWorkouts.isEmpty) {
                  return SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.fitness_center, size: 64, color: Colors.white.withOpacity(0.1)),
                          const SizedBox(height: 16),
                          Text(
                            'No workouts found',
                            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: _triggerSync,
                            icon: const Icon(Icons.sync, size: 18),
                            label: const Text('Sync from Strava'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final workout = filteredWorkouts[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: WorkoutCard(
                            workout: workout,
                            onTap: () => context.push('/workout/${workout.id}', extra: workout),
                            onDelete: () => ref.read(workoutsProvider.notifier).deleteWorkout(workout.id!),
                          ),
                        );
                      },
                      childCount: filteredWorkouts.length,
                    ),
                  ),
                );
              },
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: Color(0xFFFC4C02))),
              ),
              error: (e, _) => SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi_off_rounded, color: Colors.redAccent, size: 48),
                      const SizedBox(height: 12),
                      Text('Failed to load workouts', style: TextStyle(color: Colors.white.withOpacity(0.6))),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => ref.read(workoutsProvider.notifier).refresh(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/gps'),
        backgroundColor: const Color(0xFFFC4C02),
        icon: const Icon(Icons.play_arrow_rounded),
        label: const Text('Start Run', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildTab(String label, int count, String selected, WidgetRef ref) {
    final isSelected = selected == label;
    return GestureDetector(
      onTap: () => ref.read(selectedTabProvider.notifier).state = label,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFC4C02) : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFFFC4C02) : const Color(0xFF2A2A2A),
          ),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFFAAAAAA),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withOpacity(0.2) : const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF888888),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Stats Header ─────────────────────────────────────────────

class _StatsHeader extends StatelessWidget {
  final List<Workout> workouts;

  const _StatsHeader({required this.workouts});

  @override
  Widget build(BuildContext context) {
    final totalKm = workouts.fold<double>(0, (sum, w) => sum + w.distanceKm);
    final totalTime = workouts.fold<int>(0, (sum, w) => sum + w.movingTimeSec);
    final totalHours = totalTime ~/ 3600;
    final totalMin = (totalTime % 3600) ~/ 60;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Row(
        children: [
          _StatTile(label: 'Total Runs', value: '${workouts.length}'),
          _divider(),
          _StatTile(label: 'Distance', value: '${totalKm.toStringAsFixed(0)}km'),
          _divider(),
          _StatTile(label: 'Time', value: '${totalHours}h ${totalMin}m'),
        ],
      ),
    );
  }

  Widget _divider() => Container(
    width: 1,
    height: 32,
    color: const Color(0xFF2A2A2A),
    margin: const EdgeInsets.symmetric(horizontal: 12),
  );
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;

  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Color(0xFF888888), fontSize: 12)),
        ],
      ),
    );
  }
}

// ─── Sticky Header Delegate ───────────────────────────────────

class _TabHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _TabHeaderDelegate({required this.child});

  @override
  double get minExtent => 60;

  @override
  double get maxExtent => 60;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(_TabHeaderDelegate oldDelegate) => false;
}
