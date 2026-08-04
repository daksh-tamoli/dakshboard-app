// ============================================================
// DAKSHboard Flutter App — main.dart
// Entry point: theme, routing, Riverpod bootstrap
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dakshboard_android/screens/splash_screen.dart';
import 'package:dakshboard_android/screens/login_screen.dart';
import 'package:dakshboard_android/screens/home_screen.dart';
import 'package:dakshboard_android/screens/workout_detail_screen.dart';
import 'package:dakshboard_android/screens/gps_tracking_screen.dart';
import 'package:dakshboard_android/screens/profile_screen.dart';
import 'package:dakshboard_android/screens/settings_screen.dart';
import 'dart:convert';
import 'package:dakshboard_android/models/athlete.dart';
import 'package:dakshboard_android/models/workout.dart';
import 'package:dakshboard_android/providers/providers.dart';

import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Lock to portrait mode
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Dark status bar
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  runApp(const ProviderScope(child: DAKSHboardApp()));
}

final _router = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
    GoRoute(
      path: '/workout/:id',
      builder: (context, state) {
        final workout = state.extra as Workout;
        return WorkoutDetailScreen(workout: workout);
      },
    ),
    GoRoute(path: '/gps', builder: (context, state) => const GpsTrackingScreen()),
    GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
    GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
    GoRoute(
      path: '/oauth/callback',
      builder: (context, state) {
        final athleteParam = state.uri.queryParameters['athlete'];
        return OAuthCallbackHandler(athleteParam: athleteParam);
      },
    ),
  ],
);

class OAuthCallbackHandler extends ConsumerStatefulWidget {
  final String? athleteParam;
  const OAuthCallbackHandler({super.key, this.athleteParam});

  @override
  ConsumerState<OAuthCallbackHandler> createState() => _OAuthCallbackHandlerState();
}

class _OAuthCallbackHandlerState extends ConsumerState<OAuthCallbackHandler> {
  @override
  void initState() {
    super.initState();
    _processAuth();
  }

  Future<void> _processAuth() async {
    if (widget.athleteParam != null && widget.athleteParam!.isNotEmpty) {
      try {
        final decodedJson = jsonDecode(Uri.decodeComponent(widget.athleteParam!));
        final athlete = Athlete.fromJson(decodedJson);
        final auth = ref.read(authServiceProvider);
        await auth.saveAthlete(athlete);
        ref.invalidate(athleteProvider);
        if (mounted) {
          context.go('/home');
          return;
        }
      } catch (e) {
        debugPrint('OAuth callback parse error: $e');
      }
    }
    if (mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF121212),
      body: Center(
        child: CircularProgressIndicator(color: Color(0xFFFC4C02)),
      ),
    );
  }
}

class DAKSHboardApp extends StatelessWidget {
  const DAKSHboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'DAKSHboard',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      theme: _buildDarkTheme(),
    );
  }

  ThemeData _buildDarkTheme() {
    const stravaOrange = Color(0xFFFC4C02);
    const background = Color(0xFF121212);
    const surface = Color(0xFF1E1E1E);
    const surfaceVariant = Color(0xFF2A2A2A);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.dark(
        primary: stravaOrange,
        secondary: stravaOrange,
        surface: surface,
        surfaceContainerHighest: surfaceVariant,
        background: background,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 28),
        headlineMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
        titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18),
        titleMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 16),
        bodyLarge: TextStyle(color: Colors.white, fontSize: 16),
        bodyMedium: TextStyle(color: Color(0xFFAAAAAA), fontSize: 14),
        labelLarge: TextStyle(color: stravaOrange, fontWeight: FontWeight.bold, fontSize: 14),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: surfaceVariant, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: stravaOrange,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceVariant,
        selectedColor: stravaOrange.withOpacity(0.2),
        labelStyle: const TextStyle(color: Colors.white, fontSize: 13),
        side: const BorderSide(color: Colors.transparent),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: stravaOrange,
        unselectedItemColor: Color(0xFF666666),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }
}
