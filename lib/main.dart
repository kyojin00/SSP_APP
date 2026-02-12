import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // 웹 호환성을 위해 그대로 유지하되 로직으로 제어

import 'dart:io' show Platform;

import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'firebase_options.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  debugPrint('BG message: ${message.messageId}');
}

// Android 알림 채널 및 플러그인 설정
late AndroidNotificationChannel channel;
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await Supabase.initialize(
    url: 'https://kvgyxjnozsngtpgleyvo.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt2Z3l4am5venNuZ3RwZ2xleXZvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzAyNjk4MTksImV4cCI6MjA4NTg0NTgxOX0.oWI3831pQm0-K2TZEuqPR5-7QQvmP0o9hxgnD0mte0s',
  );

  // ✅ 모바일(Android) 환경에서만 알림 초기화 실행
  if (!kIsWeb && Platform.isAndroid) {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    await flutterLocalNotificationsPlugin.initialize(
      settings: settings,
    );

    channel = const AndroidNotificationChannel(
      'high_importance_channel',
      '긴급 공지사항',
      description: '중요한 공지 알림',
      importance: Importance.max,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  FirebaseMessaging.onBackgroundMessage(
    _firebaseMessagingBackgroundHandler,
  );

  runApp(const SspaapApp());
}

class SspaapApp extends StatefulWidget {
  const SspaapApp({super.key});

  @override
  State<SspaapApp> createState() => _SspaapAppState();
}

class _SspaapAppState extends State<SspaapApp> {
  @override
  void initState() {
    super.initState();
    _setupFCM();
    _saveDeviceToken();
  }

  Future<void> _saveDeviceToken() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    String? token;
    try {
      if (kIsWeb) {
        token = await FirebaseMessaging.instance.getToken(
          vapidKey: "BEV3s3UFvwvP9XHpaW80z0_sBwZMwNJmrTtDTtlTEyUk26z8XOIBk26He4pQ-JdhBKekbwafbs7qhwIFXC37i4g", 
        );
      } else {
        token = await FirebaseMessaging.instance.getToken();
      }

      if (token != null) {
        await Supabase.instance.client.from('user_device_tokens').upsert({
          'user_id': user.id,
          'token': token,
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'user_id,token'); 
        
        debugPrint("[FCM] 토큰 저장/업데이트 성공");
      }
    } catch (e) {
      debugPrint("[FCM] ❌ 토큰 저장 중 에러: $e");
    }
  }

  Future<void> _setupFCM() async {
    final messaging = FirebaseMessaging.instance;

    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen((message) async {
      final notification = message.notification;
      if (notification == null) return;

      if (!kIsWeb && Platform.isAndroid) {
        // ✅ 모든 인자에 이름을 명시 (title:, body: 추가)
        await flutterLocalNotificationsPlugin.show(
          id: notification.hashCode,      // id까지 이름 명시
          title: notification.title,
          body: notification.body,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
              icon: '@mipmap/ic_launcher',
            ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session;

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'sspapp',
          home: session != null
              ? const HomeScreen()
              : LoginScreen(),
        );
      },
    );
  }
}