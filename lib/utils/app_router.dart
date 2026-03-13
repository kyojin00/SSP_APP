import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

/// 앱 전체에서 사용하는 부드러운 화면 전환
class AppRouter {
  /// 기본: 페이드 + 살짝 위에서 내려오는 슬라이드
  static PageRoute<T> fade<T>(Widget screen) {
    return PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) => screen,
      transitionsBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 0.03),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  /// 오른쪽에서 슬라이드
  /// iOS: CupertinoPageRoute (네이티브 스와이프 뒤로가기)
  /// Android: MaterialPageRoute (시스템 백버튼만, 스와이프 없음)
  static PageRoute<T> slide<T>(Widget screen) {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return CupertinoPageRoute<T>(builder: (_) => screen);
    }
    return MaterialPageRoute<T>(builder: (_) => screen);
  }

  /// 모달처럼 아래에서 위로 (바텀시트 대신 풀페이지)
  static PageRoute<T> slideUp<T>(Widget screen) {
    return PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 350),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, __, ___) => screen,
      transitionsBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutQuart);
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, 1.0),
            end: Offset.zero,
          ).animate(curved),
          child: FadeTransition(
            opacity: Tween<double>(begin: 0.5, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }
}