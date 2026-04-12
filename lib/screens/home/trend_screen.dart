// trend_screen.dart — 동향 분석 페이지

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

// ══════════════════════════════════════════
// 데이터 모델
// ══════════════════════════════════════════

class _DailyMeal {
  final DateTime date;
  final int lunch;
  final int dinner;
  const _DailyMeal({required this.date, required this.lunch, required this.dinner});
}

class _DeptMeal {
  final String dept;
  final int total;
  final int headcount;
  const _DeptMeal({required this.dept, required this.total, required this.headcount});

  double get rate => headcount > 0 ? (total / headcount).clamp(0.0, 100.0) : 0.0;
  // elapsedDays: 현재까지 실제 경과한 날수 기준 퍼센트
  double rateOf(int elapsedDays) => headcount > 0 && elapsedDays > 0
      ? ((total / (headcount * elapsedDays * 2)) * 100).clamp(0.0, 100.0)
      : 0.0;
}

class _DailyAttendance {
  final DateTime date;
  final int count;
  const _DailyAttendance({required this.date, required this.count});
}

enum _Period { today, week, month }

// ══════════════════════════════════════════
// TrendScreen
// ══════════════════════════════════════════

class TrendScreen extends StatefulWidget {
  final bool isAdmin;
  const TrendScreen({Key? key, required this.isAdmin}) : super(key: key);

  @override
  State<TrendScreen> createState() => _TrendScreenState();
}

