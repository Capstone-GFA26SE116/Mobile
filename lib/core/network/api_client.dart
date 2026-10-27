import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../services/storage_service.dart';

class ApiClient {
  static String get baseUrl => AppConfig.apiBaseUrl;

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
          // Automatically attach Bearer token if present in storage
          final token = await _storageService.getAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = token.startsWith('Bearer ')
                ? token
                : 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) {
          // Centralized error handling
          return handler.next(e);
        },
      ),
    );
  }

  /// Safe error message extraction, ensuring clean, human-readable strings
  static String extractErrorMessage(
    dynamic error, [
    String fallback = 'An unexpected error occurred. Please try again.',
  ]) {
    if (error is DioException) {
      final responseData = error.response?.data;
      if (responseData is Map) {
        if (responseData['message'] != null) {
          return responseData['message'].toString();
        }
        if (responseData['error'] != null) {
          return responseData['error'].toString();
        }
        if (responseData['title'] != null) {
          return responseData['title'].toString();
        }
      } else if (responseData is String && responseData.isNotEmpty) {
        if (responseData.contains('<html') ||
            responseData.contains('<!DOCTYPE')) {
          final code = error.response?.statusCode ?? 500;
          return 'Server returned status code $code. Please try again later.';
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
