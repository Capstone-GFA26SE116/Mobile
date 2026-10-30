import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:metanoia_mobile/features/assistant/data/assistant_repository.dart';
import 'package:metanoia_mobile/features/assistant/logic/assistant_controller.dart';
import 'package:metanoia_mobile/features/assistant/logic/assistant_turn.dart';
import 'package:metanoia_mobile/features/assistant/models/assistant_turn.dart';
import 'package:metanoia_mobile/features/assistant/models/briefing.dart';
import 'package:metanoia_mobile/features/assistant/widgets/avatar_view.dart';

// Agent plan T2 (AC1–AC4).
typedef _TurnCall = ({
  String text,
  List<TurnHistoryEntry> history,
  String? selectedId,
});

class _FakeRepository implements AssistantRepository {
  final List<_TurnCall> turnCalls = [];
  int briefingCalls = 0;
  Future<Turn> Function(_TurnCall call) onTurn;
  Future<Briefing> Function() onBriefing;

  _FakeRepository({
    required this.onTurn,
    Future<Briefing> Function()? onBriefing,
  }) : onBriefing = onBriefing ?? (() async => _briefing);

  @override
  Future<Turn> turn(
    String text,
    List<TurnHistoryEntry> history, {
    String? selectedId,
  }) {
    final call = (
      text: text,
      history: List.of(history),
      selectedId: selectedId,
    );
    turnCalls.add(call);
    return onTurn(call);
  }

  @override
  Future<Briefing> getTodayBriefing() {
    briefingCalls++;
    return onBriefing();
  }
}

final Briefing _briefing = Briefing.fromJson({
  'schedule': [
    {'title': 'A'},
  ],
  'top_tasks': [
    {'title': 'Viết landing page'},
  ],
});

Turn _answer(String reply, {AvatarEmotion emotion = AvatarEmotion.happy}) =>
    Turn(
      kind: TurnKind.answer,
      tool: 'today_briefing',
      reply: reply,
      emotion: emotion,
    );

Future<Turn> Function(_TurnCall) _throws(AssistantErrorKind kind) =>
    (_) async => throw AssistantException(kind);

