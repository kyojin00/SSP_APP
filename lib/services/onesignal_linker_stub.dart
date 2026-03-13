class OneSignalLinker {
  static Future<String?> linkAndGetId(String userId) async {
    // ✅ 모바일(네이티브)에서는 웹 푸시가 아니라서 일단 skip
    return null;
  }
}