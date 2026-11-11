class FocusStartRequest {
  final String taskId;
  final String? subTaskId;
  final String? scheduleSlotId;
  final String? focusTrackId;

  const FocusStartRequest({
    required this.taskId,
    this.subTaskId,
    this.scheduleSlotId,
    this.focusTrackId,
  });

  Map<String, dynamic> toJson() {
    return {
      'taskId': taskId,
      if (subTaskId != null && subTaskId!.isNotEmpty) 'subTaskId': subTaskId,
      if (scheduleSlotId != null && scheduleSlotId!.isNotEmpty)
        'scheduleSlotId': scheduleSlotId,
      if (focusTrackId != null && focusTrackId!.isNotEmpty)
        'focusTrackId': focusTrackId,
    };
  }
}

class FocusStartResponse {
  final String sessionId;
  final DateTime startedAt;
  final String captureMethod;
  final int plannedMinutes;
  final DateTime? expectedEndAt;
  final int startedEarlyMinutes;
  final String? warning;

  const FocusStartResponse({
    required this.sessionId,
    required this.startedAt,
    required this.captureMethod,
    required this.plannedMinutes,
    this.expectedEndAt,
    this.startedEarlyMinutes = 0,
    this.warning,
  });

  factory FocusStartResponse.fromJson(Map<String, dynamic> json) {
    return FocusStartResponse(
      sessionId: json['sessionId']?.toString() ?? '',
      startedAt: DateTime.tryParse(json['startedAt']?.toString() ?? '') ??
          DateTime.now(),
      captureMethod: json['captureMethod']?.toString() ?? 'Timer',
      plannedMinutes: (json['plannedMinutes'] as num?)?.toInt() ?? 0,
      expectedEndAt: json['expectedEndAt'] != null
          ? DateTime.tryParse(json['expectedEndAt'].toString())
          : null,
      startedEarlyMinutes:
          (json['startedEarlyMinutes'] as num?)?.toInt() ?? 0,
      warning: json['warning']?.toString(),
    );
  }
}

class FocusCurrentResponse {
  final String sessionId;
  final String taskId;
  final String taskTitle;
  final String? subTaskId;
  final String? subTaskTitle;
  final String? scheduleSlotId;
  final String? focusTrackId;
  final String? focusTrackTitle;
  final DateTime startedAt;
  final int elapsedSeconds;
  final DateTime serverTime;
  final bool isOverrun;

  const FocusCurrentResponse({
    required this.sessionId,
    required this.taskId,
    required this.taskTitle,
    this.subTaskId,
    this.subTaskTitle,
    this.scheduleSlotId,
    this.focusTrackId,
    this.focusTrackTitle,
    required this.startedAt,
    required this.elapsedSeconds,
    required this.serverTime,
    this.isOverrun = false,
  });

  factory FocusCurrentResponse.fromJson(Map<String, dynamic> json) {
    return FocusCurrentResponse(
      sessionId: json['sessionId']?.toString() ?? '',
      taskId: json['taskId']?.toString() ?? '',
      taskTitle: json['taskTitle']?.toString() ?? 'Current Focus',
      subTaskId: json['subTaskId']?.toString(),
      subTaskTitle: json['subTaskTitle']?.toString(),
      scheduleSlotId: json['scheduleSlotId']?.toString(),
      focusTrackId: json['focusTrackId']?.toString(),
      focusTrackTitle: json['focusTrackTitle']?.toString(),
      startedAt: DateTime.tryParse(json['startedAt']?.toString() ?? '') ??
          DateTime.now(),
      elapsedSeconds: (json['elapsedSeconds'] as num?)?.toInt() ?? 0,
      serverTime: DateTime.tryParse(json['serverTime']?.toString() ?? '') ??
          DateTime.now(),
      isOverrun: json['isOverrun'] == true,
    );
  }
}

enum FocusStopReason {
  completed('Completed', 'Completed'),
  interrupted('Interrupted', 'Interrupted / Break'),
  blocked('Blocked', 'Blocked by obstacle'),
  other('Other', 'Other reason');

  final String value;
  final String label;
  const FocusStopReason(this.value, this.label);
}

class FocusStopRequest {
  final FocusStopReason stopReason;
  final String? note;

  const FocusStopRequest({
    required this.stopReason,
    this.note,
  });

  Map<String, dynamic> toJson() {
    return {
      'stopReason': stopReason.value,
      if (note != null && note!.trim().isNotEmpty) 'note': note!.trim(),
    };
  }
}

class FocusStopResponse {
  final String sessionId;
  final DateTime endedAt;
  final int sessionMinutes;
  final int taskTotalMinutes;
  final bool checkInRequired;

  const FocusStopResponse({
    required this.sessionId,
    required this.endedAt,
    required this.sessionMinutes,
    required this.taskTotalMinutes,
    this.checkInRequired = false,
  });

  factory FocusStopResponse.fromJson(Map<String, dynamic> json) {
    return FocusStopResponse(
      sessionId: json['sessionId']?.toString() ?? '',
      endedAt: DateTime.tryParse(json['endedAt']?.toString() ?? '') ??
          DateTime.now(),
      sessionMinutes: (json['sessionMinutes'] as num?)?.toInt() ?? 0,
      taskTotalMinutes: (json['taskTotalMinutes'] as num?)?.toInt() ?? 0,
      checkInRequired: json['checkInRequired'] == true,
    );
  }
}

class FocusPendingConfirmationItem {
  final String sessionId;
  final String taskTitle;
  final DateTime startedAt;
  final DateTime endedAt;
  final int durationMinutes;
  final int plannedMinutes;

  const FocusPendingConfirmationItem({
    required this.sessionId,
    required this.taskTitle,
    required this.startedAt,
    required this.endedAt,
    required this.durationMinutes,
    required this.plannedMinutes,
  });

  factory FocusPendingConfirmationItem.fromJson(Map<String, dynamic> json) {
    return FocusPendingConfirmationItem(
      sessionId: json['sessionId']?.toString() ?? '',
      taskTitle: json['taskTitle']?.toString() ?? 'Task',
      startedAt: DateTime.tryParse(json['startedAt']?.toString() ?? '') ??
          DateTime.now(),
      endedAt: DateTime.tryParse(json['endedAt']?.toString() ?? '') ??
          DateTime.now(),
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 0,
      plannedMinutes: (json['plannedMinutes'] as num?)?.toInt() ?? 0,
    );
  }
}

class FocusTrackItem {
  final String id;
  final String title;
  final String? artist;
  final String? category;
  final String? audioUrl;

  const FocusTrackItem({
    required this.id,
    required this.title,
    this.artist,
    this.category,
    this.audioUrl,
  });

  factory FocusTrackItem.fromJson(Map<String, dynamic> json) {
    return FocusTrackItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Focus Ambient',
      artist: json['artist']?.toString(),
      category: json['category']?.toString(),
      audioUrl: json['audioUrl']?.toString(),
    );
  }
}

