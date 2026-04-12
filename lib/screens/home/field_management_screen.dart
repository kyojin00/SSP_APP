import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'report_fault_screen.dart';

// ══════════════════════════════════════════
// 현장관리 목록 화면
// ══════════════════════════════════════════

class FieldManagementScreen extends StatefulWidget {
  final bool isAdmin;
  const FieldManagementScreen({Key? key, required this.isAdmin})
      : super(key: key);

  @override
  State<FieldManagementScreen> createState() =>
      _FieldManagementScreenState();
}

class _FieldManagementScreenState
    extends State<FieldManagementScreen> {
  final supabase = Supabase.instance.client;

  static const _orange   = Color(0xFFFF8C42);
  static const _orangeDk = Color(0xFFE65100);
  static const _bg       = Color(0xFFF4F6FB);

  Color _lighten(Color c, double a) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + a).clamp(0.0, 1.0)).toColor();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: _buildBody(),
      floatingActionButton: _GradientFab(
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => ReportFaultScreen())),
      ),
    );
  }

  Widget _buildBody() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase
          .from('equipment_reports')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false),
      builder: (context, snapshot) {
        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── 그라디언트 SliverAppBar
            SliverAppBar(
              expandedHeight: 140,
              pinned: true,
              elevation: 0,
              scrolledUnderElevation: 0,
              backgroundColor: _orangeDk,
              foregroundColor: Colors.white,
              title: const Text(
                '현장관리 (설비고장)',
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                    color: Colors.white),
              ),
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.parallax,
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF8B2500), _orangeDk, _orange],
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
                            color: Colors.white.withOpacity(0.07)),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 78, 20, 0),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle),
                          child: const Icon(
                              Icons.precision_manufacturing_rounded,
                              color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Builder(builder: (context) {
                          final data = snapshot.data ?? [];
                          final urgent = data
                              .where((r) =>
                                  r['priority'] == 'URGENT' &&
                                  r['status'] != 'COMPLETED')
                              .length;
                          return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(
                              urgent > 0
                                  ? '긴급 처리 필요 $urgent건!'
                                  : '설비 고장 신고 및 관리',
                              style: TextStyle(
                                color: urgent > 0
                                    ? const Color(0xFFFFD180)
                                    : Colors.white,
                                fontSize: urgent > 0 ? 14 : 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '전체 ${data.length}건 · 완료 ${data.where((r) => r['status'] == 'COMPLETED').length}건',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ]);
                        }),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),

            // ── 목록
            if (!snapshot.hasData)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: _orange)),
              )
            else ...[
              Builder(builder: (context) {
                final reports = snapshot.data!;
                if (reports.isEmpty) {
                  return SliverFillRemaining(
                    child: Center(
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 16, offset: const Offset(0, 4))],
                          ),
                          child: Icon(Icons.build_outlined, size: 40, color: Colors.grey[300]),
                        ),
                        const SizedBox(height: 14),
                        const Text('접수된 고장 신고가 없습니다.',
                            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _reportCard(reports[i]),
                      childCount: reports.length,
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

  Widget _reportCard(Map<String, dynamic> report) {
    final isUrgent = report['priority'] == 'URGENT';
    final status   = report['status'] as String? ?? 'PENDING';
    final isDone   = status == 'COMPLETED';

    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) =>
              ReportDetailScreen(report: report, isAdmin: widget.isAdmin))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: (isUrgent ? Colors.red : _orange).withOpacity(0.10),
              blurRadius: 14, offset: const Offset(0, 5),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6, offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(children: [
            // 카드 본체
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Hero(
                  tag: 'img_${report['id']}',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      report['image_url'],
                      width: 64, height: 64, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 64, height: 64,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isUrgent
                                ? [Colors.red.shade300, Colors.red.shade500]
                                : [_lighten(_orange, 0.15), _orange],
                            begin: Alignment.topLeft, end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.precision_manufacturing_rounded,
                            color: Colors.white, size: 30),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      if (isUrgent) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [Color(0xFFFF5252), Color(0xFFC62828)]),
                            borderRadius: BorderRadius.circular(7),
                            boxShadow: [BoxShadow(
                                color: Colors.red.withOpacity(0.28),
                                blurRadius: 6, offset: const Offset(0, 2))],
                          ),
                          child: const Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.white, size: 11),
                            SizedBox(width: 3),
                            Text('긴급', style: TextStyle(
                                color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                          ]),
                        ),
                        const SizedBox(width: 7),
                      ],
                      Expanded(
                        child: Text(
                          report['title'] ?? '',
                          style: TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 15,
                            color: isUrgent ? const Color(0xFFC62828) : const Color(0xFF1A1D2E),
                          ),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 5),
                    Row(children: [
                      Icon(Icons.person_rounded, size: 12,
                          color: Colors.black.withOpacity(0.35)),
                      const SizedBox(width: 4),
                      Text(report['reporter_name'] ?? '-',
                          style: TextStyle(fontSize: 12,
                              color: Colors.black.withOpacity(0.5),
                              fontWeight: FontWeight.w600)),
                      Text(
                        '  ·  ${DateFormat('MM/dd HH:mm').format(DateTime.parse(report['created_at']))}',
                        style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.35)),
                      ),
                    ]),
                  ]),
                ),
                const SizedBox(width: 8),
                _statusBadge(status),
              ]),
            ),

            // 관리자 버튼
            if (widget.isAdmin && !isDone) ...[
              Container(height: 1, color: Colors.black.withOpacity(0.05)),
              GestureDetector(
                onTap: () => _updateStatus(report['id'], 'COMPLETED'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_lighten(Colors.green, 0.10), Colors.green.shade600],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                  ),
                  child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 7),
                    Text('수리 완료 처리',
                        style: TextStyle(color: Colors.white,
                            fontWeight: FontWeight.w900, fontSize: 14)),
                  ]),
                ),
              ),
            ],

            // 완료 배너
            if (isDone) ...[
              Container(height: 1, color: Colors.black.withOpacity(0.05)),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.06),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.12), shape: BoxShape.circle),
                    child: const Icon(Icons.check_circle_rounded,
                        color: Colors.green, size: 14),
                  ),
                  const SizedBox(width: 7),
                  const Text('수리 완료',
                      style: TextStyle(color: Colors.green,
                          fontWeight: FontWeight.w800, fontSize: 13)),
                ]),
              ),
            ],
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
      case 'COMPLETED':
        color = Colors.green; label = '완료'; icon = Icons.check_circle_rounded;
        break;
      case 'ASSIGNED':
        color = const Color(0xFF2E6BFF); label = '진행중'; icon = Icons.engineering_rounded;
        break;
      default:
        color = const Color(0xFF8A93B0); label = '대기'; icon = Icons.pending_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_lighten(color, 0.15), color],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(
            color: color.withOpacity(0.22), blurRadius: 6,
            offset: const Offset(0, 2))],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.white, size: 11),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(
            color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
      ]),
    );
  }

  Future<void> _updateStatus(String id, String status) async {
    try {
      await supabase.from('equipment_reports')
          .update({'status': status}).eq('id', id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
          SizedBox(width: 8),
          Text('수리 완료 처리되었습니다.',
              style: TextStyle(fontWeight: FontWeight.w700)),
        ]),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ));
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('처리 중 오류가 발생했습니다.'),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }
}

