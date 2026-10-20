import 'package:dio/dio.dart';
import '../services/storage_service.dart';

class ApiClient {
  // Thay đổi sang true nếu muốn kết nối với Backend chạy cục bộ trên máy tính (localhost:5036 / 10.0.2.2:5036)
  static const bool useLocalServer = false;
  static const String onlineServerUrl = 'http://metanoia.runasp.net';
  static const String localServerUrl = 'http://10.0.2.2:5036'; // Cho Android Emulator

  static String get baseUrl => useLocalServer ? localServerUrl : onlineServerUrl;

  late final Dio dio;
  final StorageService _storageService;

  ApiClient({StorageService? storageService})
      : _storageService = storageService ?? StorageService() {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 25),
        receiveTimeout: const Duration(seconds: 25),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Tự động gắn Bearer Token nếu đã có trong storage
          final token = await _storageService.getAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] =
                token.startsWith('Bearer ') ? token : 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) {
          // Xử lý lỗi tập trung
          return handler.next(e);
        },
      ),
    );
  }

  /// Trích xuất thông báo lỗi an toàn, tuyệt đối không gây ra lỗi "type 'String' is not a subtype of type 'int' of 'index'"
  static String extractErrorMessage(dynamic error, [String fallback = 'Đã có lỗi xảy ra']) {
    if (error is DioException) {
      final responseData = error.response?.data;
      if (responseData is Map) {
        if (responseData['message'] != null) return responseData['message'].toString();
        if (responseData['error'] != null) return responseData['error'].toString();
        if (responseData['title'] != null) return responseData['title'].toString();
      } else if (responseData is String && responseData.isNotEmpty) {
        if (responseData.contains('<html') || responseData.contains('<!DOCTYPE')) {
          final code = error.response?.statusCode ?? 500;
          return 'Máy chủ phản hồi mã lỗi $code. Vui lòng thử lại sau.';
        }
        return responseData;
      }
      if (error.message != null && error.message!.isNotEmpty) {
        return error.message!;
      }
    } else if (error is Exception) {
      return error.toString().replaceAll('Exception: ', '');
    }
    return fallback;
  }
}