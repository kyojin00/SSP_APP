import 'package:flutter/material.dart';
import 'attendance_helper.dart';

class LeaveHistoryTab extends StatelessWidget {
  final List<Map<String, dynamic>> leaveHistory;
  final Future<void> Function() onRefresh;

  const LeaveHistoryTab({
    Key? key,
    required this.leaveHistory,
    required this.onRefresh,
  }) : super(key: key);

  static const _primary = Color(0xFF3D5AFE);
  static const _text    = Color(0xFF1A1D2E);
  static const _sub     = Color(0xFF8A93B0);
  static const _teal    = Colors.teal;

  static String _leaveTypeLabel(String? type) => switch (type) {
    'ANNUAL'   => '연차',  'HALF'     => '반차',
    'PUBLIC'   => '공가',  'EVENT'    => '경조사',
    'TRAINING' => '교육',  'SICK'     => '병가',
    _          => '연차',
  };
  static Color _leaveTypeColor(String? type) => switch (type) {
    'ANNUAL'   => const Color(0xFFFF8C42),
    'HALF'     => Colors.deepOrange,
    'PUBLIC'   => Colors.teal,
    'EVENT'    => const Color(0xFFFF4D64),
    'TRAINING' => const Color(0xFF00897B),
    'SICK'     => const Color(0xFF2E6BFF),
    _          => const Color(0xFFFF8C42),
  };
  static IconData _leaveTypeIcon(String? type) => switch (type) {
    'ANNUAL'   => Icons.calendar_month_rounded,
    'HALF'     => Icons.wb_sunny_rounded,
    'PUBLIC'   => Icons.account_balance_rounded,
    'EVENT'    => Icons.favorite_rounded,
    'TRAINING' => Icons.school_rounded,
    'SICK'     => Icons.local_hospital_rounded,
    _          => Icons.calendar_month_rounded,
  };

