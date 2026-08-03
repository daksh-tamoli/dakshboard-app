// ============================================================
// DAKSHboard — Riverpod State Providers
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dakshboard_android/models/workout.dart';
import 'package:dakshboard_android/models/athlete.dart';
import 'package:dakshboard_android/services/api_service.dart';
import 'package:dakshboard_android/services/auth_service.dart';

// ─── Service Providers ───────────────────────────────────────

final apiServiceProvider = Provider<ApiService>((ref) => ApiService());
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

// ─── Athlete Provider ─────────────────────────────────────────

class AthleteNotifier extends AsyncNotifier<Athlete?> {
  @override
  Future<Athlete?> build() async {
    final auth = ref.read(authServiceProvider);
    return auth.getStoredAthlete();
  }

  Future<void> loginWithStrava() async {
    state = const AsyncValue.loading();
    final auth = ref.read(authServiceProvider);
    try {
      final athlete = await auth.loginWithStrava();
      state = AsyncValue.data(athlete);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> logout() async {
    final auth = ref.read(authServiceProvider);
    await auth.logout();
    state = const AsyncValue.data(null);
  }
}

final athleteProvider = AsyncNotifierProvider<AthleteNotifier, Athlete?>(
  AthleteNotifier.new,
);

// ─── Workouts Provider ────────────────────────────────────────

class WorkoutsNotifier extends AsyncNotifier<List<Workout>> {
  @override
  Future<List<Workout>> build() async {
    return _fetch();
  }

  Future<List<Workout>> _fetch() async {
    final api = ref.read(apiServiceProvider);
    final workouts = await api.fetchWorkouts();
    // Sort newest first
    workouts.sort((a, b) {
      if (a.date == null && b.date == null) return 0;
      if (a.date == null) return 1;
      if (b.date == null) return -1;
      return b.date!.compareTo(a.date!);
    });
    return workouts;
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetch());
  }

  Future<void> syncAndRefresh() async {
    final api = ref.read(apiServiceProvider);
    final auth = ref.read(authServiceProvider);
    final stravaId = await auth.getStravaId();
    state = const AsyncValue.loading();
    try {
      await api.syncLatest(stravaId: stravaId);
      state = await AsyncValue.guard(() => _fetch());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteWorkout(int id) async {
    final api = ref.read(apiServiceProvider);
    await api.deleteWorkout(id);
    await refresh();
  }
}

final workoutsProvider = AsyncNotifierProvider<WorkoutsNotifier, List<Workout>>(
  WorkoutsNotifier.new,
);

// ─── Selected Tab Provider ────────────────────────────────────

final selectedTabProvider = StateProvider<String>((ref) => 'All');

// ─── Filtered Workouts Provider ───────────────────────────────

final filteredWorkoutsProvider = Provider<List<Workout>>((ref) {
  final workoutsAsync = ref.watch(workoutsProvider);
  final selectedTab = ref.watch(selectedTabProvider);

  return workoutsAsync.when(
    data: (workouts) {
      if (selectedTab == 'All') return workouts;
      return workouts.where((w) => w.category == selectedTab).toList();
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

// ─── Category Counts Provider ─────────────────────────────────

final categoryCountsProvider = Provider<Map<String, int>>((ref) {
  final workoutsAsync = ref.watch(workoutsProvider);

  return workoutsAsync.when(
    data: (workouts) => {
      'All': workouts.length,
      'Run': workouts.where((w) => w.category == 'Run').length,
      'Ride': workouts.where((w) => w.category == 'Ride').length,
      'Swim': workouts.where((w) => w.category == 'Swim').length,
      'Other': workouts.where((w) => w.category == 'Other').length,
    },
    loading: () => {'All': 0, 'Run': 0, 'Ride': 0, 'Swim': 0, 'Other': 0},
    error: (_, __) => {'All': 0, 'Run': 0, 'Ride': 0, 'Swim': 0, 'Other': 0},
  );
});
