class CopilotSubtaskDraft {
  final String title;
  final int minutes;
  final int order;
  final String? reason;

  CopilotSubtaskDraft({
    required this.title,
    required this.minutes,
    required this.order,
    this.reason,
  });

  factory CopilotSubtaskDraft.fromJson(Map<String, dynamic> json) {
    return CopilotSubtaskDraft(
      title: json['title'] ?? '',
      minutes: json['minutes'] ?? json['estimated_minutes'] ?? 30,
      order: json['order'] ?? json['order_index'] ?? 0,
      reason: json['reason'],
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'estimated_minutes': minutes,
        'order_index': order,
        'reason': reason,
      };
}

class CopilotDraft {
  final String messageId;
  final List<CopilotSubtaskDraft> subtasks;
  final int yourEstimateMinutes;
  final int adjustedMinutes;
  final int subtaskTotalMinutes;
  final bool adjustedIsHint;
  final String? warning;

  CopilotDraft({
    required this.messageId,
    required this.subtasks,
    required this.yourEstimateMinutes,
    required this.adjustedMinutes,
    required this.subtaskTotalMinutes,
    this.adjustedIsHint = false,
    this.warning,
  });

  factory CopilotDraft.fromJson(Map<String, dynamic> json) {
    final subtasksRaw = json['subtasks'] as List<dynamic>? ?? [];
    return CopilotDraft(
      messageId: json['message_id'] ?? json['messageId'] ?? '',
      subtasks: subtasksRaw.map((s) => CopilotSubtaskDraft.fromJson(s as Map<String, dynamic>)).toList(),
      yourEstimateMinutes: json['your_estimate_minutes'] ?? json['yourEstimateMinutes'] ?? 0,
      adjustedMinutes: json['adjusted_minutes'] ?? json['adjustedMinutes'] ?? 0,
      subtaskTotalMinutes: json['subtask_total_minutes'] ?? json['subtaskTotalMinutes'] ?? 0,
      adjustedIsHint: json['adjusted_is_hint'] ?? json['adjustedIsHint'] ?? false,
      warning: json['warning'],
    );
  }
}

class CopilotMessage {
  final String id;
  final String role; // 'user' | 'ai'
  final String text;
  final String time;
  final String kind; // 'text' | 'draft'
  final CopilotDraft? draft;

  CopilotMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.time,
    this.kind = 'text',
    this.draft,
  });

  bool get isUser => role == 'user';
  bool get isDraft => kind == 'draft' && draft != null;

  factory CopilotMessage.fromJson(Map<String, dynamic> json) {
    return CopilotMessage(
      id: json['id'] ?? '',
      role: json['role'] ?? 'ai',
      text: json['content'] ?? json['text'] ?? '',
      time: json['time'] ?? 'Just now',
      kind: json['kind'] ?? (json['draft'] != null ? 'draft' : 'text'),
      draft: json['draft'] != null ? CopilotDraft.fromJson(json['draft']) : null,
    );
  }
}
