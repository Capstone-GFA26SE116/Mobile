import 'package:dio/dio.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../models/onboarding_model.dart';

class OnboardingRepository {
  final ApiClient _apiClient;

  OnboardingRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  Future<List<DomainModel>> getDomains() async {
    try {
      final response = await _apiClient.dio.get(ApiEndpoints.domains);
      if (response.statusCode == 200 && response.data != null) {
        final list = response.data as List<dynamic>;
        return list
            .map((e) => DomainModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw Exception('Không thể lấy danh sách Domain: ${e.message}');
    }
  }

  Future<void> submitOnboarding(OnboardingRequest request) async {
    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.onboarding,
        data: request.toJson(),
      );
      if (response.statusCode != 200) {
        throw Exception('Lỗi nộp Onboarding: ${response.statusCode}');
      }
    } on DioException catch (e) {
      final msg = ApiClient.extractErrorMessage(e);
      throw Exception('Lỗi hoàn thành khảo sát: $msg');
    }
  }

  Future<bool> checkOnboardingCompleted() async {
    try {
      final response = await _apiClient.dio.get(ApiEndpoints.me);
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        return data['onboardingCompleted'] as bool? ?? false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
