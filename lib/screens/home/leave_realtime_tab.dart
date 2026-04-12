import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'attendance_helper.dart';
import 'lang_context.dart';
import 'app_strings.dart';

class LeaveRealtimeTab extends StatelessWidget {
  final List<Map<String, dynamic>> onLeaveToday;
  final List<Map<String, dynamic>> upcomingLeaves;
  final Future<void> Function() onRefresh;

  const LeaveRealtimeTab({
    Key? key,
    required this.onLeaveToday,
    required this.upcomingLeaves,
    required this.onRefresh,
  }) : super(key: key);

  // ── 헬퍼
  String _deptLabel(BuildContext context, String dept) {
    const m = {
      'MANAGEMENT': AppStrings.deptManagement,
      'PRODUCTION': AppStrings.deptProduction,
      'SALES':      AppStrings.deptSales,
      'RND':        AppStrings.deptRnd,
      'STEEL':      AppStrings.deptSteel,
      'BOX':        AppStrings.deptBox,
      'DELIVERY':   AppStrings.deptDelivery,
      'SSG':        AppStrings.deptSsg,
      'CLEANING':   AppStrings.deptCleaning,
      'NUTRITION':  AppStrings.deptNutrition,
    };
    final key = m[dept];
    return key != null ? context.tr(key) : dept;
  }

  String _leaveTypeLabel(BuildContext context, String type) => switch (type) {
    'HALF'     => context.tr(AppStrings.leaveTypeHalf),
    'PUBLIC'   => context.tr(AppStrings.leaveTypePublic),
    'EVENT'    => context.tr(AppStrings.leaveTypeEvent),
    'TRAINING' => context.tr({'ko': '교육', 'en': 'Training', 'vi': 'Dao tao', 'uz': "Ta'lim", 'km': 'បណ្តុះបណ្តាល'}),
    'SICK'     => context.tr({'ko': '병가', 'en': 'Sick Leave', 'vi': 'Nghi benh', 'uz': 'Kasal', 'km': 'ច្ឈប់ជំងឺ'}),
    _          => context.tr(AppStrings.leaveTypeAnnual),
  };

  Color _leaveTypeColor(String type) => switch (type) {
    'HALF'     => const Color(0xFFFF9500),
    'PUBLIC'   => const Color(0xFF7C5CDB),
    'EVENT'    => const Color(0xFFFF4D64),
    'TRAINING' => const Color(0xFF00897B),
    'SICK'     => Colors.blue,
    _          => const Color(0xFF2E6BFF),
  };

  IconData _leaveTypeIcon(String type) => switch (type) {
    'HALF'     => Icons.wb_sunny_rounded,
    'PUBLIC'   => Icons.account_balance_rounded,
    'EVENT'    => Icons.favorite_rounded,
    'TRAINING' => Icons.school_rounded,
    'SICK'     => Icons.local_hospital_rounded,
    _          => Icons.calendar_month_rounded,
  };

  String _daysRemaining(BuildContext context, String endDate) {
    try {
      final end   = DateTime.parse(endDate);
      final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final diff  = end.difference(today).inDays;
      if (diff == 0) return context.tr({'ko': '오늘 종료', 'en': 'Ends today', 'vi': 'Hom nay', 'uz': 'Bugun', 'km': 'ថ្ងៃនេះ'});
      return context.tr({'ko': '${diff + 1}일 예정', 'en': '${diff + 1}d left', 'vi': 'Con ${diff + 1} ngay', 'uz': '${diff + 1} kun qoldi', 'km': 'នៅ ${diff + 1} ថ្ងៃ'});
    } catch (_) { return ''; }
  }

