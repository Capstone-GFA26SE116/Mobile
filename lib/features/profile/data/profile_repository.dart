import 'package:dio/dio.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/storage_service.dart';
import '../models/profile_models.dart';

class ProfileRepository {
  final ApiClient _apiClient;
  final StorageService _storageService;

  ProfileRepository({ApiClient? apiClient, StorageService? storageService})
      : _apiClient = apiClient ?? ApiClient(),
        _storageService = storageService ?? StorageService();

  Future<ProfileModel> getProfile() async {
    try {
      final response = await _apiClient.dio.get(ApiEndpoints.me);
      if (response.statusCode == 200 && response.data != null) {
        return ProfileModel.fromJson(response.data as Map<String, dynamic>);
      }
    } catch (_) {}

    return ProfileModel(
      id: 'local_user',
      email: 'user@metanoia.io',
      fullName: 'Metanoia Member',
      role: 'Pro Member',
      timeZone: 'Asia/Ho_Chi_Minh',
      workDayStart: '08:00:00',
      workDayEnd: '18:00:00',
      worksOnWeekend: false,
      defaultBufferMinutes: 15,
      reminderLeadMinutes: 10,
      onboardingCompleted: true,
      planName: 'Pro Tier (AI Enabled)',
      googleCalendarStatus: 'Active',
    );
  }

  Future<bool> updateProfile(String fullName) async {
    try {
      final response = await _apiClient.dio.put(
        ApiEndpoints.meProfile,
        data: {'fullName': fullName},
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateSettings({
    required String workDayStart,
    required String workDayEnd,
    required bool worksOnWeekend,
    required int defaultBufferMinutes,
    required int reminderLeadMinutes,
  }) async {
    try {
      final response = await _apiClient.dio.put(
        ApiEndpoints.meSettings,
        data: {
          'workDayStart': workDayStart,
          'workDayEnd': workDayEnd,
          'worksOnWeekend': worksOnWeekend,
          'defaultBufferMinutes': defaultBufferMinutes,
          'reminderLeadMinutes': reminderLeadMinutes,
        },
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<List<SubscriptionPlanItem>> getSubscriptionPlans() async {
    try {
      final response = await _apiClient.dio.get(ApiEndpoints.subscriptionPlans);
      if (response.statusCode == 200 && response.data != null) {
        final list = response.data as List<dynamic>;
        if (list.isNotEmpty) {
          return list
              .map((e) => SubscriptionPlanItem.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (_) {}

    // Fallback plans matching Web Frontend Pricing
    return [
      SubscriptionPlanItem(
        id: 'starter',
        code: 'STARTER',
        name: 'Starter Plan',
        priceVnd: 0,
        billingCycle: 'Lifetime',
        description: 'Best for individuals getting started with cognitive workflow optimization.',
        features: [
          'Sync 1 Google Calendar account',
          'Track personal Kbias factor',
          'Up to 3 active projects',
          'AI Copilot (5 requests / day)',
        ],
      ),
      SubscriptionPlanItem(
        id: 'pro',
        code: 'PRO',
        name: 'Pro Plan',
        priceVnd: 149000,
        billingCycle: 'month',
        description: 'Full Neural Engine v2.4 power and unlimited Deep Work protection.',
        features: [
          'Unlimited projects & tasks',
          'Automated AI Schedule Propose',
          'Self-adaptive buffer & duration learning',
          'Unlimited AI Copilot task breakdown',
          'Multi-channel biological buffer support',
        ],
        isPopular: true,
      ),
      SubscriptionPlanItem(
        id: 'team',
        code: 'TEAM',
        name: 'Team Plan',
        priceVnd: 399000,
        billingCycle: 'month',
        description: 'Coordinate cognitive work across teams and reduce collaborative overhead.',
        features: [
          'All features of Pro Plan',
          'Smart team resource allocation',
          'Weekly/monthly cognitive velocity reports',
          'Dedicated SLA & 24/7 priority support',
        ],
      ),
    ];
  }

  Future<CheckoutResultModel> checkoutPayOs(String planId) async {
    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.paymentsCheckout,
        data: {'planId': planId},
      );
      if (response.statusCode == 200 && response.data != null) {
        return CheckoutResultModel.fromJson(response.data as Map<String, dynamic>);
      }
      throw Exception('Failed to generate payment checkout link');
    } on DioException catch (e) {
      final msg = ApiClient.extractErrorMessage(e);
      throw Exception('Payment error: $msg');
    }
  }

  Future<void> disconnectGoogleCalendar() async {
    try {
      await _apiClient.dio.delete(ApiEndpoints.googleCalendarDisconnect);
    } on DioException catch (e) {
      final msg = ApiClient.extractErrorMessage(e);
      throw Exception('Failed to disconnect Google Calendar: $msg');
    }
  }

  Future<String?> getGoogleCalendarConnectUrl() async {
    try {
      final response = await _apiClient.dio.get(ApiEndpoints.googleCalendarConnect);
      if (response.statusCode == 200 && response.data != null) {
        return response.data['authorizationUrl'] as String?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteAccount() async {
    try {
      await _apiClient.dio.delete(ApiEndpoints.me);
    } catch (_) {}
    await _storageService.clearTokens();
  }

  Future<void> logout() async {
    await _storageService.clearTokens();
  }
}