// ══════════════════════════════════════════
// 상세 화면
// ══════════════════════════════════════════

class ReportDetailScreen extends StatelessWidget {
  final Map<String, dynamic> report;
  final bool isAdmin;

  const ReportDetailScreen(
      {Key? key, required this.report, required this.isAdmin})
      : super(key: key);

  static const _orange   = Color(0xFFFF8C42);
  static const _orangeDk = Color(0xFFE65100);

  Color _lighten(Color c, double a) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + a).clamp(0.0, 1.0)).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final isUrgent  = report['priority'] == 'URGENT';
    final status    = report['status'] as String? ?? 'PENDING';
    final isDone    = status == 'COMPLETED';
    final createdAt = DateFormat('yyyy.MM.dd HH:mm')
        .format(DateTime.parse(report['created_at']));

    final accentColor = isUrgent ? Colors.red.shade600 : _orange;
    final lighter     = _lighten(accentColor, 0.18);

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
              boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: const Icon(Icons.arrow_back_rounded,
                color: Color(0xFF1A1D2E), size: 20),
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(children: [
          // 히어로 이미지
          SizedBox(
            height: 280,
            child: Stack(fit: StackFit.expand, children: [
              Hero(
                tag: 'img_${report['id']}',
                child: Image.network(
                  report['image_url'],
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isUrgent
                            ? [Colors.red.shade700, Colors.red.shade400]
                            : [_orangeDk, _orange],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Icon(Icons.precision_manufacturing_rounded,
                        color: Colors.white38, size: 80),
                  ),
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.3),
                        Colors.black.withOpacity(0.65),
                      ],
                      stops: const [0.4, 0.7, 1.0],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 20, right: 20, bottom: 20,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    if (isUrgent) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [Color(0xFFFF5252), Color(0xFFC62828)]),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.white, size: 12),
                          SizedBox(width: 4),
                          Text('긴급 고장', style: TextStyle(
                              color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
                        ]),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDone
                            ? Colors.green.withOpacity(0.85)
                            : Colors.orange.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isDone ? '수리 완료' : '처리 대기중',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    report['title'] ?? '',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900,
                        height: 1.3, letterSpacing: -0.3),
                  ),
                ]),
              ),
            ]),
          ),

          // 본문
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 48),
            child: Column(children: [
              _InfoCard(
                accentColor: accentColor, lighter: lighter,
                reporterName: report['reporter_name'] ?? '-',
                dept: report['dept_category'] ?? '-',
                createdAt: createdAt,
              ),
              const SizedBox(height: 14),
              _ContentCard(
                accentColor: accentColor, lighter: lighter,
                content: report['content'] ?? '',
              ),
              if (isAdmin && !isDone) ...[
                const SizedBox(height: 20),
                _CompleteButton(reportId: report['id']),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── 정보 카드
class _InfoCard extends StatelessWidget {
  final Color accentColor, lighter;
  final String reporterName, dept, createdAt;

  const _InfoCard({
    required this.accentColor, required this.lighter,
    required this.reporterName, required this.dept, required this.createdAt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: accentColor.withOpacity(0.08), blurRadius: 14, offset: const Offset(0, 4)),
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(children: [
          _row(Icons.person_rounded, '신고자', reporterName, accentColor),
          const SizedBox(height: 12),
          _row(Icons.business_rounded, '부서', dept, accentColor),
          const SizedBox(height: 12),
          _row(Icons.schedule_rounded, '신고일시', createdAt, accentColor),
        ]),
      ),
    );
  }

  Widget _row(IconData icon, String label, String value, Color color) {
    return Row(children: [
      Container(
        width: 34, height: 34,
        decoration: BoxDecoration(
            color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 16),
      ),
      const SizedBox(width: 12),
      Text(label, style: const TextStyle(
          fontSize: 13, color: Color(0xFF8A93B0), fontWeight: FontWeight.w600)),
      const SizedBox(width: 10),
      Expanded(child: Text(value, style: const TextStyle(
          fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1A1D2E)))),
    ]);
  }
}

