import 'package:flutter/material.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/storage_service.dart';
import '../../home/screens/main_shell_screen.dart';
import '../../onboarding/screens/onboarding_screen.dart';
import 'login_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final StorageService _storageService = StorageService();
  final ApiClient _apiClient = ApiClient();

  Widget? _targetScreen;

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    // 1. Check if token is stored in secure local storage
    final token = await _storageService.getAccessToken();

    if (token == null || token.isEmpty) {
      if (mounted) {
        setState(() {
          _targetScreen = const LoginScreen();
        });
      }
      return;
    }

    // 2. Verify token validity and onboarding status via /api/me
    try {
      final response = await _apiClient.dio.get(ApiEndpoints.me);
      if (response.statusCode == 200 && response.data != null) {
        final isOnboardingCompleted =
            response.data['onboardingCompleted'] as bool? ?? false;

        if (mounted) {
          setState(() {
            _targetScreen = isOnboardingCompleted
                ? const MainShellScreen()
                : const OnboardingScreen();
          });
        }
        return;
      }
    } catch (e) {
      // 401 Unauthorized: token expired -> clear tokens and route to Login
      if (e.toString().contains('401')) {
        await _storageService.clearTokens();
        if (mounted) {
          setState(() {
            _targetScreen = const LoginScreen();
          });
        }
        return;
      }

      // Network error / offline fallback: navigate to MainShell
      if (mounted) {
        setState(() {
          _targetScreen = const MainShellScreen();
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _targetScreen = const MainShellScreen();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_targetScreen != null) {
      return _targetScreen!;
    }

    // Splash screen while validating session
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Text(
                'M',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 28,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'METANOIA',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Cognitive Scheduling Engine',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 36),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
