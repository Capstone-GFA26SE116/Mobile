class NotificationItem {
  final String id;
  final String type;
  final String title;
  final String message;
  final String? scheduleSlotId;
  final DateTime sentAt;
  final bool isRead;
  final DateTime? readAt;

  const NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    this.scheduleSlotId,
    required this.sentAt,
    this.isRead = false,
    this.readAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'SlotReminder',
      title: json['title']?.toString() ?? 'Reminder',
      message: json['message']?.toString() ?? '',
      scheduleSlotId: json['scheduleSlotId']?.toString(),
      sentAt: DateTime.tryParse(json['sentAt']?.toString() ?? '') ??
          DateTime.now(),
      isRead: json['isRead'] == true,
      readAt: json['readAt'] != null
          ? DateTime.tryParse(json['readAt'].toString())
          : null,
    );
  }

  NotificationItem copyWith({
    bool? isRead,
    DateTime? readAt,
  }) {
    return NotificationItem(
      id: id,
      type: type,
      title: title,
      message: message,
      scheduleSlotId: scheduleSlotId,
      sentAt: sentAt,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
    );
  }
}

