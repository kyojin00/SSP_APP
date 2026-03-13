import 'package:flutter/material.dart';

class PwaInstallGuideScreen extends StatelessWidget {
  const PwaInstallGuideScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F8FB),
        appBar: AppBar(
          title: const Text("홈 화면에 추가",
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          centerTitle: true,
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1A1D2E),
          elevation: 0,
          surfaceTintColor: Colors.white,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(56),
            child: Container(
              color: Colors.white,
              child: Column(children: [
                Container(height: 1, color: const Color(0xFFF0F2F8)),
                TabBar(
                  labelColor: const Color(0xFF2E6BFF),
                  unselectedLabelColor: const Color(0xFF8A93B0),
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 14),
                  unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                  indicatorColor: const Color(0xFF2E6BFF),
                  indicatorWeight: 3,
                  indicatorSize: TabBarIndicatorSize.label,
                  tabs: const [
                    Tab(
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text("🍎", style: TextStyle(fontSize: 16)),
                        SizedBox(width: 6),
                        Text("아이폰 (Safari)"),
                      ]),
                    ),
                    Tab(
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text("🤖", style: TextStyle(fontSize: 16)),
                        SizedBox(width: 6),
                        Text("갤럭시 (Chrome)"),
                      ]),
                    ),
                  ],
                ),
              ]),
            ),
          ),
        ),
        body: const TabBarView(
          children: [
            _IosGuideTab(),
            _AndroidGuideTab(),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════
// iOS 가이드
// ══════════════════════════════════════════
class _IosGuideTab extends StatefulWidget {
  const _IosGuideTab();
  @override
  State<_IosGuideTab> createState() => _IosGuideTabState();
}

class _IosGuideTabState extends State<_IosGuideTab> {
  static const _primary = Color(0xFF2E6BFF);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 탭 진입 시 이미지 미리 메모리에 캐싱 → 스크롤 시 디코딩 없음
    precacheImage(const AssetImage('assets/guide/ios.jpg'), context);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      children: [
        // 헤더
        _headerCard(
          emoji: "🍎",
          title: "iPhone / iPad",
          subtitle: "Safari 브라우저 전용",
          color: _primary,
        ),
        const SizedBox(height: 20),

        // Step 1
        _StepCard(
          index: 1,
          color: _primary,
          title: "Safari로 접속",
          desc: "반드시 Safari 브라우저로 접속해야 합니다.\nChrome, 네이버앱 등은 지원되지 않습니다.",
          trailingWidget: _badge("Safari", Icons.language_rounded, _primary),
        ),

        // Step 2 — 이미지 포함
        _StepCard(
          index: 2,
          color: _primary,
          title: "하단 공유 버튼 탭 후 '홈 화면에 추가' 선택",
          desc: "화면 하단 가운데 공유 버튼을 탭한 후,\n스크롤을 내려 '홈 화면에 추가'를 탭하세요.",
          trailingWidget: _badge("공유", Icons.ios_share_rounded, _primary),
          imageAsset: "assets/guide/ios.jpg",
        ),

        // Step 3
        _StepCard(
          index: 3,
          color: _primary,
          title: "앱 이름 확인 후 '추가' 탭",
          desc: "이름을 확인하고 오른쪽 상단 '추가'를 탭하면\n홈 화면에 아이콘이 생성됩니다!",
          trailingWidget: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
                color: _primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.check_rounded, color: _primary, size: 16),
          ),
          isLast: true,
        ),

        const SizedBox(height: 8),
        _tipCard("💡 Safari에서만 가능해요",
            "iPhone에서는 반드시 Safari를 사용해야 홈 화면에 추가할 수 있어요.\n앱처럼 전체화면으로 실행되고 주소창 없이 깔끔하게 사용할 수 있습니다!"),
      ],
    );
  }
}

// ══════════════════════════════════════════
// Android 가이드
// ══════════════════════════════════════════
class _AndroidGuideTab extends StatefulWidget {
  const _AndroidGuideTab();
  @override
  State<_AndroidGuideTab> createState() => _AndroidGuideTabState();
}

