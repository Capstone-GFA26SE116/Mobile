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
      planName: plan ?? 'Free',
      googleCalendarStatus: json['googleCalendarStatus'] as String? ?? 'NotConnected',
    );
  }
}

class CalendarSlotModel {
  final String id;
  final String source; // "Slot", "Google", "Milestone", "Task"
  final String title;
  final DateTime start;
  final DateTime end;
  final bool isAllDay;
  final String? status; // "Proposed", "Approved", "Done", "Skipped", "Cancelled"
  final String? taskId;
  final String? subTaskId;
  final String? projectId;
  final String? subTaskTitle;
  final String? projectName;
  final String? clientName;
  final String? domainName;
  final String? taskType;
  final String? explanation;
  final bool isManualOverride;
  final bool syncFailed;
  final String? googleEventId;

  CalendarSlotModel({
    required this.id,
    required this.source,
    required this.title,
    required this.start,
    required this.end,
    required this.isAllDay,
    this.status,
    this.taskId,
    this.subTaskId,
    this.projectId,
    this.subTaskTitle,
    this.projectName,
    this.clientName,
    this.domainName,
    this.taskType,
    this.explanation,
    this.isManualOverride = false,
    this.syncFailed = false,
    this.googleEventId,
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
      subTaskId: json['subTaskId'] as String?,
      projectId: json['projectId'] as String?,
      subTaskTitle: json['subTaskTitle'] as String?,
      projectName: json['projectName'] as String?,
      clientName: json['clientName'] as String?,
      domainName: json['domainName'] as String?,
      taskType: json['taskType'] as String?,
      explanation: json['explanation'] as String?,
      isManualOverride: json['isManualOverride'] as bool? ?? false,
      syncFailed: json['syncFailed'] as bool? ?? false,
      googleEventId: json['googleEventId'] as String?,
    );
  }
}

class FocusSlotTag {
  final String label;
  final String tone; // 'primary', 'success', 'muted', 'warning'

  const FocusSlotTag({required this.label, this.tone = 'muted'});
}

class FocusSlotItem {
  final String id;
  final String start;
  final String end;
  final String title;
  final String desc;
  final String type; // 'meeting', 'focus', 'reading', 'task'
  final String status; // 'done', 'running', 'next', 'upcoming'
  final List<FocusSlotTag> tags;
  final int startMs;
  final int endMs;
  final int nowMs;

  const FocusSlotItem({
    required this.id,
    required this.start,
    required this.end,
    required this.title,
    required this.desc,
    required this.type,
    required this.status,
    required this.tags,
    required this.startMs,
    required this.endMs,
    required this.nowMs,
  });

  FocusSlotItem copyWith({
    String? status,
    int? nowMs,
  }) {
    return FocusSlotItem(
      id: id,
      start: start,
      end: end,
      title: title,
      desc: desc,
      type: type,
      status: status ?? this.status,
      tags: tags,
      startMs: startMs,
      endMs: endMs,
      nowMs: nowMs ?? this.nowMs,
    );
  }
}

class UpcomingTaskItem {
  final String id;
  final String title;
  final String due;
  final String urgency; // 'urgent', 'normal'
  final bool isCompleted;

  UpcomingTaskItem({
    required this.id,
    required this.title,
    required this.due,
    required this.urgency,
    this.isCompleted = false,
  });

  UpcomingTaskItem copyWith({
    String? id,
    String? title,
    String? due,
    String? urgency,
    bool? isCompleted,
  }) {
    return UpcomingTaskItem(
      id: id ?? this.id,
      title: title ?? this.title,
      due: due ?? this.due,
      urgency: urgency ?? this.urgency,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
