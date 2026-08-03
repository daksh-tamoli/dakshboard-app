// ============================================================
// DAKSHboard — Auth Service (Clean rewrite using SharedPreferences)
// Multi-modal auth: Browser Deep Link + Instant Sync fallback
// ============================================================

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:dakshboard_android/models/athlete.dart';
import 'package:dakshboard_android/services/api_service.dart';

class AuthService {
  static const String _athleteKey = 'strava_athlete';
  static const String _stravaIdKey = 'strava_id';

  // ─── Primary OAuth Flow ───────────────────────────────────
  Future<Athlete?> loginWithStrava() async {
    const callbackScheme = 'com.dakshtamoli.dakshboard';
    final api = ApiService();
    final loginUrl = api.stravaLoginUrlWithOrigin('$callbackScheme://oauth/callback');

    debugPrint('[Auth] Opening Strava login: $loginUrl');

    String result;
    try {
      result = await FlutterWebAuth2.authenticate(
        url: loginUrl,
        callbackUrlScheme: callbackScheme,
      );
    } catch (e) {
      debugPrint('[Auth] Browser auth error: $e');
      // If browser custom tab didn't auto-redirect, try fetching the latest authenticated account
      return await loginWithLatestAccount();
    }

    debugPrint('[Auth] Callback received: $result');

    final uri = Uri.parse(result);
    final stravaIdStr = uri.queryParameters['strava_id'];
    if (stravaIdStr != null) {
      final stravaId = int.tryParse(stravaIdStr);
      if (stravaId != null) {
        return await fetchAndSaveAthleteByStravaId(stravaId);
      }
    }

    return await loginWithLatestAccount();
  }

  // ─── Fallback Account Sync ────────────────────────────────
  Future<Athlete?> loginWithLatestAccount() async {
    debugPrint('[Auth] Fetching latest account from backend...');
    try {
      final dio = Dio(BaseOptions(
        baseUrl: ApiService.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ));
      final response = await dio.get('/api/auth/latest');
      final data = response.data as Map<String, dynamic>;

      final athlete = Athlete(
        id: data['id'] as int,
        firstname: data['firstname'] as String? ?? 'Athlete',
        lastname: data['lastname'] as String? ?? '',
        profileUrl: data['profile'] as String?,
      );

      await saveAthlete(athlete);
      return athlete;
    } on DioException catch (e) {
      debugPrint('[Auth] Latest account fetch failed: ${e.message}');
      throw AuthException('No authorized Strava account found. Please connect first.');
    }
  }

  // ─── Fetch Athlete by ID ──────────────────────────────────
  Future<Athlete?> fetchAndSaveAthleteByStravaId(int stravaId) async {
    try {
      final dio = Dio(BaseOptions(
        baseUrl: ApiService.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ));
      final response = await dio.get('/api/auth/me', queryParameters: {'strava_id': stravaId});
      final data = response.data as Map<String, dynamic>;

      final athlete = Athlete(
        id: data['id'] as int,
        firstname: data['firstname'] as String? ?? 'Athlete',
        lastname: data['lastname'] as String? ?? '',
        profileUrl: data['profile'] as String?,
      );

      await saveAthlete(athlete);
      return athlete;
    } on DioException catch (_) {
      final fallbackAthlete = Athlete(
        id: stravaId,
        firstname: 'Athlete',
        lastname: '',
        profileUrl: null,
      );
      await saveAthlete(fallbackAthlete);
      return fallbackAthlete;
    }
  }

  // ─── Storage (SharedPreferences — 100% Reliable) ─────────

  Future<void> saveAthlete(Athlete athlete) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_athleteKey, jsonEncode(athlete.toJson()));
    await prefs.setInt(_stravaIdKey, athlete.id);
    debugPrint('[Auth] Athlete saved via SharedPreferences: ${athlete.id}');
  }

  Future<Athlete?> getStoredAthlete() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_athleteKey);
      if (jsonStr == null) return null;
      return Athlete.fromJson(jsonDecode(jsonStr));
    } catch (e) {
      debugPrint('[Auth] Read error: $e');
      return null;
    }
  }

  Future<int?> getStravaId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_stravaIdKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_athleteKey);
    await prefs.remove(_stravaIdKey);
  }

  Future<bool> isLoggedIn() async {
    return (await getStoredAthlete()) != null;
  }
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}
