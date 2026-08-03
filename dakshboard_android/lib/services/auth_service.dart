// ============================================================
// DAKSHboard — Auth Service (Rewritten for reliability)
// OAuth: gets strava_id from callback, then fetches profile via API
// ============================================================

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:dakshboard_android/models/athlete.dart';
import 'package:dakshboard_android/services/api_service.dart';

class AuthService {
  static const String _athleteKey = 'strava_athlete';
  static const String _stravaIdKey = 'strava_id';

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  final _api = ApiService();

  // ─── Main Login Flow ───────────────────────────────────────
  Future<Athlete?> loginWithStrava() async {
    const callbackScheme = 'com.dakshtamoli.dakshboard';
    final loginUrl = _api.stravaLoginUrlWithOrigin('$callbackScheme://oauth/callback');

    debugPrint('[Auth] Opening Strava login: $loginUrl');

    String result;
    try {
      result = await FlutterWebAuth2.authenticate(
        url: loginUrl,
        callbackUrlScheme: callbackScheme,
      );
    } catch (e) {
      debugPrint('[Auth] FlutterWebAuth2 error: $e');
      throw AuthException('Browser authentication failed: $e');
    }

    debugPrint('[Auth] Callback received: $result');

    // Parse the callback URL — only need strava_id (simple integer)
    final uri = Uri.parse(result);
    final auth = uri.queryParameters['auth'];

    if (auth != 'success') {
      final reason = uri.queryParameters['reason'] ?? 'Unknown error';
      debugPrint('[Auth] Auth failed: $reason');
      throw AuthException('Strava authorization failed: $reason');
    }

    final stravaIdStr = uri.queryParameters['strava_id'];
    if (stravaIdStr == null) {
      debugPrint('[Auth] No strava_id in callback. Full URI: $result');
      throw AuthException('Authentication succeeded but no strava_id received.');
    }

    final stravaId = int.tryParse(stravaIdStr);
    if (stravaId == null) {
      throw AuthException('Invalid strava_id received: $stravaIdStr');
    }

    debugPrint('[Auth] Got strava_id: $stravaId — fetching profile from backend...');

    // Fetch full athlete profile from backend database (reliable, no URL encoding)
    try {
      final dio = Dio(BaseOptions(
        baseUrl: ApiService.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ));
      final response = await dio.get('/api/auth/me', queryParameters: {'strava_id': stravaId});
      final data = response.data as Map<String, dynamic>;
      debugPrint('[Auth] Got athlete data: $data');

      final athlete = Athlete(
        id: data['id'] as int,
        firstname: data['firstname'] as String? ?? '',
        lastname: data['lastname'] as String? ?? '',
        profileUrl: data['profile'] as String?,
      );

      await saveAthlete(athlete);
      return athlete;
    } on DioException catch (e) {
      debugPrint('[Auth] Failed to fetch athlete profile: ${e.message}');
      // Fallback: create a minimal athlete with just the strava_id so they can at least log in
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

  // ─── Storage ───────────────────────────────────────────────

  Future<void> saveAthlete(Athlete athlete) async {
    try {
      await _storage.write(key: _athleteKey, value: jsonEncode(athlete.toJson()));
      await _storage.write(key: _stravaIdKey, value: athlete.id.toString());
      debugPrint('[Auth] Athlete saved: ${athlete.id}');
    } catch (e) {
      debugPrint('[Auth] Storage write error, retrying after clear: $e');
      try {
        await _storage.deleteAll();
        await _storage.write(key: _athleteKey, value: jsonEncode(athlete.toJson()));
        await _storage.write(key: _stravaIdKey, value: athlete.id.toString());
      } catch (e2) {
        debugPrint('[Auth] Storage retry failed: $e2');
      }
    }
  }

  Future<Athlete?> getStoredAthlete() async {
    try {
      final json = await _storage.read(key: _athleteKey);
      if (json == null) return null;
      return Athlete.fromJson(jsonDecode(json));
    } catch (e) {
      debugPrint('[Auth] Storage read error: $e');
      try { await _storage.deleteAll(); } catch (_) {}
      return null;
    }
  }

  Future<int?> getStravaId() async {
    try {
      final val = await _storage.read(key: _stravaIdKey);
      return val != null ? int.tryParse(val) : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> logout() async {
    try { await _storage.deleteAll(); } catch (_) {}
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
