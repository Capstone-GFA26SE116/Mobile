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
  factory Turn.fromJson(Map<String, dynamic> json) {
    final kind = TurnKind.values.asNameMap()[json['kind']];
    final reply = (json['reply'] as String? ?? '').trim();
    if (kind == null || reply.isEmpty) {
      throw FormatException('Unexpected turn: kind=${json['kind']}');
    }
    final options = json['options'] as List<dynamic>? ?? const [];
    final suggestions = json['suggestions'] as List<dynamic>? ?? const [];
    final action = json['action'] is Map<String, dynamic>
        ? TurnAction.fromJson(json['action'] as Map<String, dynamic>)
        : null;
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

/// FR-22c: the 4 kinds of action the app may run on the Backend.
enum TurnActionType { startTimer, stopTimer, extendTimer, approveProposal }

/// What a `confirm` turn asks the user to approve. The AI service never runs it.
class TurnAction {
  static const Map<String, TurnActionType> _types = {
    'start_timer': TurnActionType.startTimer,
    'stop_timer': TurnActionType.stopTimer,
    'extend_timer': TurnActionType.extendTimer,
    'approve_proposal': TurnActionType.approveProposal,
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

  const TurnAction({
    required this.type,
    this.taskId,
    this.taskTitle,
    this.slotId,
    this.sessionId,
    this.stopReason,
    this.minutes,
    this.proposalId,
  });

  bool get finishes => stopReason == 'Completed';

  /// Throws [FormatException] for an unknown type or a missing id the action needs.
  factory TurnAction.fromJson(Map<String, dynamic> json) {
    final type = _types[json['type']];
    if (type == null) throw FormatException('Unknown action: ${json['type']}');
    final action = TurnAction(
      type: type,
      taskId: json['task_id'] as String?,
      taskTitle: json['task_title'] as String?,
      slotId: json['slot_id'] as String?,
      sessionId: json['session_id'] as String?,
      stopReason: json['stop_reason'] as String?,
      minutes: json['minutes'] as int?,
      proposalId: json['proposal_id'] as String?,
    );
    final complete = switch (type) {
      TurnActionType.startTimer => action.taskId != null,
      TurnActionType.stopTimer =>
        action.sessionId != null && action.stopReason != null,
      TurnActionType.extendTimer =>
        action.slotId != null && action.minutes != null,
      TurnActionType.approveProposal => action.proposalId != null,
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
