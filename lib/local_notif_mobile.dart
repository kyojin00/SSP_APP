import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

final _plugin = FlutterLocalNotificationsPlugin();
late AndroidNotificationChannel _channel;

class LocalNotifService {
  static Future<void> init() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      _channel = const AndroidNotificationChannel(
        'high_importance_channel',
        '긴급 공지사항',
        description: '중요한 공지 알림',
        importance: Importance.max,
      );
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _plugin.initialize(
        const InitializationSettings(
          iOS: DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
          ),
        ),
      );
    }
  }

  // ✅ RemoteMessage에서 title/body 추출 (notification 또는 data 둘 다 처리)
  static Future<void> showFromMessage(RemoteMessage message) async {
    // data-only 메시지: notification이 null이므로 data에서 꺼냄
    final title = message.notification?.title ?? message.data['title'] ?? '새 공지사항';
    final body  = message.notification?.body  ?? message.data['body']  ?? '';
    await show(message.hashCode, title, body);
  }

  static Future<void> show(int id, String? title, String? body) async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _plugin.show(
        id, title, body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id, _channel.name,
            channelDescription: _channel.description,
            icon: '@mipmap/ic_launcher',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _plugin.show(
        id, title, body,
        const NotificationDetails(
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
    }
  }
}