  String _daysUntil(BuildContext context, String startDate) {
    try {
      final start = DateTime.parse(startDate);
      final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final diff  = start.difference(today).inDays;
      if (diff == 0) return context.tr({'ko': '오늘 예정', 'en': 'Today', 'vi': 'Hom nay', 'uz': 'Bugun', 'km': 'ថ្ងៃនេះ'});
      if (diff == 1) return context.tr({'ko': '내일 예정', 'en': 'Tomorrow', 'vi': 'Ngay mai', 'uz': 'Ertaga', 'km': 'ថ្ងៃស្អែក'});
      return context.tr({'ko': 'D-$diff', 'en': 'D-$diff', 'vi': 'D-$diff', 'uz': 'D-$diff', 'km': 'D-$diff'});
    } catch (_) { return ''; }
  }

  String _fmtDate(String d) {
    if (d.length < 10) return d;
    return '${d.substring(5, 7)}/${d.substring(8, 10)}';
  }

  Color _lighten(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('yyyy년 MM월 dd일 (E)', 'ko_KR').format(DateTime.now());

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [

          // ── 날짜 배너 카드
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3949AB), Color(0xFF5C6BC0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3949AB).withOpacity(0.30),
                  blurRadius: 16, offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Stack(children: [
              Positioned(
                right: -20, top: -20,
                child: Container(width: 90, height: 90,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.08))),
              ),
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.today_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(today,
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(
                      context.tr({'ko': '실시간 휴가 현황', 'en': 'Realtime Leave Status', 'vi': 'Tinh trang nghi phep', 'uz': "Ta'til holati", 'km': 'ស្ថានភាព휴가ក្នុងពេលវេលាពិត'}),
                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ]),
                ),
                // 오늘 휴가자 수 배지
                if (onLeaveToday.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('${onLeaveToday.length}',
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                      Text(context.tr({'ko': '명 휴가', 'en': 'on leave', 'vi': 'nghi', 'uz': 'ta\'tilda', 'km': 'នាក់휴가'}),
                          style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 10, fontWeight: FontWeight.w700)),
                    ]),
                  ),
              ]),
            ]),
          ),
          const SizedBox(height: 24),

          // ── 오늘 휴가 중 섹션
          _SectionHeader(
            icon: Icons.flight_takeoff_rounded,
            label: context.tr(AppStrings.leaveOnToday),
            count: onLeaveToday.length,
            color: Colors.indigo,
          ),
          const SizedBox(height: 12),
          if (onLeaveToday.isEmpty)
            _EmptyCard(
              icon: Icons.check_circle_outline_rounded,
              color: Colors.green,
              message: context.tr(AppStrings.leaveOnTodayEmpty),
            )
          else
            ...onLeaveToday.map((e) => _LeaveCard(
              item: e,
              isToday: true,
              deptLabel: _deptLabel(context, e['dept_category'] as String? ?? ''),
              typeLabel: _leaveTypeLabel(context, e['leave_type'] as String? ?? 'ANNUAL'),
              typeColor: _leaveTypeColor(e['leave_type'] as String? ?? 'ANNUAL'),
              typeIcon:  _leaveTypeIcon(e['leave_type'] as String? ?? 'ANNUAL'),
              subLabel:  _daysRemaining(context, e['end_date'] as String? ?? ''),
              fmtDate:   _fmtDate,
              lighten:   _lighten,
            )),

          const SizedBox(height: 28),

          // ── 예정된 휴가 섹션
          _SectionHeader(
            icon: Icons.event_rounded,
            label: context.tr(AppStrings.leaveUpcomingCount).replaceAll('{n}', '${upcomingLeaves.length}'),
            count: upcomingLeaves.length,
            color: Colors.orange,
          ),
          const SizedBox(height: 12),
          if (upcomingLeaves.isEmpty)
            _EmptyCard(
              icon: Icons.event_busy_rounded,
              color: Colors.grey,
              message: context.tr(AppStrings.leaveUpcomingEmpty),
            )
          else
            ...upcomingLeaves.map((e) => _LeaveCard(
              item: e,
              isToday: false,
              deptLabel: _deptLabel(context, e['dept_category'] as String? ?? ''),
              typeLabel: _leaveTypeLabel(context, e['leave_type'] as String? ?? 'ANNUAL'),
              typeColor: _leaveTypeColor(e['leave_type'] as String? ?? 'ANNUAL'),
              typeIcon:  _leaveTypeIcon(e['leave_type'] as String? ?? 'ANNUAL'),
              subLabel:  _daysUntil(context, e['start_date'] as String? ?? ''),
              fmtDate:   _fmtDate,
              lighten:   _lighten,
            )),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════
