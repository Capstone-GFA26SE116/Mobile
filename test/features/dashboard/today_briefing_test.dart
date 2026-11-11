import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metanoia_mobile/features/dashboard/data/briefing_repository.dart';
import 'package:metanoia_mobile/features/dashboard/models/today_briefing.dart';
import 'package:metanoia_mobile/features/dashboard/widgets/today_briefing_card.dart';

// W6-02: the "AI Focus Today" card. Hand-written fakes, no extra package.

class _FakeAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) handler;
  final List<RequestOptions> requests = [];

  _FakeAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int status, Object body) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

final _now = DateTime.now();
final _today = DateTime(_now.year, _now.month, _now.day, 17);

Map<String, Object?> _body() => {
      'date': '2026-11-11',
      'time_zone': 'Asia/Ho_Chi_Minh',
      'calendar_connected': true,
      'has_pending_proposal': true,
      'schedule': [],
      'all_day': [],
      'top_tasks': [
        {
          'task_id': 'a',
          'title': 'Write the blog post',
          'project_name': 'Spa app',
          'deadline': _today.toUtc().toIso8601String(),
          'remaining_minutes': 90,
          'reasons': [
            {'code': 'deadline_soon', 'text': 'Due today at 5 pm.'},
            {'code': 'started', 'text': 'You already started it.'},
            {'code': 'bias', 'text': 'Writing usually takes you 30% longer.'},
          ],
          'similar_warning': {'text': 'Similar tasks took 1.4 times the plan.'},
        },
      ],
      'at_risk': [
        {
          'task_id': 'b',
          'title': 'Weekly report',
          'deadline': _today.toUtc().toIso8601String(),
          'missing_minutes': 45,
        },
      ],
      'productive_hint': {
        'ranges': [
          {'start': '08:00', 'end': '11:00'},
        ],
        'text': 'You usually focus best 8–11 am.',
      },
    };

class _FakeRepository extends BriefingRepository {
  Object answer; // a TodayBriefing or a BriefingException
  int calls = 0;

  _FakeRepository(this.answer) : super(Dio());

  @override
  Future<TodayBriefing> today({String language = 'en'}) async {
    calls++;
    if (answer is BriefingException) throw answer as BriefingException;
    return answer as TodayBriefing;
  }
}

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  test('T1: parses every part the card shows', () {
    final b = TodayBriefing.fromJson(_body());

    expect(b.hasPendingProposal, isTrue);
    expect(b.topTasks.single.title, 'Write the blog post');
    expect(b.topTasks.single.projectName, 'Spa app');
    expect(b.topTasks.single.remainingMinutes, 90);
    expect(b.topTasks.single.reasons, hasLength(3));
    expect(b.topTasks.single.similarWarning, 'Similar tasks took 1.4 times the plan.');
    expect(b.atRisk.single.missingMinutes, 45);
    expect(b.productiveHint, 'You usually focus best 8–11 am.');
  });

  test('T1: missing optional parts are empty, not invented', () {
    final b = TodayBriefing.fromJson({'top_tasks': [], 'at_risk': []});

    expect(b.topTasks, isEmpty);
    expect(b.atRisk, isEmpty);
    expect(b.hasPendingProposal, isFalse);
    expect(b.productiveHint, isNull);
  });

  test('T2: asks the AI service in English', () async {
    final adapter = _FakeAdapter((_) async => _json(200, _body()));
    final dio = Dio(BaseOptions(baseUrl: 'https://ai.test'))..httpClientAdapter = adapter;

    await BriefingRepository(dio).today();

    expect(adapter.requests.single.path, '/briefing/today');
    expect(adapter.requests.single.queryParameters, {'language': 'en'});
  });

  test('T2: a server error becomes a message, not fake data', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://ai.test'))
      ..httpClientAdapter = _FakeAdapter((_) async => _json(500, {}));

    expect(BriefingRepository(dio).today(), throwsA(isA<BriefingException>()));
  });

  test('dueText and minutesText', () {
    final now = DateTime(2026, 11, 11, 9);
    expect(dueText(DateTime(2026, 11, 11, 17, 5), now: now), '17:05 today');
    expect(dueText(DateTime(2026, 11, 12, 9), now: now), '09:00 tomorrow');
    expect(dueText(DateTime(2026, 11, 20, 9), now: now), '20/11 09:00');
    expect(minutesText(45), '45 min');
    expect(minutesText(120), '2h');
    expect(minutesText(90), '1h 30m');
  });

  testWidgets('T3: shows tasks, reasons (at most 2), risks, proposal and hint', (tester) async {
    await tester.pumpWidget(_app(TodayBriefingCard(
      repository: _FakeRepository(TodayBriefing.fromJson(_body())),
    )));
    await tester.pumpAndSettle();

    expect(find.text('AI Focus Today'), findsOneWidget);
    expect(find.text('Write the blog post'), findsOneWidget);
    expect(find.text('Due today at 5 pm.'), findsOneWidget);
    expect(find.text('You already started it.'), findsOneWidget);
    expect(find.text('Writing usually takes you 30% longer.'), findsNothing); // 3rd reason
    expect(find.text('Similar tasks took 1.4 times the plan.'), findsOneWidget);
    expect(find.text('Deadlines at risk'), findsOneWidget);
    expect(find.textContaining('Weekly report · due 17:00 today · 45 min short'), findsOneWidget);
    expect(find.textContaining('proposed schedule is waiting'), findsOneWidget);
    expect(find.text('You usually focus best 8–11 am.'), findsOneWidget);
  });

  testWidgets('T3: no tasks invites to add one', (tester) async {
    await tester.pumpWidget(_app(TodayBriefingCard(
      repository: _FakeRepository(TodayBriefing.fromJson({'top_tasks': [], 'at_risk': []})),
    )));
    await tester.pumpAndSettle();

    expect(find.textContaining('No open tasks yet'), findsOneWidget);
  });

  testWidgets('T3: an error is shown; a new refreshKey loads again', (tester) async {
    final repo = _FakeRepository(const BriefingException('AI briefing is unavailable. Pull down to retry.'));
    await tester.pumpWidget(_app(TodayBriefingCard(repository: repo)));
    await tester.pumpAndSettle();

    expect(find.text('AI briefing is unavailable. Pull down to retry.'), findsOneWidget);

    repo.answer = TodayBriefing.fromJson(_body());
    await tester.pumpWidget(_app(TodayBriefingCard(repository: repo, refreshKey: 1)));
    await tester.pumpAndSettle();

    expect(repo.calls, 2);
    expect(find.text('Write the blog post'), findsOneWidget);
  });
}
