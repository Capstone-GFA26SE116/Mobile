import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metanoia_mobile/features/assistant/logic/assistant_controller.dart';
import 'package:metanoia_mobile/features/assistant/widgets/assistant_text_input.dart';

// plans/assistant-text-input.md T1–T4.
Widget _app({required bool enabled, required List<String> sent}) => MaterialApp(
  home: Scaffold(
    body: AssistantTextInput(enabled: enabled, onSend: sent.add),
  ),
);

Finder get _send => find.byTooltip('Send');

IconButton _sendButton(WidgetTester tester) => tester.widget<IconButton>(
  find.widgetWithIcon(IconButton, Icons.send_rounded),
);

void main() {
  testWidgets('T1 send button sends the trimmed text and clears the box', (
    tester,
  ) async {
    final sent = <String>[];
    await tester.pumpWidget(_app(enabled: true, sent: sent));

    await tester.enterText(find.byType(TextField), '  Hôm nay làm gì?  ');
    await tester.pump();
    await tester.tap(_send);
    await tester.pump();

    expect(sent, ['Hôm nay làm gì?']);
    expect(find.text('Hôm nay làm gì?'), findsNothing);
  });

  testWidgets('T2 the keyboard send key sends too', (tester) async {
    final sent = <String>[];
    await tester.pumpWidget(_app(enabled: true, sent: sent));

    await tester.enterText(find.byType(TextField), 'Còn bao nhiêu task?');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();

    expect(sent, ['Còn bao nhiêu task?']);
  });

  testWidgets('T3 blank text cannot be sent', (tester) async {
    final sent = <String>[];
    await tester.pumpWidget(_app(enabled: true, sent: sent));

    expect(_sendButton(tester).onPressed, isNull);
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect(_sendButton(tester).onPressed, isNull);
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    expect(sent, isEmpty);
  });

  testWidgets('T4 disabled while the avatar loads or the mic is held', (
    tester,
  ) async {
    final sent = <String>[];
    await tester.pumpWidget(_app(enabled: false, sent: sent));

    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    expect(_sendButton(tester).onPressed, isNull);
  });

  testWidgets('the box stops at the request limit', (tester) async {
    await tester.pumpWidget(_app(enabled: true, sent: []));
    expect(
      tester.widget<TextField>(find.byType(TextField)).maxLength,
      AssistantController.textMaxChars,
    );
  });
}
