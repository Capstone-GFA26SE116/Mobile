import 'package:flutter_test/flutter_test.dart';
import 'package:metanoia_mobile/features/assistant/data/assistant_repository.dart';
import 'package:metanoia_mobile/features/assistant/logic/assistant_turn.dart';
import 'package:metanoia_mobile/features/assistant/logic/intent_router.dart';
import 'package:metanoia_mobile/features/assistant/models/briefing.dart';
import 'package:metanoia_mobile/features/assistant/screens/assistant_screen.dart';
import 'package:metanoia_mobile/features/assistant/widgets/avatar_view.dart';

// Step 8 flow (AC3, AC4, AC6), shared by spoken sentences and DEV_UTTERANCE (C3).
Briefing _briefing({List<String> atRisk = const []}) => Briefing.fromJson({
      'calendar_connected': true,
      'schedule': [
        {'title': 'A'},
      ],
      'top_tasks': [
        {
          'title': 'Viết landing page',
          'reasons': [
            {'code': 'deadline_soon', 'text': 'Hạn hôm nay.'},
          ],
        },
      ],
      'at_risk': [
        for (final title in atRisk) {'title': title},
      ],
    });

void main() {
  late int calls;

  AssistantTurn turnWith(Future<Briefing> Function() fetch) {
    calls = 0;
    return AssistantTurn(
      fetchBriefing: () {
        calls++;
        return fetch();
      },
    );
  }

  test('briefing question → reads the briefing, happy', () async {
    final reply = await turnWith(() async => _briefing())
        .answer('Hôm nay tôi nên làm gì?');
    expect(calls, 1);
    expect(reply.text, startsWith('Hôm nay bạn có 1 việc trên lịch.'));
    expect(reply.emotion, AvatarEmotion.happy);
  });

  test('at-risk deadline → neutral face', () async {
    final reply = await turnWith(() async => _briefing(atRisk: ['Viết landing page']))
        .answer('hom nay lam gi');
    expect(reply.emotion, AvatarEmotion.neutral);
    expect(reply.text, contains('có nguy cơ trễ hạn'));
  });

  test('other sentence → suggestion, no API call (AC4)', () async {
    final reply = await turnWith(() async => _briefing()).answer('Thời tiết thế nào?');
    expect(calls, 0);
    expect(reply.text, IntentRouter.fallbackReply);
  });

  test('nothing heard → ask again, no API call', () async {
    final reply = await turnWith(() async => _briefing()).answer('   ');
    expect(calls, 0);
    expect(reply.text, AssistantTurn.notHeard);
  });

  test('API error → error sentence, sad, no fake data (AC6)', () async {
    final reply = await turnWith(
      () async => throw const AssistantException(AssistantErrorKind.unauthorized),
    ).answer('Hôm nay tôi nên làm gì?');
    expect(reply.text, const AssistantException(AssistantErrorKind.unauthorized).message);
    expect(reply.emotion, AvatarEmotion.sad);
  });

  test('AssistantScreen without dev options keeps the normal behaviour (C3, C4)', () {
    const screen = AssistantScreen();
    expect(screen.devUtterance, isNull);
    expect(screen.devTour, isFalse);
  });
}
