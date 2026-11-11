import 'package:flutter_test/flutter_test.dart';
import 'package:metanoia_mobile/features/notifications/models/notification_models.dart';

void main() {
  group('Notification Models Tests', () {
    test('NotificationItem deserializes correctly', () {
      final json = {
        'id': 'notif-101',
        'type': 'SlotReminder',
        'title': 'Đến giờ làm việc',
        'message': 'Đến giờ rồi! Bấm Start để bắt đầu "Thiết kế UI".',
        'scheduleSlotId': 'slot-555',
        'sentAt': '2026-11-11T14:00:00Z',
        'isRead': false,
        'readAt': null,
      };

      final item = NotificationItem.fromJson(json);
      expect(item.id, 'notif-101');
      expect(item.type, 'SlotReminder');
      expect(item.title, 'Đến giờ làm việc');
      expect(item.scheduleSlotId, 'slot-555');
      expect(item.isRead, false);
      expect(item.readAt, isNull);
    });

    test('NotificationItem copyWith works', () {
      final item = NotificationItem(
        id: 'notif-102',
        type: 'MissedSlot',
        title: 'Bỏ lỡ phiên',
        message: 'Bạn đã bỏ lỡ lịch làm việc.',
        sentAt: DateTime.now(),
        isRead: false,
      );

      final now = DateTime.now();
      final updated = item.copyWith(isRead: true, readAt: now);
      expect(updated.id, 'notif-102');
      expect(updated.isRead, true);
      expect(updated.readAt, now);
    });
  });
}