// ── 내용 카드
class _ContentCard extends StatelessWidget {
  final Color accentColor, lighter;
  final String content;

  const _ContentCard({
    required this.accentColor, required this.lighter, required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
            color: accentColor.withOpacity(0.08), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(children: [
          Container(
            height: 4,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accentColor, lighter],
                begin: Alignment.centerLeft, end: Alignment.centerRight,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [lighter, accentColor],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(
                        color: accentColor.withOpacity(0.28),
                        blurRadius: 8, offset: const Offset(0, 3))],
                  ),
                  child: const Icon(Icons.description_rounded,
                      color: Colors.white, size: 17),
                ),
                const SizedBox(width: 12),
                const Text('고장 상세 내용', style: TextStyle(
                    fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF1A1D2E))),
              ]),
              const SizedBox(height: 14),
              Container(
                width: double.infinity, height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accentColor.withOpacity(0.3), Colors.transparent],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                content.isNotEmpty ? content : '상세 설명이 없습니다.',
                style: TextStyle(
                    fontSize: 15, height: 1.8,
                    color: content.isNotEmpty ? const Color(0xFF374151) : Colors.black38,
                    fontStyle: content.isNotEmpty ? FontStyle.normal : FontStyle.italic),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── 완료 처리 버튼
class _CompleteButton extends StatefulWidget {
  final String reportId;
  const _CompleteButton({required this.reportId});

  @override
  State<_CompleteButton> createState() => _CompleteButtonState();
}

class _CompleteButtonState extends State<_CompleteButton> {
  bool _loading = false;
  bool _pressed = false;

  Future<void> _complete() async {
    setState(() => _loading = true);
    try {
      await Supabase.instance.client
          .from('equipment_reports')
          .update({'status': 'COMPLETED'})
          .eq('id', widget.reportId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
          SizedBox(width: 8),
          Text('수리 완료 처리되었습니다.',
              style: TextStyle(fontWeight: FontWeight.w700)),
        ]),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ));
      Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _loading ? null : (_) => setState(() => _pressed = true),
      onTapUp: _loading ? null : (_) { setState(() => _pressed = false); _complete(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          height: 54, width: double.infinity,
          decoration: BoxDecoration(
            gradient: _loading ? null : LinearGradient(
              colors: [Colors.green.shade400, Colors.green.shade600],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            color: _loading ? const Color(0xFFE2E4ED) : null,
            borderRadius: BorderRadius.circular(18),
            boxShadow: _loading || _pressed ? [] : [
              BoxShadow(color: Colors.green.withOpacity(0.35),
                  blurRadius: 14, offset: const Offset(0, 6))
            ],
          ),
          child: Center(
            child: _loading
                ? const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.22), shape: BoxShape.circle),
                      child: const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 9),
                    const Text('수리 완료 처리', style: TextStyle(
                        color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                  ]),
          ),
        ),
      ),
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
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF8B2500), Color(0xFFE65100), Color(0xFFFF8C42)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: _pressed ? [] : [
              BoxShadow(color: const Color(0xFFFF8C42).withOpacity(0.42),
                  blurRadius: 16, offset: const Offset(0, 6))
            ],
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.report_problem_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('고장 신고하기', style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
          ]),
        ),
      ),
    );
  }
}