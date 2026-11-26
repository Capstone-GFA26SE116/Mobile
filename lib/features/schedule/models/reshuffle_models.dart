/// FR-22d proposals from the AI service (`/schedule/insert-block`, `/postpone`,
/// `/catch-up`, also sent as `action.preview` by `/assistant/turn`). Read only:
/// the app applies them through the Backend after the user agrees.
library;

DateTime _time(dynamic value) => DateTime.parse(value as String).toLocal();

/// One slot that moves, with its old time kept for undo (M18).
class ReshuffleMove {
  final String slotId;
  final String taskTitle;
  final DateTime oldStart;
  final DateTime oldEnd;
  final DateTime newStart;
  final DateTime newEnd;

  const ReshuffleMove({
    required this.slotId,
    required this.taskTitle,
    required this.oldStart,
    required this.oldEnd,
    required this.newStart,
    required this.newEnd,
  });

  factory ReshuffleMove.fromJson(Map<String, dynamic> json) => ReshuffleMove(
    slotId: json['slot_id'] as String,
    taskTitle: json['task_title'] as String? ?? '',
    oldStart: _time(json['old_start']),
    oldEnd: _time(json['old_end']),
    newStart: _time(json['new_start']),
    newEnd: _time(json['new_end']),
  );
}

/// Something in the way of an urgent block that the AI never moves (M4).
class BlockConflict {
  /// fixed_task / calendar_event / group_slot / started_slot
  final String kind;
  final String? id;
  final String title;
  final DateTime start;
  final DateTime end;
  final bool important;

  /// client / personal / other_people / group / running
  final String why;

  const BlockConflict({
    required this.kind,
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    required this.important,
    required this.why,
  });

  factory BlockConflict.fromJson(Map<String, dynamic> json) => BlockConflict(
    kind: json['kind'] as String? ?? '',
    id: json['id'] as String?,
    title: json['title'] as String? ?? '',
    start: _time(json['start']),
    end: _time(json['end']),
    important: json['important'] as bool? ?? false,
    why: json['why'] as String? ?? '',
  );

  /// Short Vietnamese label for the card.
  String get whyLabel => switch (why) {
    'client' => 'việc với khách',
    'personal' => 'việc cá nhân',
    'other_people' => 'lịch Google',
    'group' => 'việc nhóm',
    'running' => 'đang làm',
    _ => '',
  };
}

/// What the user can do about conflicts (M4).
enum BlockChoice { otherTime, overwrite, cancel }

BlockChoice? _choice(dynamic value) => switch (value) {
  'other_time' => BlockChoice.otherTime,
  'overwrite' => BlockChoice.overwrite,
  'cancel' => BlockChoice.cancel,
  _ => null,
};

List<T> _list<T>(dynamic value, T Function(Map<String, dynamic>) read) => [
  for (final item in value as List<dynamic>? ?? const [])
    read(item as Map<String, dynamic>),
];

List<String> _titles(dynamic value) => [
  for (final item in value as List<dynamic>? ?? const [])
    (item as Map<String, dynamic>)['task_title'] as String? ?? '',
];

/// M3 / M4: urgent work from [start] to [end].
class InsertPreview {
  final String title;
  final DateTime start;
  final DateTime end;
  final bool pastDayEnd;
  final String? projectId;
  final String? domainId;
  final List<ReshuffleMove> moves;
  final List<String> notPlaced;
  final List<BlockConflict> conflicts;
  final List<BlockChoice> options;
  final BlockChoice? recommendation;
  final ({DateTime start, DateTime end})? otherTime;
  final List<String> skipTaskIds;
  final String summary;

  const InsertPreview({
    required this.title,
    required this.start,
    required this.end,
    required this.pastDayEnd,
    required this.projectId,
    required this.domainId,
    required this.moves,
    required this.notPlaced,
    required this.conflicts,
    required this.options,
    required this.recommendation,
    required this.otherTime,
    required this.skipTaskIds,
    required this.summary,
  });

  bool get hasConflicts => conflicts.isNotEmpty;

  factory InsertPreview.fromJson(Map<String, dynamic> json) {
    final block = json['block'] as Map<String, dynamic>;
    final other = json['other_time'] as Map<String, dynamic>?;
    return InsertPreview(
      title: block['title'] as String? ?? '',
      start: _time(block['start']),
      end: _time(block['end']),
      pastDayEnd: json['past_day_end'] as bool? ?? false,
      projectId: json['project_id'] as String?,
      domainId: json['domain_id'] as String?,
      moves: _list(json['moves'], ReshuffleMove.fromJson),
      notPlaced: _titles(json['not_placed']),
      conflicts: _list(json['conflicts'], BlockConflict.fromJson),
      options: [
        for (final o in json['options'] as List<dynamic>? ?? const [])
          ?_choice(o),
      ],
      recommendation: _choice(json['recommendation']),
      otherTime: other == null
          ? null
          : (start: _time(other['start']), end: _time(other['end'])),
      skipTaskIds: [
        for (final id in json['skip_task_ids'] as List<dynamic>? ?? const [])
          id as String,
      ],
      summary: json['summary'] as String? ?? '',
    );
  }
}

/// M7: one slot to the next working day; [move] is null when nothing fits before the deadline.
class PostponePreview {
  final String slotId;
  final String taskTitle;
  final ReshuffleMove? move;
  final String summary;

  const PostponePreview({
    required this.slotId,
    required this.taskTitle,
    required this.move,
    required this.summary,
  });

  factory PostponePreview.fromJson(Map<String, dynamic> json) =>
      PostponePreview(
        slotId: json['slot_id'] as String,
        taskTitle: json['task_title'] as String? ?? '',
        move: json['move'] == null
            ? null
            : ReshuffleMove.fromJson(json['move'] as Map<String, dynamic>),
        summary: json['summary'] as String? ?? '',
      );
}

/// M10: missed slots placed again from now.
class CatchUpPreview {
  final List<ReshuffleMove> moves;
  final List<String> notPlaced;
  final String summary;

  const CatchUpPreview({
    required this.moves,
    required this.notPlaced,
    required this.summary,
  });

  factory CatchUpPreview.fromJson(Map<String, dynamic> json) => CatchUpPreview(
    moves: _list(json['moves'], ReshuffleMove.fromJson),
    notPlaced: _titles(json['not_placed']),
    summary: json['summary'] as String? ?? '',
  );
}

/// What was changed on the Backend, so it can be put back (M18).
class ReshuffleUndo {
  final String? createdTaskId;
  final List<({String slotId, DateTime start, DateTime end, String status})>
  slots;
  final List<({String taskId, String status})> skippedTasks;
  final DateTime appliedAt;

  const ReshuffleUndo({
    required this.createdTaskId,
    required this.slots,
    required this.skippedTasks,
    required this.appliedAt,
  });

  static const Duration window = Duration(minutes: 5);

  bool get isEmpty =>
      createdTaskId == null && slots.isEmpty && skippedTasks.isEmpty;

  bool isOpenAt(DateTime now) => !isEmpty && now.difference(appliedAt) < window;
}