class _TrendScreenState extends State<TrendScreen>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;

  static const _excludedDepts = {'NUTRITION'};
  static const _primary  = Color(0xFF2E6BFF);
  static const _primary2 = Color(0xFF1A3FA3);

  _Period _period         = _Period.week;
  bool    _loading        = true;
  bool    _deptShowPercent = true;

  List<_DailyMeal>        _mealTrend   = [];
  List<_DeptMeal>         _deptMeal    = [];
  List<_DailyAttendance>  _attendTrend = [];
  int _deptPeriodDays  = 7; // ← 전체 기간 일수
  int _deptElapsedDays = 1; // ← 오늘까지 실제 경과 일수 (퍼센트 계산용)

  int _totalLunch     = 0;
  int _totalDinner    = 0;
  int _totalEmployees = 0;

  late final AnimationController _animCtrl;
  late final Animation<double>   _fadeAnim;

  Color _lighten(Color c, double a) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + a).clamp(0.0, 1.0)).toColor();
  }

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _loadData();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  DateTimeRange get _range {
    final now = DateTime.now();
    if (_period == _Period.today) {
      final today = DateTime(now.year, now.month, now.day);
      return DateTimeRange(start: today, end: today);
    } else if (_period == _Period.week) {
      final mon = now.subtract(Duration(days: now.weekday - 1));
      final sun = mon.add(const Duration(days: 6));
      return DateTimeRange(
        start: DateTime(mon.year, mon.month, mon.day),
        end:   DateTime(sun.year, sun.month, sun.day),
      );
    } else {
      final lastDay = DateTime(now.year, now.month + 1, 0);
      return DateTimeRange(
        start: DateTime(now.year, now.month, 1),
        end:   DateTime(lastDay.year, lastDay.month, lastDay.day),
      );
    }
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    _animCtrl.reset();

    final from = DateFormat('yyyy-MM-dd').format(_range.start);
    final to   = DateFormat('yyyy-MM-dd').format(_range.end);
    final now  = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    try {
      final results = await Future.wait([
        supabase.from('meal_requests')
            .select('meal_date, meal_type, user_id')
            .gte('meal_date', from).lte('meal_date', to),
        supabase.from('attendance')
            .select('work_date')
            .gte('work_date', from).lte('work_date', to),
        supabase.from('profiles').select('id, dept_category, role'),
      ]);

      final mealRaw    = results[0] as List;
      final attendRaw  = results[1] as List;
      final profileRaw = results[2] as List;

      // user_id → dept 맵 (영양사만 제외)
      final userDept = <String, String>{};
      for (final p in profileRaw) {
        final dept = p['dept_category'] as String? ?? '';
        if (!_excludedDepts.contains(dept)) {
          userDept[p['id'] as String] = dept;
        }
      }

      // 부서별 headcount
      final deptHeadcount = <String, int>{};
      for (final dept in userDept.values) {
        deptHeadcount[dept] = (deptHeadcount[dept] ?? 0) + 1;
      }
      final empCount = deptHeadcount.values.fold(0, (a, b) => a + b);

      // 영양사 제외 식수만
      final filteredMealRaw = mealRaw.where((r) {
        final uid = r['user_id'] as String?;
        return uid != null && userDept.containsKey(uid);
      }).toList();

      // 일별 식수 집계
      final mealByDate = <String, Map<String, int>>{};
      for (final r in filteredMealRaw) {
        final date = r['meal_date'] as String;
        final type = r['meal_type'] as String? ?? '';
        mealByDate.putIfAbsent(date, () => {'LUNCH': 0, 'DINNER': 0});
        if (type == 'LUNCH')  mealByDate[date]!['LUNCH']  = mealByDate[date]!['LUNCH']!  + 1;
        if (type == 'DINNER') mealByDate[date]!['DINNER'] = mealByDate[date]!['DINNER']! + 1;
      }

      // 날짜 리스트 생성 (주말 제외: month만)
      final days = <_DailyMeal>[];
      var cur = _range.start;
      while (!cur.isAfter(_range.end)) {
        final key = DateFormat('yyyy-MM-dd').format(cur);
        final include = _period == _Period.today ||
            _period == _Period.week ||
            cur.weekday < 6;
        if (include) {
          final m = mealByDate[key];
          days.add(_DailyMeal(
            date:   cur,
            lunch:  m?['LUNCH']  ?? 0,
            dinner: m?['DINNER'] ?? 0,
          ));
        }
        cur = cur.add(const Duration(days: 1));
      }

      // ── 경과 일수 계산 (오늘까지 지난 날 기준)
      // days 중 today 이전(포함)인 것만 카운트
      final elapsedDays = days
          .where((d) => !d.date.isAfter(today))
          .length
          .clamp(1, 999);

      // 부서별 식수
      final deptTotals = <String, int>{};
      for (final r in filteredMealRaw) {
        final uid = r['user_id'] as String?;
        if (uid == null) continue;
        final dept = userDept[uid];
        if (dept == null) continue;
        deptTotals[dept] = (deptTotals[dept] ?? 0) + 1;
      }
      final deptList = deptHeadcount.entries
          .where((e) => e.value > 0)
          .map((e) => _DeptMeal(
                dept:      e.key,
                total:     deptTotals[e.key] ?? 0,
                headcount: e.value,
              ))
          .toList()
        ..sort((a, b) => b.total.compareTo(a.total));

      // 출근 일별 집계
      final attendByDate = <String, int>{};
      for (final a in attendRaw) {
        final key = a['work_date'] as String;
        attendByDate[key] = (attendByDate[key] ?? 0) + 1;
      }
      final attendDays = <_DailyAttendance>[];
      cur = _range.start;
      while (!cur.isAfter(_range.end)) {
        final key = DateFormat('yyyy-MM-dd').format(cur);
        final include = _period == _Period.today ||
            _period == _Period.week ||
            cur.weekday < 6;
        if (include) {
          attendDays.add(_DailyAttendance(
              date: cur, count: attendByDate[key] ?? 0));
        }
        cur = cur.add(const Duration(days: 1));
      }

      if (!mounted) return;
      setState(() {
        _mealTrend       = days;
        _deptMeal        = deptList;
        _attendTrend     = attendDays;
        _totalLunch      = filteredMealRaw.where((r) => r['meal_type'] == 'LUNCH').length;
        _totalDinner     = filteredMealRaw.where((r) => r['meal_type'] == 'DINNER').length;
        _totalEmployees  = empCount;
        _deptPeriodDays  = days.length.clamp(1, 999);
        _deptElapsedDays = elapsedDays; // ← 실제 경과 일수
        _loading         = false;
      });
      _animCtrl.forward();
    } catch (e) {
      debugPrint('TrendScreen 로드 실패: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  // ──────────────────────────────────────────
  // UI
  // ──────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    // 경과일 안내 문구
    String elapsedNote = '';
    if (_period == _Period.week) {
      elapsedNote = '${now.weekday}일 경과';
    } else if (_period == _Period.month) {
      elapsedNote = '${now.day}일 경과';
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F7),
      body: CustomScrollView(
        slivers: [
          // ── 그라디언트 SliverAppBar
          SliverAppBar(
            pinned: true,
            expandedHeight: 100,
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: const Text('동향 분석',
                style: TextStyle(fontWeight: FontWeight.w900,
                    fontSize: 17, color: Colors.white)),
            actions: [
              // 기간 선택 버튼
              Container(
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(12)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _PeriodBtn(label: '오늘',   selected: _period == _Period.today,
                      onTap: () { if (_period != _Period.today) { setState(() => _period = _Period.today); _loadData(); } }),
                  _PeriodBtn(label: '이번주', selected: _period == _Period.week,
                      onTap: () { if (_period != _Period.week)  { setState(() => _period = _Period.week);  _loadData(); } }),
                  _PeriodBtn(label: '이번달', selected: _period == _Period.month,
                      onTap: () { if (_period != _Period.month) { setState(() => _period = _Period.month); _loadData(); } }),
                ]),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_lighten(_primary, 0.18), _primary, _primary2],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(children: [
                  Positioned(right: -30, top: -30, child: Container(
                    width: 130, height: 130,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.06)))),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 62, 20, 0),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle),
                        child: const Icon(Icons.insights_rounded,
                            color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('동향 분석',
                            style: TextStyle(color: Colors.white,
                                fontSize: 14, fontWeight: FontWeight.w900)),
                        if (elapsedNote.isNotEmpty)
                          Text(elapsedNote,
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 11, fontWeight: FontWeight.w600)),
                      ]),
                    ]),
                  ),
                ]),
              ),
            ),
          ),

          // ── 바디
          SliverToBoxAdapter(
            child: _loading
                ? const SizedBox(
                    height: 300,
                    child: Center(child: CircularProgressIndicator(
                        color: _primary)))
                : FadeTransition(
                    opacity: _fadeAnim,
                    child: RefreshIndicator(
                      color: _primary,
                      onRefresh: _loadData,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(14, 18, 14, 48),
                        child: Column(children: [
                          // 요약 카드
                          _summaryCards(),
                          const SizedBox(height: 20),

                          // 일별 식수 추이
                          if (_period != _Period.today) ...[
                            _sectionHeader(Icons.restaurant_rounded,
                                const Color(0xFFFF7A2F), '일별 식수 현황'),
                            const SizedBox(height: 12),
                            _mealLineChart(),
                            const SizedBox(height: 24),
                          ],

                          // 부서별 식수 현황
                          Row(children: [
                            Expanded(child: _sectionHeader(
                                Icons.bar_chart_rounded, _primary, '부서별 식수 현황')),
                            _toggleBtn(),
                          ]),
                          // 경과일 안내
                          if (_period != _Period.today && elapsedNote.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6, bottom: 2),
                              child: Row(children: [
                                const Icon(Icons.info_outline_rounded,
                                    size: 12, color: Color(0xFF8A93B0)),
                                const SizedBox(width: 5),
                                Text(
                                  '퍼센트는 $elapsedNote 기준으로 계산됩니다',
                                  style: const TextStyle(
                                      fontSize: 11, color: Color(0xFF8A93B0),
                                      fontWeight: FontWeight.w600),
                                ),
                              ]),
                            ),
                          const SizedBox(height: 10),
                          _deptBarChart(),

                          // 일별 출근 현황
                          if (_period != _Period.today) ...[
                            const SizedBox(height: 24),
                            _sectionHeader(Icons.punch_clock_rounded,
                                const Color(0xFF7C5CDB), '일별 출근 현황'),
                            const SizedBox(height: 12),
                            _attendLineChart(),
                          ],
                        ]),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ── 섹션 헤더
  Widget _sectionHeader(IconData icon, Color color, String title) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [_lighten(color, 0.18), color],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [BoxShadow(color: color.withOpacity(0.25),
              blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Icon(icon, color: Colors.white, size: 15),
      ),
      const SizedBox(width: 10),
      Text(title, style: const TextStyle(
          fontSize: 14, fontWeight: FontWeight.w900,
          color: Color(0xFF1A1D2E))),
    ]);
  }

  // ── 참여도/건수 토글
  Widget _toggleBtn() {
    return GestureDetector(
      onTap: () => setState(() => _deptShowPercent = !_deptShowPercent),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _deptShowPercent
              ? _primary.withOpacity(0.1)
              : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
              color: _deptShowPercent
                  ? _primary.withOpacity(0.35)
                  : Colors.grey.withOpacity(0.25)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            _deptShowPercent
                ? Icons.percent_rounded
                : Icons.format_list_numbered_rounded,
            size: 13,
            color: _deptShowPercent ? _primary : Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            _deptShowPercent ? '참여도' : '건수',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                color: _deptShowPercent ? _primary : Colors.grey[600])),
        ]),
      ),
    );
  }

  // ── 요약 카드 3개
  Widget _summaryCards() {
    final totalAttend = _attendTrend.isEmpty
        ? 0
        : _attendTrend.map((e) => e.count).reduce((a, b) => a + b);
    final periodLabel = switch (_period) {
      _Period.today => '오늘',
      _Period.week  => '이번주',
      _Period.month => '이번달',
    };

    return Row(children: [
      Expanded(child: _SummaryCard(
          icon: Icons.light_mode_rounded,  color: Colors.orange,
          label: '$periodLabel 중식', value: '$_totalLunch명')),
      const SizedBox(width: 10),
      Expanded(child: _SummaryCard(
          icon: Icons.dark_mode_rounded,   color: Colors.indigo,
          label: '$periodLabel 석식', value: '$_totalDinner명')),
      const SizedBox(width: 10),
      Expanded(child: _SummaryCard(
          icon: Icons.how_to_reg_rounded,  color: const Color(0xFF7C5CDB),
          label: '$periodLabel 출근', value: '$totalAttend명')),
    ]);
  }

  // ── 일별 식수 라인 차트
  Widget _mealLineChart() {
    if (_mealTrend.isEmpty) return _emptyChart();

    final lunchSpots  = _mealTrend.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.lunch.toDouble())).toList();
    final dinnerSpots = _mealTrend.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.dinner.toDouble())).toList();
    final maxY = (_mealTrend.map((e) => e.lunch > e.dinner ? e.lunch : e.dinner)
            .reduce((a, b) => a > b ? a : b) * 1.3).ceilToDouble();

    return _ChartCard(
      legend: Row(children: [
        _LegendDot(color: Colors.orange, label: '중식'),
        const SizedBox(width: 16),
        _LegendDot(color: Colors.indigo, label: '석식'),
      ]),
      child: SizedBox(
        height: 200,
        child: LineChart(LineChartData(
          minY: 0,
          maxY: maxY < 5 ? 10 : maxY,
          gridData: FlGridData(
            show: true, drawVerticalLine: false,
            horizontalInterval: (maxY / 4).ceilToDouble().clamp(1, 9999),
            getDrawingHorizontalLine: (_) => FlLine(
                color: Colors.black.withOpacity(0.05), strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true, reservedSize: 30,
              interval: (maxY / 4).ceilToDouble().clamp(1, 9999),
              getTitlesWidget: (v, _) => Text('${v.toInt()}',
                  style: TextStyle(fontSize: 10,
                      color: Colors.black.withOpacity(0.4))),
            )),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true, reservedSize: 26,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= _mealTrend.length) return const SizedBox.shrink();
                final date = _mealTrend[i].date;
                final isWeekend = date.weekday == 6 || date.weekday == 7;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _period == _Period.week
                        ? _weekdayLabel(date.weekday)
                        : '${date.day}',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                        color: (_period == _Period.week && isWeekend)
                            ? Colors.red.withOpacity(0.5)
                            : Colors.black.withOpacity(0.5))),
                );
              },
            )),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => const Color(0xFF1A1D2E),
              getTooltipItems: (spots) => spots.map((s) {
                final label = s.barIndex == 0 ? '중식' : '석식';
                return LineTooltipItem(
                  '$label ${s.y.toInt()}명',
                  const TextStyle(color: Colors.white, fontSize: 12,
                      fontWeight: FontWeight.w700),
                );
              }).toList(),
            ),
          ),
          lineBarsData: [
            _lineBar(lunchSpots, Colors.orange),
            _lineBar(dinnerSpots, Colors.indigo),
          ],
        )),
      ),
    );
  }

  LineChartBarData _lineBar(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots, color: color, isCurved: true, curveSmoothness: 0.3,
      barWidth: 2.5, dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          colors: [color.withOpacity(0.15), color.withOpacity(0.0)],
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
        ),
      ),
    );
  }

  // ── 부서별 식수 바 차트
  Widget _deptBarChart() {
    if (_deptMeal.isEmpty) return _emptyChart();

    final colors = [
      const Color(0xFF2E6BFF), const Color(0xFFFF7A2F), const Color(0xFF7C5CDB),
      const Color(0xFF00BCD4), const Color(0xFFFF4D64), const Color(0xFF4CAF50),
      const Color(0xFFE91E8C), const Color(0xFF009688), const Color(0xFFFFC107),
    ];

    // 경과일 기준 퍼센트 사용
    final values = _deptMeal.map((d) =>
        _deptShowPercent
            ? d.rateOf(_deptElapsedDays)   // ← 경과 일수 기준
            : d.total.toDouble()).toList();
    final maxY = values.isEmpty ? 10.0
        : (values.reduce((a, b) => a > b ? a : b) * 1.3).ceilToDouble();

    return _ChartCard(
      child: Column(children: [
        SizedBox(
          height: 180,
          child: BarChart(BarChartData(
            maxY: maxY < 1 ? 10 : maxY,
            gridData: FlGridData(
              show: true, drawVerticalLine: false,
              horizontalInterval: (maxY / 4).ceilToDouble().clamp(1, 9999),
              getDrawingHorizontalLine: (_) => FlLine(
                  color: Colors.black.withOpacity(0.05), strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true, reservedSize: 22,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= _deptMeal.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(_deptShort(_deptMeal[i].dept),
                        style: TextStyle(fontSize: 9,
                            color: Colors.black.withOpacity(0.5),
                            fontWeight: FontWeight.w600)),
                  );
                },
              )),
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => const Color(0xFF1A1D2E),
                getTooltipItem: (group, _, rod, __) {
                  final d = _deptMeal[group.x];
                  final txt = _deptShowPercent
                      ? '${d.rateOf(_deptElapsedDays).toStringAsFixed(1)}%'
                      : '${d.total}건';
                  return BarTooltipItem(
                    '${_deptFull(d.dept)}\n$txt',
                    const TextStyle(color: Colors.white, fontSize: 11,
                        fontWeight: FontWeight.w700),
                  );
                },
              ),
            ),
            barGroups: _deptMeal.asMap().entries.map((e) {
              final color = colors[e.key % colors.length];
              final val   = values[e.key];
              return BarChartGroupData(
                x: e.key,
                barRods: [BarChartRodData(
                  toY: val, color: color, width: 18,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true, toY: maxY < 1 ? 10 : maxY,
                    color: color.withOpacity(0.05),
                  ),
                )],
              );
            }).toList(),
          )),
        ),
        const SizedBox(height: 12),

        // 부서별 상세 바
        ..._deptMeal.asMap().entries.map((e) {
          final color = colors[e.key % colors.length];
          final d     = e.value;
          final pct   = d.rateOf(_deptElapsedDays); // ← 경과 일수 기준
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.15)),
              boxShadow: [BoxShadow(color: color.withOpacity(0.06),
                  blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: Row(children: [
              Container(width: 8, height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Text(_deptFull(d.dept), style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(width: 6),
              Text('${d.headcount}명', style: TextStyle(
                  fontSize: 11, color: Colors.black.withOpacity(0.4))),
              const Spacer(),
              Text('${d.total}건', style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: Colors.black.withOpacity(0.5))),
              const SizedBox(width: 10),
              SizedBox(width: 80, child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end, children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: (pct / 100).clamp(0.0, 1.0), minHeight: 6,
                    backgroundColor: color.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
                const SizedBox(height: 3),
                Text('${pct.toStringAsFixed(1)}%',
                    style: TextStyle(fontSize: 11,
                        fontWeight: FontWeight.w800, color: color)),
              ])),
            ]),
          );
        }),
      ]),
    );
  }

  // ── 일별 출근 라인 차트
  Widget _attendLineChart() {
    if (_attendTrend.isEmpty) return _emptyChart();

    final spots = _attendTrend.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.count.toDouble())).toList();
    final maxY = (_attendTrend.map((e) => e.count).reduce((a, b) => a > b ? a : b) * 1.3)
        .ceilToDouble();

    return _ChartCard(
      legend: Row(children: [
        _LegendDot(color: const Color(0xFF7C5CDB), label: '출근 인원'),
      ]),
      child: SizedBox(
        height: 200,
        child: LineChart(LineChartData(
          minY: 0,
          maxY: maxY < 5 ? 10 : maxY,
          gridData: FlGridData(
            show: true, drawVerticalLine: false,
            horizontalInterval: (maxY / 4).ceilToDouble().clamp(1, 9999),
            getDrawingHorizontalLine: (_) => FlLine(
                color: Colors.black.withOpacity(0.05), strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true, reservedSize: 30,
              interval: (maxY / 4).ceilToDouble().clamp(1, 9999),
              getTitlesWidget: (v, _) => Text('${v.toInt()}',
                  style: TextStyle(fontSize: 10,
                      color: Colors.black.withOpacity(0.4))),
            )),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true, reservedSize: 26,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= _attendTrend.length) return const SizedBox.shrink();
                final date = _attendTrend[i].date;
                final isWeekend = date.weekday == 6 || date.weekday == 7;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _period == _Period.week ? _weekdayLabel(date.weekday) : '${date.day}',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                        color: (_period == _Period.week && isWeekend)
                            ? Colors.red.withOpacity(0.5)
                            : Colors.black.withOpacity(0.5))),
                );
              },
            )),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => const Color(0xFF1A1D2E),
              getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
                '출근 ${s.y.toInt()}명',
                const TextStyle(color: Colors.white, fontSize: 12,
                    fontWeight: FontWeight.w700),
              )).toList(),
            ),
          ),
          lineBarsData: [_lineBar(spots, const Color(0xFF7C5CDB))],
        )),
      ),
    );
  }

  Widget _emptyChart() {
    return Container(
      height: 120,
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Center(child: Text('데이터 없음',
          style: TextStyle(color: Colors.grey[400], fontSize: 13))),
    );
  }

  String _weekdayLabel(int w) =>
      ['월', '화', '수', '목', '금', '토', '일'][w - 1];

  String _deptFull(String dept) {
    const m = {
      'MANAGEMENT': '관리부', 'PRODUCTION': '생산관리부', 'SALES': '영업부',
      'RND': '연구소', 'STEEL': '스틸생산부', 'BOX': '박스생산부',
      'DELIVERY': '포장납품부', 'SSG': '에스에스지', 'CLEANING': '환경미화',
    };
    return m[dept] ?? dept;
  }

  String _deptShort(String dept) {
    const m = {
      'MANAGEMENT': '관리부', 'PRODUCTION': '생산관리', 'SALES': '영업부',
      'RND': '연구소', 'STEEL': '스틸', 'BOX': '박스',
      'DELIVERY': '납품', 'SSG': 'SSG', 'CLEANING': '미화',
    };
    return m[dept] ?? dept;
  }
}

