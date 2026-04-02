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
  late Map<String, bool> _expanded;

  // ── 마감 헬퍼 ──────────────────────────────
  static String get _todayStr =>
      DateFormat('yyyy-MM-dd').format(DateTime.now());
  static int get _nowHour => DateTime.now().hour;

  /// 해당 날짜+끼니의 마감이 지났는지 (미응답 카운트 여부)
  static bool _isDue(String date, String mealType) {
    final t = _todayStr;
    if (date.compareTo(t) > 0) return false; // 미래
    if (date.compareTo(t) < 0) return true;  // 과거
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
  void initState() {
    super.initState();
    _expanded = {for (final d in widget.depts) d: true};
  }

  @override
  void didUpdateWidget(MealDetailTab old) {
    super.didUpdateWidget(old);
    for (final d in widget.depts) {
      _expanded.putIfAbsent(d, () => true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          mrDropBtn<int>(
              value: widget.selectedYear,
              items: List.generate(3, (i) => DateTime.now().year - i),
              label: (y) => '$y년',
              onChanged: (v) =>
                  widget.onMonthChanged(v!, widget.selectedMonth)),
          const SizedBox(width: 8),
          mrDropBtn<int>(
              value: widget.selectedMonth,
              items: List.generate(12, (i) => i + 1),
              label: (m) => '$m월',
              onChanged: (v) =>
                  widget.onMonthChanged(widget.selectedYear, v!)),
          const Spacer(),
          TextButton.icon(
            onPressed: () {
              final allExpanded = _expanded.values.every((v) => v);
              setState(() => _expanded.updateAll((_, __) => !allExpanded));
            },
            icon: Icon(
              _expanded.values.every((v) => v)
                  ? Icons.unfold_less_rounded
                  : Icons.unfold_more_rounded,
              size: 16, color: mrPrimary,
            ),
            label: Text(
              _expanded.values.every((v) => v) ? "모두 접기" : "모두 펼치기",
              style: const TextStyle(
                  fontSize: 12,
                  color: mrPrimary,
                  fontWeight: FontWeight.w700),
            ),
            style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8)),
          ),
        ]),
      ),
      Divider(height: 1, color: const Color(0xFFF0F2F8)),

      Expanded(
        child: widget.allProfiles.isEmpty
            ? Center(
                child: Text(
                    "${widget.selectedYear}년 ${widget.selectedMonth}월 데이터 없음",
                    style: const TextStyle(color: mrSub)))
            : RefreshIndicator(
                onRefresh: () async => widget.onRefresh(),
                color: mrPrimary,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                  children: widget.depts
                      .map((dept) => _buildDeptCard(dept))
                      .toList(),
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

    int deptTotalEat = 0, deptTotalNo = 0;
    for (final p in profiles) {
      final userId = p['id'] as String;
      final myRows = widget.allMonthlyRaw
          .where((r) => r['user_id'] == userId).toList();
      deptTotalEat += myRows.where((r) => r['is_eating'] == true).length;
      deptTotalNo  += myRows.where((r) => r['is_eating'] == false).length;
    }
    // 유효 슬롯 기반
    final effSlots = widget.dayStats.fold(
        0, (sum, day) => sum + _dueSlots(day.date));
    final deptSlots = effSlots * profiles.length;
    final deptRate  = deptSlots > 0
        ? (deptTotalEat + deptTotalNo) / deptSlots : 0.0;
    final deptRc    = mrRateColor(deptRate);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        InkWell(
          onTap: () =>
              setState(() => _expanded[dept] = !isOpen),
          onLongPress: () =>
              _showDeptMealSheet(context, dept, profiles),
          borderRadius: BorderRadius.vertical(
              top: const Radius.circular(18),
              bottom: isOpen ? Radius.zero : const Radius.circular(18)),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
                color: dc.withOpacity(0.06),
                borderRadius: BorderRadius.vertical(
                    top: const Radius.circular(18),
                    bottom: isOpen
                        ? Radius.zero
                        : const Radius.circular(18))),
            child: Row(children: [
              GestureDetector(
                onTap: () =>
                    _showDeptMealSheet(context, dept, profiles),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                      color: dc.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.group_rounded, color: dc, size: 16),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () =>
                    _showDeptMealSheet(context, dept, profiles),
                child: Text(mrDeptLabel(dept),
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: dc)),
              ),
              const SizedBox(width: 8),
              Text("${profiles.length}명",
                  style:
                      TextStyle(fontSize: 12, color: dc.withOpacity(0.6))),
              const Spacer(),
              Text("${(deptRate * 100).toStringAsFixed(1)}%",
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: deptRc)),
              const SizedBox(width: 8),
              AnimatedRotation(
                turns: isOpen ? 0 : -0.25,
                duration: const Duration(milliseconds: 200),
                child: Icon(Icons.keyboard_arrow_down_rounded,
                    color: dc, size: 22),
              ),
            ]),
          ),
        ),

        AnimatedCrossFade(
          firstChild: Column(children: [
            Divider(height: 1, color: Colors.black.withOpacity(0.05)),
            ...profiles.asMap().entries.map((entry) {
              final i       = entry.key;
              final profile = entry.value;
              return _buildPersonRow(
                  context, profile, i == profiles.length - 1);
            }),
            const SizedBox(height: 4),
          ]),
          secondChild: const SizedBox(width: double.infinity),
          crossFadeState: isOpen
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          duration: const Duration(milliseconds: 220),
        ),
      ]),
    );
  }

  void _showDeptMealSheet(BuildContext context, String dept,
      List<Map<String, dynamic>> profiles) {
    final dc        = mrDeptColor(dept);
    final recentDays = widget.dayStats.reversed.toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DeptMealSheet(
        dept: dept, dc: dc,
        profiles: profiles,
        allMonthlyRaw: widget.allMonthlyRaw,
        dayStats: recentDays,
        year: widget.selectedYear,
        month: widget.selectedMonth,
      ),
    );
  }

  Widget _buildPersonRow(BuildContext context,
      Map<String, dynamic> profile, bool isLast) {
    final userId    = profile['id'] as String;
    final name      = profile['full_name'] as String? ?? '-';
    final dept      = profile['dept_category'] as String? ?? '';
    final dc        = mrDeptColor(dept);
    final myRows    = widget.allMonthlyRaw
        .where((r) => r['user_id'] == userId).toList();
    final lunchEat  = myRows.where((r) =>
        r['meal_type'] == 'LUNCH'  && r['is_eating'] == true).length;
    final lunchNo   = myRows.where((r) =>
        r['meal_type'] == 'LUNCH'  && r['is_eating'] == false).length;
    final dinnerEat = myRows.where((r) =>
        r['meal_type'] == 'DINNER' && r['is_eating'] == true).length;
    final dinnerNo  = myRows.where((r) =>
        r['meal_type'] == 'DINNER' && r['is_eating'] == false).length;

    // 유효 슬롯 기반 totalSlots
    final totalSlots = widget.dayStats.fold(
        0, (sum, day) => sum + _dueSlots(day.date));
    final responded  = lunchEat + lunchNo + dinnerEat + dinnerNo;
    final noReply    = (totalSlots - responded).clamp(0, 9999);
    final rate       = totalSlots > 0 ? responded / totalSlots : 0.0;
    final rc         = mrRateColor(rate);

    return Column(children: [
      InkWell(
        onTap: () => _showPersonDetail(context, profile, myRows),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 12),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Row(children: [
              CircleAvatar(
                  radius: 16,
                  backgroundColor: dc.withOpacity(0.1),
                  child: Text(name.isNotEmpty ? name[0] : '?',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: dc))),
              const SizedBox(width: 10),
              Text(name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: mrText)),
              const Spacer(),
              Text("${(rate * 100).toStringAsFixed(0)}%",
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: rc)),
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
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: rate.clamp(0.0, 1.0), minHeight: 4,
                backgroundColor: Colors.black.withOpacity(0.06),
                valueColor: AlwaysStoppedAnimation(rc),
              ),
            ),
          ]),
        ),
      ),
      if (!isLast)
        Divider(height: 1, indent: 16, endIndent: 16,
            color: Colors.black.withOpacity(0.04)),
    ]);
  }

  void _showPersonDetail(BuildContext context,
      Map<String, dynamic> profile,
      List<Map<String, dynamic>> myRows) {
    final name = profile['full_name'] as String? ?? '-';
    final dept = profile['dept_category'] as String? ?? '';
    final dc   = mrDeptColor(dept);

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
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(28))),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Center(child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2)))),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(children: [
                CircleAvatar(
                    radius: 22,
                    backgroundColor: dc.withOpacity(0.1),
                    child: Text(name.isNotEmpty ? name[0] : '?',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: dc))),
                const SizedBox(width: 12),
                Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(name,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: mrText)),
                  const SizedBox(height: 2),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                          color: dc.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6)),
                      child: Text(mrDeptLabel(dept),
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: dc)),
                    ),
                    const SizedBox(width: 6),
                    Text(
                        "${widget.selectedYear}년 ${widget.selectedMonth}월",
                        style: const TextStyle(
                            fontSize: 11, color: mrSub)),
                  ]),
                ]),
              ]),
            ),
            Divider(height: 1, color: Colors.black.withOpacity(0.06)),
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
                  final weekday = mrWeekdayStr(DateTime(
                      int.parse(parts[0]),
                      int.parse(parts[1]), dd).weekday);
                  final hasAny = lunch.isNotEmpty || dinner.isNotEmpty;
                  final isFuture =
                      day.date.compareTo(_todayStr) > 0;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isFuture
                          ? mrBg
                          : hasAny ? Colors.white : mrBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: (!isFuture && hasAny)
                              ? Colors.black.withOpacity(0.06)
                              : Colors.transparent),
                      boxShadow: (!isFuture && hasAny)
                          ? [BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 6,
                              offset: const Offset(0, 2))]
                          : [],
                    ),
                    child: Row(children: [
                      Container(
                        width: 42,
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        decoration: BoxDecoration(
                            color: (!isFuture && hasAny)
                                ? mrPrimary.withOpacity(0.08)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(9)),
                        child: Column(children: [
                          Text("$dd",
                              style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: (!isFuture && hasAny)
                                      ? mrPrimary
                                      : mrSub.withOpacity(0.4))),
                          Text(weekday,
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: (!isFuture && hasAny)
                                      ? mrPrimary.withOpacity(0.6)
                                      : mrSub.withOpacity(0.3))),
                        ]),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          _dayMealRow("🌞 점심", lunch, mrOrange,
                              isDue: _isDue(day.date, 'LUNCH')),
                          const SizedBox(height: 6),
                          _dayMealRow("🌙 저녁", dinner, mrTeal,
                              isDue: _isDue(day.date, 'DINNER')),
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

  Widget _dayMealRow(String label, Map<String, dynamic> row, Color color,
      {bool isDue = true}) {
    if (row.isEmpty) {
      return Row(children: [
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color.withOpacity(isDue ? 0.7 : 0.3))),
        const SizedBox(width: 8),
        Text(isDue ? "미응답" : "-",
            style: TextStyle(
                fontSize: 11,
                color: isDue
                    ? mrSub.withOpacity(0.6)
                    : mrSub.withOpacity(0.3))),
      ]);
    }
    final isEating = row['is_eating'] == true;
    return Row(children: [
      Text(label,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: color)),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: isEating
                ? mrOrange.withOpacity(0.1)
                : mrSub.withOpacity(0.08),
            borderRadius: BorderRadius.circular(6)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(
              isEating
                  ? Icons.restaurant_rounded
                  : Icons.do_not_disturb_alt_rounded,
              size: 12,
              color: isEating ? mrOrange : mrSub),
          const SizedBox(width: 4),
          Text(isEating ? "식사" : "불참",
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isEating ? mrOrange : mrSub)),
        ]),
      ),
    ]);
  }

  Widget _mealBadge(String label, int eat, int no, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(width: 6),
        mrTiny("${eat}식", mrOrange),
        const SizedBox(width: 3),
        mrTiny("${no}불", mrSub),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════
// 부서 식사 현황 바텀시트
// ══════════════════════════════════════════════════════════
class _DeptMealSheet extends StatefulWidget {
  final String dept;
  final Color dc;
  final List<Map<String, dynamic>> profiles;
  final List<Map<String, dynamic>> allMonthlyRaw;
  final List<DayStat> dayStats;
  final int year, month;

  const _DeptMealSheet({
    required this.dept, required this.dc,
    required this.profiles, required this.allMonthlyRaw,
    required this.dayStats,
    required this.year, required this.month,
  });

  @override
  State<_DeptMealSheet> createState() => _DeptMealSheetState();
}

class _DeptMealSheetState extends State<_DeptMealSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late String _selectedDate;

  static String get _todayStr =>
      DateFormat('yyyy-MM-dd').format(DateTime.now());
  static int get _nowHour => DateTime.now().hour;

  static bool _isDue(String date, String mealType) {
    final t = _todayStr;
    if (date.compareTo(t) > 0) return false;
    if (date.compareTo(t) < 0) return true;
    return mealType == 'LUNCH' ? _nowHour >= 10 : _nowHour >= 15;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedDate =
        widget.dayStats.isNotEmpty ? widget.dayStats.first.date : '';
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _getList(String mealType) {
    final due = _isDue(_selectedDate, mealType);
    final eating    = <Map<String, dynamic>>[];
    final notEating = <Map<String, dynamic>>[];
    final noReply   = <Map<String, dynamic>>[];

    for (final p in widget.profiles) {
      final userId = p['id'] as String;
      final row = widget.allMonthlyRaw.firstWhere(
        (r) => r['user_id'] == userId &&
               r['meal_date'] == _selectedDate &&
               r['meal_type'] == mealType,
        orElse: () => {},
      );
      if (row.isEmpty) {
        // 마감 전이면 미응답으로 분류 안 함
        if (due) noReply.add(p);
      } else if (row['is_eating'] == true) {
        eating.add(p);
      } else {
        notEating.add(p);
      }
    }
    return [...eating, ...notEating, ...noReply];
  }

  String _mealStatus(String userId, String mealType) {
    // 마감 전이면 'pending'
    if (!_isDue(_selectedDate, mealType)) return 'pending';
    final row = widget.allMonthlyRaw.firstWhere(
      (r) => r['user_id'] == userId &&
             r['meal_date'] == _selectedDate &&
             r['meal_type'] == mealType,
      orElse: () => {},
    );
    if (row.isEmpty) return 'none';
    return row['is_eating'] == true ? 'eat' : 'no';
  }

  @override
  Widget build(BuildContext context) {
    final dc = widget.dc;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)))),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                    color: dc.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.restaurant_menu_rounded,
                    color: dc, size: 20),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(mrDeptLabel(widget.dept),
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: dc)),
                Text(
                    "${widget.year}년 ${widget.month}월 · ${widget.profiles.length}명",
                    style: const TextStyle(fontSize: 12, color: mrSub)),
              ]),
            ]),
          ),

          // 날짜 선택 칩
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: widget.dayStats.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final day   = widget.dayStats[i];
                final parts = day.date.split('-');
                final dd    = parts[2];
                final dt    = DateTime(int.parse(parts[0]),
                    int.parse(parts[1]), int.parse(parts[2]));
                final wd        = mrWeekdayStr(dt.weekday);
                final isSelected = _selectedDate == day.date;
                final isFuture   =
                    day.date.compareTo(_todayStr) > 0;
                return GestureDetector(
                  onTap: () =>
                      setState(() => _selectedDate = day.date),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? dc
                          : isFuture
                              ? Colors.grey.withOpacity(0.08)
                              : dc.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text("$dd($wd)",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: isSelected
                              ? Colors.white
                              : isFuture
                                  ? Colors.grey
                                  : dc,
                        )),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),

          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: dc.withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                  color: dc, borderRadius: BorderRadius.circular(10)),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: dc,
              labelStyle: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800),
              tabs: const [
                Tab(text: "🌞  점심"),
                Tab(text: "🌙  저녁"),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Divider(height: 1, color: Colors.black.withOpacity(0.05)),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMealList('LUNCH', scrollController),
                _buildMealList('DINNER', scrollController),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildMealList(
      String mealType, ScrollController scrollController) {
    final due  = _isDue(_selectedDate, mealType);
    final list = _getList(mealType);

    final eatCount  = list
        .where((p) => _mealStatus(p['id'], mealType) == 'eat').length;
    final noCount   = list
        .where((p) => _mealStatus(p['id'], mealType) == 'no').length;
    final noneCount = list
        .where((p) => _mealStatus(p['id'], mealType) == 'none').length;

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
      children: [
        // 미래·마감 전 안내
        if (!due)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.07),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              Icon(Icons.schedule_rounded,
                  size: 16, color: Colors.grey[400]),
              const SizedBox(width: 8),
              Text(
                mealType == 'LUNCH'
                    ? "점심 마감(10:00) 전입니다"
                    : "저녁 마감(15:00) 전입니다",
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w600),
              ),
            ]),
          ),

        // 요약 뱃지 (마감 후에만)
        if (due)
          Row(children: [
            _summaryBadge("식사", eatCount, mrOrange),
            const SizedBox(width: 8),
            _summaryBadge("불참", noCount, mrSub),
            const SizedBox(width: 8),
            _summaryBadge("미응답", noneCount, mrRed),
          ]),
        if (due) const SizedBox(height: 12),

        ...list.map((p) {
          final name   = p['full_name'] as String? ?? '-';
          final status = _mealStatus(p['id'] as String, mealType);

          // pending(마감 전)이면 회색으로
          if (status == 'pending') {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.04),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Row(children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor: Colors.grey.withOpacity(0.1),
                  child: Text(name.isNotEmpty ? name[0] : '?',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Colors.grey)),
                ),
                const SizedBox(width: 10),
                Text(name,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: mrText.withOpacity(0.4))),
                const Spacer(),
                Text("-",
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey[400])),
              ]),
            );
          }

          final (icon, label, color, bg) = switch (status) {
            'eat'  => (Icons.restaurant_rounded,
                       "식사", mrOrange, mrOrange.withOpacity(0.08)),
            'no'   => (Icons.do_not_disturb_alt_rounded,
                       "불참", mrSub,    mrSub.withOpacity(0.07)),
            _      => (Icons.help_outline_rounded,
                       "미응답", mrRed,  mrRed.withOpacity(0.06)),
          };

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: bg, borderRadius: BorderRadius.circular(13),
            ),
            child: Row(children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: widget.dc.withOpacity(0.1),
                child: Text(name.isNotEmpty ? name[0] : '?',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: widget.dc)),
              ),
              const SizedBox(width: 10),
              Text(name,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: mrText)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, size: 13, color: color),
                  const SizedBox(width: 4),
                  Text(label,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: color)),
                ]),
              ),
            ]),
          );
        }),
      ],
    );
  }

  Widget _summaryBadge(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(width: 6),
        Text("$count명",
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w900, color: color)),
      ]),
    );
  }
}