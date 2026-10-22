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

// ==========================================
// PROJECT CHAT MODELS (AI Service Endpoints)
// ==========================================

class ProjectConversationModel {
  final String conversationId;
  final String title;
  final String status; // 'active' | 'applied' | 'closed'
  final DateTime createdAt;

  ProjectConversationModel({
    required this.conversationId,
    required this.title,
    required this.status,
    required this.createdAt,
  });

  factory ProjectConversationModel.fromJson(Map<String, dynamic> json) {
    return ProjectConversationModel(
      conversationId: json['conversation_id']?.toString() ?? '',
      title: json['title'] ?? 'Project Conversation',
      status: json['status']?.toString() ?? 'active',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class DraftDomain {
  final String id;
  final String name;

  DraftDomain({required this.id, required this.name});

  factory DraftDomain.fromJson(Map<String, dynamic> json) {
    return DraftDomain(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'General',
    );
  }
}

class DraftTaskItem {
  final String? key;
  final String title;
  final DraftDomain domain;
  final int estimatedMinutes;
  final String? reason;

  DraftTaskItem({
    this.key,
    required this.title,
    required this.domain,
    required this.estimatedMinutes,
    this.reason,
  });

  factory DraftTaskItem.fromJson(Map<String, dynamic> json) {
    return DraftTaskItem(
      key: json['key']?.toString(),
      title: json['title'] ?? '',
      domain: json['domain'] is Map<String, dynamic>
          ? DraftDomain.fromJson(json['domain'] as Map<String, dynamic>)
          : DraftDomain(id: '', name: 'General'),
      estimatedMinutes: json['estimated_minutes'] is int
          ? json['estimated_minutes'] as int
          : int.tryParse(json['estimated_minutes']?.toString() ?? '') ?? 30,
      reason: json['reason']?.toString(),
    );
  }
}

class DraftMilestoneItem {
  final String? key;
  final String title;
  final String deadline; // 'YYYY-MM-DD'
  final List<DraftTaskItem> tasks;

  DraftMilestoneItem({
    this.key,
    required this.title,
    required this.deadline,
    required this.tasks,
  });

  factory DraftMilestoneItem.fromJson(Map<String, dynamic> json) {
    final tasksRaw = json['tasks'] as List<dynamic>? ?? [];
    return DraftMilestoneItem(
      key: json['key']?.toString(),
      title: json['title'] ?? '',
      deadline: json['deadline']?.toString() ?? '',
      tasks: tasksRaw
          .map((t) => DraftTaskItem.fromJson(t as Map<String, dynamic>))
          .toList(),
    );
  }
}

class DomainNumbers {
  final String domain;
  final int estimatedMinutes;
  final int adjustedMinutes;

  DomainNumbers({
    required this.domain,
    required this.estimatedMinutes,
    required this.adjustedMinutes,
  });

  factory DomainNumbers.fromJson(Map<String, dynamic> json) {
    return DomainNumbers(
      domain: json['domain'] ?? '',
      estimatedMinutes: json['estimated_minutes'] is int
          ? json['estimated_minutes'] as int
          : int.tryParse(json['estimated_minutes']?.toString() ?? '') ?? 0,
      adjustedMinutes: json['adjusted_minutes'] is int
          ? json['adjusted_minutes'] as int
          : int.tryParse(json['adjusted_minutes']?.toString() ?? '') ?? 0,
    );
  }
}

class DraftNumbers {
  final List<DomainNumbers> byDomain;
  final int totalEstimatedMinutes;
  final int totalAdjustedMinutes;
  final int? daysLeft;
  final bool adjustedIsHint;

  DraftNumbers({
    required this.byDomain,
    required this.totalEstimatedMinutes,
    required this.totalAdjustedMinutes,
    this.daysLeft,
    this.adjustedIsHint = false,
  });

  factory DraftNumbers.fromJson(Map<String, dynamic> json) {
    final domainListRaw = json['by_domain'] as List<dynamic>? ?? [];
    return DraftNumbers(
      byDomain: domainListRaw
          .map((d) => DomainNumbers.fromJson(d as Map<String, dynamic>))
          .toList(),
      totalEstimatedMinutes: json['total_estimated_minutes'] is int
          ? json['total_estimated_minutes'] as int
          : int.tryParse(json['total_estimated_minutes']?.toString() ?? '') ?? 0,
      totalAdjustedMinutes: json['total_adjusted_minutes'] is int
          ? json['total_adjusted_minutes'] as int
          : int.tryParse(json['total_adjusted_minutes']?.toString() ?? '') ?? 0,
      daysLeft: json['days_left'] is int
          ? json['days_left'] as int
          : int.tryParse(json['days_left']?.toString() ?? ''),
      adjustedIsHint: json['adjusted_is_hint'] == true,
    );
  }
}

class ProjectDraft {
  final String messageId;
  final List<DraftMilestoneItem> milestones;
  final List<String> reminders;
  final DraftNumbers numbers;
  final List<String> warnings;

  ProjectDraft({
    required this.messageId,
    required this.milestones,
    required this.reminders,
    required this.numbers,
    required this.warnings,
  });

  factory ProjectDraft.fromJson(Map<String, dynamic> json) {
    final msRaw = json['milestones'] as List<dynamic>? ?? [];
    final remRaw = json['reminders'] as List<dynamic>? ?? [];
    final warnRaw = json['warnings'] as List<dynamic>? ?? [];

    return ProjectDraft(
      messageId: json['message_id']?.toString() ?? '',
      milestones: msRaw
          .map((m) => DraftMilestoneItem.fromJson(m as Map<String, dynamic>))
          .toList(),
      reminders: remRaw.map((r) => r.toString()).toList(),
      numbers: json['numbers'] is Map<String, dynamic>
          ? DraftNumbers.fromJson(json['numbers'] as Map<String, dynamic>)
          : DraftNumbers(
              byDomain: [],
              totalEstimatedMinutes: 0,
              totalAdjustedMinutes: 0,
            ),
      warnings: warnRaw.map((w) => w.toString()).toList(),
    );
  }
}

class ProjectChatMessage {
  final String id;
  final String role; // 'user' | 'assistant'
  final String? kind; // 'question' | 'draft' | null
  final String content;
  final DateTime createdAt;
  final ProjectDraft? draft;

  ProjectChatMessage({
    required this.id,
    required this.role,
    this.kind,
    required this.content,
    required this.createdAt,
    this.draft,
  });

  bool get isUser => role.toLowerCase() == 'user';
  bool get isAssistant =>
      role.toLowerCase() == 'assistant' || role.toLowerCase() == 'ai';
  bool get hasDraft => draft != null && draft!.milestones.isNotEmpty;

  factory ProjectChatMessage.fromJson(Map<String, dynamic> json) {
    return ProjectChatMessage(
      id: json['id']?.toString() ?? '',
      role: json['role']?.toString() ?? 'assistant',
      kind: json['kind']?.toString(),
      content: json['content']?.toString() ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      draft: json['draft'] is Map<String, dynamic>
          ? ProjectDraft.fromJson(json['draft'] as Map<String, dynamic>)
          : null,
    );
  }
}

class ProjectChatTurn {
  final String conversationId;
  final ProjectChatMessage userMessage;
  final ProjectChatMessage aiMessage;

  ProjectChatTurn({
    required this.conversationId,
    required this.userMessage,
    required this.aiMessage,
  });

  factory ProjectChatTurn.fromJson(Map<String, dynamic> json) {
    return ProjectChatTurn(
      conversationId: json['conversation_id']?.toString() ?? '',
      userMessage: ProjectChatMessage.fromJson(
        json['user_message'] as Map<String, dynamic>? ?? {},
      ),
      aiMessage: ProjectChatMessage.fromJson(
        json['ai_message'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}

class ProjectChatDetail {
  final String conversationId;
  final String projectId;
  final String status;
  final List<ProjectChatMessage> messages;
  final ProjectDraft? latestDraft;
  final bool applied;

  ProjectChatDetail({
    required this.conversationId,
    required this.projectId,
    required this.status,
    required this.messages,
    this.latestDraft,
    required this.applied,
  });

  factory ProjectChatDetail.fromJson(Map<String, dynamic> json) {
    final msgListRaw = json['messages'] as List<dynamic>? ?? [];
    return ProjectChatDetail(
      conversationId: json['conversation_id']?.toString() ?? '',
      projectId: json['project_id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'active',
      messages: msgListRaw
          .map((m) => ProjectChatMessage.fromJson(m as Map<String, dynamic>))
          .toList(),
      latestDraft: json['latest_draft'] is Map<String, dynamic>
          ? ProjectDraft.fromJson(json['latest_draft'] as Map<String, dynamic>)
          : null,
      applied: json['applied'] == true,
    );
  }
}
