import 'package:dio/dio.dart';
import '../services/storage_service.dart';

class ApiClient {
  static const String baseUrl = 'http://metanoia.runasp.net';
  late final Dio dio;
  final StorageService _storageService;

  ApiClient({StorageService? storageService})
      : _storageService = storageService ?? StorageService() {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
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
          // Xử lý lỗi tập trung (mất mạng, server 500...)
          return handler.next(e);
        },
      ),
    );
  }
}