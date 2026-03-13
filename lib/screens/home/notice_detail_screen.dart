import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:translator/translator.dart';
import 'edit_notice_screen.dart';
import 'app_strings.dart';
import 'lang_context.dart';

class NoticeDetailScreen extends StatefulWidget {
  final Map<String, dynamic> notice;
  final bool isAdmin;

  const NoticeDetailScreen({
    Key? key,
    required this.notice,
    required this.isAdmin,
  }) : super(key: key);

  @override
  State<NoticeDetailScreen> createState() => _NoticeDetailScreenState();
}

class _NoticeDetailScreenState extends State<NoticeDetailScreen>
    with SingleTickerProviderStateMixin {

  bool   _isDeleting     = false;
  bool   _isResending    = false;

  static const String _webhookSecret = 'notice_secret_2026_sspapp';
  bool   _showTranslate  = false;
  bool   _showReadStatus = false;
  bool   _isTranslating  = false;
  String _selectedLang   = 'ko';
  String _displayTitle   = '';
  String _displayContent = '';

  final GoogleTranslator _translator = GoogleTranslator();
  final String _myUuid = "b72e0fb3-1632-480c-afff-33f8348e2aeb";

  late AnimationController _animCtrl;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  static const _deptLabels = <String, String>{
    'MANAGEMENT': '관리부',
    'PRODUCTION': '생산관리부',
    'SALES':      '영업부',
    'RND':        '연구소',
    'STEEL':      '스틸생산부',
    'BOX':        '박스생산부',
    'DELIVERY':   '포장납품부',
    'SSG':        '에스에스지',
    'CLEANING':   '환경미화',
    'NUTRITION':  '영양사',
    'ALL':        '전체',
    'TEST':       'TEST',
  };

  static const _deptColors = <String, Color>{
    'MANAGEMENT': Color(0xFF3B5BDB),
    'PRODUCTION': Color(0xFF7048E8),
    'SALES':      Color(0xFFE8590C),
    'RND':        Color(0xFF0C8599),
    'STEEL':      Color(0xFF495057),
    'BOX':        Color(0xFF2F9E44),
    'DELIVERY':   Color(0xFFAD1457),
    'SSG':        Color(0xFF00897B),
    'CLEANING':   Color(0xFF558B2F),
    'NUTRITION':  Color(0xFFD84315),
    'ALL':        Color(0xFF1971C2),
    'TEST':       Color(0xFFC92A2A),
  };

  static const _deptIcons = <String, IconData>{
    'MANAGEMENT': Icons.business_center_rounded,
    'PRODUCTION': Icons.precision_manufacturing_rounded,
    'SALES':      Icons.storefront_rounded,
    'RND':        Icons.science_rounded,
    'STEEL':      Icons.construction_rounded,
    'BOX':        Icons.inventory_2_rounded,
    'DELIVERY':   Icons.local_shipping_rounded,
    'SSG':        Icons.store_rounded,
    'CLEANING':   Icons.cleaning_services_rounded,
    'NUTRITION':  Icons.restaurant_rounded,
    'ALL':        Icons.campaign_rounded,
    'TEST':       Icons.bug_report_rounded,
  };

  String   _deptLabel(String c) => _deptLabels[c] ?? c;
  Color    _deptColor(String c) => _deptColors[c] ?? const Color(0xFF1971C2);
  IconData _deptIcon (String c) => _deptIcons[c]  ?? Icons.campaign_rounded;

  @override
  void initState() {
    super.initState();
    _displayTitle   = (widget.notice['title']   ?? '').toString();
    _displayContent = (widget.notice['content'] ?? '').toString();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
    _markAsRead();
  }


  Future<void> _resendNotification() async {
    if (!mounted) return;
    // await 전에 messenger 미리 캡처
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isResending = true);
    bool? ok;
    String? errorMsg;
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'send_notice_onesignal',
        headers: {'x-webhook-secret': _webhookSecret},
        body: {
          'notice_id': widget.notice['id'],
          'title': widget.notice['title'],
          'content': widget.notice['content'],
          'target_category': widget.notice['target_category'],
          'secret': _webhookSecret,
        },
      );
      ok = res.status == 200 || res.status == 207;
    } catch (e) {
      errorMsg = e.toString();
    }
    if (!mounted) return;
    setState(() => _isResending = false);
    final msg = errorMsg != null
        ? "오류: $errorMsg"
        : (ok == true ? _tr(AppStrings.notifResendDone) : _tr(AppStrings.notifResendFail));
    messenger.showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
      backgroundColor: (errorMsg != null || ok != true) ? const Color(0xFFC92A2A) : const Color(0xFF1A1D2E),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ));
  }

  String _tr(Map<String, String> map) => context.tr(map);

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _translateTo(String code) async {
    if (code == 'ko') {
      setState(() {
        _selectedLang   = 'ko';
        _displayTitle   = (widget.notice['title']   ?? '').toString();
        _displayContent = (widget.notice['content'] ?? '').toString();
      });
      return;
    }
    setState(() { _selectedLang = code; _isTranslating = true; });
    try {
      final results = await Future.wait([
        _translator.translate((widget.notice['title']   ?? '').toString(), to: code),
        _translator.translate((widget.notice['content'] ?? '').toString(), to: code),
      ]);
      if (!mounted) return;
      setState(() { _displayTitle = results[0].text; _displayContent = results[1].text; });
    } catch (_) {
      if (mounted) _snack("번역 중 오류가 발생했습니다.", isError: true);
    } finally {
      if (mounted) setState(() => _isTranslating = false);
    }
  }

  Future<void> _markAsRead() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null || widget.notice['target_category'] == 'TEST') return;
      await Supabase.instance.client.from('notice_reads').upsert({
        'notice_id': widget.notice['id'],
        'user_id':   user.id,
        'read_at':   DateTime.now().toIso8601String(),
      }, onConflict: 'notice_id,user_id');
    } catch (e) { debugPrint("읽음 처리: $e"); }
  }

  Future<void> _deleteNotice() async {
    setState(() => _isDeleting = true);
    try {
      await Supabase.instance.client.from('notices').delete().eq('id', widget.notice['id']);
      if (!mounted) return;
      _snack("공지사항이 삭제되었습니다.");
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      _snack("삭제 실패: $e", isError: true);
    }
  }

  Future<List<Map<String, dynamic>>> _getReaderProfiles(List<Map<String, dynamic>> logs) async {
    final ids = logs.map((l) => l['user_id'].toString()).toSet().toList();
    if (ids.isEmpty) return [];
    try {
      final res = await Supabase.instance.client
          .from('profiles')
          .select('id, full_name, dept_category, position')
          .filter('id', 'in', ids);
      return List<Map<String, dynamic>>.from(res);
    } catch (_) { return []; }
  }

  Future<Map<String, int>> _getDeptTotals() async {
    try {
      final res = await Supabase.instance.client.from('profiles').select('dept_category');
      final Map<String, int> map = {};
      for (final r in res) {
        final d = (r['dept_category'] ?? '').toString();
        map[d] = (map[d] ?? 0) + 1;
      }
      return map;
    } catch (_) { return {for (final k in _deptLabels.keys) k: 1}; }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
      backgroundColor: isError ? const Color(0xFFC92A2A) : const Color(0xFF1A1D2E),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ));
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        titlePadding:   const EdgeInsets.fromLTRB(24, 24, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0F0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.delete_forever_rounded, color: Color(0xFFC92A2A), size: 22),
          ),
          const SizedBox(width: 12),
          const Text("공지 삭제", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        ]),
        content: const Text(
          "이 공지사항을 삭제하면\n복구할 수 없습니다. 계속할까요?",
          style: TextStyle(fontSize: 14, height: 1.7, color: Color(0xFF6B7280)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF9CA3AF),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text("취소", style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC92A2A),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: () { Navigator.pop(context); _deleteNotice(); },
            child: const Text("삭제하기", style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (widget.notice['target_category'] == 'TEST' &&
        (currentUser == null || currentUser.id != _myUuid)) {
      return const Scaffold(body: Center(child: Text("접근 권한이 없는 공지입니다.")));
    }

    final category    = (widget.notice['target_category'] ?? 'ALL').toString();
    final created     = (widget.notice['created_at']      ?? '').toString();
    final createdDate = created.length >= 10 ? created.substring(0, 10) : created;
    final catColor    = _deptColor(category);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F8),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.92),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0,2))],
            ),
            child: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1A1D2E), size: 20),
          ),
        ),
        actions: [
          if (widget.isAdmin) ...[
            _floatBtn(Icons.notifications_active_rounded, const Color(0xFFFF8C42),
                _isResending ? null : _resendNotification, loading: _isResending),
            _floatBtn(Icons.edit_rounded, catColor, () async {
              final result = await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => EditNoticeScreen(notice: widget.notice)));
              if (result == true && mounted) Navigator.pop(context, true);
            }),
            _floatBtn(Icons.delete_rounded, const Color(0xFFC92A2A),
                _isDeleting ? null : _showDeleteDialog, loading: _isDeleting),
            const SizedBox(width: 6),
          ],
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(children: [
              // ── 풀블리드 헤더
              _buildHeroHeader(category, createdDate, catColor),
              // ── 본문 영역
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 48),
                child: Column(children: [
                  const SizedBox(height: 16),
                  _buildTranslateCard(),
                  if (_isTranslating)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          minHeight: 3,
                          backgroundColor: catColor.withOpacity(0.08),
                          valueColor: AlwaysStoppedAnimation(catColor),
                        ),
                      ),
                    ),
                  const SizedBox(height: 14),
                  _buildContentCard(catColor),
                  if (widget.isAdmin) ...[
                    const SizedBox(height: 14),
                    _buildStatsCard(),
                    const SizedBox(height: 14),
                    _buildReadStatusCard(),
                  ],
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ── 플로팅 앱바 버튼
  Widget _floatBtn(IconData icon, Color color, VoidCallback? onTap, {bool loading = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0,2))],
        ),
        child: loading
            ? Padding(padding: const EdgeInsets.all(11),
                child: CircularProgressIndicator(strokeWidth: 2, color: color))
            : Icon(icon, color: color, size: 20),
      ),
    );
  }

  // ── 히어로 헤더 (풀블리드)
  Widget _buildHeroHeader(String category, String createdDate, Color catColor) {
    final imageUrl = widget.notice['image_url'];
    final lightColor = HSLColor.fromColor(catColor)
        .withLightness((HSLColor.fromColor(catColor).lightness + 0.18).clamp(0.0, 0.92))
        .toColor();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [catColor, lightColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(children: [
        // 배경 원 패턴
        Positioned(right: -40, top: -40,
          child: Container(width: 180, height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.07),
            ),
          ),
        ),
        Positioned(right: 40, bottom: -30,
          child: Container(width: 110, height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.05),
            ),
          ),
        ),
        // 실제 내용
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 8),
              // 태그 줄
              Row(children: [
                _heroBadge(_deptIcon(category), _deptLabel(category)),
                const SizedBox(width: 8),
                _heroBadge(Icons.calendar_today_rounded, createdDate),
                const Spacer(),
                _heroBadge(Icons.translate_rounded, _langFullLabel(_selectedLang)),
              ]),
              const SizedBox(height: 20),
              // 이미지 (있을 때)
              if (imageUrl != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.network(
                    imageUrl.toString(),
                    width: double.infinity,
                    height: 180,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(),
                  ),
                ),
                const SizedBox(height: 18),
              ],
              // 제목
              Text(
                _displayTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  height: 1.3,
                  letterSpacing: -0.5,
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _heroBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.white, size: 12),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
      ]),
    );
  }

  // ── 번역 카드
  Widget _buildTranslateCard() {
    return _card(
      child: Column(children: [
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => setState(() => _showTranslate = !_showTranslate),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.deepOrangeAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.translate_rounded, color: Colors.deepOrangeAccent, size: 17),
              ),
              const SizedBox(width: 12),
              const Text("번역", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF1A1D2E))),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _isTranslating
                      ? Colors.deepOrangeAccent.withOpacity(0.1)
                      : Colors.black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _langFullLabel(_selectedLang),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _isTranslating ? Colors.deepOrangeAccent : const Color(0xFF9CA3AF),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              AnimatedRotation(
                turns: _showTranslate ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(Icons.expand_more_rounded, color: Color(0xFFCBD5E1), size: 22),
              ),
            ]),
          ),
        ),
        if (_showTranslate) ...[
          Container(height: 1, color: Colors.black.withOpacity(0.05)),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(children: [
                _langChip("🇰🇷 한국어",    "ko"),
                _langChip("🇺🇸 English",  "en"),
                _langChip("🇻🇳 Việt",     "vi"),
                _langChip("🇰🇭 ខ្មែរ",     "km"),
                _langChip("🇹🇭 ภาษาไทย",  "th"),
                _langChip("🇺🇿 O'zbek",   "uz"),
              ]),
            ),
          ),
        ],
      ]),
    );
  }

  // ── 본문 카드
  Widget _buildContentCard(Color catColor) {
    return _card(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: catColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.article_rounded, color: catColor, size: 17),
          ),
          const SizedBox(width: 12),
          const Text("공지 내용",
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF1A1D2E))),
        ]),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [catColor.withOpacity(0.3), Colors.transparent],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          _displayContent,
          style: const TextStyle(
            fontSize: 16,
            height: 1.95,
            color: Color(0xFF374151),
            letterSpacing: -0.1,
          ),
        ),
      ]),
    );
  }

  // ── 통계 카드
  Widget _buildStatsCard() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client
          .from('notice_reads').stream(primaryKey: ['id']).eq('notice_id', widget.notice['id']),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final logs = snapshot.data!;
        return FutureBuilder<Map<String, dynamic>>(
          future: Future.wait<dynamic>([_getReaderProfiles(logs), _getDeptTotals()])
              .then((v) => {'readers': v[0] as List<Map<String, dynamic>>, 'totals': v[1] as Map<String, int>}),
          builder: (context, snap) {
            if (!snap.hasData) return const SizedBox();
            final readers = snap.data!['readers'] as List<Map<String, dynamic>>;
            final totals  = snap.data!['totals']  as Map<String, int>;
            final Map<String, int> deptRead = {};
            for (final r in readers) {
              final d = (r['dept_category'] ?? '').toString();
              deptRead[d] = (deptRead[d] ?? 0) + 1;
            }
            const depts = ['MANAGEMENT','PRODUCTION','SALES','RND','STEEL','BOX','DELIVERY','SSG','CLEANING','NUTRITION'];
            return _card(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5C6BC0).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.insert_chart_rounded, color: Color(0xFF5C6BC0), size: 17),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(child: Text("부서별 읽음 통계",
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF1A1D2E)))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2F9E44).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text("${readers.length}명 완료",
                        style: const TextStyle(fontSize: 12, color: Color(0xFF2F9E44), fontWeight: FontWeight.w900)),
                  ),
                ]),
                const SizedBox(height: 20),
                ...depts.map((d) {
                  final read  = deptRead[d] ?? 0;
                  final total = totals[d]   ?? 0;
                  if (total == 0) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _statBar(d, read, total),
                  );
                }),
              ]),
            );
          },
        );
      },
    );
  }

  // ── 확인 명단 카드
  Widget _buildReadStatusCard() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client
          .from('notice_reads').stream(primaryKey: ['id']).eq('notice_id', widget.notice['id']),
      builder: (context, snapshot) {
        final logs  = snapshot.data ?? [];
        final count = logs.length;
        return _card(
          child: Column(children: [
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => setState(() => _showReadStatus = !_showReadStatus),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2F9E44).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.how_to_reg_rounded, color: Color(0xFF2F9E44), size: 17),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(child: Text("확인 명단",
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF1A1D2E)))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2F9E44).withOpacity(0.09),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text("$count명",
                        style: const TextStyle(fontSize: 12, color: Color(0xFF2F9E44), fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _showReadStatus ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.expand_more_rounded, color: Color(0xFFCBD5E1), size: 22),
                  ),
                ]),
              ),
            ),
            if (_showReadStatus) ...[
              Container(height: 1, color: Colors.black.withOpacity(0.05)),
              Padding(
                padding: const EdgeInsets.all(18),
                child: count == 0
                    ? _emptyState(Icons.hourglass_empty_rounded, "아직 확인한 인원이 없습니다.")
                    : FutureBuilder<List<Map<String, dynamic>>>(
                        future: _getReaderProfiles(logs),
                        builder: (context, snap) {
                          final users = snap.data ?? [];
                          if (users.isEmpty) {
                            return const Center(child: Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2F9E44))));
                          }
                          return Wrap(
                            spacing: 8, runSpacing: 8,
                            children: users.map(_readerChip).toList(),
                          );
                        },
                      ),
              ),
            ],
          ]),
        );
      },
    );
  }

  // ══════════════════════════════════════════
  // Atoms
  // ══════════════════════════════════════════

  Widget _card({required Widget child, EdgeInsets? padding}) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(20), child: child),
    );
  }

  Widget _langChip(String label, String code) {
    final sel = _selectedLang == code;
    return GestureDetector(
      onTap: _isTranslating ? null : () => _translateTo(code),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: sel ? Colors.deepOrangeAccent : Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: sel ? Colors.deepOrangeAccent : Colors.black.withOpacity(0.07),
          ),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 12.5,
          color: sel ? Colors.white : const Color(0xFF6B7280),
          fontWeight: FontWeight.w800,
        )),
      ),
    );
  }

  Widget _statBar(String deptCode, int current, int total) {
    final ratio = (total > 0 ? current / total : 0.0).clamp(0.0, 1.0);
    final color = _deptColor(deptCode);
    final pct   = (ratio * 100).toStringAsFixed(0);
    return Column(children: [
      Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(9)),
          child: Icon(_deptIcon(deptCode), color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(_deptLabel(deptCode),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1A1D2E)))),
        Text("$current / $total",
            style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w700)),
        const SizedBox(width: 8),
        SizedBox(
          width: 38,
          child: Text("$pct%",
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w900)),
        ),
      ]),
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: LinearProgressIndicator(
          value: ratio,
          backgroundColor: color.withOpacity(0.09),
          valueColor: AlwaysStoppedAnimation(color),
          minHeight: 6,
        ),
      ),
    ]);
  }

  Widget _readerChip(Map<String, dynamic> u) {
    final name     = (u['full_name']     ?? '').toString();
    final dept     = (u['dept_category'] ?? '').toString();
    final position = (u['position']      ?? '').toString();
    final color    = _deptColor(dept);
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.14)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        CircleAvatar(
          radius: 15,
          backgroundColor: color.withOpacity(0.13),
          child: Text(name.isNotEmpty ? name[0] : '?',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: color)),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF1A1D2E))),
          Text("${_deptLabel(dept)}  ·  $position",
              style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
        ]),
      ]),
    );
  }

  Widget _emptyState(IconData icon, String message) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 28),
    child: Column(children: [
      Icon(icon, color: Colors.black.withOpacity(0.1), size: 44),
      const SizedBox(height: 10),
      Text(message, style: const TextStyle(color: Color(0xFF9CA3AF), fontWeight: FontWeight.w600, fontSize: 13)),
    ]),
  );

  String _langFullLabel(String code) {
    const m = {
      'ko': '한국어', 'en': 'English', 'vi': 'Tiếng Việt',
      'km': 'ខ្មែរ', 'th': 'ภาษาไทย', 'uz': "O'zbek",
    };
    return m[code] ?? code.toUpperCase();
  }
}