import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metanoia_mobile/features/assistant/widgets/avatar_view.dart';
import 'package:metanoia_mobile/features/focus/logic/focus_companion.dart';
import 'package:metanoia_mobile/features/focus/widgets/focus_companion_view.dart';

// 3D idea 1: the focus companion. Pure rules + the bubble; the WebView is replaced.

List<String> _ids(int minutes, int planned) => [
  for (final c in FocusCompanion.cuesAt(
    elapsedSeconds: minutes * 60,
    plannedMinutes: planned,
  ))
    c.id,
];

class _Session extends ChangeNotifier {
  int elapsed = 0;

  void tick(int seconds) {
    elapsed = seconds;
    notifyListeners();
  }
}

void main() {
  group('cuesAt', () {
    test('a 60-minute session, in order', () {
      expect(_ids(0, 60), ['start']);
      expect(_ids(30, 60), ['start', 'half']);
      expect(_ids(50, 60), ['start', 'half', 'break_50']);
      expect(_ids(55, 60), ['start', 'half', 'break_50', 'five_left']);
      expect(_ids(60, 60), [
        'start',
        'half',
        'break_50',
        'five_left',
        'planned',
      ]);
      expect(_ids(75, 60).last, 'over_15');
      expect(_ids(120, 60).last, 'over_60');
    });

    test('short sessions skip half and 5-left', () {
      expect(_ids(10, 10), ['start', 'planned']);
      expect(_ids(10, 15), ['start', 'five_left']);
    });

    test('long sessions remind a break every 50 minutes, not at the end', () {
      expect(
        _ids(120, 120),
        containsAllInOrder(['break_50', 'break_100', 'planned']),
      );
      expect(_ids(100, 100), isNot(contains('break_100')));
    });

    test('unknown plan (0) counts as 30 minutes', () {
      expect(_ids(30, 0).last, 'planned');
    });

    test('every line is short and has no internal names', () {
      final all = FocusCompanion.cuesAt(
        elapsedSeconds: 1000 * 60,
        plannedMinutes: 200,
      );
      for (final c in all) {
        expect(c.text.split(' ').length, lessThanOrEqualTo(20), reason: c.id);
        expect(c.text, isNot(contains('K_bias')));
      }
    });
  });

  group('next', () {
    test('says each cue once', () {
      final c = FocusCompanion();
      expect(c.next(elapsedSeconds: 0, plannedMinutes: 60)?.id, 'start');
      expect(c.next(elapsedSeconds: 60, plannedMinutes: 60), isNull);
      expect(c.next(elapsedSeconds: 30 * 60, plannedMinutes: 60)?.id, 'half');
      expect(c.next(elapsedSeconds: 31 * 60, plannedMinutes: 60), isNull);
    });

    test('opening the screen late says only the latest cue', () {
      final c = FocusCompanion();
      expect(
        c.next(elapsedSeconds: 56 * 60, plannedMinutes: 60)?.id,
        'five_left',
      );
      expect(c.next(elapsedSeconds: 57 * 60, plannedMinutes: 60), isNull);
      expect(
        c.next(elapsedSeconds: 60 * 60, plannedMinutes: 60)?.id,
        'planned',
      );
    });
  });

  testWidgets('the bubble follows the session', (tester) async {
    final session = _Session();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FocusCompanionView(
            session: session,
            elapsedSeconds: () => session.elapsed,
            plannedMinutes: () => 40,
            avatarBuilder: (_) => const SizedBox(),
          ),
        ),
      ),
    );
    expect(find.text("Let's go! I'm right here with you."), findsOneWidget);

    session.tick(20 * 60);
    await tester.pumpAndSettle();
    expect(find.text('Halfway there. Keep the pace.'), findsOneWidget);

    session.tick(41 * 60);
    await tester.pumpAndSettle();
    expect(find.textContaining('Planned time is up'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4)); // the "speaking" timer ends
  });

  test('the companion avatar does not share the assistant port', () {
    expect(FocusCompanionView.avatarPort, isNot(AvatarView.defaultPort));
  });
}
