import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PushTokenService {
  static final _fcm = FirebaseMessaging.instance;

  static Future<void> registerMyToken() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    print('=== [FCM] registerMyToken START ===');

    if (user == null) {
      print('[FCM] STOP: 로그인된 유저가 없습니다.');
      return;
    }

    // 1. 토큰 획득
    String? token;
    try {
      token = await _fcm.getToken();
      print('[FCM] 가져온 토큰: $token');
    } catch (e) {
      print('[FCM] 토큰 획득 실패: $e');
      return;
    }

    if (token == null) return;

    // 2. ✅ 중복 충돌 해결 로직
    try {
      print('[FCM] 충돌 방지를 위한 기존 토큰 데이터 정리 중...');

      // 💡 [핵심 수정]: 이 토큰(기기)을 이미 다른 유저가 등록해 두었다면, 
      // 그 유저의 레코드를 먼저 지워야 409 Conflict가 발생하지 않습니다.
      await supabase
          .from('user_device_tokens')
          .delete()
          .eq('token', token);

      print('[FCM] 새 유저 정보로 토큰 등록 중...');
      
      // 💡 upsert를 사용하여 유저 한 명당 토큰 하나만 유지되도록 처리
      await supabase.from('user_device_tokens').upsert({
        'user_id': user.id,
        'token': token,
        'platform': kIsWeb ? 'web' : (Platform.isIOS ? 'ios' : 'android'),
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id'); // 유저 ID가 겹치면 업데이트

      print('[FCM] ✅ 토큰 저장 성공 (계정 전환 대응 완료)');
    } catch (e) {
      print('[FCM] ❌ 토큰 저장 최종 실패: $e');
    }
  }
}