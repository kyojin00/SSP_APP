import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'notice_detail_screen.dart';
import 'write_notice_screen.dart';

class NoticeListScreen extends StatefulWidget {
  final bool isAdmin;
  final String myDept;

  const NoticeListScreen({
    Key? key,
    required this.isAdmin,
    required this.myDept,
  }) : super(key: key);

  @override
  State<NoticeListScreen> createState() => _NoticeListScreenState();
}

class _NoticeListScreenState extends State<NoticeListScreen> {
  final supabase = Supabase.instance.client;

  static const _primary  = Color(0xFF7C5CDB);
  static const _lighter  = Color(0xFFAB8FE8);

  // 부서별 색상
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

  Color    _catColor(String c) => _deptColors[c] ?? _primary;
  IconData _catIcon (String c) => _deptIcons[c]  ?? Icons.campaign_rounded;

  Color _lighten(Color c, double a) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + a).clamp(0.0, 1.0)).toColor();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: _buildNoticeStream(),
      floatingActionButton: widget.isAdmin
          ? _GradientFab(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const WriteNoticeScreen())),
            )
          : null,
    );
  }

  Widget _buildNoticeStream() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase
          .from('notices')
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
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              title: const Text(
                '공지 / 지시',
                style: TextStyle(
                    fontWeight: FontWeight.w900, fontSize: 17, color: Colors.white),
              ),
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.parallax,
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF5A3FBF), _primary, _lighter],
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
                          color: Colors.white.withOpacity(0.07),
                        ),
                      ),
                    ),
                    Positioned(
                      left: -20, bottom: -30,
                      child: Container(
                        width: 120, height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.05),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 80, 20, 0),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.campaign_rounded,
                              color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '공지사항 · 지시사항',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
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

            // ── 컨텐츠
            if (snapshot.hasError)
              SliverFillRemaining(child: _buildStatusMessage("데이터를 불러올 수 없습니다."))
            else if (!snapshot.hasData)
              const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(
                      color: _primary, strokeWidth: 2)))
            else ...[
              Builder(builder: (context) {
                final allNotices = snapshot.data!;
                final filteredNotices = allNotices.where((notice) {
                  final target = notice['target_category'];
                  if (target == 'TEST') return widget.myDept == 'TEST';
                  if (widget.isAdmin) return true;
                  return target == 'ALL' || target == widget.myDept;
                }).toList();

                if (filteredNotices.isEmpty) {
                  return SliverFillRemaining(
                      child: _buildStatusMessage("표시할 공지사항이 없습니다."));
                }

                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final notice = filteredNotices[index];
                        final createdAt =
                            DateTime.parse(notice['created_at']).toLocal();

                        bool showDateHeader = false;
                        if (index == 0) {
                          showDateHeader = true;
                        } else {
                          final prevDate = DateTime.parse(
                                  filteredNotices[index - 1]['created_at'])
                              .toLocal();
                          if (DateFormat('yyyy-MM-dd').format(createdAt) !=
                              DateFormat('yyyy-MM-dd').format(prevDate)) {
                            showDateHeader = true;
                          }
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (showDateHeader)
                              _buildDateDivider(createdAt),
                            _noticeTile(notice, createdAt),
                          ],
                        );
                      },
                      childCount: filteredNotices.length,
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

  Widget _buildDateDivider(DateTime date) {
    final now       = DateTime.now();
    final today     = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final itemDate  = DateTime(date.year, date.month, date.day);

    final String dateText;
    if (itemDate == today) {
      dateText = '오늘';
    } else if (itemDate == yesterday) {
      dateText = '어제';
    } else {
      dateText = DateFormat('yyyy년 MM월 dd일').format(date);
    }

    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 12),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF5A3FBF), _primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            dateText,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.white),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _primary.withOpacity(0.25),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _noticeTile(Map<String, dynamic> notice, DateTime createdAt) {
    final category = (notice['target_category'] ?? 'ALL') as String;
    final color    = _catColor(category);
    final icon     = _catIcon(category);
    final lighter  = _lighten(color, 0.18);
    final title    = (notice['title'] ?? '') as String;
    final content  = (notice['content'] ?? '') as String;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) =>
                NoticeDetailScreen(notice: notice, isAdmin: widget.isAdmin)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.10),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // 그라디언트 원형 아이콘
            Container(
              width: 48, height: 48,
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
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 13),
            // 텍스트
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: Color(0xFF1A1D2E),
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    content,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.black.withOpacity(0.45),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: color.withOpacity(0.2)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(icon, size: 10, color: color),
                        const SizedBox(width: 4),
                        Text(
                          _categoryLabel(category),
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: color),
                        ),
                      ]),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      DateFormat('HH:mm').format(createdAt),
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.black.withOpacity(0.32),
                          fontWeight: FontWeight.w500),
                    ),
                  ]),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chevron_right_rounded,
                color: color,
                size: 16,
              ),
            ),
          ]),
        ),
      ),
    );
  }

  String _categoryLabel(String c) {
    const m = {
      'MANAGEMENT': '관리부',
      'PRODUCTION': '생산',
      'SALES':      '영업',
      'RND':        '연구소',
      'STEEL':      '스틸',
      'BOX':        '박스',
      'DELIVERY':   '포장납품',
      'SSG':        '에스에스지',
      'CLEANING':   '환경미화',
      'NUTRITION':  '영양사',
      'ALL':        '전체',
      'TEST':       'TEST',
    };
    return m[c] ?? c;
  }

  Widget _buildStatusMessage(String msg) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: Icon(Icons.campaign_outlined,
              color: Colors.grey.withOpacity(0.4), size: 40),
        ),
        const SizedBox(height: 16),
        Text(msg,
            style: TextStyle(
                color: Colors.black.withOpacity(0.35),
                fontWeight: FontWeight.w700,
                fontSize: 14)),
      ]),
    );
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
              colors: [Color(0xFF5A3FBF), Color(0xFF7C5CDB), Color(0xFFAB8FE8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: _pressed
                ? []
                : [
                    BoxShadow(
                      color: const Color(0xFF7C5CDB).withOpacity(0.40),
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
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 8),
              const Text(
                '공지 작성',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}