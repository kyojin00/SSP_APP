import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'write_suggestion_screen.dart';

// ══════════════════════════════════════════
// 건의 / 신고함 목록
// ══════════════════════════════════════════

class SuggestionScreen extends StatefulWidget {
  final bool isAdmin;
  const SuggestionScreen({Key? key, required this.isAdmin}) : super(key: key);

  @override
  State<SuggestionScreen> createState() => _SuggestionScreenState();
}

class _SuggestionScreenState extends State<SuggestionScreen> {
  final supabase = Supabase.instance.client;

  static const _indigo  = Color(0xFF3D5AFE);
  static const _indigoDk = Color(0xFF1A237E);
  static const _bg      = Color(0xFFF4F6FB);

  Color _lighten(Color c, double a) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + a).clamp(0.0, 1.0)).toColor();
  }

  // 카테고리별 색상 / 아이콘
  Color _catColor(String? cat) => switch (cat) {
    '인사/노무'  => const Color(0xFF2E6BFF),
    '안전보건'   => const Color(0xFFFF8C42),
    '생산현장'   => const Color(0xFF00897B),
    '시설환경'   => const Color(0xFF7C5CDB),
    _           => const Color(0xFF3D5AFE),
  };

  IconData _catIcon(String? cat) => switch (cat) {
    '인사/노무'  => Icons.people_alt_rounded,
    '안전보건'   => Icons.health_and_safety_rounded,
    '생산현장'   => Icons.precision_manufacturing_rounded,
    '시설환경'   => Icons.business_rounded,
    _           => Icons.campaign_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: _buildBody(),
      floatingActionButton: _GradientFab(
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const WriteSuggestionScreen())),
      ),
    );
  }

  Widget _buildBody() {
    final myId = supabase.auth.currentUser?.id;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase
          .from('suggestions')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false),
      builder: (context, snapshot) {
        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── 그라디언트 SliverAppBar
            SliverAppBar(
              expandedHeight: 130,
              pinned: true,
              elevation: 0,
              scrolledUnderElevation: 0,
              backgroundColor: _indigoDk,
              foregroundColor: Colors.white,
              title: const Text(
                '건의 및 신고함',
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                    color: Colors.white),
              ),
              actions: [
                Container(
                  margin: const EdgeInsets.only(right: 12),
                  child: IconButton(
                    onPressed: () => setState(() {}),
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.refresh_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.parallax,
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0D0D6B), _indigoDk, _indigo],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Stack(children: [
                    Positioned(
                      right: -40, top: -40,
                      child: Container(
                        width: 170, height: 170,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.07),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 76, 20, 0),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.mark_chat_unread_rounded,
                              color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '익명 제보 · 건의사항 접수함',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),

            // ── 목록
            if (snapshot.connectionState == ConnectionState.waiting)
              const SliverFillRemaining(
                child: Center(
                    child: CircularProgressIndicator(
                        color: _indigo, strokeWidth: 2)),
              )
            else ...[
              Builder(builder: (context) {
                final items = snapshot.data ?? [];

                if (items.isEmpty) {
                  return SliverFillRemaining(
                    child: Center(
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4))
                            ],
                          ),
                          child: Icon(Icons.inbox_rounded,
                              size: 40, color: Colors.grey[300]),
                        ),
                        const SizedBox(height: 14),
                        const Text('접수된 의견이 없습니다.',
                            style: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.w700,
                                fontSize: 14)),
                      ]),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _suggestionCard(items[i], myId),
                      childCount: items.length,
                    ),
                  ),
                );
              }),
            ],
          ],
        );
      },
    );
  }

  Future<void> _deleteSuggestion(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.delete_forever_rounded,
                color: Colors.red, size: 20),
          ),
          const SizedBox(width: 10),
          const Text('글 삭제', style: TextStyle(fontWeight: FontWeight.w900)),
        ]),
        content: const Text('이 건의/신고를 삭제하시겠습니까?\n삭제 후 복구할 수 없습니다.',
            style: TextStyle(height: 1.6)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소',
                  style: TextStyle(
                      color: Colors.grey, fontWeight: FontWeight.w700))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제하기',
                style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await supabase.from('suggestions').delete().eq('id', item['id']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('삭제되었습니다.'),
            behavior: SnackBarBehavior.floating));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('삭제 실패: $e')));
      }
    }
  }

  Widget _suggestionCard(Map<String, dynamic> item, String? myId) {
    final isAnonymous = item['is_anonymous'] ?? true;
    final status      = item['status']       ?? 'RECEIVED';
    final isMine      = myId != null && item['user_id'] == myId;
    final cat         = item['category'] as String?;
    final color       = _catColor(cat);
    final icon        = _catIcon(cat);
    final lighter     = _lighten(color, 0.18);

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => SuggestionDetailScreen(
              item: item, isAdmin: widget.isAdmin))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.10),
              blurRadius: 14, offset: const Offset(0, 5),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6, offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            // 그라디언트 원형 아이콘
            Container(
              width: 50, height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [lighter, color],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.28),
                    blurRadius: 10, offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 13),
            // 본문
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                  item['title'] ?? '',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: Color(0xFF1A1D2E)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                Row(children: [
                  Text(
                    isAnonymous
                        ? '익명 제보'
                        : (item['reporter_name'] ?? '성명불상'),
                    style: TextStyle(
                        fontSize: 12,
                        color: color.withOpacity(0.8),
                        fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '  ·  ${DateFormat('MM/dd').format(DateTime.parse(item['created_at']))}',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.black.withOpacity(0.35)),
                  ),
                  if (isMine) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _indigo.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('내 글',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: _indigo)),
                    ),
                  ],
                ]),
              ]),
            ),
            const SizedBox(width: 8),
            // 상태 뱃지 + 삭제
            Column(mainAxisSize: MainAxisSize.min, children: [
              _statusBadge(status),
              if (isMine) ...[
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => _deleteSuggestion(item),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.delete_outline_rounded,
                          size: 12, color: Colors.red),
                      SizedBox(width: 3),
                      Text('삭제',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.red)),
                    ]),
                  ),
                ),
              ],
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    final Color color;
    final String label;
    final IconData icon;

    switch (status) {
      case 'PROGRESS':
        color = const Color(0xFF2E6BFF);
        label = '검토중';
        icon  = Icons.hourglass_top_rounded;
        break;
      case 'COMPLETED':
        color = Colors.green;
        label = '완료';
        icon  = Icons.check_circle_rounded;
        break;
      default:
        color = const Color(0xFF8A93B0);
        label = '접수';
        icon  = Icons.inbox_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_lighten(color, 0.15), color],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.22),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.white, size: 11),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

