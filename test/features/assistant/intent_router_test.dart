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

    test('matches whole words only', () {
      // "lam gia" (làm giả) must not match "lam gi".
      expect(IntentRouter.route('Đừng làm giả'), AssistantIntent.unknown);
    });
  });

  test('normalize strips diacritics and đ', () {
    expect(IntentRouter.normalize('  Đường   ĐI  Ưu Tiên '), 'duong di uu tien');
  });
}
