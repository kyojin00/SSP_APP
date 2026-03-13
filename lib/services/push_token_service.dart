// import 'dart:io' show Platform;
// import 'package:flutter/foundation.dart' show kIsWeb;
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';

// // class PushTokenService {
// //   static final _fcm = FirebaseMessaging.instance;

// //   static Future<void> registerMyToken() async {
// //     final supabase = Supabase.instance.client;
// //     final user = supabase.auth.currentUser;

// //     print('=== [FCM] registerMyToken START ===');

// //     if (user == null) {
// //       print('[FCM] STOP: 로그인된 유저가 없습니다.');
// //       return;
// //     }

// //     // 1. 토큰 획득
// //     String? token;
// //     try {
// //       token = await _fcm.getToken();
// //       print('[FCM] 가져온 토큰: $token');
// //     } catch (e) {
// //       print('[FCM] 토큰 획득 실패: $e');
// //       return;
// //     }

// //     if (token == null) {
// //       print('[FCM] STOP: 토큰이 null입니다.');
// //       return;
// //     }

// //     // 2. platform 값 명확하게 결정 (null 절대 안 되게)
// //     final String platform;
// //     if (kIsWeb) {
// //       platform = 'web';
// //     } else if (Platform.isIOS) {
// //       platform = 'ios';
// //     } else {
// //       platform = 'android';
// //     }
// //     print('[FCM] 감지된 플랫폼: $platform');

// //     try {
// //       print('[FCM] 기존 토큰 정리 중 (다른 유저 동일 기기 대응)...');

// //       // 이 기기 토큰을 다른 유저가 갖고 있으면 먼저 삭제
// //       await supabase
// //           .from('user_device_tokens')
// //           .delete()
// //           .eq('token', token)
// //           .neq('user_id', user.id); // 내 것은 지우지 않음

// //       print('[FCM] 토큰 저장 중 (upsert by user_id + platform)...');

// //       // user_id + platform 조합으로 upsert
// //       // → 같은 유저가 웹/앱 동시 사용해도 각각 유지됨
// //       await supabase.from('user_device_tokens').upsert({
// //         'user_id': user.id,
// //         'token': token,
// //         'platform': platform,
// //         'updated_at': DateTime.now().toIso8601String(),
// //       }, onConflict: 'user_id,platform'); // ← 핵심 수정

// //       print('[FCM] ✅ 토큰 저장 성공 | user: ${user.id} | platform: $platform');
// //     } catch (e) {
// //       print('[FCM] ❌ 토큰 저장 실패: $e');

// //       // fallback: upsert 실패 시 delete → insert
// //       try {
// //         print('[FCM] fallback: delete → insert 시도');
// //         await supabase
// //             .from('user_device_tokens')
// //             .delete()
// //             .eq('user_id', user.id)
// //             .eq('platform', platform);

// //         await supabase.from('user_device_tokens').insert({
// //           'user_id': user.id,
// //           'token': token,
// //           'platform': platform,
// //           'updated_at': DateTime.now().toIso8601String(),
// //         });
// //         print('[FCM] ✅ fallback 저장 성공');
// //       } catch (e2) {
// //         print('[FCM] ❌ fallback도 실패: $e2');
// //       }
// //     }
// //   }
// // }