// ══════════════════════════════════════════
// UI 컴포넌트
// ══════════════════════════════════════════

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   label, value;
  const _SummaryCard({
    required this.icon, required this.color,
    required this.label, required this.value,
  });

  Color _lighten(Color c, double a) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + a).clamp(0.0, 1.0)).toColor();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.10), blurRadius: 12,
              offset: const Offset(0, 4)),
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 5,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [_lighten(color, 0.18), color],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: color.withOpacity(0.25),
                blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        const SizedBox(height: 9),
        Text(value, style: TextStyle(
            fontSize: 18, fontWeight: FontWeight.w900, color: color)),
        const SizedBox(height: 3),
        Text(label, style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w600,
            color: Colors.black.withOpacity(0.4)),
            textAlign: TextAlign.center),
      ]),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final Widget  child;
  final Widget? legend;
  const _ChartCard({required this.child, this.legend});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05),
              blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (legend != null) ...[legend!, const SizedBox(height: 14)],
        child,
      ]),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color  color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 10, height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
          color: Colors.black.withOpacity(0.55))),
    ]);
  }
}

class _PeriodBtn extends StatelessWidget {
  final String   label;
  final bool     selected;
  final VoidCallback onTap;
  const _PeriodBtn({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w800,
          color: selected
              ? const Color(0xFF1E4AD9)
              : Colors.white.withOpacity(0.75),
        )),
      ),
    );
  }
}