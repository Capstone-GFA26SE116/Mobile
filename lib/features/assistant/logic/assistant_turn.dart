import '../data/assistant_repository.dart';
import '../models/briefing.dart';
import '../widgets/avatar_view.dart';
import 'briefing_speech.dart';
import 'intent_router.dart';

/// What the avatar says back, and with which face.
class AssistantReply {
  final String text;
  final AvatarEmotion emotion;

  const AssistantReply(this.text, this.emotion);
}

/// Decides the answer to one sentence (plan section 2, steps 2–3 of "Luồng một lần nói").
/// Used for both spoken sentences and the debug DEV_UTTERANCE, so both take the same path.
class AssistantTurn {
  static const String notHeard =
      'Mình chưa nghe rõ, bạn giữ nút và nói lại nhé.';

  final Future<Briefing> Function() fetchBriefing;

  const AssistantTurn({required this.fetchBriefing});

  /// Whether [sentence] needs the briefing API, so the screen can show "thinking" first.
  static bool needsBriefing(String sentence) =>
      sentence.trim().isNotEmpty &&
      IntentRouter.route(sentence) == AssistantIntent.briefing;

  Future<AssistantReply> answer(String sentence) async {
    if (sentence.trim().isEmpty) {
      return const AssistantReply(notHeard, AvatarEmotion.neutral);
    }
    if (!needsBriefing(sentence)) {
      return const AssistantReply(
        IntentRouter.fallbackReply,
        AvatarEmotion.neutral,
      );
    }
    try {
      final briefing = await fetchBriefing();
      return AssistantReply(
        BriefingSpeech.build(briefing),
        briefing.hasRisk ? AvatarEmotion.neutral : AvatarEmotion.happy,
      );
    } on AssistantException catch (e) {
      return AssistantReply(e.message, AvatarEmotion.sad);
    }
  }
}