// 섹션 헤더
// ══════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;

  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              HSLColor.fromColor(color).withLightness(
                  (HSLColor.fromColor(color).lightness + 0.15).clamp(0.0, 1.0)).toColor(),
              color,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: color.withOpacity(0.28), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
      const SizedBox(width: 10),
      Text(
        label,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF1A1D2E)),
      ),
      const SizedBox(width: 8),
      if (count > 0)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('$count',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: color)),
        ),
    ]);
  }
}

// ══════════════════════════════════════════
// 빈 상태 카드
// ══════════════════════════════════════════

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;

  const _EmptyCard({required this.icon, required this.color, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 30, color: color.withOpacity(0.5)),
        ),
        const SizedBox(height: 12),
        Text(message,
            style: TextStyle(
                color: Colors.black.withOpacity(0.35),
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ══════════════════════════════════════════
// 휴가 카드
// ══════════════════════════════════════════

class _LeaveCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isToday;
  final String deptLabel, typeLabel, subLabel;
  final Color typeColor;
  final IconData typeIcon;
  final String Function(String) fmtDate;
  final Color Function(Color, double) lighten;

  const _LeaveCard({
    required this.item,
    required this.isToday,
    required this.deptLabel,
    required this.typeLabel,
    required this.typeColor,
    required this.typeIcon,
    required this.subLabel,
    required this.fmtDate,
    required this.lighten,
  });

  @override
  Widget build(BuildContext context) {
    final fullName  = item['full_name']  as String? ?? '-';
    final startDate = item['start_date'] as String? ?? '';
    final endDate   = item['end_date']   as String? ?? '';
    final days      = (item['leave_days'] as num?)?.toDouble() ?? 0;
    final daysStr   = days % 1 == 0 ? '${days.toInt()}일' : '${days}일';
    final dateStr   = startDate == endDate
        ? fmtDate(startDate)
        : '${fmtDate(startDate)} ~ ${fmtDate(endDate)}';

    // 상태 색상 (오늘 휴가 중 vs 예정)
    final accentColor = isToday ? Colors.indigo : Colors.orange;
    final lighter     = lighten(typeColor, 0.18);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: typeColor.withOpacity(0.12),
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
          // ── 그라디언트 원형 아이콘
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [lighter, typeColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: typeColor.withOpacity(0.30),
                  blurRadius: 10, offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              isToday ? Icons.flight_takeoff_rounded : typeIcon,
              color: Colors.white, size: 22,
            ),
          ),
          const SizedBox(width: 13),
          // ── 이름 + 정보
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(fullName,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w900,
                        color: Color(0xFF1A1D2E))),
                const SizedBox(width: 8),
                // 타입 뱃지
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: typeColor.withOpacity(0.2)),
                  ),
                  child: Text(typeLabel,
                      style: TextStyle(
                          color: typeColor, fontSize: 10, fontWeight: FontWeight.w800)),
                ),
              ]),
              const SizedBox(height: 4),
              Text(
                '$deptLabel  ·  $dateStr  ($daysStr)',
                style: TextStyle(
                    fontSize: 12, color: Colors.black.withOpacity(0.42),
                    fontWeight: FontWeight.w500),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          // ── D-day / 날짜 뱃지
          if (subLabel.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    lighten(accentColor, 0.15),
                    accentColor,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withOpacity(0.25),
                    blurRadius: 8, offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Text(subLabel,
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w900,
                      color: Colors.white)),
            ),
        ]),
      ),
    );
  }
}