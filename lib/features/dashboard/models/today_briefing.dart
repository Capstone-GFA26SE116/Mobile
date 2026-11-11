/// `GET /briefing/today` (AI service, FR-12) for the "AI Focus Today" card (W6-02).
/// The assistant keeps its own smaller `Briefing`; this one carries every part the card shows.
class TodayBriefing {
  final bool hasPendingProposal;
  final List<TopTask> topTasks; // at most 3, in the order to do them
  final List<AtRiskTask> atRisk;
  final String? productiveHint; // a full sentence, or null

  const TodayBriefing({
    required this.hasPendingProposal,
    required this.topTasks,
    required this.atRisk,
    this.productiveHint,
  });

  factory TodayBriefing.fromJson(Map<String, dynamic> json) {
    final hint = json['productive_hint'] as Map<String, dynamic>?;
    return TodayBriefing(
      hasPendingProposal: json['has_pending_proposal'] as bool? ?? false,
      topTasks: [
        for (final t in json['top_tasks'] as List<dynamic>? ?? const [])
          TopTask.fromJson(t as Map<String, dynamic>),
      ],
      atRisk: [
        for (final t in json['at_risk'] as List<dynamic>? ?? const [])
          AtRiskTask.fromJson(t as Map<String, dynamic>),
      ],
      productiveHint: _text(hint?['text']),
    );
  }
}

class TopTask {
  final String title;
  final String projectName;
  final DateTime deadline;
  final int remainingMinutes;
  final List<String> reasons; // full sentences, at most 2 shown
  final String? similarWarning; // "Similar tasks took 1.4× the plan…"

  const TopTask({
    required this.title,
    required this.projectName,
    required this.deadline,
    required this.remainingMinutes,
    required this.reasons,
    this.similarWarning,
  });

  factory TopTask.fromJson(Map<String, dynamic> json) {
    final warning = json['similar_warning'] as Map<String, dynamic>?;
    return TopTask(
      title: _text(json['title']) ?? '',
      projectName: _text(json['project_name']) ?? '',
      deadline: DateTime.parse(json['deadline'] as String).toLocal(),
      remainingMinutes: json['remaining_minutes'] as int? ?? 0,
      reasons: [
        for (final r in json['reasons'] as List<dynamic>? ?? const [])
          ?_text((r as Map<String, dynamic>)['text']),
      ],
      similarWarning: _text(warning?['text']),
    );
  }
}

class AtRiskTask {
  final String title;
  final DateTime deadline;
  final int missingMinutes;

  const AtRiskTask({
    required this.title,
    required this.deadline,
    required this.missingMinutes,
  });

  factory AtRiskTask.fromJson(Map<String, dynamic> json) => AtRiskTask(
        title: _text(json['title']) ?? '',
        deadline: DateTime.parse(json['deadline'] as String).toLocal(),
        missingMinutes: json['missing_minutes'] as int? ?? 0,
      );
}

String? _text(Object? value) {
  final text = (value as String?)?.trim();
  return text == null || text.isEmpty ? null : text;
}
