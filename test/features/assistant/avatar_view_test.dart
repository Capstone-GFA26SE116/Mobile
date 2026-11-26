import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metanoia_mobile/features/assistant/widgets/avatar_view.dart';

/// The assistant orb (plans/assistant-orb.md, T1–T5).
void main() {
  group('AvatarController', () {
    test('notifies only on a real change', () async {
      final c = AvatarController();
      var calls = 0;
      c.addListener(() => calls++);

      await c.setSpeaking(true);
      await c.setSpeaking(true);
      await c.setEmotion(AvatarEmotion.neutral); // already neutral
      await c.setListening(true);
      await c.setThinking(true);

      expect(calls, 3);
      expect(c.isReady, isTrue);
    });

    test('happy bumps the cheer count once per change', () async {
      final c = AvatarController();
      await c.setEmotion(AvatarEmotion.happy);
      await c.setEmotion(AvatarEmotion.happy);
      await c.setEmotion(AvatarEmotion.sad);
      await c.setEmotion(AvatarEmotion.happy);
      expect(c.cheers, 2);
    });
  });

  test('mode priority: listening > thinking > speaking > idle', () async {
    final c = AvatarController();
    expect(orbMode(c), OrbMode.idle);
    await c.setSpeaking(true);
    expect(orbMode(c), OrbMode.speaking);
    await c.setThinking(true);
    expect(orbMode(c), OrbMode.thinking);
    await c.setListening(true);
    expect(orbMode(c), OrbMode.listening);
  });

  group('orbScale', () {
    test('stays in a calm range for every mode and emotion', () {
      for (final mode in OrbMode.values) {
        for (final emotion in AvatarEmotion.values) {
          for (var t = 0.0; t < 5; t += 0.05) {
            final s = orbScale(mode, emotion, t);
            expect(
              s,
              inInclusiveRange(0.88, 1.08),
              reason: '$mode $emotion $t',
            );
          }
        }
      }
    });

    test(
      'speaking moves more than idle; sad is smaller; still when motion is off',
      () {
        double spread(OrbMode m) {
          final values = [
            for (var t = 0.0; t < 4; t += 0.02)
              orbScale(m, AvatarEmotion.neutral, t),
          ];
          return values.reduce((a, b) => a > b ? a : b) -
              values.reduce((a, b) => a < b ? a : b);
        }

        expect(spread(OrbMode.speaking), greaterThan(spread(OrbMode.idle)));
        expect(
          orbScale(OrbMode.speaking, AvatarEmotion.sad, 1.3, moving: false),
          0.92,
        );
        expect(
          orbScale(OrbMode.speaking, AvatarEmotion.happy, 1.3, moving: false),
          1.0,
        );
      },
    );
  });

  test('each emotion has its own colours; neutral is the brand green', () {
    final colours = AvatarEmotion.values.map(orbColors).toSet();
    expect(colours, hasLength(AvatarEmotion.values.length));
    expect(orbColors(AvatarEmotion.neutral).$1, const Color(0xFF00D992));
  });

  testWidgets('ready after the first frame and follows the controller', (
    tester,
  ) async {
    final c = AvatarController();
    var ready = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AvatarView(controller: c, onReady: () => ready++),
        ),
      ),
    );
    await tester.pump();
    expect(ready, 1);
    expect(find.bySemanticsLabel('Trợ lý'), findsOneWidget);

    await c.setListening(true);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.bySemanticsLabel('Trợ lý đang nghe'), findsOneWidget);

    await c.setListening(false);
    await c.setEmotion(AvatarEmotion.happy); // bounce
    await c.setSpeaking(true);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.bySemanticsLabel('Trợ lý đang nói'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('reduced motion draws a still orb', (tester) async {
    final c = AvatarController();
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(body: AvatarView(controller: c)),
        ),
      ),
    );
    final painter =
        tester
                .widget<CustomPaint>(
                  find.descendant(
                    of: find.byType(AvatarView),
                    matching: find.byType(CustomPaint),
                  ),
                )
                .painter!
            as OrbPainter;
    expect(painter.time, isNull);
  });
}
