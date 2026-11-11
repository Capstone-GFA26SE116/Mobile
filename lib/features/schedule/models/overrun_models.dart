/// FR-16b proposal from `POST /schedule/overrun` (AI service): a slot runs over and the
/// user needs more time. Nothing is changed until the user applies it.
enum OverrunKind { extend, replan }

/// A slot and the times it should get.
class SlotTimes {
  final String slotId;
  final DateTime start;
  final DateTime end;

  const SlotTimes(this.slotId, this.start, this.end);
}

class OverrunMove {
  final String slotId;
  final String taskTitle;
  final DateTime oldStart;
  final DateTime oldEnd;
  final DateTime newStart;
  final DateTime newEnd;

  const OverrunMove({
    required this.slotId,
    required this.taskTitle,
    required this.oldStart,
    required this.oldEnd,
    required this.newStart,
    required this.newEnd,
  });

  factory OverrunMove.fromJson(Map<String, dynamic> json) => OverrunMove(
        slotId: json['slot_id'] as String,
        taskTitle: json['task_title'] as String,
        oldStart: _time(json['old_start']),
        oldEnd: _time(json['old_end']),
        newStart: _time(json['new_start']),
        newEnd: _time(json['new_end']),
      );
}

class OverrunPlan {
  final OverrunKind kind;
  final SlotTimes extended; // the late slot with its new end
  final List<OverrunMove> moves; // empty when extending
  final List<String> notPlacedTitles; // would miss their deadline: left as they are
  final bool pastDayEnd;
  final String summary;

  const OverrunPlan({
    required this.kind,
    required this.extended,
    required this.moves,
    required this.notPlacedTitles,
    required this.pastDayEnd,
    required this.summary,
  });

  /// Every slot to update, the late one first.
  List<SlotTimes> get changes => [
        extended,
        for (final m in moves) SlotTimes(m.slotId, m.newStart, m.newEnd),
      ];

  factory OverrunPlan.fromJson(Map<String, dynamic> json) {
    final extended = json['extended'] as Map<String, dynamic>;
    return OverrunPlan(
      kind: json['kind'] == 'replan' ? OverrunKind.replan : OverrunKind.extend,
      extended: SlotTimes(
        extended['slot_id'] as String,
        _time(extended['start']),
        _time(extended['end']),
      ),
      moves: [
        for (final m in json['moves'] as List<dynamic>? ?? [])
          OverrunMove.fromJson(m as Map<String, dynamic>),
      ],
      notPlacedTitles: [
        for (final n in json['not_placed'] as List<dynamic>? ?? [])
          (n as Map<String, dynamic>)['task_title'] as String,
      ],
      pastDayEnd: json['past_day_end'] as bool? ?? false,
      summary: json['summary'] as String? ?? '',
    );
  }
}

DateTime _time(Object? value) => DateTime.parse(value as String).toLocal();
