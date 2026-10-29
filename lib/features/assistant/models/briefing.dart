/// The parts of `GET /briefing/today` the assistant reads aloud (see FR-12).
/// `all_day`, `has_pending_proposal`, `productive_hint` and internal codes are left out on purpose.
class Briefing {
  final bool calendarConnected;
  final int scheduleCount;
  final List<BriefingTopTask> topTasks;
  final List<String> atRiskTitles;

  const Briefing({
    required this.calendarConnected,
    required this.scheduleCount,
    required this.topTasks,
    required this.atRiskTitles,
  });

  bool get hasRisk => atRiskTitles.isNotEmpty;

  factory Briefing.fromJson(Map<String, dynamic> json) {
    final schedule = json['schedule'] as List<dynamic>? ?? const [];
    final topTasks = json['top_tasks'] as List<dynamic>? ?? const [];
    final atRisk = json['at_risk'] as List<dynamic>? ?? const [];
    return Briefing(
      calendarConnected: json['calendar_connected'] as bool? ?? true,
      scheduleCount: schedule.length,
      topTasks: topTasks
          .map((t) => BriefingTopTask.fromJson(t as Map<String, dynamic>))
          .where((t) => t.title.isNotEmpty)
          .toList(),
      atRiskTitles: atRisk
          .map((t) => ((t as Map<String, dynamic>)['title'] as String? ?? '').trim())
          .where((title) => title.isNotEmpty)
          .toList(),
    );
  }
}

class BriefingTopTask {
  final String title;

  /// Text of the first reason, already a full Vietnamese sentence from the AI service.
  final String? reason;

  const BriefingTopTask({required this.title, this.reason});

  factory BriefingTopTask.fromJson(Map<String, dynamic> json) {
    final reasons = json['reasons'] as List<dynamic>? ?? const [];
    final firstReason = reasons.isEmpty
        ? null
        : ((reasons.first as Map<String, dynamic>)['text'] as String?)?.trim();
    return BriefingTopTask(
      title: (json['title'] as String? ?? '').trim(),
      reason: (firstReason == null || firstReason.isEmpty) ? null : firstReason,
    );
  }
}
