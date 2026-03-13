import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLang {
  final String code;
  final String flag;
  final String label;
  final String nativeLabel;
  const AppLang({required this.code, required this.flag, required this.label, required this.nativeLabel});
}

const kSupportedLangs = [
  AppLang(code: 'ko', flag: '🇰🇷', label: '한국어',     nativeLabel: '한국어'),
  AppLang(code: 'en', flag: '🇺🇸', label: 'English',    nativeLabel: 'English'),
  AppLang(code: 'vi', flag: '🇻🇳', label: 'Tiếng Việt', nativeLabel: 'Tiếng Việt'),
  AppLang(code: 'uz', flag: '🇺🇿', label: "O'zbek",     nativeLabel: "O'zbek"),
  AppLang(code: 'km', flag: '🇰🇭', label: 'ខ្មែរ',       nativeLabel: 'ខ្មែរ'),
];

class AppLanguageProvider extends ChangeNotifier {
  static const _prefKey = 'app_language';
  String _lang = 'ko';
  String get lang => _lang;

  AppLanguageProvider() { _loadSaved(); }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    _lang = prefs.getString(_prefKey) ?? 'ko';
    notifyListeners();
  }

  Future<void> setLang(String code) async {
    _lang = code;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, code);
  }

  String? get fontFamily => _lang == 'km' ? 'NotoSansKhmer' : null;

  String t(Map<String, String> translations) {
    return translations[_lang] ?? translations['ko'] ?? '';
  }
}