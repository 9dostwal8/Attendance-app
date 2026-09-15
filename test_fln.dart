import 'package:flutter_local_notifications/flutter_local_notifications.dart';

void main() async {
  final fln = FlutterLocalNotificationsPlugin();
  
  await fln.initialize(
    settings: const InitializationSettings(),
  );

  await fln.show(
    id: 1,
    title: 'test',
    body: 'test',
    notificationDetails: const NotificationDetails(),
  );
}
