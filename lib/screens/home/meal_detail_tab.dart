// meal_detail_tab.dart — 상세 현황 탭 (부서별 접기/펼치기 + 개인 식사 기록)

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'meal_report_models.dart';

class MealDetailTab extends StatefulWidget {
  final int selectedYear, selectedMonth;
  final List<Map<String, dynamic>> allProfiles;
  final List<Map<String, dynamic>> allMonthlyRaw;
  final List<String> depts;
  final List<DayStat> dayStats;
  final void Function(int year, int month) onMonthChanged;
  final VoidCallback onRefresh;

  const MealDetailTab({
    Key? key,
    required this.selectedYear, required this.selectedMonth,
    required this.allProfiles, required this.allMonthlyRaw,
    required this.depts, required this.dayStats,
    required this.onMonthChanged, required this.onRefresh,
  }) : super(key: key);

  @override
  State<MealDetailTab> createState() => _MealDetailTabState();
}

class _MealDetailTabState extends State<MealDetailTab> {
  // 부서별 펼침 상태 (기본 모두 펼침)
  late Map<String, bool> _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = {for (final d in widget.depts) d: true};
  }

  @override
  void didUpdateWidget(MealDetailTab old) {
    super.didUpdateWidget(old);
    // 새 부서 생기면 기본 펼침
    for (final d in widget.depts) {
      _expanded.putIfAbsent(d, () => true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // 필터 바
      Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          mrDropBtn<int>(value: widget.selectedYear,
              items: List.generate(3, (i) => DateTime.now().year - i),
              label: (y) => '$y년',
              onChanged: (v) => widget.onMonthChanged(v!, widget.selectedMonth)),
          const SizedBox(width: 8),
          mrDropBtn<int>(value: widget.selectedMonth,
              items: List.generate(12, (i) => i + 1),
              label: (m) => '$m월',
              onChanged: (v) => widget.onMonthChanged(widget.selectedYear, v!)),
          const Spacer(),
          // 전체 펼침/접기 토글
          TextButton.icon(
            onPressed: () {
              final allExpanded = _expanded.values.every((v) => v);
              setState(() => _expanded.updateAll((_, __) => !allExpanded));
            },
            icon: Icon(
              _expanded.values.every((v) => v)
                  ? Icons.unfold_less_rounded : Icons.unfold_more_rounded,
              size: 16, color: mrPrimary,
            ),
            label: Text(
              _expanded.values.every((v) => v) ? "모두 접기" : "모두 펼치기",
              style: const TextStyle(fontSize: 12, color: mrPrimary, fontWeight: FontWeight.w700),
            ),
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
          ),
        ]),
      ),
      Divider(height: 1, color: const Color(0xFFF0F2F8)),

      Expanded(
        child: widget.allProfiles.isEmpty
            ? Center(child: Text("${widget.selectedYear}년 ${widget.selectedMonth}월 데이터 없음",
                style: const TextStyle(color: mrSub)))
            : RefreshIndicator(
                onRefresh: () async => widget.onRefresh(),
                color: mrPrimary,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                  children: widget.depts.map((dept) => _buildDeptCard(dept)).toList(),
                ),
              ),
      ),
    ]);
  }

  Widget _buildDeptCard(String dept) {
    final dc       = mrDeptColor(dept);
    final profiles = widget.allProfiles
        .where((p) => p['dept_category'] == dept)
        .toList();
    final isOpen = _expanded[dept] ?? true;

    // 부서 전체 집계 (미리 계산)
    int deptTotalEat = 0, deptTotalNo = 0;
    for (final p in profiles) {
      final userId = p['id'] as String;
      final myRows = widget.allMonthlyRaw.where((r) => r['user_id'] == userId).toList();
      deptTotalEat += myRows.where((r) => r['is_eating'] == true).length;
      deptTotalNo  += myRows.where((r) => r['is_eating'] == false).length;
    }
    final deptSlots = profiles.length * widget.dayStats.length * 2;
    final deptRate  = deptSlots > 0 ? (deptTotalEat + deptTotalNo) / deptSlots : 0.0;
    final deptRc    = mrRateColor(deptRate);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        // ── 부서 헤더 (탭하면 접기/펼치기)
        InkWell(
          onTap: () => setState(() => _expanded[dept] = !isOpen),
          borderRadius: BorderRadius.vertical(
              top: const Radius.circular(18),
              bottom: isOpen ? Radius.zero : const Radius.circular(18)),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
                color: dc.withOpacity(0.06),
                borderRadius: BorderRadius.vertical(
                    top: const Radius.circular(18),
                    bottom: isOpen ? Radius.zero : const Radius.circular(18))),
            child: Row(children: [
              Container(padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(color: dc.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.group_rounded, color: dc, size: 16)),
              const SizedBox(width: 10),
              Text(mrDeptLabel(dept), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: dc)),
              const SizedBox(width: 8),
              Text("${profiles.length}명", style: TextStyle(fontSize: 12, color: dc.withOpacity(0.6))),
              const Spacer(),
              // 부서 참여율
              Text("${(deptRate * 100).toStringAsFixed(1)}%",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: deptRc)),
              const SizedBox(width: 8),
              AnimatedRotation(
                turns: isOpen ? 0 : -0.25,
                duration: const Duration(milliseconds: 200),
                child: Icon(Icons.keyboard_arrow_down_rounded, color: dc, size: 22),
              ),
            ]),
          ),
        ),

        // ── 개인별 목록 (접히면 사라짐)
        AnimatedCrossFade(
          firstChild: Column(children: [
            Divider(height: 1, color: Colors.black.withOpacity(0.05)),
            ...profiles.asMap().entries.map((entry) {
              final i       = entry.key;
              final profile = entry.value;
              return _buildPersonRow(context, profile, i == profiles.length - 1);
            }),
            const SizedBox(height: 4),
          ]),
          secondChild: const SizedBox(width: double.infinity),
          crossFadeState: isOpen ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          duration: const Duration(milliseconds: 220),
        ),
      ]),
    );
  }

  Widget _buildPersonRow(BuildContext context, Map<String, dynamic> profile, bool isLast) {
    final userId    = profile['id'] as String;
    final name      = profile['full_name'] as String? ?? '-';
    final dept      = profile['dept_category'] as String? ?? '';
    final dc        = mrDeptColor(dept);
    final myRows    = widget.allMonthlyRaw.where((r) => r['user_id'] == userId).toList();
    final lunchEat  = myRows.where((r) => r['meal_type'] == 'LUNCH'  && r['is_eating'] == true).length;
    final lunchNo   = myRows.where((r) => r['meal_type'] == 'LUNCH'  && r['is_eating'] == false).length;
    final dinnerEat = myRows.where((r) => r['meal_type'] == 'DINNER' && r['is_eating'] == true).length;
    final dinnerNo  = myRows.where((r) => r['meal_type'] == 'DINNER' && r['is_eating'] == false).length;
    final totalSlots = widget.dayStats.length * 2;
    final responded  = lunchEat + lunchNo + dinnerEat + dinnerNo;
    final noReply    = (totalSlots - responded).clamp(0, 9999);
    final rate       = totalSlots > 0 ? responded / totalSlots : 0.0;
    final rc         = mrRateColor(rate);

    return Column(children: [
      InkWell(
        onTap: () => _showPersonDetail(context, profile, myRows),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(radius: 16, backgroundColor: dc.withOpacity(0.1),
                  child: Text(name.isNotEmpty ? name[0] : '?',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: dc))),
              const SizedBox(width: 10),
              Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: mrText)),
              const Spacer(),
              Text("${(rate * 100).toStringAsFixed(0)}%",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: rc)),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: mrSub, size: 18),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              _mealBadge("🌞 점심", lunchEat, lunchNo, mrOrange),
              const SizedBox(width: 8),
              _mealBadge("🌙 저녁", dinnerEat, dinnerNo, mrTeal),
              const Spacer(),
              if (noReply > 0) mrTiny("미응답 $noReply", mrRed),
            ]),
            const SizedBox(height: 8),
            ClipRRect(borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: rate.clamp(0.0, 1.0), minHeight: 4,
                    backgroundColor: Colors.black.withOpacity(0.06), valueColor: AlwaysStoppedAnimation(rc))),
          ]),
        ),
      ),
      if (!isLast) Divider(height: 1, indent: 16, endIndent: 16, color: Colors.black.withOpacity(0.04)),
    ]);
  }

  // ── 개인 식사 기록 바텀시트
  void _showPersonDetail(BuildContext context, Map<String, dynamic> profile,
      List<Map<String, dynamic>> myRows) {
    final name = profile['full_name'] as String? ?? '-';
    final dept = profile['dept_category'] as String? ?? '';
    final dc   = mrDeptColor(dept);

    // 날짜별로 그룹
    final byDate = <String, Map<String, dynamic>>{};
    for (final day in widget.dayStats) {
      final lunchRow  = myRows.firstWhere(
          (r) => r['meal_date'] == day.date && r['meal_type'] == 'LUNCH',
          orElse: () => {});
      final dinnerRow = myRows.firstWhere(
          (r) => r['meal_date'] == day.date && r['meal_type'] == 'DINNER',
          orElse: () => {});
      byDate[day.date] = {'lunch': lunchRow, 'dinner': dinnerRow};
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: Column(children: [
            // 핸들
            Padding(padding: const EdgeInsets.only(top: 14),
                child: Center(child: Container(width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))))),
            // 헤더
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(children: [
                CircleAvatar(radius: 22, backgroundColor: dc.withOpacity(0.1),
                    child: Text(name.isNotEmpty ? name[0] : '?',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: dc))),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: mrText)),
                  const SizedBox(height: 2),
                  Row(children: [
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: dc.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                        child: Text(mrDeptLabel(dept), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: dc))),
                    const SizedBox(width: 6),
                    Text("${widget.selectedYear}년 ${widget.selectedMonth}월",
                        style: const TextStyle(fontSize: 11, color: mrSub)),
                  ]),
                ]),
              ]),
            ),
            Divider(height: 1, color: Colors.black.withOpacity(0.06)),

            // 날짜별 리스트
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: widget.dayStats.reversed.map((day) {
                  final data   = byDate[day.date]!;
                  final lunch  = data['lunch'] as Map<String, dynamic>;
                  final dinner = data['dinner'] as Map<String, dynamic>;
                  final parts   = day.date.split('-');
                  final dd      = int.parse(parts[2]);
                  final weekday = mrWeekdayStr(DateTime(int.parse(parts[0]), int.parse(parts[1]), dd).weekday);
                  final hasAny  = lunch.isNotEmpty || dinner.isNotEmpty;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: hasAny ? Colors.white : mrBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: hasAny
                          ? Colors.black.withOpacity(0.06) : Colors.transparent),
                      boxShadow: hasAny ? [BoxShadow(color: Colors.black.withOpacity(0.03),
                          blurRadius: 6, offset: const Offset(0, 2))] : [],
                    ),
                    child: Row(children: [
                      // 날짜
                      Container(width: 42,
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          decoration: BoxDecoration(
                              color: hasAny ? mrPrimary.withOpacity(0.08) : Colors.transparent,
                              borderRadius: BorderRadius.circular(9)),
                          child: Column(children: [
                            Text("$dd", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900,
                                color: hasAny ? mrPrimary : mrSub.withOpacity(0.4))),
                            Text(weekday, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                                color: hasAny ? mrPrimary.withOpacity(0.6) : mrSub.withOpacity(0.3))),
                          ])),
                      const SizedBox(width: 12),
                      // 점심/저녁
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          _dayMealRow("🌞 점심", lunch, mrOrange),
                          const SizedBox(height: 6),
                          _dayMealRow("🌙 저녁", dinner, mrTeal),
                        ]),
                      ),
                    ]),
                  );
                }).toList(),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _dayMealRow(String label, Map<String, dynamic> row, Color color) {
    if (row.isEmpty) {
      return Row(children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color.withOpacity(0.4))),
        const SizedBox(width: 8),
        Text("미응답", style: TextStyle(fontSize: 11, color: mrSub.withOpacity(0.4))),
      ]);
    }
    final isEating = row['is_eating'] == true;
    return Row(children: [
      Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: isEating ? mrOrange.withOpacity(0.1) : mrSub.withOpacity(0.08),
            borderRadius: BorderRadius.circular(6)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(isEating ? Icons.restaurant_rounded : Icons.do_not_disturb_alt_rounded,
              size: 12, color: isEating ? mrOrange : mrSub),
          const SizedBox(width: 4),
          Text(isEating ? "식사" : "불참",
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                  color: isEating ? mrOrange : mrSub)),
        ]),
      ),
    ]);
  }

  Widget _mealBadge(String label, int eat, int no, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: color.withOpacity(0.07), borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(width: 6),
        mrTiny("${eat}식", mrOrange),
        const SizedBox(width: 3),
        mrTiny("${no}불", mrSub),
      ]),
    );
  }
}