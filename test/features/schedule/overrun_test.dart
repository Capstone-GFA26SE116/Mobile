import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metanoia_mobile/features/schedule/data/overrun_repository.dart';
import 'package:metanoia_mobile/features/schedule/models/overrun_models.dart';
import 'package:metanoia_mobile/features/schedule/screens/overrun_sheet.dart';

// FR-16b on the phone: proposal parsing, the AI call, applying through the Backend,
// and the sheet. Hand-written fake adapter, no extra package.

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

Dio _dio(_FakeAdapter adapter) =>
    Dio(BaseOptions(baseUrl: 'https://x.test'))..httpClientAdapter = adapter;

const _replan = {
  'kind': 'replan',
  'extended': {
    'slot_id': 'late',
    'start': '2026-11-11T09:00:00+07:00',
    'end': '2026-11-11T11:05:00+07:00',
  },
  'moves': [
    {
      'slot_id': 'design',
      'task_title': 'Thiết kế',
      'old_start': '2026-11-11T10:15:00+07:00',
      'old_end': '2026-11-11T11:15:00+07:00',
      'new_start': '2026-11-11T13:00:00+07:00',
      'new_end': '2026-11-11T14:00:00+07:00',
    },
  ],
  'not_placed': [
    {'slot_id': 'send', 'task_title': 'Gửi khách'},
  ],
  'past_day_end': false,
  'summary': 'To keep working on Viết blog until 11:05 am, move 1 task: Thiết kế to 1 pm.',
};

void main() {
  test('proposal parses, and changes start with the late slot', () {
    final plan = OverrunPlan.fromJson(_replan);

    expect(plan.kind, OverrunKind.replan);
    expect(plan.extended.end, DateTime.parse('2026-11-11T04:05:00Z').toLocal());
    expect(plan.moves.single.taskTitle, 'Thiết kế');
    expect(plan.notPlacedTitles, ['Gửi khách']);
    expect(plan.changes.map((c) => c.slotId), ['late', 'design']);
  });

  test('propose posts the slot, minutes and language to the AI service', () async {
    final ai = _FakeAdapter((_) async => _json(200, _replan));
    final repo = OverrunRepository(_dio(_FakeAdapter((_) async => _json(500, {}))), _dio(ai));

    final plan = await repo.propose(slotId: 'late', extraMinutes: 60);

    expect(plan.kind, OverrunKind.replan);
    expect(ai.requests.single.method, 'POST');
    expect(ai.requests.single.path, '/schedule/overrun');
    expect(ai.requests.single.data, {'slot_id': 'late', 'extra_minutes': 60, 'language': 'en'});
  });

  test('a slot that cannot run over says so', () async {
    final ai = _FakeAdapter((_) async => _json(409, {'detail': 'x'}));
    final repo = OverrunRepository(_dio(_FakeAdapter((_) async => _json(500, {}))), _dio(ai));

    expect(
      () => repo.propose(slotId: 'late', extraMinutes: 30),
      throwsA(isA<OverrunException>().having(
        (e) => e.message,
        'message',
        'This slot is finished or cannot be extended.',
      )),
    );
  });

  test('apply reads each slot and sends it back with only the times changed', () async {
    final backend = _FakeAdapter((o) async {
      if (o.method == 'GET') {
        return _json(200, {
          'id': 'x',
          'subTaskId': 'sub-1',
          'scheduleProposalId': 'prop-1',
          'startTime': '2026-11-11T02:00:00Z',
          'endTime': '2026-11-11T03:00:00Z',
          'originalStartTime': null,
          'isManualOverride': false,
          'kbiasUsed': 1.25,
          'explanation': 'Best focus hour',
          'status': 'Approved',
        });
      }
      return _json(200, {});
    });
    final repo = OverrunRepository(_dio(backend), _dio(_FakeAdapter((_) async => _json(500, {}))));

    final failed = await repo.apply(OverrunPlan.fromJson(_replan));

    expect(failed, 0);
    expect(
      backend.requests.map((r) => '${r.method} ${r.path}'),
      [
        'GET /api/schedule-slots/late',
        'PUT /api/schedule-slots/late',
        'GET /api/schedule-slots/design',
        'PUT /api/schedule-slots/design',
      ],
    );
    final put = backend.requests[3].data as Map<String, dynamic>;
    expect(put['startTime'], '2026-11-11T06:00:00.000Z'); // 13:00 +07:00
    expect(put['endTime'], '2026-11-11T07:00:00.000Z');
    expect(put['subTaskId'], 'sub-1');
    expect(put['scheduleProposalId'], 'prop-1');
    expect(put['kbiasUsed'], 1.25);
    expect(put['explanation'], 'Best focus hour');
    expect(put['status'], 'Approved');
  });

  test('apply counts the slots it could not update', () async {
    final backend = _FakeAdapter((o) async =>
        o.path.endsWith('/design') ? _json(404, {}) : _json(200, {'status': 'Overrun'}));
    final repo = OverrunRepository(_dio(backend), _dio(_FakeAdapter((_) async => _json(500, {}))));

    expect(await repo.apply(OverrunPlan.fromJson(_replan)), 1);
  });

  testWidgets('sheet: pick minutes, see the proposal, apply it', (tester) async {
    final repo = _FakeRepository();
    bool? result;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showModalBottomSheet<bool>(
                context: context,
                isScrollControlled: true, // as on the schedule screen
                builder: (_) => OverrunSheet(
                  slotId: 'late',
                  slotTitle: 'Viết blog',
                  repository: repo,
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final apply = find.widgetWithText(ElevatedButton, 'Apply changes');
    expect(tester.widget<ElevatedButton>(apply).onPressed, isNull); // nothing proposed yet

    await tester.tap(find.text('+60 min'));
    await tester.pumpAndSettle();

    expect(repo.asked, 60);
    expect(find.textContaining('To keep working on Viết blog'), findsOneWidget);
    expect(find.textContaining('Thiết kế:'), findsOneWidget);
    expect(find.textContaining('Gửi khách: not moved'), findsOneWidget);

    await tester.ensureVisible(apply);
    await tester.tap(apply);
    await tester.pumpAndSettle();

    expect(repo.applied, isTrue);
    expect(result, isTrue);
  });
}

class _FakeRepository extends OverrunRepository {
  int? asked;
  bool applied = false;

  _FakeRepository() : super(Dio(), Dio());

  @override
  Future<OverrunPlan> propose({
    required String slotId,
    required int extraMinutes,
    String language = 'en',
  }) async {
    asked = extraMinutes;
    return OverrunPlan.fromJson(_replan);
  }

  @override
  Future<int> apply(OverrunPlan plan) async {
    applied = true;
    return 0;
  }
}
