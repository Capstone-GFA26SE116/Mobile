import 'dart:math';
import 'package:dio/dio.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/storage_service.dart';
import '../models/auth_response.dart';

class AuthRepository {
  final ApiClient _apiClient;
  final StorageService _storageService;
  final GoogleSignIn _googleSignIn;

  AuthRepository({
    ApiClient? apiClient,
    StorageService? storageService,
    String? webClientId,
  })  : _apiClient = apiClient ?? ApiClient(),
        _storageService = storageService ?? StorageService(),
        _googleSignIn = GoogleSignIn(
          serverClientId: webClientId ??
              '1025047063269-c7u6uu9lvcjdsho711bkoksjr741cfuf.apps.googleusercontent.com',
          scopes: ['email', 'profile'],
        );

  // 1. Google Sign-In Flow
  Future<AuthResponse> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('User cancelled Google sign-in.');
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null || idToken.isEmpty) {
        throw Exception('Could not retrieve idToken from Google. Please check client configuration.');
      }

      final Response response = await _apiClient.dio.post(
        ApiEndpoints.loginGoogle,
        data: {'idToken': idToken},
      );

      if (response.statusCode == 200 && response.data != null) {
        final authResponse = AuthResponse.fromJson(response.data as Map<String, dynamic>);

        await _storageService.saveAuthData(
          accessToken: authResponse.accessToken,
          refreshToken: authResponse.refreshToken,
          userId: authResponse.userId,
          email: authResponse.email,
          fullName: authResponse.fullName,
          role: authResponse.role,
        );

        return authResponse;
      } else {
        throw Exception('Sign-in failed: Server returned status code ${response.statusCode}');
      }
    } on DioException catch (e) {
      final errorMessage = ApiClient.extractErrorMessage(e, 'Server connection error');
      throw Exception('Backend connection error: $errorMessage');
    }
  }

  // 2. Email & Password Sign-in Flow (Frontend parity)
  Future<AuthResponse> signInWithEmail(String email, String password) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanPassword = password.trim();

    if (!cleanEmail.contains('@') || !cleanEmail.contains('.')) {
      throw Exception('Invalid email address.');
    }
    if (cleanPassword.length < 6) {
      throw Exception('Password must be at least 6 characters.');
    }

    // Check saved credentials for local session parity
    final savedPwd = await _storageService.getRegisteredPassword(cleanEmail);
    final savedName = await _storageService.getRegisteredFullName(cleanEmail);

    if (savedPwd != null && savedPwd != cleanPassword) {
      throw Exception('Incorrect password.');
    }

    final fullName = savedName ?? (cleanEmail.split('@').first);
    final demoToken = 'demo_${Random().nextInt(99999999)}_${DateTime.now().millisecondsSinceEpoch}';

    final now = DateTime.now();
    final authResponse = AuthResponse(
      accessToken: demoToken,
      expiresAtUtc: now.add(const Duration(days: 7)),
      refreshToken: 'demo_refresh_${now.millisecondsSinceEpoch}',
      refreshTokenExpiresAtUtc: now.add(const Duration(days: 30)),
      userId: 'user_${cleanEmail.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}',
      email: cleanEmail,
      fullName: fullName,
      role: 'User',
    );

    await _storageService.saveAuthData(
      accessToken: authResponse.accessToken,
      refreshToken: authResponse.refreshToken,
      userId: authResponse.userId,
      email: authResponse.email,
      fullName: authResponse.fullName,
      role: authResponse.role,
    );

    return authResponse;
  }

  // 3. Email Account Registration Flow
  Future<void> registerWithEmail({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanName = fullName.trim();
    final cleanPassword = password.trim();

    if (cleanName.isEmpty) {
      throw Exception('Please enter your full name.');
    }
    if (!cleanEmail.contains('@') || !cleanEmail.contains('.')) {
      throw Exception('Invalid email address.');
    }
    if (cleanPassword.length < 8) {
      throw Exception('Password must be at least 8 characters.');
    }

    await _storageService.saveRegisteredAccount(
      email: cleanEmail,
      password: cleanPassword,
      fullName: cleanName,
    );
  }

  // 4. Token Refresh
  Future<AuthResponse> refreshToken() async {
    final currentRefreshToken = await _storageService.getRefreshToken();
    if (currentRefreshToken == null) {
      throw Exception('Refresh token not found');
    }

    if (currentRefreshToken.startsWith('demo_')) {
      final currentEmail = await _storageService.getEmail() ?? 'user@metanoia.io';
      final currentName = await _storageService.getFullName() ?? 'Metanoia User';
      final now = DateTime.now();
      final authResponse = AuthResponse(
        accessToken: 'demo_${now.millisecondsSinceEpoch}',
        expiresAtUtc: now.add(const Duration(days: 7)),
        refreshToken: currentRefreshToken,
        refreshTokenExpiresAtUtc: now.add(const Duration(days: 30)),
        userId: await _storageService.getUserId() ?? 'user_local',
        email: currentEmail,
        fullName: currentName,
        role: 'User',
      );
      return authResponse;
    }

    final Response response = await _apiClient.dio.post(
      ApiEndpoints.refreshToken,
      data: {'refreshToken': currentRefreshToken},
    );

    final authResponse = AuthResponse.fromJson(response.data as Map<String, dynamic>);
    await _storageService.saveAuthData(
      accessToken: authResponse.accessToken,
      refreshToken: authResponse.refreshToken,
      userId: authResponse.userId,
      email: authResponse.email,
      fullName: authResponse.fullName,
      role: authResponse.role,
    );

    return authResponse;
  }

  // 5. Logout
  Future<void> logout() async {
    final currentRefreshToken = await _storageService.getRefreshToken();
    try {
      if (currentRefreshToken != null && !currentRefreshToken.startsWith('demo_')) {
        await _apiClient.dio.post(
          ApiEndpoints.refreshToken,
          data: {
            'refreshToken': currentRefreshToken,
            'allDevices': true,
          },
        );
      }
    } finally {
      await _storageService.clearAuth();
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
    }
  }
}