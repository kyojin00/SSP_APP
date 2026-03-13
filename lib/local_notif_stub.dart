// 웹용 stub - flutter_local_notifications 미지원
class LocalNotifService {
  static Future<void> init() async {}
  static Future<void> show(int id, String? title, String? body) async {}
  static Future<void> showFromMessage(dynamic message) async {}
}