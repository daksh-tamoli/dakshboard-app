// ============================================================
// DAKSHboard — API Service
// Connects to Render.com FastAPI backend
// ============================================================

import 'package:dio/dio.dart';
import 'package:dakshboard_android/models/workout.dart';

class ApiService {
  static const String baseUrl = 'https://dakshboard-app.onrender.com';

  late final Dio _dio;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));

    // Logging interceptor for debugging
    _dio.interceptors.add(LogInterceptor(
      requestBody: false,
      responseBody: false,
      error: true,
    ));
  }

  // Fetch all workouts
  Future<List<Workout>> fetchWorkouts() async {
    try {
      final response = await _dio.get('/api/workouts/');
      final List<dynamic> data = response.data;
      return data.map((json) => Workout.fromJson(json)).toList();
    } on DioException catch (e) {
      throw ApiException('Failed to load workouts: ${e.message}');
    }
  }

  // Trigger sync of latest Strava activities
  Future<Map<String, dynamic>> syncLatest({int? stravaId}) async {
    try {
      final Map<String, dynamic>? params = stravaId != null ? {'strava_id': stravaId} : null;
      final response = await _dio.get('/api/strava/sync-latest', queryParameters: params);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException('Sync failed: ${e.message}');
    }
  }

  // Delete a workout
  Future<void> deleteWorkout(int id) async {
    try {
      await _dio.delete('/api/workouts/$id');
    } on DioException catch (e) {
      throw ApiException('Delete failed: ${e.message}');
    }
  }

  // Build Strava OAuth login URL (used by auth service)
  String get stravaLoginUrl => '$baseUrl/api/auth/login';

  // Build full OAuth login URL with frontend origin
  String stravaLoginUrlWithOrigin(String frontendOrigin) =>
      '$stravaLoginUrl?frontend_origin=${Uri.encodeComponent(frontendOrigin)}';
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}
