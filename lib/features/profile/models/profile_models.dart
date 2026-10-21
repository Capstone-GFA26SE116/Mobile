class ProfileModel {
  final String id;
  final String email;
  final String fullName;
  final String role;
  final String timeZone;
  final String workDayStart;
  final String workDayEnd;
  final bool worksOnWeekend;
  final int defaultBufferMinutes;
  final int reminderLeadMinutes;
  final bool onboardingCompleted;
  final String planName;
  final DateTime? planEndAt;
  final String googleCalendarStatus;

  ProfileModel({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.timeZone,
    required this.workDayStart,
    required this.workDayEnd,
    required this.worksOnWeekend,
    required this.defaultBufferMinutes,
    required this.reminderLeadMinutes,
    required this.onboardingCompleted,
    required this.planName,
    this.planEndAt,
    required this.googleCalendarStatus,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    final sub = json['currentSubscription'] as Map<String, dynamic>?;
    return ProfileModel(
      id: json['id']?.toString() ?? '',
      email: json['email'] ?? '',
      fullName: json['fullName'] ?? 'User',
      role: json['role'] ?? 'User',
      timeZone: json['timeZone'] ?? 'Asia/Ho_Chi_Minh',
      workDayStart: json['workDayStart']?.toString() ?? '08:00:00',
      workDayEnd: json['workDayEnd']?.toString() ?? '18:00:00',
      worksOnWeekend: json['worksOnWeekend'] ?? false,
      defaultBufferMinutes: json['defaultBufferMinutes'] ?? 15,
      reminderLeadMinutes: json['reminderLeadMinutes'] ?? 10,
      onboardingCompleted: json['onboardingCompleted'] ?? false,
      planName: sub != null ? (sub['planName'] ?? 'Starter') : 'Starter',
      planEndAt: sub?['endAt'] != null ? DateTime.tryParse(sub!['endAt']) : null,
      googleCalendarStatus: json['googleCalendarStatus'] ?? 'NotConnected',
    );
  }
}

class SubscriptionPlanItem {
  final String id;
  final String code;
  final String name;
  final int priceVnd;
  final String billingCycle;
  final String description;
  final List<String> features;
  final bool isPopular;

  SubscriptionPlanItem({
    required this.id,
    required this.code,
    required this.name,
    required this.priceVnd,
    required this.billingCycle,
    required this.description,
    required this.features,
    this.isPopular = false,
  });

  factory SubscriptionPlanItem.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlanItem(
      id: json['id']?.toString() ?? '',
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      priceVnd: (json['price'] as num?)?.toInt() ?? json['priceVnd'] ?? 0,
      billingCycle: json['billingCycle'] ?? 'month',
      description: json['description'] ?? '',
      features: (json['features'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      isPopular: json['isPopular'] ?? false,
    );
  }
}

class CheckoutResultModel {
  final String paymentId;
  final int orderCode;
  final String status;
  final String? checkoutUrl;
  final String? qrCode;
  final DateTime? expiresAt;
  final bool reused;

  CheckoutResultModel({
    required this.paymentId,
    required this.orderCode,
    required this.status,
    this.checkoutUrl,
    this.qrCode,
    this.expiresAt,
    this.reused = false,
  });

  factory CheckoutResultModel.fromJson(Map<String, dynamic> json) {
    return CheckoutResultModel(
      paymentId: json['paymentId']?.toString() ?? '',
      orderCode: (json['orderCode'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'Pending',
      checkoutUrl: json['checkoutUrl'] as String?,
      qrCode: json['qrCode'] as String?,
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'] as String)
          : null,
      reused: json['reused'] as bool? ?? false,
    );
  }
}
