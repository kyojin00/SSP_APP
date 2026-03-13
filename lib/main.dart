import 'dart:io';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'local_notif_stub.dart'
    if (dart.library.io) 'local_notif_mobile.dart';

import 'screens/auth/login_screen.dart';
import 'screens/home/lang_context.dart';
import 'screens/home/app_language_provider.dart';
import 'screens/home/home_screen.dart';
import 'screens/splash_screen.dart';
import 'firebase_options.dart';

bool get _isAndroid =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
bool get _isIOS =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
bool get _isMobile => _isAndroid || _isIOS;

String get _platformStr {
  if (kIsWeb) return 'web';
  if (Platform.isIOS) return 'ios';
  return 'android';
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(
    RemoteMessage message) async {
  await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform);
  await LocalNotifService.showFromMessage(message);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Intl.defaultLocale = 'ko_KR';
  await initializeDateFormatting('ko_KR', null);

  await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform);

  await Supabase.initialize(
    url: 'https://kvgyxjnozsngtpgleyvo.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt2Z3l4am5venNuZ3RwZ2xleXZvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzAyNjk4MTksImV4cCI6MjA4NTg0NTgxOX0.oWI3831pQm0-K2TZEuqPR5-7QQvmP0o9hxgnD0mte0s',
  );

  if (_isMobile) {
    FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler);
    await LocalNotifService.init();
  }

  runApp(const SspaapApp());
}

class SspaapApp extends StatefulWidget {
  const SspaapApp({super.key});
  @override
  State<SspaapApp> createState() => _SspaapAppState();
}

class _SspaapAppState extends State<SspaapApp> {
  bool _fcmInited = false;
  bool _savingToken = false;
  bool _tokenRefreshRegistered = false;

  final _navigatorKey = GlobalKey<NavigatorState>();
  final _langProvider = AppLanguageProvider();

  @override
  void initState() {
    super.initState();
    _initFCMOnce();
    _listenAuthState();
    _langProvider.addListener(() => setState(() {}));
  }

  void _listenAuthState() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final session = data.session;

      debugPrint("[FCM] Auth 이벤트: $event");

      if (event == AuthChangeEvent.signedIn && session != null) {
        _savingToken = false;
        _saveDeviceToken();
        _navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      } else if (event == AuthChangeEvent.signedOut) {
        _navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => LoginScreen()),
          (route) => false,
        );
      }
    });
  }

  Future<void> _initFCMOnce() async {
    if (_fcmInited) return;
    _fcmInited = true;
    await _setupFCM();
    await _saveDeviceToken();
  }

  Future<void> _saveDeviceToken() async {
    if (_savingToken) return;
    _savingToken = true;

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        debugPrint("[FCM] 로그인 안됨 - 토큰 저장 스킵");
        return;
      }

      debugPrint("[FCM] 플랫폼: $_platformStr 토큰 요청 중");

      String? token;
      if (kIsWeb) {
        token = await FirebaseMessaging.instance.getToken(
          vapidKey:
              "BEV3s3UFvwvP9XHpaW80z0_sBwZMwNJmrTtDTtlTEyUk26z8XOIBk26He4pQ-JdhBKekbwafbs7qhwIFXC37i4g",
        );
      } else {
        token = await FirebaseMessaging.instance.getToken();
      }

      if (token == null) {
        debugPrint("[FCM] 토큰 null");
        return;
      }

      debugPrint(
          "[FCM] 토큰 획득: ...${token.substring(token.length - 10)}");

      final platform = _platformStr;

      // ✅ 내 플랫폼 row만 삭제 후 재삽입 (42P10 완전 차단 구조)
      await Supabase.instance.client
          .from('user_device_tokens')
          .delete()
          .eq('user_id', user.id)
          .eq('platform', platform);

      await Supabase.instance.client
          .from('user_device_tokens')
          .insert({
        'user_id': user.id,
        'platform': platform,
        'token': token,
        'updated_at': DateTime.now().toIso8601String(),
      });

      debugPrint("[FCM] 토큰 저장 완료 ($platform)");

    } catch (e) {
      debugPrint("[FCM] 토큰 저장 에러: $e");
    } finally {
      _savingToken = false;
    }
  }

  Future<void> _setupFCM() async {
    final messaging = FirebaseMessaging.instance;

    final settings = await messaging.requestPermission(
        alert: true, badge: true, sound: true);

    debugPrint("[FCM] 권한 요청 결과: ${settings.authorizationStatus}");

    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    if (!_tokenRefreshRegistered) {
      _tokenRefreshRegistered = true;

      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        debugPrint("[FCM] 토큰 갱신 감지");

        final user =
            Supabase.instance.client.auth.currentUser;
        if (user == null) return;

        final platform = _platformStr;

        try {
          await Supabase.instance.client
              .from('user_device_tokens')
              .delete()
              .eq('user_id', user.id)
              .eq('platform', platform);

          await Supabase.instance.client
              .from('user_device_tokens')
              .insert({
            'user_id': user.id,
            'platform': platform,
            'token': newToken,
            'updated_at':
                DateTime.now().toIso8601String(),
          });

          debugPrint("[FCM] 토큰 갱신 저장 완료");
        } catch (e) {
          debugPrint("[FCM] 토큰 갱신 실패: $e");
        }
      });
    }

    if (_isMobile) {
      FirebaseMessaging.onMessage.listen((message) async {
        debugPrint("[FCM] 포그라운드 메시지: ${message.data}");
        await LocalNotifService.showFromMessage(message);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LangProvider(
      provider: _langProvider,
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        debugShowCheckedModeBanner: false,
        title: 'sspapp',
        locale: Locale(_langProvider.lang),
        theme: ThemeData(
          pageTransitionsTheme:
              const PageTransitionsTheme(
            builders: {
              TargetPlatform.android:
                  FadeUpwardsPageTransitionsBuilder(),
              TargetPlatform.iOS:
                  CupertinoPageTransitionsBuilder(),
              TargetPlatform.fuchsia:
                  FadeUpwardsPageTransitionsBuilder(),
            },
          ),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}