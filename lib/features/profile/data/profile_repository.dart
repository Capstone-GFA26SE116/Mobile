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
        name: 'Gói Cơ Bản (Starter)',
        priceVnd: 0,
        billingCycle: 'Vĩnh viễn',
        description: 'Tối ưu cho người mới bắt đầu thiết lập thói quen làm việc nhận thức.',
        features: [
          'Đồng bộ 1 tài khoản Google Calendar',
          'Theo dõi hệ số Kbias cá nhân',
          'Tối đa 3 dự án đồng thời',
          'AI Copilot (5 lượt / ngày)',
        ],
      ),
      SubscriptionPlanItem(
        id: 'pro',
        code: 'PRO',
        name: 'Gói Chuyên Nghiệp (Pro)',
        priceVnd: 149000,
        billingCycle: 'tháng',
        description: 'Đầy đủ sức mạnh Neural Engine v2.4 và bảo vệ Deep Work không giới hạn.',
        features: [
          'Không giới hạn dự án & tác vụ',
          'Tự động hóa lập lịch AI Schedule Propose',
          'Tự động học bù trừ thời gian tự thích nghi',
          'AI Copilot phân rã subtask không giới hạn',
          'Hỗ trợ đệm nghỉ sinh học đa kênh',
        ],
        isPopular: true,
      ),
      SubscriptionPlanItem(
        id: 'team',
        code: 'TEAM',
        name: 'Gói Nhóm (Team)',
        priceVnd: 399000,
        billingCycle: 'tháng',
        description: 'Điều phối nhận thức nhóm và giảm thiểu tải nhận thức cộng tác.',
        features: [
          'Tất cả tính năng của gói Pro',
          'Phân bổ tài nguyên nhóm thông minh',
          'Báo cáo hiệu suất nhận thức tuần/tháng',
          'Dedicated SLA & Hỗ trợ ưu tiên 24/7',
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
      throw Exception('Không tạo được liên kết thanh toán');
    } on DioException catch (e) {
      final msg = ApiClient.extractErrorMessage(e);
      throw Exception('Lỗi thanh toán: $msg');
    }
  }

  Future<void> disconnectGoogleCalendar() async {
    try {
      await _apiClient.dio.delete(ApiEndpoints.googleCalendarDisconnect);
    } on DioException catch (e) {
      final msg = ApiClient.extractErrorMessage(e);
      throw Exception('Lỗi hủy liên kết Google Calendar: $msg');
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
