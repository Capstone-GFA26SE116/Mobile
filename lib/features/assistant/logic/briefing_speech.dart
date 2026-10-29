import '../models/briefing.dart';

/// Builds the sentence the avatar reads for a briefing (plan section 2, "Câu đọc").
class BriefingSpeech {
  static const int maxWords = 60;
  static const String emptyDay =
      'Hôm nay bạn chưa có việc nào cần làm. Muốn mình xếp lịch không?';
  static const String calendarNotConnected = 'Bạn chưa kết nối Google Calendar.';

  static String build(Briefing briefing) {
    // Reasons are the longest part, so drop them first, then later tasks, to stay within maxWords.
    final attempts = [
      (withReason: true, taskLimit: 3),
      (withReason: false, taskLimit: 3),
      (withReason: false, taskLimit: 1),
    ];
    var text = '';
    for (final attempt in attempts) {
      text = _compose(briefing, withReason: attempt.withReason, taskLimit: attempt.taskLimit);
      if (wordCount(text) <= maxWords) break;
    }
    return text;
  }

  static int wordCount(String text) =>
      text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

  static String _compose(Briefing briefing, {required bool withReason, required int taskLimit}) {
    final parts = <String>[];
    final tasks = briefing.topTasks.take(taskLimit).toList();

    if (briefing.scheduleCount == 0 && tasks.isEmpty && !briefing.hasRisk) {
      parts.add(emptyDay);
    } else {
      parts.add('Hôm nay bạn có ${briefing.scheduleCount} việc trên lịch.');
      if (tasks.isNotEmpty) {
        final first = tasks.first;
        final reason = first.reason;
        parts.add(withReason && reason != null
            ? 'Nên làm trước: ${first.title}, vì ${_asClause(reason)}.'
            : 'Nên làm trước: ${first.title}.');
        if (tasks.length > 1) {
          parts.add('Sau đó là ${tasks.skip(1).map((t) => t.title).join(' và ')}.');
        }
      }
      if (briefing.hasRisk) {
        final names = briefing.atRiskTitles.take(2).join(' và ');
        parts.add('Cẩn thận: $names có nguy cơ trễ hạn.');
      }
    }

    if (!briefing.calendarConnected) parts.add(calendarNotConnected);
    return parts.join(' ');
  }

  /// "Còn cần khoảng 3 giờ." → "còn cần khoảng 3 giờ", to follow "vì".
  static String _asClause(String sentence) {
    final trimmed = sentence.trim().replaceFirst(RegExp(r'[.!?]+$'), '');
    if (trimmed.isEmpty) return trimmed;
    return trimmed[0].toLowerCase() + trimmed.substring(1);
  }
}
