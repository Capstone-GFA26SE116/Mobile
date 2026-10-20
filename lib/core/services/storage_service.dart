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

  // Lưu toàn bộ thông tin đăng nhập sau khi backend trả về
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

  Future<String?> getAccessToken() async => await _storage.read(key: _keyAccessToken);
  Future<String?> getRefreshToken() async => await _storage.read(key: _keyRefreshToken);
  Future<String?> getUserId() async => await _storage.read(key: _keyUserId);
  Future<String?> getFullName() async => await _storage.read(key: _keyFullName);

  // Xóa toàn bộ dữ liệu khi đăng xuất
  Future<void> clearAuth() async {
    await _storage.deleteAll();
  }

  Future<void> clearTokens() async => clearAuth();
}