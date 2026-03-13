import 'package:flutter/material.dart';
import 'app_language_provider.dart';

extension LangContext on BuildContext {
  AppLanguageProvider get lang => _LangScope.of(this);
  String tr(Map<String, String> map) => lang.t(map);
  String get langCode => lang.lang;
  String? get langFont => lang.fontFamily;
}

// provider를 외부(main.dart)에서 주입받는 버전
class LangProvider extends StatelessWidget {
  final AppLanguageProvider provider;
  final Widget child;
  const LangProvider({Key? key, required this.provider, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return _LangScope(provider: provider, child: child);
  }
}

class _LangScope extends InheritedWidget {
  final AppLanguageProvider provider;
  const _LangScope({required this.provider, required super.child});

  static AppLanguageProvider of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_LangScope>()!.provider;
  }

  @override
  bool updateShouldNotify(_LangScope old) => provider.lang != old.provider.lang;
}