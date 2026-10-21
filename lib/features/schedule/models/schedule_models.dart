class AiSlotItem {
  final String slotId;
  final String taskId;
  final String? taskTitle;
  final String? subTaskId;
  final DateTime start;
  final DateTime end;
  final int proposedMinutes;
  final String? explanation;
  final String status;

  AiSlotItem({
    required this.slotId,
    required this.taskId,
    this.taskTitle,
    this.subTaskId,
    required this.start,
    required this.end,
    required this.proposedMinutes,
    this.explanation,
    this.status = 'Proposed',
  });

  AiSlotItem copyWith({
    String? slotId,
    String? taskId,
    String? taskTitle,
    String? subTaskId,
    DateTime? start,
    DateTime? end,
    int? proposedMinutes,
    String? explanation,
    String? status,
  }) {
    return AiSlotItem(
      slotId: slotId ?? this.slotId,
      taskId: taskId ?? this.taskId,
      taskTitle: taskTitle ?? this.taskTitle,
      subTaskId: subTaskId ?? this.subTaskId,
      start: start ?? this.start,
      end: end ?? this.end,
      proposedMinutes: proposedMinutes ?? this.proposedMinutes,
      explanation: explanation ?? this.explanation,
      status: status ?? this.status,
    );
  }

  factory AiSlotItem.fromJson(Map<String, dynamic> json) {
    final startStr = json['startTime'] as String? ?? json['start'] as String? ?? '';
    final endStr = json['endTime'] as String? ?? json['end'] as String? ?? '';
    final s = DateTime.tryParse(startStr)?.toLocal() ?? DateTime.now();
    final e = DateTime.tryParse(endStr)?.toLocal() ?? DateTime.now();
    final diffMins = e.difference(s).inMinutes;

    return AiSlotItem(
      slotId: json['id'] as String? ?? json['slotId'] as String? ?? json['slot_id'] as String? ?? '',
      taskId: json['taskId'] as String? ?? json['task_id'] as String? ?? '',
      taskTitle: json['taskTitle'] as String? ?? json['task_title'] as String?,
      subTaskId: json['subTaskId'] as String? ?? json['subtask_id'] as String?,
      start: s,
      end: e,
      proposedMinutes: json['proposedMinutes'] as int? ?? json['proposed_minutes'] as int? ?? (diffMins > 0 ? diffMins : 60),
      explanation: json['explanation'] as String?,
      status: json['status'] as String? ?? 'Proposed',
    );
  }
}

class AiWarningItem {
  final String? taskId;
  final String type;
  final int? neededMinutes;
  final int? freeMinutes;
  final String message;

  AiWarningItem({
    this.taskId,
    required this.type,
    this.neededMinutes,
    this.freeMinutes,
    required this.message,
  });

  factory AiWarningItem.fromJson(Map<String, dynamic> json) {
    return AiWarningItem(
      taskId: json['taskId'] as String? ?? json['task_id'] as String?,
      type: json['type'] as String? ?? '',
      neededMinutes: json['neededMinutes'] as int? ?? json['needed_minutes'] as int?,
      freeMinutes: json['freeMinutes'] as int? ?? json['free_minutes'] as int?,
      message: json['message'] as String? ?? '',
    );
  }
}

class AiProposalResponse {
  final String? proposalId;
  final String status;
  final bool isFeasible;
  final int? missingMinutes;
  final String explanation;
  final DateTime? createdAt;
  final List<AiSlotItem> slots;
  final List<AiWarningItem> warnings;

  AiProposalResponse({
    this.proposalId,
    this.status = 'Pending',
    required this.isFeasible,
    this.missingMinutes,
    required this.explanation,
    this.createdAt,
    required this.slots,
    required this.warnings,
  });

  AiProposalResponse copyWith({
    String? proposalId,
    String? status,
    bool? isFeasible,
    int? missingMinutes,
    String? explanation,
    DateTime? createdAt,
    List<AiSlotItem>? slots,
    List<AiWarningItem>? warnings,
  }) {
    return AiProposalResponse(
      proposalId: proposalId ?? this.proposalId,
      status: status ?? this.status,
      isFeasible: isFeasible ?? this.isFeasible,
      missingMinutes: missingMinutes ?? this.missingMinutes,
      explanation: explanation ?? this.explanation,
      createdAt: createdAt ?? this.createdAt,
      slots: slots ?? this.slots,
      warnings: warnings ?? this.warnings,
    );
  }

  factory AiProposalResponse.fromJson(Map<String, dynamic> json) {
    final rawSlots = json['slots'] as List<dynamic>? ?? [];
    final rawWarnings = json['warnings'] as List<dynamic>? ?? [];

    final createdStr = json['createdAt'] as String? ?? json['created_at'] as String?;
    final created = createdStr != null ? DateTime.tryParse(createdStr)?.toLocal() : null;

    return AiProposalResponse(
      proposalId: json['id'] as String? ?? json['proposalId'] as String? ?? json['proposal_id'] as String?,
      status: json['status'] as String? ?? 'Pending',
      isFeasible: json['isFeasible'] as bool? ?? json['is_feasible'] as bool? ?? true,
      missingMinutes: json['missingMinutes'] as int? ?? json['missing_minutes'] as int?,
      explanation: json['explanation'] as String? ?? '',
      createdAt: created,
      slots: rawSlots.map((e) => AiSlotItem.fromJson(e as Map<String, dynamic>)).toList(),
      warnings: rawWarnings.map((e) => AiWarningItem.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}
