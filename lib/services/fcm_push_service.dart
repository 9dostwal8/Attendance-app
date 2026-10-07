import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Direct Push Notification Service for Spark Plan.
/// Delivers push notifications directly to FCM even when receiver app is closed/killed.
class FcmPushService {
  static const String _legacyFcmUrl = 'https://fcm.googleapis.com/fcm/send';

  /// Legacy Server Key or FCM token relay.
  /// If using legacy HTTP protocol, it delivers to the device token with high priority.
  static Future<bool> sendNotification({
    required String targetFcmToken,
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? serverKey,
  }) async {
    if (targetFcmToken.trim().isEmpty) {
      debugPrint('[FcmPushService] Target FCM token is empty. Notification skipped.');
      return false;
    }

    try {
      final payload = {
        'to': targetFcmToken,
        'priority': 'high',
        'notification': {
          'title': title,
          'body': body,
          'sound': 'default',
          'channel_id': 'chat_channel_id',
          'android_channel_id': 'chat_channel_id',
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        },
        'data': {
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
          'status': 'done',
          'title': title,
          'body': body,
          ...?data,
        },
      };

      // If a custom server key is stored in Firebase settings or passed:
      final authHeader = (serverKey != null && serverKey.isNotEmpty)
          ? 'key=$serverKey'
          : null;

      if (authHeader == null) {
        debugPrint('[FcmPushService] Server key not configured for direct FCM. Skipping legacy HTTP call.');
        return false;
      }

      final response = await http.post(
        Uri.parse(_legacyFcmUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': authHeader,
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 10));

      debugPrint('[FcmPushService] Response: ${response.statusCode} - ${response.body}');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[FcmPushService] Error sending FCM push notification: $e');
      return false;
    }
  }
}