  Color _lighten(Color c, double a) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + a).clamp(0.0, 1.0)).toColor();
  }

  @override
  Widget build(BuildContext context) {
    if (leaveHistory.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(children: [
          const SizedBox(height: 80),
          Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white, shape: BoxShape.circle,
                boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 14, offset: const Offset(0, 4))],
              ),
              child: Icon(Icons.event_busy_rounded,
                  size: 38, color: Colors.grey[300]),
            ),
            const SizedBox(height: 14),
            Text('연차 기록이 없습니다.',
                style: TextStyle(
                    color: Colors.grey[400],
                    fontWeight: FontWeight.w600)),
          ])),
        ]),
      );
    }

    // 월별 그룹화
    final Map<String, List<Map<String, dynamic>>> byMonth = {};
    for (final item in leaveHistory) {
      final start = item['start_date'] as String? ?? '';
      final month = start.length >= 7 ? start.substring(0, 7) : '알 수 없음';
      byMonth.putIfAbsent(month, () => []).add(item);
    }

    // 전체 통계
    final totalUsed = leaveHistory.fold<double>(
        0, (s, e) => s + ((e['leave_days'] as num?)?.toDouble() ?? 0));
    final annualCount = leaveHistory
        .where((e) => (e['leave_type'] as String?) == 'ANNUAL').length;

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: _primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 40),
        children: [
          // ── 전체 요약 카드
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_lighten(_primary, 0.20), _primary],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(
                  color: _primary.withOpacity(0.28), blurRadius: 14,
                  offset: const Offset(0, 6))],
            ),
            child: Stack(children: [
              Positioned(right: -30, top: -30, child: Container(
                  width: 110, height: 110,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.08)))),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.22),
                        shape: BoxShape.circle),
                    child: const Icon(Icons.history_rounded,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('연차 사용 기록',
                        style: TextStyle(
                            color: Colors.white70, fontSize: 11,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('총 ${_fmtD(totalUsed)}일 사용',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 18,
                            fontWeight: FontWeight.w900)),
                  ])),
                  Column(children: [
                    _summaryChip('${leaveHistory.length}건', Icons.receipt_rounded),
                    const SizedBox(height: 6),
                    _summaryChip('${byMonth.length}개월', Icons.calendar_month_rounded),
                  ]),
                ]),
              ),
            ]),
          ),

          // ── 월별 그룹
          ...byMonth.entries.map((entry) {
            final totalDays = entry.value.fold<double>(
                0, (s, e) => s + ((e['leave_days'] as num?)?.toDouble() ?? 0));
            final monthLabel = _formatMonth(entry.key);

            return Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              // 월 헤더
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: [_lighten(Colors.teal, 0.15), Colors.teal],
                          begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(9),
                      boxShadow: [BoxShadow(
                          color: Colors.teal.withOpacity(0.25),
                          blurRadius: 6, offset: const Offset(0, 2))],
                    ),
                    child: const Icon(Icons.calendar_month_rounded,
                        color: Colors.white, size: 13),
                  ),
                  const SizedBox(width: 9),
                  Text(monthLabel,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w900,
                          color: _text)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text('${_fmtD(totalDays)}일 사용',
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w800,
                            color: Colors.teal)),
                  ),
                ]),
              ),
              ...entry.value.map(_historyCard),
              const SizedBox(height: 18),
            ]);
          }),
        ],
      ),
    );
  }

  Widget _summaryChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.20),
          borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: Colors.white),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(
            fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _historyCard(Map<String, dynamic> item) {
    final leaveType = item['leave_type'] as String? ?? 'ANNUAL';
    final tc        = _leaveTypeColor(leaveType);
    final icon      = _leaveTypeIcon(leaveType);
    final name      = item['full_name']     as String? ?? '-';
    final dept      = item['dept_category'] as String? ?? '';
    final dc        = deptColor(dept);
    final days      = (item['leave_days']   as num?)?.toDouble() ?? 0;
    final reason    = item['reason']        as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: tc.withOpacity(0.07), blurRadius: 10,
              offset: const Offset(0, 3)),
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 5,
              offset: const Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Row(children: [
          // 왼쪽 컬러 바
          Container(
            width: 4,
            height: 72,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_lighten(tc, 0.15), tc],
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // 아이콘
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: tc.withOpacity(0.1),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: tc, size: 18),
          ),
          const SizedBox(width: 10),

          // 내용
          Expanded(child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                // 이름이 있으면 표시 (관리자 뷰)
                if (name != '-') ...[
                  Container(
                    width: 24, height: 24,
                    decoration: BoxDecoration(
                        color: dc.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(7)),
                    child: Center(child: Text(
                      name.isNotEmpty ? name.substring(0, 1) : '?',
                      style: TextStyle(fontSize: 11,
                          fontWeight: FontWeight.w900, color: dc),
                    )),
                  ),
                  const SizedBox(width: 6),
                  Text(name, style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 13, color: _text)),
                  const SizedBox(width: 8),
                ],
                _typeBadge(leaveType),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.date_range_rounded, size: 11, color: _sub),
                const SizedBox(width: 3),
                Text(
                  '${item['start_date']} ~ ${item['end_date']}',
                  style: const TextStyle(fontSize: 11, color: _sub)),
              ]),
              if (reason.isNotEmpty) ...[
                const SizedBox(height: 2),
                Row(children: [
                  const Icon(Icons.notes_rounded, size: 11, color: _sub),
                  const SizedBox(width: 3),
                  Expanded(child: Text(reason,
                      style: const TextStyle(fontSize: 11, color: _sub),
                      overflow: TextOverflow.ellipsis)),
                ]),
              ],
            ]),
          )),
          const SizedBox(width: 8),

          // 일수 + 승인 뱃지
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${_fmtD(days)}일',
                  style: TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 16, color: tc)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [_lighten(Colors.green, 0.15),
                          Colors.green.shade600],
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [BoxShadow(
                      color: Colors.green.withOpacity(0.22),
                      blurRadius: 5, offset: const Offset(0, 2))],
                ),
                child: const Text('승인완료',
                    style: TextStyle(
                        color: Colors.white, fontSize: 9,
                        fontWeight: FontWeight.w900)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _typeBadge(String? leaveType) {
    final label = _leaveTypeLabel(leaveType);
    final color = _leaveTypeColor(leaveType);
    final icon  = _leaveTypeIcon(leaveType);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.25))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 9, color: color),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(
            fontSize: 9, fontWeight: FontWeight.w800, color: color)),
      ]),
    );
  }

  String _fmtD(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toString();

  String _formatMonth(String yyyyMM) {
    try {
      final parts = yyyyMM.split('-');
      return '${parts[0]}년 ${int.parse(parts[1])}월';
    } catch (_) { return yyyyMM; }
  }
}