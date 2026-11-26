import '../../schedule/models/reshuffle_models.dart';
import '../widgets/avatar_view.dart';

/// `POST /assistant/turn` response (FR-22 section 1, `Turn`).
enum TurnKind { answer, clarify, unsupported, smalltalk, confirm }

class Turn {
  static const int maxOptions = 3;
  static const int maxSuggestions = 3;

  final TurnKind kind;

  /// Name of the read tool the AI service ran, null for unsupported / smalltalk.
  final String? tool;
  final String reply;
  final AvatarEmotion emotion;

  /// Only for [TurnKind.clarify]: the projects / tasks the user may have meant.
  final List<TurnOption> options;

  /// Sentences the user can tap instead of speaking (unsupported, smalltalk "help").
  final List<String> suggestions;

  /// Only for [TurnKind.confirm] (FR-22c): what the app runs after the user says yes.
  final TurnAction? action;

  const Turn({
    required this.kind,
    required this.reply,
    required this.emotion,
    this.tool,
    this.options = const [],
    this.suggestions = const [],
    this.action,
  });

  /// Throws [FormatException] when `kind` or `reply` is missing or unknown.
  /// A confirm turn whose action this app does not know yet is read as a plain
  /// answer (the reply is still said), so a newer AI service never breaks the app.
  factory Turn.fromJson(Map<String, dynamic> json) {
    var kind = TurnKind.values.asNameMap()[json['kind']];
    final reply = (json['reply'] as String? ?? '').trim();
    if (kind == null || reply.isEmpty) {
      throw FormatException('Unexpected turn: kind=${json['kind']}');
    }
    final options = json['options'] as List<dynamic>? ?? const [];
    final suggestions = json['suggestions'] as List<dynamic>? ?? const [];
    TurnAction? action;
    if (json['action'] is Map<String, dynamic>) {
      try {
        action = TurnAction.fromJson(json['action'] as Map<String, dynamic>);
      } on UnknownActionException {
        action = null;
        kind = TurnKind.answer;
      }
    }
    if (kind == TurnKind.confirm && action == null) {
      throw const FormatException('A confirm turn without an action');
    }
    return Turn(
      kind: kind,
      tool: json['tool'] as String?,
      reply: reply,
      emotion: emotionOf(json['emotion'] as String?),
      options: options
          .map((o) => TurnOption.fromJson(o as Map<String, dynamic>))
          .where((o) => o.id.isNotEmpty && o.title.isNotEmpty)
          .take(maxOptions)
          .toList(),
      suggestions: suggestions
          .map((s) => (s as String).trim())
          .where((s) => s.isNotEmpty)
          .take(maxSuggestions)
          .toList(),
      action: kind == TurnKind.confirm ? action : null,
    );
  }

  /// Unknown or missing emotions fall back to neutral, so a new server value never breaks the face.
  static AvatarEmotion emotionOf(String? name) =>
      AvatarEmotion.values.asNameMap()[name] ?? AvatarEmotion.neutral;
}

/// An action type this app does not know (a newer AI service).
class UnknownActionException extends FormatException {
  const UnknownActionException(super.message);
}

/// FR-22c: the kinds of action the app may run on the Backend; FR-22d adds the
/// three schedule changes, each with the proposal to show (`preview`).
enum TurnActionType {
  startTimer,
  stopTimer,
  extendTimer,
  approveProposal,
  insertBlock,
  postpone,
  catchUp,
}

/// What a `confirm` turn asks the user to approve. The AI service never runs it.
class TurnAction {
  static const Map<String, TurnActionType> _types = {
    'start_timer': TurnActionType.startTimer,
    'stop_timer': TurnActionType.stopTimer,
    'extend_timer': TurnActionType.extendTimer,
    'approve_proposal': TurnActionType.approveProposal,
    'insert_block': TurnActionType.insertBlock,
    'postpone': TurnActionType.postpone,
    'catch_up': TurnActionType.catchUp,
  };

  final TurnActionType type;
  final String? taskId;
  final String? taskTitle;
  final String? slotId;
  final String? sessionId;

  /// Backend `FocusStopReason` name: "Completed" or "Interrupted".
  final String? stopReason;
  final int? minutes;
  final String? proposalId;

  /// FR-22d: the proposal of an insertBlock / postpone / catchUp action.
  final InsertPreview? insert;
  final PostponePreview? postponed;
  final CatchUpPreview? catchUp;

  const TurnAction({
    required this.type,
    this.taskId,
    this.taskTitle,
    this.slotId,
    this.sessionId,
    this.stopReason,
    this.minutes,
    this.proposalId,
    this.insert,
    this.postponed,
    this.catchUp,
  });

  bool get finishes => stopReason == 'Completed';

  /// Throws [FormatException] for an unknown type or a missing id the action needs.
  factory TurnAction.fromJson(Map<String, dynamic> json) {
    final type = _types[json['type']];
    if (type == null) {
      throw UnknownActionException('Unknown action: ${json['type']}');
    }
    final preview = json['preview'] as Map<String, dynamic>?;
    final action = TurnAction(
      type: type,
      taskId: json['task_id'] as String?,
      taskTitle: json['task_title'] as String?,
      slotId: json['slot_id'] as String?,
      sessionId: json['session_id'] as String?,
      stopReason: json['stop_reason'] as String?,
      minutes: json['minutes'] as int?,
      proposalId: json['proposal_id'] as String?,
      insert: type == TurnActionType.insertBlock && preview != null
          ? InsertPreview.fromJson(preview)
          : null,
      postponed: type == TurnActionType.postpone && preview != null
          ? PostponePreview.fromJson(preview)
          : null,
      catchUp: type == TurnActionType.catchUp && preview != null
          ? CatchUpPreview.fromJson(preview)
          : null,
    );
    final complete = switch (type) {
      TurnActionType.startTimer => action.taskId != null,
      TurnActionType.stopTimer =>
        action.sessionId != null && action.stopReason != null,
      TurnActionType.extendTimer =>
        action.slotId != null && action.minutes != null,
      TurnActionType.approveProposal => action.proposalId != null,
      TurnActionType.insertBlock => action.insert != null,
      TurnActionType.postpone => action.postponed?.move != null,
      TurnActionType.catchUp => action.catchUp?.moves.isNotEmpty ?? false,
    };
    if (!complete) throw FormatException('Incomplete action: ${json['type']}');
    return action;
  }
}

class TurnOption {
  final String id;
  final String title;

  const TurnOption({required this.id, required this.title});

  factory TurnOption.fromJson(Map<String, dynamic> json) => TurnOption(
    id: (json['id'] as String? ?? '').trim(),
    title: (json['title'] as String? ?? '').trim(),
  );
}

enum TurnRole { user, assistant }

/// One line of the on-screen conversation sent back as `history` (FR-22 decision #10).
class TurnHistoryEntry {
  final TurnRole role;
  final String text;

  const TurnHistoryEntry(this.role, this.text);

  Map<String, dynamic> toJson() => {'role': role.name, 'text': text};
}
