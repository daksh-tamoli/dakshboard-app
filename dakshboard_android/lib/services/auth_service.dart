// ============================================================
// DAKSHboard — Auth Service
// Strava OAuth using flutter_web_auth_2 (in-app browser)
// ============================================================

import 'dart:convert';
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

  // Trigger Strava OAuth flow via in-app browser
  // Returns the authenticated Athlete on success
  Future<Athlete?> loginWithStrava() async {
    const callbackScheme = 'com.dakshtamoli.dakshboard';

    // The backend will redirect back to our Render backend after auth
    // but we use the state param to carry our own redirect target
    // For mobile, we intercept the callback using the custom scheme
    final loginUrl = _api.stravaLoginUrlWithOrigin('$callbackScheme://oauth/callback');

    try {
      final result = await FlutterWebAuth2.authenticate(
        url: loginUrl,
        callbackUrlScheme: callbackScheme,
      );

      // The callback URL will contain auth=success&athlete=...
      final uri = Uri.parse(result);
      final athleteParam = uri.queryParameters['athlete'];

      if (athleteParam != null) {
        final athleteJson = jsonDecode(Uri.decodeComponent(athleteParam));
        final athlete = Athlete.fromJson(athleteJson);
        await saveAthlete(athlete);
        return athlete;
      }
    } catch (e) {
      throw AuthException('Strava authentication failed: $e');
    }
    return null;
  }

  // Save athlete to secure storage
  Future<void> saveAthlete(Athlete athlete) async {
    await _storage.write(key: _athleteKey, value: jsonEncode(athlete.toJson()));
    await _storage.write(key: _stravaIdKey, value: athlete.id.toString());
  }

  // Load stored athlete
  Future<Athlete?> getStoredAthlete() async {
    final json = await _storage.read(key: _athleteKey);
    if (json == null) return null;
    try {
      return Athlete.fromJson(jsonDecode(json));
    } catch (_) {
      return null;
    }
  }

  // Get stored strava_id
  Future<int?> getStravaId() async {
    final val = await _storage.read(key: _stravaIdKey);
    return val != null ? int.tryParse(val) : null;
  }

  // Logout — clear all stored credentials
  Future<void> logout() async {
    await _storage.deleteAll();
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    final athlete = await getStoredAthlete();
    return athlete != null;
  }
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}
