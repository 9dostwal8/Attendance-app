import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String senderId;
  final String receiverId;
  final String text;
  final DateTime timestamp;
  final bool isRequestCard;
  final String? requestId;
  final bool isRead;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.text,
    required this.timestamp,
    this.isRequestCard = false,
    this.requestId,
    this.isRead = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'isRequestCard': isRequestCard,
      'requestId': requestId,
      'isRead': isRead,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parsedTime = DateTime.now();
    if (map['timestamp'] != null) {
      try {
        if (map['timestamp'] is Timestamp) {
          parsedTime = (map['timestamp'] as Timestamp).toDate();
        } else if (map['timestamp'] is String) {
          parsedTime = DateTime.parse(map['timestamp'] as String).toLocal();
        } else if (map['timestamp'] is int) {
          parsedTime =
              DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int)
                  .toLocal();
        }
      } catch (_) {}
    }

    return ChatMessage(
      id: map['id']?.toString() ?? docId,
      senderId: map['senderId']?.toString() ?? '',
      receiverId: map['receiverId']?.toString() ?? '',
      text: map['text']?.toString() ?? '',
      timestamp: parsedTime,
      isRequestCard: map['isRequestCard'] == true,
      requestId: map['requestId']?.toString(),
      isRead: map['isRead'] == true,
    );
  }

  ChatMessage copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    String? text,
    DateTime? timestamp,
    bool? isRequestCard,
    String? requestId,
    bool? isRead,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      isRequestCard: isRequestCard ?? this.isRequestCard,
      requestId: requestId ?? this.requestId,
      isRead: isRead ?? this.isRead,
    );
  }
}
