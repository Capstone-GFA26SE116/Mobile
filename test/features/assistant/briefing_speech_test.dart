import 'package:flutter_test/flutter_test.dart';
import 'package:metanoia_mobile/features/assistant/logic/briefing_speech.dart';
import 'package:metanoia_mobile/features/assistant/models/briefing.dart';

// T2 (AC3)
Map<String, dynamic> _task(String title, {String? reason}) => {
      'task_id': 'id-$title',
      'title': title,
      'project_name': 'Dự án',
      'reasons': [
        if (reason != null) {'code': 'at_risk', 'text': reason},
      ],
    };

Briefing _briefing({
  int schedule = 0,
  List<Map<String, dynamic>> tasks = const [],
  List<String> atRisk = const [],
  bool calendarConnected = true,
}) {
  return Briefing.fromJson({
    'calendar_connected': calendarConnected,
    'schedule': [
      for (var i = 0; i < schedule; i++) {'kind': 'slot', 'title': 'Slot $i', 'task_id': 'x'},
    ],
    'all_day': [
      {'title': 'Nghỉ lễ'},
    ],
    'top_tasks': tasks,
    'at_risk': [
      for (final title in atRisk) {'task_id': 'r', 'title': title, 'missing_minutes': 60},
    ],
    'has_pending_proposal': true,
  });
}

void main() {
  test('no tasks → empty-day sentence', () {
    expect(BriefingSpeech.build(_briefing()), BriefingSpeech.emptyDay);
  });

  test('one task with reason, all_day not counted', () {
    final text = BriefingSpeech.build(_briefing(
      schedule: 2,
      tasks: [_task('Viết landing page', reason: 'Hạn hôm nay.')],
    ));
    expect(
      text,
      'Hôm nay bạn có 2 việc trên lịch. Nên làm trước: Viết landing page, vì hạn hôm nay.',
    );
  });

  test('3+ tasks: only the first three are read', () {
    final text = BriefingSpeech.build(_briefing(
      schedule: 3,
      tasks: [
        _task('A', reason: 'Đã quá hạn 1 ngày.'),
        _task('B'),
        _task('C'),
        _task('D'),
      ],
    ));
    expect(
      text,
      'Hôm nay bạn có 3 việc trên lịch. Nên làm trước: A, vì đã quá hạn 1 ngày. Sau đó là B và C.',
    );
  });

  test('one at-risk task', () {
    final text = BriefingSpeech.build(_briefing(schedule: 1, tasks: [_task('A')], atRisk: ['A']));
    expect(text, endsWith('Cẩn thận: A có nguy cơ trễ hạn.'));
  });

  test('several at-risk tasks: names the first two', () {
    final text = BriefingSpeech.build(
      _briefing(schedule: 1, tasks: [_task('A')], atRisk: ['A', 'B', 'C']),
    );
    expect(text, endsWith('Cẩn thận: A và B có nguy cơ trễ hạn.'));
    expect(text, isNot(contains('C có')));
  });

  test('calendar not connected adds a reminder', () {
    expect(
      BriefingSpeech.build(_briefing(calendarConnected: false)),
      '${BriefingSpeech.emptyDay} ${BriefingSpeech.calendarNotConnected}',
    );
  });

  test('long reasons are dropped to stay within 60 words', () {
    final longReason = List.filled(40, 'chữ').join(' ');
    final text = BriefingSpeech.build(_briefing(
      schedule: 4,
      tasks: [
        _task('Viết báo cáo tuần', reason: longReason),
        _task('Sửa lỗi đăng nhập'),
        _task('Gọi khách hàng'),
      ],
      atRisk: ['Viết báo cáo tuần', 'Gọi khách hàng'],
      calendarConnected: false,
    ));
    expect(BriefingSpeech.wordCount(text), lessThanOrEqualTo(BriefingSpeech.maxWords));
    expect(text, isNot(contains(longReason)));
    expect(text, contains('Nên làm trước: Viết báo cáo tuần.'));
  });

  test('never reads internal names or codes', () {
    final text = BriefingSpeech.build(_briefing(
      schedule: 2,
      tasks: [_task('A', reason: 'Hạn trong 2 ngày.'), _task('B')],
      atRisk: ['B'],
      calendarConnected: false,
    ));
    for (final internal in ['at_risk', 'task_id', 'missing_minutes', 'id-', 'Nghỉ lễ', 'Dự án', '60']) {
      expect(text, isNot(contains(internal)), reason: internal);
    }
    expect(BriefingSpeech.wordCount(text), lessThanOrEqualTo(BriefingSpeech.maxWords));
  });
}
