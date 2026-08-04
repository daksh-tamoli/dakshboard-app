// ============================================================
// DAKSHboard — API Service
// Connects to Render.com FastAPI backend
// ============================================================

import 'package:dio/dio.dart';
import 'package:dakshboard_android/models/workout.dart';

class ApiService {
  static const String baseUrl = 'https://dakshboard-app.onrender.com';

  late final Dio _dio;

  String? _jwtToken;

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

    // Auth interceptor for JWT
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_jwtToken != null) {
          options.headers['Authorization'] = 'Bearer $_jwtToken';
        }
        return handler.next(options);
      },
    ));
  }

  void setToken(String token) {
    _jwtToken = token;
  }

  // Fetch workouts for the currently authenticated user
  Future<List<Workout>> fetchWorkouts({int? skip = 0, int? limit = 100}) async {
    try {
      final response = await _dio.get('/api/workouts/', queryParameters: {
        'skip': skip,
        'limit': limit,
      });
      final List<dynamic> data = response.data;
      return data.map((json) => Workout.fromJson(json as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException('Failed to load workouts: ${e.message}');
    }
  }

  // Trigger sync of latest Strava activities
  Future<Map<String, dynamic>> syncLatest() async {
    try {
      final response = await _dio.post('/api/strava/sync-latest');
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
