// lib/stub_notifications.dart
// Web용 stub (아무 동작 안 함)

class FlutterLocalNotificationsPlugin {
  Future<void> initialize({required InitializationSettings settings}) async {}

  T? resolvePlatformSpecificImplementation<T>() => null;

  Future<void> show(
    int id,
    String? title,
    String? body,
    NotificationDetails details,
  ) async {}
}

class AndroidFlutterLocalNotificationsPlugin {
  Future<void> createNotificationChannel(AndroidNotificationChannel channel) async {}
}

class InitializationSettings {
  final AndroidInitializationSettings? android;
  final DarwinInitializationSettings? iOS;

  const InitializationSettings({this.android, this.iOS});
}

class AndroidInitializationSettings {
  final String defaultIcon;
  const AndroidInitializationSettings(this.defaultIcon);
}

class DarwinInitializationSettings {
  const DarwinInitializationSettings();
}

class AndroidNotificationChannel {
  final String id;
  final String name;
  final String? description;
  final dynamic importance;

  const AndroidNotificationChannel(
    this.id,
    this.name, {
    this.description,
    this.importance,
  });
}

class NotificationDetails {
  final AndroidNotificationDetails? android;
  const NotificationDetails({this.android});
}

class AndroidNotificationDetails {
  final String channelId;
  final String channelName;
  final String? channelDescription;
  final String? icon;

  const AndroidNotificationDetails(
    this.channelId,
    this.channelName, {
    this.channelDescription,
    this.icon,
  });
}

class Importance {
  static const max = null;
}
