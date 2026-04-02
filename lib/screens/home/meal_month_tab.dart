// meal_month_tab.dart — 월별 요약 탭

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'meal_report_models.dart';

class MealMonthTab extends StatelessWidget {
  final int selectedYear, selectedMonth;
  final List<Map<String, dynamic>> allProfiles;
  final List<String> depts;
  final List<DayStat> dayStats;
  final int monthEating, monthNotEating, monthNoReply, monthTotalSlots;
  final String today;
  final void Function(int year, int month) onMonthChanged;
  final VoidCallback onRefresh;

  const MealMonthTab({
    Key? key,
    required this.selectedYear, required this.selectedMonth,
    required this.allProfiles, required this.depts,
    required this.dayStats,
    required this.monthEating, required this.monthNotEating,
    required this.monthNoReply, required this.monthTotalSlots,
    required this.today,
    required this.onMonthChanged, required this.onRefresh,
  }) : super(key: key);

  // ── 마감 헬퍼 ──────────────────────────────
  static String get _todayStr =>
      DateFormat('yyyy-MM-dd').format(DateTime.now());
  static int get _nowHour => DateTime.now().hour;

  /// 해당 날짜+끼니의 마감이 지났는지
  static bool _isDue(String date, String mealType) {
    final t = _todayStr;
    if (date.compareTo(t) > 0) return false; // 미래
    if (date.compareTo(t) < 0) return true;  // 과거
    // 오늘
    return mealType == 'LUNCH' ? _nowHour >= 10 : _nowHour >= 15;
  }

  /// 해당 날짜의 유효 슬롯 수 (0~2)
  static int _dueSlots(String date) {
    final t = _todayStr;
    if (date.compareTo(t) > 0) return 0;
    if (date.compareTo(t) < 0) return 2;
    return (_nowHour >= 10 ? 1 : 0) + (_nowHour >= 15 ? 1 : 0);
  }

