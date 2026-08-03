// ============================================================
// DAKSHboard — Login Screen
// Strava OAuth login with in-app browser
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dakshboard_android/providers/providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handleStravaLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(athleteProvider.notifier).loginWithStrava();
      if (mounted) {
        final athlete = ref.read(athleteProvider).value;
        if (athlete != null) {
          context.go('/home');
        } else {
          setState(() {
            _errorMessage = 'Authentication failed. Please try again.';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleLatestAccountSync() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final auth = ref.read(authServiceProvider);
      final athlete = await auth.loginWithLatestAccount();
      if (mounted) {
        if (athlete != null) {
          ref.invalidate(athleteProvider);
          context.go('/home');
        } else {
          setState(() {
            _errorMessage = 'No authorized Strava account found.';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Please authorize in browser first.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Logo
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFFFC4C02),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(Icons.flash_on_rounded, color: Colors.white, size: 44),
              ),
              const SizedBox(height: 24),
              const Text(
                'DAKSHboard',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Your personal athletic\nperformance dashboard',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 16,
                  height: 1.5,
                ),
              ),

              const Spacer(flex: 2),

              // Feature highlights
              _FeatureRow(icon: Icons.directions_run, text: 'GPS Run Tracking'),
              const SizedBox(height: 12),
              _FeatureRow(icon: Icons.bar_chart_rounded, text: 'Detailed Pace & HR Analytics'),
              const SizedBox(height: 12),
              _FeatureRow(icon: Icons.notifications_rounded, text: 'Smart Training Reminders'),
              const SizedBox(height: 12),
              _FeatureRow(icon: Icons.share_rounded, text: 'Share Workouts to Instagram'),

              const Spacer(flex: 1),

              // Error message
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Connect with Strava button
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _handleStravaLogin,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.link_rounded, size: 22),
                label: Text(_isLoading ? 'Connecting...' : 'Connect with Strava'),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: _isLoading ? null : _handleLatestAccountSync,
                icon: const Icon(Icons.sync_rounded, size: 18, color: Color(0xFFFC4C02)),
                label: const Text(
                  'Already Authorized? Tap to Sync',
                  style: TextStyle(color: Color(0xFFFC4C02), fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'We only read your workout data.\nYour data stays private.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFFC4C02).withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFFFC4C02), size: 20),
        ),
        const SizedBox(width: 14),
        Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
      ],
    );
  }
}
