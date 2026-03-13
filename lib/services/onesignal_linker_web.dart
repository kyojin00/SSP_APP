import 'dart:js_util' as js_util;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/home/notice_detail_screen.dart';

class OneSignalLinker {
  static Future<String?> linkAndGetId(String userId) async {
    final res = await js_util.promiseToFuture<Object?>(
      js_util.callMethod(js_util.globalThis, 'onesignalLinkAndGetId', [userId]),
    );

    if (res == null) return null;

    final ok = js_util.getProperty<Object?>(res, 'ok');
    if (ok != true) return null;

    final id = js_util.getProperty<Object?>(res, 'onesignalId');
    if (id == null) return null;

    final s = id.toString();
    return s.isEmpty ? null : s;
  }

  /// 알림 클릭 핸들러 등록 - HomeScreen didChangeDependencies에서 1회 호출
  static void registerClickHandler(BuildContext context, {bool isAdmin = false}) {
    try {
      // 1) 앱 시작 전 클릭된 pending notice_id 처리
      final pending = js_util.callMethod<Object?>(
        js_util.globalThis, 'onesignalGetPendingNoticeId', [],
      );
      if (pending != null && pending.toString().isNotEmpty) {
        _navigateToNotice(context, pending.toString(), isAdmin: isAdmin);
      }

      // 2) 실시간 클릭 콜백 등록
      final callback = js_util.allowInterop((String noticeId) {
        if (context.mounted) {
          _navigateToNotice(context, noticeId, isAdmin: isAdmin);
        }
      });
      js_util.callMethod(js_util.globalThis, 'onesignalSetClickHandler', [callback]);
      debugPrint('[OneSignal] click handler registered');
    } catch (e) {
      debugPrint('[OneSignal] registerClickHandler error: $e');
    }
  }

  static Future<void> _navigateToNotice(
    BuildContext context,
    String noticeId, {
    bool isAdmin = false,
  }) async {
    debugPrint('[OneSignal] navigate to notice: $noticeId');
    try {
      final data = await Supabase.instance.client
          .from('notices')
          .select()
          .eq('id', noticeId)
          .single();

      if (!context.mounted) return;

      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => NoticeDetailScreen(
          notice: Map<String, dynamic>.from(data),
          isAdmin: isAdmin,
        ),
      ));
    } catch (e) {
      debugPrint('[OneSignal] navigate error: $e');
    }
  }
}