void main() {
  late _FakeRepository repository;
  late List<String> spoken;
  late bool hasVoice;

  AssistantController controllerWith(
    Future<Turn> Function(_TurnCall call) onTurn, {
    Future<Briefing> Function()? onBriefing,
  }) {
    repository = _FakeRepository(onTurn: onTurn, onBriefing: onBriefing);
    spoken = [];
    hasVoice = true;
    return AssistantController(
      repository: repository,
      speak: (text) async {
        spoken.add(text);
        return hasVoice;
      },
    );
  }

  test('answer: thinking while waiting, then speaks the reply with its emotion (AC1)', () async {
    final pending = Completer<Turn>();
    final controller = controllerWith((_) => pending.future);

    controller.startListening();
    expect(controller.phase, AssistantPhase.listening);
    controller.updateHeard('Chiều nay');
    expect(controller.heard, 'Chiều nay');

    final asking = controller.ask('Chiều nay tôi có gì?');
    expect(controller.phase, AssistantPhase.thinking);
    expect(controller.emotion, AvatarEmotion.thinking);

    pending.complete(_answer('Chiều nay bạn có 2 việc.'));
    await asking;

    expect(repository.turnCalls.single.text, 'Chiều nay tôi có gì?');
    expect(repository.turnCalls.single.history, isEmpty);
    expect(repository.turnCalls.single.selectedId, isNull);
    expect(controller.phase, AssistantPhase.speaking);
    expect(controller.reply, 'Chiều nay bạn có 2 việc.');
    expect(controller.emotion, AvatarEmotion.happy);
    expect(spoken, ['Chiều nay bạn có 2 việc.']);

    controller.speakingChanged(false);
    expect(controller.phase, AssistantPhase.idle);
  });

  test('history: each turn sends the previous lines, at most 6', () async {
    var n = 0;
    final controller = controllerWith((_) async => _answer('Trả lời ${++n}.'));

    for (var i = 1; i <= 5; i++) {
      await controller.ask('Câu $i');
    }

    final last = repository.turnCalls.last;
    expect(last.text, 'Câu 5');
    expect(last.history.length, AssistantController.historyMaxEntries);
    expect(last.history.first.role, TurnRole.user);
    expect(last.history.first.text, 'Câu 2');
    expect(last.history.last.role, TurnRole.assistant);
    expect(last.history.last.text, 'Trả lời 4.');
    expect(controller.history.last.text, 'Trả lời 5.');
  });

  test(
    'history: oldest lines dropped past 2000 characters; text clipped to 500',
    () async {
      final controller = controllerWith((_) async => _answer('Được.'));
      final long = 'a' * 900;

      await controller.ask(long);
      await controller.ask(long);
      await controller.ask('b' * 600);

      expect(
        repository.turnCalls.last.text.length,
        AssistantController.textMaxChars,
      );
      final chars = controller.history.fold<int>(
        0,
        (sum, e) => sum + e.text.length,
      );
      expect(chars, lessThanOrEqualTo(AssistantController.historyMaxChars));
      expect(controller.history.last.text, 'Được.');
    },
  );

  test(
    'unsupported: shows suggestions; tapping one sends that sentence (AC2)',
    () async {
      final controller = controllerWith(
        (call) async => call.text == 'Bật timer giúp tôi'
            ? const Turn(
                kind: TurnKind.unsupported,
                reply: 'Mình chưa hỗ trợ việc này.',
                emotion: AvatarEmotion.neutral,
                suggestions: [
                  'Hôm nay tôi nên làm gì?',
                  'Deadline nào đang gấp?',
                ],
              )
            : _answer('Hạn gấp nhất là Viết landing page.'),
      );

      await controller.ask('Bật timer giúp tôi');
      expect(controller.reply, 'Mình chưa hỗ trợ việc này.');
      expect(controller.suggestions, [
        'Hôm nay tôi nên làm gì?',
        'Deadline nào đang gấp?',
      ]);
      expect(controller.options, isEmpty);

      await controller.ask(controller.suggestions[1]);
      expect(repository.turnCalls.last.text, 'Deadline nào đang gấp?');
      expect(controller.heard, 'Deadline nào đang gấp?');
      expect(controller.suggestions, isEmpty);
      expect(controller.reply, 'Hạn gấp nhất là Viết landing page.');
    },
  );

  test('clarify: shows options; choosing re-sends the question with selected_id (AC3)', () async {
    const options = [
      TurnOption(id: 'p-1', title: 'Landing page — Client A'),
      TurnOption(id: 'p-2', title: 'Landing page — Client B'),
    ];
    final controller = controllerWith(
      (call) async => call.text == 'Chào'
          ? _answer('Chào bạn!')
          : call.selectedId == null
          ? const Turn(
              kind: TurnKind.clarify,
              tool: 'project_progress',
              reply: 'Bạn muốn hỏi dự án nào?',
              emotion: AvatarEmotion.thinking,
              options: options,
            )
          : _answer('Landing page — Client B đã xong 40%.'),
    );

    await controller.ask('Chào');
    await controller.ask('Dự án landing tới đâu rồi?');
    expect(controller.emotion, AvatarEmotion.thinking);
    expect(controller.options, options);

    await controller.choose(controller.options[1]);
    final call = repository.turnCalls.last;
    expect(call.text, 'Dự án landing tới đâu rồi?');
    expect(call.selectedId, 'p-2');
    // Same history as the question itself, without the clarify exchange.
    expect(call.history.map((e) => e.text), ['Chào', 'Chào bạn!']);
    expect(controller.options, isEmpty);
    expect(controller.reply, 'Landing page — Client B đã xong 40%.');
    expect(controller.history.map((e) => e.text), [
      'Chào',
      'Chào bạn!',
      'Dự án landing tới đâu rồi?',
      'Landing page — Client B đã xong 40%.',
    ]);
  });

  test('a new question drops the pending clarify', () async {
    const option = TurnOption(id: 'p-1', title: 'A');
    final controller = controllerWith(
      (_) async => const Turn(
        kind: TurnKind.clarify,
        reply: 'Dự án nào?',
        emotion: AvatarEmotion.thinking,
        options: [option],
      ),
    );

    await controller.ask('Tiến độ dự án A?');
    controller.startListening();
    await controller.choose(option);
    expect(repository.turnCalls, hasLength(1));
  });

  for (final kind in [
    AssistantErrorKind.quotaExceeded,
    AssistantErrorKind.noPlan,
    AssistantErrorKind.network,
    AssistantErrorKind.server,
  ]) {
    test(
      '${kind.name} + briefing sentence → MVP keyword path via /briefing/today (AC4)',
      () async {
        final controller = controllerWith(_throws(kind));
        await controller.ask('Hôm nay tôi nên làm gì?');
        expect(repository.briefingCalls, 1);
        expect(
          controller.reply,
          startsWith('Hôm nay bạn có 1 việc trên lịch.'),
        );
        expect(controller.emotion, AvatarEmotion.happy);
        expect(controller.history, isEmpty);
      },
    );

    test(
      '${kind.name} + other sentence → that error, sad, no briefing (AC4)',
      () async {
        final controller = controllerWith(_throws(kind));
        await controller.ask('Chiều nay tôi có gì?');
        expect(repository.briefingCalls, 0);
        expect(controller.reply, AssistantException(kind).message);
        expect(controller.emotion, AvatarEmotion.sad);
      },
    );
  }

  test('401 → asks to sign in again, no fallback', () async {
    final controller = controllerWith(_throws(AssistantErrorKind.unauthorized));
    await controller.ask('Hôm nay tôi nên làm gì?');
    expect(repository.briefingCalls, 0);
    expect(
      controller.reply,
      const AssistantException(AssistantErrorKind.unauthorized).message,
    );
  });

  test(
    '429 and the fallback briefing fails too → its error, no fake data',
    () async {
      final controller = controllerWith(
        _throws(AssistantErrorKind.quotaExceeded),
        onBriefing: () async =>
            throw const AssistantException(AssistantErrorKind.network),
      );
      await controller.ask('Hôm nay tôi nên làm gì?');
      expect(
        controller.reply,
        const AssistantException(AssistantErrorKind.network).message,
      );
      expect(controller.emotion, AvatarEmotion.sad);
    },
  );

  test('nothing heard → ask again, no call', () async {
    final controller = controllerWith((_) async => _answer('x'));
    await controller.ask('  ');
    expect(repository.turnCalls, isEmpty);
    expect(controller.reply, AssistantTurn.notHeard);
  });

  test(
    'an answer arriving after the mic is pressed again is dropped',
    () async {
      final pending = Completer<Turn>();
      final controller = controllerWith((_) => pending.future);

      final asking = controller.ask('Chiều nay tôi có gì?');
      controller.startListening();
      pending.complete(_answer('Muộn rồi.'));
      await asking;

      expect(controller.phase, AssistantPhase.listening);
      expect(controller.reply, isNull);
      expect(spoken, isEmpty);
    },
  );

  test('no Vietnamese voice → reply stays as text, back to idle', () async {
    final controller = controllerWith((_) async => _answer('Chào bạn.'));
    hasVoice = false;
    await controller.ask('Chào');
    expect(controller.noVoice, isTrue);
    expect(controller.reply, 'Chào bạn.');
    expect(controller.phase, AssistantPhase.idle);
  });
}
