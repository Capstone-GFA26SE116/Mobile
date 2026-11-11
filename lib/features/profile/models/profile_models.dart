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
  final int? durationDays;
  final int? aiCallLimit;
  final int? storageLimitMb;
  final int? projectLimit;
  final bool isActive;

  SubscriptionPlanItem({
    required this.id,
    required this.code,
    required this.name,
    required this.priceVnd,
    required this.billingCycle,
    required this.description,
    required this.features,
    this.isPopular = false,
    this.durationDays,
    this.aiCallLimit,
    this.storageLimitMb,
    this.projectLimit,
    this.isActive = true,
  });

  factory SubscriptionPlanItem.fromJson(Map<String, dynamic> json) {
    final rawFeatures = (json['features'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    final price = (json['price'] as num?)?.toInt() ??
        (json['priceVnd'] as num?)?.toInt() ??
        0;
    final durationDays = (json['durationDays'] as num?)?.toInt();
    final aiLimit = (json['aiCallLimit'] as num?)?.toInt();
    final storageMb = (json['storageLimitMb'] as num?)?.toInt() ?? 0;
    final projLimit = (json['projectLimit'] as num?)?.toInt();
    final name = json['name']?.toString() ?? 'Subscription Plan';
    final isPopular = json['isPopular'] as bool? ??
        name.toLowerCase().contains('pro') ||
        (price > 0 && price < 300000);

    // Auto-synthesize features if BE didn't supply a textual list
    final features = List<String>.from(rawFeatures);
    if (features.isEmpty) {
      if (projLimit != null) {
        features.add('Up to $projLimit active projects');
      } else {
        features.add('Unlimited active projects & tasks');
      }

      if (aiLimit != null) {
        features.add('$aiLimit AI Copilot requests / month');
      } else {
        features.add('Unlimited AI Copilot & Planning requests');
      }

      if (storageMb > 0) {
        features.add('$storageMb MB secure cloud storage');
      } else {
        features.add('Unlimited cloud document storage');
      }

      features.add('Two-way Google Calendar synchronization');
      features.add('Personal work rhythm & Kbias learning');
    }

    final cycle = durationDays != null && durationDays >= 360
        ? 'year'
        : durationDays != null && durationDays >= 28
            ? 'month'
            : json['billingCycle']?.toString() ?? 'month';

    return SubscriptionPlanItem(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      name: name,
      priceVnd: price,
      billingCycle: cycle,
      description: json['description']?.toString() ??
          (price == 0
              ? 'Starter plan for personal schedule and workflow management.'
              : 'Maximize AI-driven schedule optimization and deep work planning.'),
      features: features,
      isPopular: isPopular,
      durationDays: durationDays,
      aiCallLimit: aiLimit,
      storageLimitMb: storageMb,
      projectLimit: projLimit,
      isActive: json['isActive'] as bool? ?? true,
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

class PaymentSyncResultModel {
  final String id;
  final String userId;
  final String planId;
  final int orderCode;
  final String gateway;
  final int amount;
  final String status;
  final DateTime? createdAt;
  final DateTime? expiresAt;
  final DateTime? paidAt;

  PaymentSyncResultModel({
    required this.id,
    required this.userId,
    required this.planId,
    required this.orderCode,
    required this.gateway,
    required this.amount,
    required this.status,
    this.createdAt,
    this.expiresAt,
    this.paidAt,
  });

  factory PaymentSyncResultModel.fromJson(Map<String, dynamic> json) {
    return PaymentSyncResultModel(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      planId: json['planId']?.toString() ?? '',
      orderCode: (json['orderCode'] as num?)?.toInt() ?? 0,
      gateway: json['gateway']?.toString() ?? 'PayOS',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? 'Pending',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'] as String)
          : null,
      paidAt: json['paidAt'] != null
          ? DateTime.tryParse(json['paidAt'] as String)
          : null,
    );
  }

  bool get isSucceeded => status.toLowerCase() == 'succeeded';
  bool get isPending => status.toLowerCase() == 'pending';
  bool get isCancelled => status.toLowerCase() == 'cancelled';
  bool get isExpired => status.toLowerCase() == 'expired';
}
