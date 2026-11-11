import 'package:flutter_test/flutter_test.dart';
import 'package:metanoia_mobile/features/assistant/logic/intent_router.dart';

// T1 (AC3, AC4)
void main() {
  group('IntentRouter.route', () {
    test('matches Vietnamese with diacritics', () {
      expect(IntentRouter.route('Hôm nay tôi nên làm gì?'), AssistantIntent.briefing);
      expect(IntentRouter.route('Việc gì quan trọng nhất'), AssistantIntent.briefing);
      expect(IntentRouter.route('Cái nào ưu tiên'), AssistantIntent.briefing);
    });

    test('matches text typed without diacritics', () {
      expect(IntentRouter.route('hom nay toi nen lam gi'), AssistantIntent.briefing);
    });

    test('matches decomposed (NFD) Vietnamese', () {
      // "hôm nay" written as base letters + combining marks.
      expect(IntentRouter.route('Hôm nay'), AssistantIntent.briefing);
    });

    test('matches English', () {
      expect(IntentRouter.route('What should I do TODAY?'), AssistantIntent.briefing);
    });

    test('ignores unrelated sentences', () {
      expect(IntentRouter.route('Thời tiết thế nào?'), AssistantIntent.unknown);
      expect(IntentRouter.route('Mở nhạc đi'), AssistantIntent.unknown);
      expect(IntentRouter.route(''), AssistantIntent.unknown);
    });

    test('leaves questions for other assistant tools alone', () {
      // Found in the T4 run: these matched "viec gi" / "hom nay" and read the briefing.
      expect(IntentRouter.route('Tôi đang bấm giờ việc gì vậy?'), AssistantIntent.unknown);
      expect(IntentRouter.route('Tôi hay trễ việc gì?'), AssistantIntent.unknown);
      expect(IntentRouter.route('Chiều nay có việc gì?'), AssistantIntent.unknown);
      expect(IntentRouter.route('Hôm nay tôi còn bao nhiêu lượt AI?'), AssistantIntent.unknown);
      expect(IntentRouter.route('Dự án nào cần làm gì?'), AssistantIntent.unknown);
      expect(IntentRouter.route('What should I do tomorrow?'), AssistantIntent.unknown);
    });

    test('still matches the briefing question with "trên"/"trước" words nearby', () {
      // Whole-word check: "tre" must not hit "tren" or "truoc".
      expect(IntentRouter.route('Hôm nay trên lịch tôi nên làm gì?'), AssistantIntent.briefing);
      expect(IntentRouter.route('Việc gì làm trước hôm nay?'), AssistantIntent.briefing);
    });

    test('matches whole words only', () {
      // "lam gia" (làm giả) must not match "lam gi".
      expect(IntentRouter.route('Đừng làm giả'), AssistantIntent.unknown);
    });
  });

  test('normalize strips diacritics and đ', () {
    expect(IntentRouter.normalize('  Đường   ĐI  Ưu Tiên '), 'duong di uu tien');
  });
}
