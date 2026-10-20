class UserProfileModel {
  final String id;
  final String email;
  final String fullName;
  final String role;
  final String timeZone;
  final String workDayStart;
  final String workDayEnd;
  final bool worksOnWeekend;
  final int defaultBufferMinutes;
  final bool onboardingCompleted;
  final String? planName;
  final String googleCalendarStatus;

  UserProfileModel({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.timeZone,
    required this.workDayStart,
    required this.workDayEnd,
    required this.worksOnWeekend,
    required this.defaultBufferMinutes,
    required this.onboardingCompleted,
    this.planName,
    required this.googleCalendarStatus,
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    String? plan;
    if (json['currentSubscription'] != null) {
      plan = json['currentSubscription']['planName'] as String?;
    }
    return UserProfileModel(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      role: json['role'] as String? ?? 'User',
      timeZone: json['timeZone'] as String? ?? 'Asia/Ho_Chi_Minh',
      workDayStart: json['workDayStart'] as String? ?? '08:00:00',
      workDayEnd: json['workDayEnd'] as String? ?? '18:00:00',
      worksOnWeekend: json['worksOnWeekend'] as bool? ?? false,
      defaultBufferMinutes: json['defaultBufferMinutes'] as int? ?? 15,
      onboardingCompleted: json['onboardingCompleted'] as bool? ?? false,
      planName: plan ?? 'Miễn phí',
      googleCalendarStatus: json['googleCalendarStatus'] as String? ?? 'NotConnected',
    );
  }
}

class CalendarSlotModel {
  final String id;
  final String source; // "Slot" hoặc "Google"
  final String title;
  final DateTime start;
  final DateTime end;
  final bool isAllDay;
  final String? status; // "Proposed", "Approved", "Done", "Skipped"
  final String? taskId;

  CalendarSlotModel({
    required this.id,
    required this.source,
    required this.title,
    required this.start,
    required this.end,
    required this.isAllDay,
    this.status,
    this.taskId,
  });

  factory CalendarSlotModel.fromJson(Map<String, dynamic> json) {
    return CalendarSlotModel(
      id: json['id'] as String? ?? '',
      source: json['source'] as String? ?? 'Slot',
      title: json['title'] as String? ?? '',
      start: DateTime.tryParse(json['start'] as String? ?? '')?.toLocal() ?? DateTime.now(),
      end: DateTime.tryParse(json['end'] as String? ?? '')?.toLocal() ?? DateTime.now().add(const Duration(hours: 1)),
      isAllDay: json['isAllDay'] as bool? ?? false,
      status: json['status'] as String?,
      taskId: json['taskId'] as String?,
    );
  }
}
