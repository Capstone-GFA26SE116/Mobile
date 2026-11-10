import '../widgets/avatar_view.dart';

/// `POST /assistant/turn` response (FR-22 section 1, `Turn`).
enum TurnKind { answer, clarify, unsupported, smalltalk }

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

  const Turn({
    required this.kind,
    required this.reply,
    required this.emotion,
    this.tool,
    this.options = const [],
    this.suggestions = const [],
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
    );
  }

  /// Unknown or missing emotions fall back to neutral, so a new server value never breaks the face.
  static AvatarEmotion emotionOf(String? name) =>
      AvatarEmotion.values.asNameMap()[name] ?? AvatarEmotion.neutral;
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