// ══════════════════════════════════════════
// 상세 화면
// ══════════════════════════════════════════

class SuggestionDetailScreen extends StatefulWidget {
  final Map<String, dynamic> item;
  final bool isAdmin;
  const SuggestionDetailScreen(
      {Key? key, required this.item, required this.isAdmin})
      : super(key: key);

  @override
  State<SuggestionDetailScreen> createState() =>
      _SuggestionDetailScreenState();
}

class _SuggestionDetailScreenState extends State<SuggestionDetailScreen> {
  late TextEditingController _commentController;
  String? _status;
  bool _isSaving = false;

  static const _indigo   = Color(0xFF3D5AFE);
  static const _indigoDk = Color(0xFF1A237E);

  Color _lighten(Color c, double a) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + a).clamp(0.0, 1.0)).toColor();
  }

  Color _catColor(String? cat) => switch (cat) {
    '인사/노무'  => const Color(0xFF2E6BFF),
    '안전보건'   => const Color(0xFFFF8C42),
    '생산현장'   => const Color(0xFF00897B),
    '시설환경'   => const Color(0xFF7C5CDB),
    _           => _indigo,
  };

  IconData _catIcon(String? cat) => switch (cat) {
    '인사/노무'  => Icons.people_alt_rounded,
    '안전보건'   => Icons.health_and_safety_rounded,
    '생산현장'   => Icons.precision_manufacturing_rounded,
    '시설환경'   => Icons.business_rounded,
    _           => Icons.campaign_rounded,
  };

  Color _statusColor(String? s) => switch (s) {
    'PROGRESS'  => const Color(0xFF2E6BFF),
    'COMPLETED' => Colors.green,
    _           => const Color(0xFF8A93B0),
  };

  String _statusLabel(String? s) => switch (s) {
    'PROGRESS'  => '검토중',
    'COMPLETED' => '처리 완료',
    _           => '신규 접수',
  };

  @override
  void initState() {
    super.initState();
    _status            = widget.item['status'] ?? 'RECEIVED';
    _commentController = TextEditingController(
        text: widget.item['admin_comment'] ?? '');
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _saveAdminResponse() async {
    setState(() => _isSaving = true);
    try {
      await Supabase.instance.client.from('suggestions').update({
        'status':        _status,
        'admin_comment': _commentController.text.trim(),
      }).eq('id', widget.item['id']);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('답변이 저장되었습니다.'),
              behavior: SnackBarBehavior.floating));
    } catch (e) {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item      = widget.item;
    final date      = DateFormat('yyyy.MM.dd HH:mm')
        .format(DateTime.parse(item['created_at']));
    final myId      = Supabase.instance.client.auth.currentUser?.id;
    final isMine    = myId != null && item['user_id'] == myId;
    final cat       = item['category'] as String?;
    final catColor  = _catColor(cat);
    final catIcon   = _catIcon(cat);
    final lighter   = _lighten(catColor, 0.20);
    final statusColor = _statusColor(_status);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
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
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ],
            ),
            child: const Icon(Icons.arrow_back_rounded,
                color: Color(0xFF1A1D2E), size: 20),
          ),
        ),
        actions: [
          if (isMine)
            GestureDetector(
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    title: const Text('글 삭제',
                        style: TextStyle(fontWeight: FontWeight.w900)),
                    content: const Text('이 건의/신고를 삭제하시겠습니까?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('취소')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10))),
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('삭제'),
                      ),
                    ],
                  ),
                );
                if (confirmed != true || !mounted) return;
                await Supabase.instance.client
                    .from('suggestions')
                    .delete()
                    .eq('id', item['id']);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('삭제되었습니다.')));
                }
              },
              child: Container(
                margin: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: const Icon(Icons.delete_outline_rounded,
                    color: Colors.red, size: 20),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(children: [
          // ── 그라디언트 히어로 헤더
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_indigoDk, _indigo, _lighten(_indigo, 0.12)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(children: [
              Positioned(
                right: -40, top: -40,
                child: Container(
                  width: 180, height: 180,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.07)),
                ),
              ),
              Positioned(
                right: 40, bottom: -30,
                child: Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.05)),
                ),
              ),
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const SizedBox(height: 50),
                    // 카테고리 + 상태 뱃지
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.3)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(catIcon, color: Colors.white, size: 13),
                          const SizedBox(width: 5),
                          Text(cat ?? '기타',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800)),
                        ]),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.25)),
                        ),
                        child: Text(
                          _statusLabel(_status),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    Text(
                      item['title'] ?? '',
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.3,
                          letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 10),
                    Row(children: [
                      Icon(Icons.schedule_rounded,
                          size: 12, color: Colors.white.withOpacity(0.6)),
                      const SizedBox(width: 5),
                      Text(date,
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 12,
                              fontWeight: FontWeight.w500)),
                    ]),
                  ]),
                ),
              ),
            ]),
          ),

          // ── 본문 영역
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 48),
            child: Column(children: [
              // 제보 내용 카드
              _ContentCard(
                catColor: catColor,
                lighter: lighter,
                content: item['content'] ?? '',
              ),

              const SizedBox(height: 16),

              // 관리자 패널 / 사용자 답변 뷰
              if (widget.isAdmin)
                _AdminPanel(
                  status: _status,
                  controller: _commentController,
                  isSaving: _isSaving,
                  onStatusChanged: (v) => setState(() => _status = v),
                  onSave: _saveAdminResponse,
                )
              else
                _UserResponseCard(
                  comment: item['admin_comment'] as String?,
                  status: _status,
                  statusColor: statusColor,
                  statusLabel: _statusLabel(_status),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════
// 내용 카드
// ══════════════════════════════════════════

class _ContentCard extends StatelessWidget {
  final Color catColor, lighter;
  final String content;
  const _ContentCard({
    required this.catColor,
    required this.lighter,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: catColor.withOpacity(0.08),
              blurRadius: 14,
              offset: const Offset(0, 4)),
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // 상단 컬러 스트라이프
          Container(
            height: 4,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [catColor, lighter],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [lighter, catColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: catColor.withOpacity(0.28),
                          blurRadius: 8,
                          offset: const Offset(0, 3))
                    ],
                  ),
                  child: const Icon(Icons.description_rounded,
                      color: Colors.white, size: 17),
                ),
                const SizedBox(width: 12),
                const Text('제보 내용',
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: Color(0xFF1A1D2E))),
              ]),
              const SizedBox(height: 16),
              Container(
                width: double.infinity, height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [catColor.withOpacity(0.3), Colors.transparent],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                content,
                style: const TextStyle(
                    fontSize: 15,
                    height: 1.85,
                    color: Color(0xFF374151),
                    letterSpacing: -0.1),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════
// 관리자 답변 패널
// ══════════════════════════════════════════

class _AdminPanel extends StatelessWidget {
  final String? status;
  final TextEditingController controller;
  final bool isSaving;
  final ValueChanged<String?> onStatusChanged;
  final VoidCallback onSave;

  const _AdminPanel({
    required this.status,
    required this.controller,
    required this.isSaving,
    required this.onStatusChanged,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.indigo.withOpacity(0.08),
              blurRadius: 14,
              offset: const Offset(0, 4))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(children: [
          // 상단 헤더
          Container(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1A237E), Color(0xFF3D5AFE)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle),
                child: const Icon(Icons.admin_panel_settings_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              const Text('관리자 답변 및 상태 관리',
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: Colors.white)),
            ]),
          ),
          // 폼
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(children: [
              // 상태 드롭다운
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F6FB),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: Colors.black.withOpacity(0.08)),
                ),
                child: DropdownButtonFormField<String>(
                  value: status,
                  decoration: InputDecoration(
                    labelText: '처리 상태',
                    labelStyle: const TextStyle(
                        color: Color(0xFF8A93B0),
                        fontWeight: FontWeight.w600),
                    prefixIcon: const Icon(Icons.swap_horiz_rounded,
                        color: Color(0xFF3D5AFE), size: 20),
                    filled: true,
                    fillColor: Colors.transparent,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'RECEIVED',
                        child: Text('📥 신규 접수')),
                    DropdownMenuItem(
                        value: 'PROGRESS',
                        child: Text('⚙️ 검토 및 진행 중')),
                    DropdownMenuItem(
                        value: 'COMPLETED',
                        child: Text('✅ 처리 완료')),
                  ],
                  onChanged: onStatusChanged,
                ),
              ),
              const SizedBox(height: 14),
              // 답변 텍스트필드
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F6FB),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: Colors.black.withOpacity(0.08)),
                ),
                child: TextField(
                  controller: controller,
                  maxLines: 5,
                  style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF1A1D2E),
                      height: 1.6),
                  decoration: InputDecoration(
                    hintText: '답변 내용을 입력하세요',
                    hintStyle: TextStyle(
                        color: Colors.black.withOpacity(0.3),
                        fontSize: 14),
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(left: 14, right: 10, top: 14),
                      child: Icon(Icons.edit_note_rounded,
                          color: Color(0xFF3D5AFE), size: 20),
                    ),
                    prefixIconConstraints: const BoxConstraints(
                        minWidth: 48, minHeight: 48),
                    filled: true,
                    fillColor: Colors.transparent,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.fromLTRB(0, 14, 14, 14),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // 저장 버튼
              GestureDetector(
                onTap: isSaving ? null : onSave,
                child: Container(
                  height: 52,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: isSaving
                        ? null
                        : const LinearGradient(
                            colors: [Color(0xFF1A237E), Color(0xFF3D5AFE)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                    color: isSaving ? Colors.grey.shade200 : null,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: isSaving
                        ? []
                        : [
                            BoxShadow(
                              color: const Color(0xFF3D5AFE).withOpacity(0.35),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                  ),
                  child: Center(
                    child: isSaving
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    shape: BoxShape.circle),
                                child: const Icon(Icons.check_rounded,
                                    color: Colors.white, size: 16),
                              ),
                              const SizedBox(width: 8),
                              const Text('답변 등록하기',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15)),
                            ],
                          ),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════
// 사용자용 답변 뷰
// ══════════════════════════════════════════

class _UserResponseCard extends StatelessWidget {
  final String? comment;
  final String? status;
  final Color statusColor;
  final String statusLabel;

  const _UserResponseCard({
    required this.comment,
    required this.status,
    required this.statusColor,
    required this.statusLabel,
  });

  @override
  Widget build(BuildContext context) {
    final hasComment = comment != null && comment!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: statusColor.withOpacity(0.08),
              blurRadius: 14,
              offset: const Offset(0, 4))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(children: [
          // 상단 헤더
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.07),
              border: Border(
                bottom: BorderSide(
                    color: statusColor.withOpacity(0.15)),
              ),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _lightenColor(statusColor, 0.15),
                      statusColor
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                        color: statusColor.withOpacity(0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: Icon(
                  status == 'COMPLETED'
                      ? Icons.mark_email_read_rounded
                      : Icons.pending_actions_rounded,
                  color: Colors.white,
                  size: 17,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('관리자 답변',
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: Color(0xFF1A1D2E))),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _lightenColor(statusColor, 0.12),
                      statusColor
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                        color: statusColor.withOpacity(0.22),
                        blurRadius: 6,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: Text(statusLabel,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800)),
              ),
            ]),
          ),
          // 본문
          Padding(
            padding: const EdgeInsets.all(18),
            child: Text(
              hasComment
                  ? comment!
                  : '담당자가 내용을 확인 중입니다. 잠시만 기다려 주세요.',
              style: TextStyle(
                  fontSize: 15,
                  height: 1.75,
                  color: hasComment
                      ? const Color(0xFF1A1D2E)
                      : Colors.black38,
                  fontStyle:
                      hasComment ? FontStyle.normal : FontStyle.italic),
            ),
          ),
        ]),
      ),
    );
  }

  static Color _lightenColor(Color c, double a) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + a).clamp(0.0, 1.0)).toColor();
  }
}

// ══════════════════════════════════════════
// 그라디언트 FAB
// ══════════════════════════════════════════

class _GradientFab extends StatefulWidget {
  final VoidCallback onTap;
  const _GradientFab({required this.onTap});

  @override
  State<_GradientFab> createState() => _GradientFabState();
}

class _GradientFabState extends State<_GradientFab> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapUp:     (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: ()  => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1A237E), Color(0xFF3D5AFE), Color(0xFF6B7FFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: _pressed
                ? []
                : [
                    BoxShadow(
                      color: const Color(0xFF3D5AFE).withOpacity(0.40),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Stack(children: [
            Positioned(
              top: -12, right: -8,
              child: Container(
                width: 50, height: 50,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.08)),
              ),
            ),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.22),
                    shape: BoxShape.circle),
                child: const Icon(Icons.edit_note_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 8),
              const Text('의견 작성',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14)),
            ]),
          ]),
        ),
      ),
    );
  }
}