class _AndroidGuideTabState extends State<_AndroidGuideTab> {
  static const _teal = Color(0xFF0BC5C5);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage('assets/guide/android.jpg'), context);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      children: [
        // 헤더
        _headerCard(
          emoji: "🤖",
          title: "Android",
          subtitle: "Chrome / 삼성인터넷 전용",
          color: _teal,
        ),
        const SizedBox(height: 20),

        // Step 1
        _StepCard(
          index: 1,
          color: _teal,
          title: "Chrome으로 접속",
          desc: "Chrome 또는 삼성인터넷 브라우저로 사이트에 접속하세요.",
          trailingWidget: _badge("Chrome", Icons.language_rounded, _teal),
        ),

        // Step 2 — 이미지 포함
        _StepCard(
          index: 2,
          color: _teal,
          title: "점 3개 메뉴 탭 후 '홈 화면에 추가' 선택",
          desc: "주소창 오른쪽 끝 ⋮ 메뉴를 탭한 후,\n'홈 화면에 추가'를 탭하세요.",
          trailingWidget: _badge("메뉴", Icons.more_vert_rounded, _teal),
          imageAsset: "assets/guide/android.jpg",
        ),

        // Step 3
        _StepCard(
          index: 3,
          color: _teal,
          title: "설치 팝업에서 '추가' 탭",
          desc: "팝업창에서 '추가' 또는 '설치'를 탭하면\n홈 화면에 아이콘이 생성됩니다!",
          trailingWidget: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
                color: _teal.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.check_rounded, color: _teal, size: 16),
          ),
          isLast: true,
        ),

        const SizedBox(height: 8),
        _tipCard("💡 삼성인터넷 사용자",
            "삼성인터넷에서는 하단 탭바의 메뉴(☰) 아이콘을 탭해 보세요.\n'페이지 추가' → '홈 화면'으로 추가할 수 있습니다."),
      ],
    );
  }
}

// ══════════════════════════════════════════
// 공용 위젯
// ══════════════════════════════════════════
Widget _headerCard({
  required String emoji,
  required String title,
  required String subtitle,
  required Color color,
}) {
  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [color, color.withOpacity(0.7)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
            color: color.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 6))
      ],
    ),
    child: Row(children: [
      Text(emoji, style: const TextStyle(fontSize: 40)),
      const SizedBox(width: 16),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8)),
          child: Text(subtitle,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ),
      ]),
      const Spacer(),
      Icon(Icons.smartphone_rounded,
          color: Colors.white.withOpacity(0.3), size: 48),
    ]),
  );
}

Widget _badge(String label, IconData icon, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(10),
      boxShadow: [
        BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3))
      ],
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: Colors.white, size: 14),
      const SizedBox(width: 4),
      Text(label,
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.white)),
    ]),
  );
}

Widget _tipCard(String title, String content) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFFFFBEB),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3)),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text("💡", style: TextStyle(fontSize: 20)),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF92660A))),
          const SizedBox(height: 4),
          Text(content,
              style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF92660A),
                  height: 1.5)),
        ]),
      ),
    ]),
  );
}

// ══════════════════════════════════════════
// Step 카드 (이미지 선택적 포함)
// ══════════════════════════════════════════
class _StepCard extends StatelessWidget {
  final int index;
  final Color color;
  final String title;
  final String desc;
  final Widget? trailingWidget;
  final String? imageAsset; // assets 경로
  final bool isLast;

  const _StepCard({
    required this.index,
    required this.color,
    required this.title,
    required this.desc,
    this.trailingWidget,
    this.imageAsset,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 왼쪽: 번호 + 연결선
        Column(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(12)),
            child: Center(
              child: Text("$index",
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900)),
            ),
          ),
          if (!isLast)
            Container(
              width: 2,
              height: imageAsset != null ? 260 : 32,
              margin: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
        ]),
        const SizedBox(width: 12),
        // 오른쪽: 카드
        Expanded(
          child: Container(
            margin: EdgeInsets.only(bottom: isLast ? 0 : 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 텍스트 영역
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF1A1D2E))),
                            const SizedBox(height: 5),
                            Text(desc,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF8A93B0),
                                    height: 1.5)),
                          ],
                        ),
                      ),
                      if (trailingWidget != null) ...[
                        const SizedBox(width: 8),
                        trailingWidget!,
                      ],
                    ],
                  ),
                ),
                // 이미지 영역
                if (imageAsset != null) ...[
                  Container(height: 1, color: const Color(0xFFF0F2F8)),
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                    child: Image.asset(
                      imageAsset!,
                      width: double.infinity,
                      fit: BoxFit.fitWidth, // cover → fitWidth (불필요한 크롭 연산 제거)
                      // 이미지 해상도를 화면 크기에 맞게 다운샘플링 → 메모리/렌더링 부담 감소
                      cacheWidth: 800,
                      filterQuality: FilterQuality.medium,
                      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                        if (wasSynchronouslyLoaded || frame != null) return child;
                        // 로딩 중 placeholder
                        return Container(
                          height: 200,
                          color: const Color(0xFFF4F6FB),
                          child: const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF2E6BFF),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}