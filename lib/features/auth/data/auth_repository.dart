import 'package:dio/dio.dart';
import 'package:google_sign_in/google_sign_in.dart';
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
        // Dán chính xác Client ID của Web vào đây:
        serverClientId: webClientId ??
            '1025047063269-c7u6uu9lvcjdsho711bkoksjr741cfuf.apps.googleusercontent.com',
        scopes: ['email', 'profile'],
      );

  // 1. Luồng Đăng nhập Google
  Future<AuthResponse> signInWithGoogle() async {
    try {
      // Kích hoạt dialog chọn tài khoản Google trên điện thoại
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Người dùng đã hủy đăng nhập Google.');
      }

      // Lấy idToken từ tài khoản đã chọn
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null || idToken.isEmpty) {
        throw Exception('Không lấy được idToken từ Google. Kiểm tra lại Web Client ID.');
      }

      // Gửi idToken lên backend Metanoia
      final Response response = await _apiClient.dio.post(
        '/api/Auth/google',
        data: {'idToken': idToken},
      );

      if (response.statusCode == 200 && response.data != null) {
        final authResponse = AuthResponse.fromJson(response.data as Map<String, dynamic>);

        // Lưu trữ an toàn vào máy
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
        throw Exception('Đăng nhập thất bại: Máy chủ phản hồi mã ${response.statusCode}');
      }
    } on DioException catch (e) {
      final errorMessage = e.response?.data?['message'] ?? e.message;
      throw Exception('Lỗi kết nối Backend: $errorMessage');
    }
  }

  // 2. Làm mới Token tự động
  Future<AuthResponse> refreshToken() async {
    final currentRefreshToken = await _storageService.getRefreshToken();
    if (currentRefreshToken == null) {
      throw Exception('Không tìm thấy refreshToken');
    }

    final Response response = await _apiClient.dio.post(
      '/api/Auth/refresh',
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

  // 3. Đăng xuất
  Future<void> logout() async {
    final currentRefreshToken = await _storageService.getRefreshToken();
    try {
      if (currentRefreshToken != null) {
        await _apiClient.dio.post(
          '/api/Auth/logout',
          data: {
            'refreshToken': currentRefreshToken,
            'allDevices': true,
          },
        );
      }
    } finally {
      // Luôn dọn dẹp sạch token cục bộ dù request có lỗi mạng
      await _storageService.clearAuth();
      await _googleSignIn.signOut();
    }
  }
}