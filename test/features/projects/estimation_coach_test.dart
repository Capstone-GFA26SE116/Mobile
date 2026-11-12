import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metanoia_mobile/features/projects/data/estimation_coach_repository.dart';
import 'package:metanoia_mobile/features/projects/logic/estimation_coach.dart';
import 'package:metanoia_mobile/features/projects/widgets/estimation_coach_hint.dart';

// 3D idea 2: the estimation coach under the estimate field.

class _FakeAdapter implements HttpClientAdapter {
  final ResponseBody Function() answer;
  final List<RequestOptions> requests = [];

  _FakeAdapter(this.answer);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return answer();
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

DomainBias _bias({
  String confidence = 'confident',
  double? factor = 1.3,
  String? direction = 'slower',
  int? percent = 30,
  int samples = 12,
}) => DomainBias(
  domainId: 'd1',
  name: 'Writing',
  samples: samples,
  confidence: confidence,
  factor: factor,
  direction: direction,
  percent: percent,
);

void main() {
  group('hint', () {
    test('slower', () {
      expect(
        EstimationCoach.hint(_bias(), 60),
        'In Writing you usually take about 30% longer than you estimate. '
        '60 min may really take about 80 min.',
      );
    });

    test('faster', () {
      expect(
        EstimationCoach.hint(
          _bias(factor: 0.8, direction: 'faster', percent: 20),
          50,
        ),
        'In Writing you usually finish about 20% sooner than you estimate. '
        '50 min may really take about 40 min.',
      );
    });

    test('still learning says so', () {
      expect(
        EstimationCoach.hint(_bias(confidence: 'learning', samples: 4), 60),
        contains('(early sign, 4 tasks)'),
      );
    });

    test('quiet when there is nothing worth saying', () {
      expect(EstimationCoach.hint(null, 60), isNull);
      expect(EstimationCoach.hint(_bias(), null), isNull);
      expect(EstimationCoach.hint(_bias(), 0), isNull);
      expect(EstimationCoach.hint(_bias(confidence: 'none'), 60), isNull);
      expect(
        EstimationCoach.hint(_bias(direction: 'accurate', percent: null), 60),
        isNull,
      );
      expect(EstimationCoach.hint(_bias(factor: 1.05, percent: 5), 60), isNull);
    });

    test('roundTo5', () {
      expect(EstimationCoach.roundTo5(78), 80);
      expect(EstimationCoach.roundTo5(1.2), 5);
    });
  });

  group('repository', () {
    test('reads the domains of all time, no AI call', () async {
      final adapter = _FakeAdapter(
        () => _json(200, {
          'domains': [
            {
              'domain_id': 'd1',
              'domain_name': 'Writing',
              'samples': 12,
              'confidence': 'confident',
              'factor': 1.3,
              'direction': 'slower',
              'percent': 30,
              'text': 'x',
              'trend': [],
            },
          ],
        }),
      );
      final dio = Dio(BaseOptions(baseUrl: 'https://ai.test'))
        ..httpClientAdapter = adapter;

      final habits = await EstimationCoachRepository(dio).habits();

      expect(adapter.requests.single.path, '/analytics/overview');
      expect(adapter.requests.single.queryParameters, {
        'range': 'all',
        'language': 'en',
      });
      expect(habits['d1']!.factor, 1.3);
    });

    test('an error leaves the coach quiet', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://ai.test'))
        ..httpClientAdapter = _FakeAdapter(() => _json(500, {}));

      expect(await EstimationCoachRepository(dio).habits(), isEmpty);
    });
  });

  testWidgets('the hint shows only with text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: EstimationCoachHint(text: null))),
    );
    expect(find.byIcon(Icons.psychology_alt), findsNothing);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: EstimationCoachHint(text: 'Hi')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Hi'), findsOneWidget);
  });
}
