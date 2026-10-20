class AiSlotItem {
  final String slotId;
  final String taskId;
  final String? subTaskId;
  final DateTime start;
  final DateTime end;
  final int proposedMinutes;
  final String? explanation;

  AiSlotItem({
    required this.slotId,
    required this.taskId,
    this.subTaskId,
    required this.start,
    required this.end,
    required this.proposedMinutes,
    this.explanation,
  });

  factory AiSlotItem.fromJson(Map<String, dynamic> json) {
    return AiSlotItem(
      slotId: json['slotId'] as String? ?? json['slot_id'] as String? ?? '',
      taskId: json['taskId'] as String? ?? json['task_id'] as String? ?? '',
      subTaskId: json['subTaskId'] as String? ?? json['subtask_id'] as String?,
      start: DateTime.tryParse(json['start'] as String? ?? '')?.toLocal() ?? DateTime.now(),
      end: DateTime.tryParse(json['end'] as String? ?? '')?.toLocal() ?? DateTime.now(),
      proposedMinutes: json['proposedMinutes'] as int? ?? json['proposed_minutes'] as int? ?? 0,
      explanation: json['explanation'] as String?,
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
  final bool isFeasible;
  final int? missingMinutes;
  final String explanation;
  final List<AiSlotItem> slots;
  final List<AiWarningItem> warnings;

  AiProposalResponse({
    this.proposalId,
    required this.isFeasible,
    this.missingMinutes,
    required this.explanation,
    required this.slots,
    required this.warnings,
  });

  factory AiProposalResponse.fromJson(Map<String, dynamic> json) {
    final rawSlots = json['slots'] as List<dynamic>? ?? [];
    final rawWarnings = json['warnings'] as List<dynamic>? ?? [];

    return AiProposalResponse(
      proposalId: json['proposalId'] as String? ?? json['proposal_id'] as String?,
      isFeasible: json['isFeasible'] as bool? ?? json['is_feasible'] as bool? ?? true,
      missingMinutes: json['missingMinutes'] as int? ?? json['missing_minutes'] as int?,
      explanation: json['explanation'] as String? ?? '',
      slots: rawSlots.map((e) => AiSlotItem.fromJson(e as Map<String, dynamic>)).toList(),
      warnings: rawWarnings.map((e) => AiWarningItem.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}