  @override
  Widget build(BuildContext context) {
    // ── 유효 슬롯 기반 재계산 (미래·미마감 제외)
    int effectiveEating = 0, effectiveNotEating = 0;
    for (final day in dayStats) {
      if (_isDue(day.date, 'LUNCH')) {
        effectiveEating    += day.lunch.eating;
        effectiveNotEating += day.lunch.notEating;
      }
      if (_isDue(day.date, 'DINNER')) {
        effectiveEating    += day.dinner.eating;
        effectiveNotEating += day.dinner.notEating;
      }
    }
    final effectiveSlots = dayStats.fold(
        0, (sum, day) => sum + _dueSlots(day.date));
    final totalEffective   = effectiveSlots * allProfiles.length;
    final effectiveNoReply =
        (totalEffective - effectiveEating - effectiveNotEating)
            .clamp(0, 999999);
    final rate = totalEffective > 0
        ? (effectiveEating + effectiveNotEating) / totalEffective
        : 0.0;

    final lastDay = dayStats.length;

    final deptMonthStats = depts.map((dept) {
      final members = allProfiles
          .where((p) => p['dept_category'] == dept).length;
      int eating = 0, notEating = 0;
      for (final day in dayStats) {
        eating    += (day.lunchByDept[dept]?.eating    ?? 0) +
                     (day.dinnerByDept[dept]?.eating   ?? 0);
        notEating += (day.lunchByDept[dept]?.notEating ?? 0) +
                     (day.dinnerByDept[dept]?.notEating ?? 0);
      }
      // 유효 슬롯 기반 totalSlots
      final totalSlots = dayStats.fold(
          0, (sum, day) => sum + _dueSlots(day.date)) * members;
      return DeptMealStat(
        dept: dept, members: members,
        eating: eating, notEating: notEating,
        noReply: (totalSlots - eating - notEating).clamp(0, 999999),
      );
    }).toList();

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: mrPrimary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        children: [
          // 연월 필터
          Row(children: [
            mrDropBtn<int>(value: selectedYear,
                items: List.generate(3, (i) => DateTime.now().year - i),
                label: (y) => '$y년',
                onChanged: (v) => onMonthChanged(v!, selectedMonth)),
            const SizedBox(width: 8),
            mrDropBtn<int>(value: selectedMonth,
                items: List.generate(12, (i) => i + 1),
                label: (m) => '$m월',
                onChanged: (v) => onMonthChanged(selectedYear, v!)),
          ]),
          const SizedBox(height: 20),

          // 전체 4칸 (유효 슬롯 기반)
          Row(children: [
            mrSumCard("식사", "$effectiveEating", mrOrange,
                Icons.restaurant_rounded),
            const SizedBox(width: 8),
            mrSumCard("불참", "$effectiveNotEating", mrSub,
                Icons.do_not_disturb_alt_rounded),
            const SizedBox(width: 8),
            mrSumCard("미응답", "$effectiveNoReply", mrRed,
                Icons.help_outline_rounded),
            const SizedBox(width: 8),
            mrSumCard("참여율",
                "${(rate * 100).toStringAsFixed(1)}%",
                mrTeal, Icons.pie_chart_rounded),
          ]),
          const SizedBox(height: 16),

          _buildDeptMonthCard(deptMonthStats, lastDay),
          const SizedBox(height: 16),

          const Row(children: [
            Text("일별 상세",
                style: TextStyle(fontSize: 15,
                    fontWeight: FontWeight.w900, color: mrText)),
            SizedBox(width: 8),
            Text("최근순 · 탭해서 부서별 확인",
                style: TextStyle(fontSize: 11, color: mrSub)),
          ]),
          const SizedBox(height: 12),
          _buildDayList(context),
        ],
      ),
    );
  }

  Widget _buildDeptMonthCard(
      List<DeptMealStat> deptMonthStats, int lastDay) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
              color: mrPrimary.withOpacity(0.06),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18))),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                  color: mrPrimary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.bar_chart_rounded,
                  color: mrPrimary, size: 16)),
            const SizedBox(width: 10),
            const Text("부서별 월간 현황",
                style: TextStyle(fontSize: 15,
                    fontWeight: FontWeight.w900, color: mrPrimary)),
            const Spacer(),
            Text("$selectedYear.$selectedMonth",
                style: const TextStyle(fontSize: 12, color: mrSub)),
          ]),
        ),
        Divider(height: 1, color: Colors.black.withOpacity(0.05)),
        ...deptMonthStats.asMap().entries.map((entry) {
          final i = entry.key; final s = entry.value;
          final dc = mrDeptColor(s.dept);
          // 유효 슬롯 기반 비율
          final effSlots = dayStats.fold(
              0, (sum, day) => sum + _dueSlots(day.date)) * s.members;
          final r2  = effSlots > 0
              ? (s.eating + s.notEating) / effSlots : 0.0;
          final rc2 = mrRateColor(r2);
          return Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 13),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                        color: dc.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text(mrDeptLabel(s.dept),
                        style: TextStyle(fontSize: 12,
                            fontWeight: FontWeight.w800, color: dc)),
                  ),
                  const SizedBox(width: 8),
                  Text("${s.members}명",
                      style: const TextStyle(
                          fontSize: 12, color: mrSub)),
                  const Spacer(),
                  Text("${(r2 * 100).toStringAsFixed(1)}%",
                      style: TextStyle(fontSize: 16,
                          fontWeight: FontWeight.w900, color: rc2)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  mrChip("식사 ${s.eating}", mrOrange),
                  const SizedBox(width: 6),
                  mrChip("불참 ${s.notEating}", mrSub),
                  if (s.noReply > 0) ...[
                    const SizedBox(width: 6),
                    mrChip("미응답 ${s.noReply}", mrRed),
                  ],
                ]),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: r2.clamp(0.0, 1.0), minHeight: 6,
                    backgroundColor: Colors.black.withOpacity(0.06),
                    valueColor: AlwaysStoppedAnimation(rc2),
                  ),
                ),
              ]),
            ),
            if (i < deptMonthStats.length - 1)
              Divider(height: 1, indent: 16, endIndent: 16,
                  color: Colors.black.withOpacity(0.05)),
          ]);
        }),
        const SizedBox(height: 4),
      ]),
    );
  }

  Widget _buildDayList(BuildContext context) {
    return Column(children: dayStats.reversed.map((day) {
      final isToday    = day.date == today;
      final isFuture   = day.date.compareTo(_todayStr) > 0;
      final parts      = day.date.split('-');
      final dd         = int.parse(parts[2]);
      final weekday    = mrWeekdayStr(
          DateTime(int.parse(parts[0]), int.parse(parts[1]), dd).weekday);
      final hasAnyData = day.eating > 0 || day.notEating > 0;

      // 미래이거나 아직 마감 안 된 경우 미응답 표시 안 함
      final showLunchNoReply  = _isDue(day.date, 'LUNCH');
      final showDinnerNoReply = _isDue(day.date, 'DINNER');

      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isToday
              ? Border.all(color: mrPrimary.withOpacity(0.4), width: 1.5)
              : Border.all(color: Colors.transparent),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Theme(
          data: Theme.of(context)
              .copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            childrenPadding:
                const EdgeInsets.fromLTRB(12, 0, 12, 12),
            initiallyExpanded: isToday,
            title: Row(children: [
              Container(
                width: 44,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                    color: isToday ? mrPrimary : mrBg,
                    borderRadius: BorderRadius.circular(10)),
                child: Column(children: [
                  Text("$dd",
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w900,
                          color: isToday ? Colors.white : mrText)),
                  Text(weekday,
                      style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w600,
                          color: isToday
                              ? Colors.white.withOpacity(0.8)
                              : mrSub)),
                ]),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: isFuture
                    // 미래: 예정 표시
                    ? Text("예정",
                        style: TextStyle(
                            fontSize: 12, color: mrSub.withOpacity(0.5)))
                    : !hasAnyData && (showLunchNoReply || showDinnerNoReply)
                        // 오늘이고 마감됐는데 아무 데이터 없음
                        ? Row(children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                  color: mrRed.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(6)),
                              child: Text("전원 미응답",
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: mrRed.withOpacity(0.7))),
                            ),
                            const SizedBox(width: 8),
                            Text("${day.noReply}명",
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: mrRed.withOpacity(0.6))),
                          ])
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _mealRowChip("중식", day.lunch, mrPrimary,
                                  showNoReply: showLunchNoReply),
                              const SizedBox(height: 4),
                              _mealRowChip("석식", day.dinner, mrTeal,
                                  showNoReply: showDinnerNoReply),
                            ]),
              ),
            ]),
            children: [
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                    color: mrBg,
                    borderRadius: BorderRadius.circular(12)),
                child: Column(children: [
                  _mealDeptSection(
                      "🍱 중식", day.lunchByDept, mrPrimary,
                      showNoReply: showLunchNoReply),
                  const Divider(height: 1, indent: 12, endIndent: 12),
                  _mealDeptSection(
                      "🍽 석식", day.dinnerByDept, mrTeal,
                      showNoReply: showDinnerNoReply),
                ]),
              ),
            ],
          ),
        ),
      );
    }).toList());
  }

  Widget _mealRowChip(String label, MealStat s, Color color,
      {bool showNoReply = true}) {
    if (s.eating == 0 && s.notEating == 0) {
      return Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(5)),
          child: Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ),
        const SizedBox(width: 6),
        Text(showNoReply ? "미집계" : "-",
            style: TextStyle(fontSize: 11, color: mrSub.withOpacity(0.6))),
      ]);
    }
    final rateColor = mrRateColor(s.rate);
    return Row(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(5)),
        child: Text(label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      ),
      const SizedBox(width: 8),
      mrTiny("${s.eating}식", mrOrange), const SizedBox(width: 4),
      mrTiny("${s.notEating}불", mrSub),
      if (showNoReply && s.noReply > 0) ...[
        const SizedBox(width: 4),
        mrTiny("${s.noReply}무", mrRed),
      ],
      const Spacer(),
      Text("${(s.rate * 100).toStringAsFixed(0)}%",
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w800, color: rateColor)),
    ]);
  }

  Widget _mealDeptSection(
      String title, Map<String, MealStat> byDept, Color color,
      {bool showNoReply = true}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 8),
        ...byDept.entries.map((e) {
          final dept = e.key; final s = e.value;
          final dc = mrDeptColor(dept);
          if (s.members == 0) return const SizedBox();
          final rc = mrRateColor(s.rate);
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Container(
                width: 58,
                padding: const EdgeInsets.symmetric(
                    horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                    color: dc.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(5)),
                child: Text(mrDeptLabel(dept),
                    style: TextStyle(fontSize: 10,
                        fontWeight: FontWeight.w700, color: dc),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center),
              ),
              const SizedBox(width: 8),
              Text("${s.eating}식",
                  style: const TextStyle(
                      fontSize: 12, color: mrOrange,
                      fontWeight: FontWeight.w700)),
              const SizedBox(width: 6),
              Text("${s.notEating}불",
                  style: const TextStyle(fontSize: 12, color: mrSub)),
              if (showNoReply && s.noReply > 0) ...[
                const SizedBox(width: 6),
                Text("${s.noReply}무",
                    style: const TextStyle(
                        fontSize: 12, color: mrRed,
                        fontWeight: FontWeight.w700)),
              ],
              const Spacer(),
              SizedBox(
                width: 60,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: s.rate.clamp(0.0, 1.0), minHeight: 5,
                    backgroundColor: Colors.black.withOpacity(0.06),
                    valueColor: AlwaysStoppedAnimation(rc),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 32,
                child: Text("${(s.rate * 100).toStringAsFixed(0)}%",
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: rc),
                    textAlign: TextAlign.right),
              ),
            ]),
          );
        }),
      ]),
    );
  }
}