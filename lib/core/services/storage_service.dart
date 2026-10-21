import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const String _keyAccessToken = 'access_token';
  static const String _keyRefreshToken = 'refresh_token';
  static const String _keyUserId = 'user_id';
  static const String _keyEmail = 'user_email';
  static const String _keyFullName = 'user_fullname';
  static const String _keyRole = 'user_role';

  // Save complete authentication payload returned from backend
  Future<void> saveAuthData({
    required String accessToken,
    required String refreshToken,
    required String userId,
    required String email,
    required String fullName,
    required String role,
  }) async {
    await Future.wait([
      _storage.write(key: _keyAccessToken, value: accessToken),
      _storage.write(key: _keyRefreshToken, value: refreshToken),
      _storage.write(key: _keyUserId, value: userId),
      _storage.write(key: _keyEmail, value: email),
      _storage.write(key: _keyFullName, value: fullName),
      _storage.write(key: _keyRole, value: role),
    ]);
  }

  Future<void> saveRegisteredAccount({
    required String email,
    required String password,
    required String fullName,
  }) async {
    await _storage.write(key: 'reg_pwd_${email.toLowerCase().trim()}', value: password);
    await _storage.write(key: 'reg_name_${email.toLowerCase().trim()}', value: fullName);
  }

  Future<String?> getRegisteredPassword(String email) async {
    return await _storage.read(key: 'reg_pwd_${email.toLowerCase().trim()}');
  }

  Future<String?> getRegisteredFullName(String email) async {
    return await _storage.read(key: 'reg_name_${email.toLowerCase().trim()}');
  }

  Future<String?> getAccessToken() async => await _storage.read(key: _keyAccessToken);
  Future<String?> getRefreshToken() async => await _storage.read(key: _keyRefreshToken);
  Future<String?> getUserId() async => await _storage.read(key: _keyUserId);
  Future<String?> getEmail() async => await _storage.read(key: _keyEmail);
  Future<String?> getFullName() async => await _storage.read(key: _keyFullName);

  // Clear all cached credentials on logout
  Future<void> clearAuth() async {
    await _storage.delete(key: _keyAccessToken);
    await _storage.delete(key: _keyRefreshToken);
    await _storage.delete(key: _keyUserId);
    await _storage.delete(key: _keyEmail);
    await _storage.delete(key: _keyFullName);
    await _storage.delete(key: _keyRole);
  }

  Future<void> clearTokens() async => clearAuth();
}