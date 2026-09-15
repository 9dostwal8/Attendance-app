// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

Future<void> requestWebNotificationPermission() async {
  try {
    if (html.Notification.permission != 'granted') {
      await html.Notification.requestPermission();
    }
  } catch (_) {}
}

void showBrowserNotification(String title, String body) {
  try {
    if (html.Notification.permission == 'granted') {
      html.Notification(
        title,
        body: body,
        icon: 'favicon.png',
      );
    }
  } catch (_) {}
}
