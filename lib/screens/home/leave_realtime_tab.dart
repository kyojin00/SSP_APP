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

  static const Map<String, String> _deptLabels = {
    'MANAGEMENT': 'MANAGEMENT', 'PRODUCTION': 'PRODUCTION',
    'SALES': 'SALES', 'RND': 'RND', 'STEEL': 'STEEL',
    'BOX': 'BOX', 'DELIVERY': 'DELIVERY', 'SSG': 'SSG',
    'CLEANING': 'CLEANING', 'NUTRITION': 'NUTRITION',
  };

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
    'HALF'   => context.tr(AppStrings.leaveTypeHalf),
    'PUBLIC' => context.tr(AppStrings.leaveTypePublic),
    'EVENT'  => context.tr(AppStrings.leaveTypeEvent),
    _        => context.tr(AppStrings.leaveTypeAnnual),
  };

  Color _leaveTypeColor(String type) => switch (type) {
    'HALF'   => const Color(0xFFFF9500),
    'PUBLIC' => const Color(0xFF7C5CDB),
    'EVENT'  => const Color(0xFFFF4D64),
    _        => const Color(0xFF2E6BFF),
  };

  String _daysRemaining(BuildContext context, String endDate) {
    try {
      final end   = DateTime.parse(endDate);
      final today = DateTime.now();
      final diff  = end.difference(DateTime(today.year, today.month, today.day)).inDays;
      if (diff == 0) return context.tr(AppStrings.leaveReturnToday);
      return context.tr(AppStrings.leaveReturnDays).replaceAll('{n}', '${diff + 1}');
    } catch (_) { return ''; }
  }

  String _daysUntil(BuildContext context, String startDate) {
    try {
      final start = DateTime.parse(startDate);
      final today = DateTime.now();
      final diff  = start.difference(DateTime(today.year, today.month, today.day)).inDays;
      if (diff == 1) return context.tr(AppStrings.leaveReturnTomorrow);
      return context.tr(AppStrings.leaveReturnDays).replaceAll('{n}', '$diff');
    } catch (_) { return ''; }
  }

  String _fmtDate(String d) {
    if (d.length < 10) return d;
    return '${d.substring(5, 7)}/${d.substring(8, 10)}';
  }

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('yyyy년 MM월 dd일 (E)', 'ko_KR').format(DateTime.now());

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 날짜 헤더
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: const Color(0xFF2E6BFF).withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              const Icon(Icons.calendar_today_rounded,
                  size: 14, color: Color(0xFF2E6BFF)),
              const SizedBox(width: 8),
              Text(today, style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700,
                  color: Color(0xFF2E6BFF))),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: const Color(0xFF2E6BFF),
                    borderRadius: BorderRadius.circular(8)),
                child: Text(
                  context.tr(AppStrings.leaveOnTodayCount)
                      .replaceAll('{n}', '${onLeaveToday.length}'),
                  style: const TextStyle(
                      color: Colors.white, fontSize: 11,
                      fontWeight: FontWeight.w800)),
              ),
            ]),
          ),

          // 오늘 휴가 중
          attendanceSectionHeader(
            context.tr(AppStrings.leaveOnToday) +
                ' (${onLeaveToday.length}${context.tr(AppStrings.members)})',
            Icons.flight_takeoff_rounded, Colors.indigo),
          const SizedBox(height: 12),
          if (onLeaveToday.isEmpty)
            _emptyState(context, context.tr(AppStrings.leaveOnTodayEmpty),
                Icons.check_circle_outline_rounded, Colors.green)
          else
            ...onLeaveToday.map((e) => _leaveCard(context, e, isToday: true)),

          const SizedBox(height: 28),

          // 예정된 휴가
          attendanceSectionHeader(
            context.tr(AppStrings.leaveUpcomingCount)
                .replaceAll('{n}', '${upcomingLeaves.length}'),
            Icons.event_rounded, Colors.orange),
          const SizedBox(height: 12),
          if (upcomingLeaves.isEmpty)
            _emptyState(context, context.tr(AppStrings.leaveUpcomingEmpty),
                Icons.event_busy_rounded, Colors.grey)
          else
            ...upcomingLeaves.map((e) => _leaveCard(context, e, isToday: false)),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _leaveCard(BuildContext context, Map<String, dynamic> item,
      {required bool isToday}) {
    final leaveType = item['leave_type']    as String? ?? 'ANNUAL';
    final dept      = item['dept_category'] as String? ?? '';
    final startDate = item['start_date']    as String? ?? '';
    final endDate   = item['end_date']      as String? ?? '';
    final days      = (item['leave_days']   as num?)?.toDouble() ?? 0;
    final fullName  = item['full_name']     as String? ?? '-';

    final typeColor = _leaveTypeColor(leaveType);
    final typeLabel = _leaveTypeLabel(context, leaveType);
    final dateStr   = startDate == endDate
        ? _fmtDate(startDate)
        : '${_fmtDate(startDate)} ~ ${_fmtDate(endDate)}';
    final subLabel  = isToday
        ? _daysRemaining(context, endDate)
        : _daysUntil(context, startDate);
    final daysStr   = days % 1 == 0 ? '${days.toInt()}일' : '${days}일';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isToday
                ? Colors.indigo.withOpacity(0.2)
                : Colors.orange.withOpacity(0.2)),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(children: [
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
              color: typeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(13)),
          child: Icon(
              isToday ? Icons.flight_takeoff_rounded : Icons.event_rounded,
              color: typeColor, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(fullName, style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6)),
                child: Text(typeLabel, style: TextStyle(
                    color: typeColor, fontSize: 10,
                    fontWeight: FontWeight.w800)),
              ),
            ]),
            const SizedBox(height: 3),
            Text(
              '${_deptLabel(context, dept)}  ·  $dateStr  ($daysStr)',
              style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.45)),
            ),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: isToday
                ? Colors.indigo.withOpacity(0.1)
                : Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(subLabel, style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w800,
              color: isToday ? Colors.indigo : Colors.orange)),
        ),
      ]),
    );
  }

  Widget _emptyState(BuildContext context, String msg, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(children: [
        Icon(icon, size: 40, color: color.withOpacity(0.4)),
        const SizedBox(height: 10),
        Text(msg, style: TextStyle(
            color: Colors.black.withOpacity(0.35),
            fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}