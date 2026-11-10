import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metanoia_mobile/features/assistant/data/assistant_repository.dart';
import 'package:metanoia_mobile/features/assistant/logic/assistant_controller.dart';
import 'package:metanoia_mobile/features/assistant/models/assistant_turn.dart';
import 'package:metanoia_mobile/features/assistant/models/briefing.dart';
import 'package:metanoia_mobile/features/assistant/widgets/assistant_prompts.dart';
import 'package:metanoia_mobile/features/assistant/widgets/avatar_view.dart';

// Agent plan T3 (AC2, AC3).
class _FakeRepository implements AssistantRepository {
  final List<({String text, String? selectedId})> calls = [];
  final Turn Function(String text, String? selectedId) onTurn;

  _FakeRepository(this.onTurn);

  @override
  Future<Turn> turn(
    String text,
    List<TurnHistoryEntry> history, {
    String? selectedId,
  }) async {
    calls.add((text: text, selectedId: selectedId));
    return onTurn(text, selectedId);
  }

  @override
  Future<Briefing> getTodayBriefing() => throw UnimplementedError();
}

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

/// The prompts as the screen draws them, driven by a real controller.
Widget _screenPrompts(AssistantController controller) => _app(
  ListenableBuilder(
    listenable: controller,
    builder: (context, _) => AssistantPrompts(
      options: controller.options,
      suggestions: controller.suggestions,
      onOption: controller.choose,
      onSuggestion: controller.ask,
    ),
  ),
);

const _options = [
  TurnOption(id: 'p-1', title: 'Landing page — Client A'),
  TurnOption(id: 'p-2', title: 'Landing page — Client B'),
];

void main() {
  testWidgets('nothing to show → no chips', (tester) async {
    await tester.pumpWidget(
      _app(
        AssistantPrompts(
          options: const [],
          suggestions: const [],
          onOption: (_) {},
          onSuggestion: (_) {},
        ),
      ),
    );
    expect(find.byType(ActionChip), findsNothing);
  });

  testWidgets('suggestions and options show and report taps', (tester) async {
    final tappedSuggestions = <String>[];
    final tappedOptions = <TurnOption>[];
    await tester.pumpWidget(
      _app(
        AssistantPrompts(
          options: _options,
          suggestions: const ['Hôm nay tôi nên làm gì?'],
          onOption: tappedOptions.add,
          onSuggestion: tappedSuggestions.add,
        ),
      ),
    );

    expect(find.byType(ActionChip), findsNWidgets(3));
    await tester.tap(find.text('Landing page — Client B'));
    await tester.tap(find.text('Hôm nay tôi nên làm gì?'));

    expect(tappedOptions, [_options[1]]);
    expect(tappedSuggestions, ['Hôm nay tôi nên làm gì?']);
  });

  testWidgets(
    'unsupported → tapping a suggestion asks it, no speaking needed (AC2)',
    (tester) async {
      final repository = _FakeRepository(
        (text, _) => text == 'Đặt vé máy bay'
            ? const Turn(
                kind: TurnKind.unsupported,
                reply: 'Mình chưa hỗ trợ việc này.',
                emotion: AvatarEmotion.neutral,
                suggestions: [
                  'Hôm nay tôi nên làm gì?',
                  'Deadline nào đang gấp?',
                ],
              )
            : const Turn(
                kind: TurnKind.answer,
                reply: 'Có 1 hạn gấp.',
                emotion: AvatarEmotion.neutral,
              ),
      );
      final controller = AssistantController(
        repository: repository,
        speak: (_) async => true,
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(_screenPrompts(controller));
      await tester.runAsync(() => controller.ask('Đặt vé máy bay'));
      await tester.pump();
      expect(find.byType(ActionChip), findsNWidgets(2));

      await tester.tap(find.text('Deadline nào đang gấp?'));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();

      expect(repository.calls.last.text, 'Deadline nào đang gấp?');
      expect(find.byType(ActionChip), findsNothing);
    },
  );

  testWidgets(
    'clarify → tapping an option re-sends the question with its id (AC3)',
    (tester) async {
      final repository = _FakeRepository(
        (text, selectedId) => selectedId == null
            ? const Turn(
                kind: TurnKind.clarify,
                reply: 'Bạn muốn hỏi dự án nào?',
                emotion: AvatarEmotion.thinking,
                options: _options,
              )
            : const Turn(
                kind: TurnKind.answer,
                reply: 'Đã xong 40%.',
                emotion: AvatarEmotion.happy,
              ),
      );
      final controller = AssistantController(
        repository: repository,
        speak: (_) async => true,
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(_screenPrompts(controller));
      await tester.runAsync(() => controller.ask('Dự án landing tới đâu rồi?'));
      await tester.pump();
      expect(find.text('Landing page — Client A'), findsOneWidget);
      expect(find.text('Landing page — Client B'), findsOneWidget);

      await tester.tap(find.text('Landing page — Client A'));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();

      expect(repository.calls.last, (
        text: 'Dự án landing tới đâu rồi?',
        selectedId: 'p-1',
      ));
      expect(find.byType(ActionChip), findsNothing);
    },
  );
}
