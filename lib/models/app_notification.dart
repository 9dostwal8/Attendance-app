enum NotificationType { chat, request, system }

class AppNotification {
  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  final NotificationType type;
  final String? relatedId; // contactId for chat, requestId for request
  bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.type = NotificationType.chat,
    this.relatedId,
    this.isRead = false,
  });
}
