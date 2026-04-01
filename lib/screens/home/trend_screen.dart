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
  final int headcount; // 부서 인원수
  const _DeptMeal({required this.dept, required this.total, required this.headcount});

  // 1인당 평균 식수 횟수 (참여율 기반)
  double get rate => headcount > 0 ? (total / headcount).clamp(0.0, 100.0) : 0.0;
  // 퍼센트 표시용 (최대 참여 가능 식수 = 인원 × 기간 × 2끼 기준)
  double rateOf(int days) => headcount > 0 && days > 0
      ? ((total / (headcount * days * 2)) * 100).clamp(0.0, 100.0)
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

  _Period _period = _Period.week;
  bool _loading = true;
  bool _deptShowPercent = true; // true: 참여율%, false: 절대 건수

  List<_DailyMeal> _mealTrend = [];
  List<_DeptMeal> _deptMeal = [];
  List<_DailyAttendance> _attendTrend = [];
  int _deptPeriodDays = 7; // 조회 기간 영업일수

  int _totalLunch = 0;
  int _totalDinner = 0;
  int _totalEmployees = 0;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;

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

  // ──────────────────────────────────────────
  // 날짜 범위
  // ──────────────────────────────────────────

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
        end: DateTime(sun.year, sun.month, sun.day),
      );
    } else {
      final lastDay = DateTime(now.year, now.month + 1, 0);
      return DateTimeRange(
        start: DateTime(now.year, now.month, 1),
        end: DateTime(lastDay.year, lastDay.month, lastDay.day),
      );
    }
  }

  // ──────────────────────────────────────────
  // 데이터 로딩
  // ──────────────────────────────────────────

  Future<void> _loadData() async {
    setState(() => _loading = true);
    _animCtrl.reset();

    final from = DateFormat('yyyy-MM-dd').format(_range.start);
    final to   = DateFormat('yyyy-MM-dd').format(_range.end);

    try {
      final results = await Future.wait([
        supabase
            .from('meal_requests')
            .select('meal_date, meal_type, user_id')
            .gte('meal_date', from)
            .lte('meal_date', to),
        supabase
            .from('attendance')
            .select('work_date')
            .gte('work_date', from)
            .lte('work_date', to),
        supabase.from('profiles').select('id, dept_category, role'),
      ]);

      final mealRaw    = results[0] as List;
      final attendRaw  = results[1] as List;
      final profileRaw = results[2] as List;

      final userDept = <String, String>{};
      for (final p in profileRaw) {
        userDept[p['id'] as String] = p['dept_category'] as String? ?? '기타';
      }
      final empCount = profileRaw.where((p) =>
          (p['dept_category'] as String?)?.isNotEmpty == true).length;

      // ── 식수 일별 집계
      final mealByDate = <String, Map<String, int>>{};
      for (final r in mealRaw) {
        final d = r['meal_date'] as String;
        final t = r['meal_type'] as String;
        mealByDate.putIfAbsent(d, () => {'LUNCH': 0, 'DINNER': 0});
        mealByDate[d]![t] = (mealByDate[d]![t] ?? 0) + 1;
      }

      // 오늘: 1칸 / 이번주: 월~일 7칸 / 이번달: 평일만
      final days = <_DailyMeal>[];
      var cur = _range.start;
      while (!cur.isAfter(_range.end)) {
        final key = DateFormat('yyyy-MM-dd').format(cur);
        final m = mealByDate[key] ?? {};
        final include = _period == _Period.today ||
            _period == _Period.week ||
            cur.weekday < 6;
        if (include) {
          days.add(_DailyMeal(
              date: cur,
              lunch: m['LUNCH'] ?? 0,
              dinner: m['DINNER'] ?? 0));
        }
        cur = cur.add(const Duration(days: 1));
      }

      // ── 부서별 집계
      const deptOrder = [
        'MANAGEMENT', 'PRODUCTION', 'SALES', 'RND',
        'STEEL', 'BOX', 'DELIVERY', 'SSG', 'CLEANING', 'NUTRITION',
      ];
      final deptCount    = <String, int>{};
      final deptHeadcount = <String, int>{};

      // 부서별 인원수 (role 관계없이 dept_category 있는 모든 직원)
      for (final p in profileRaw) {
        final dept = p['dept_category'] as String?;
        if (dept != null && dept.isNotEmpty) {
          deptHeadcount[dept] = (deptHeadcount[dept] ?? 0) + 1;
        }
      }
      // 부서별 식수 횟수
      for (final r in mealRaw) {
        final uid  = r['user_id'] as String? ?? '';
        final dept = userDept[uid] ?? '기타';
        deptCount[dept] = (deptCount[dept] ?? 0) + 1;
      }
      final deptList = deptOrder
          .where((d) => deptCount.containsKey(d) || deptHeadcount.containsKey(d))
          .map((d) => _DeptMeal(
              dept: d,
              total: deptCount[d] ?? 0,
              headcount: deptHeadcount[d] ?? 0))
          .toList();

      // ── 출근 일별 집계
      final attendByDate = <String, int>{};
      for (final r in attendRaw) {
        final d = r['work_date'] as String;
        attendByDate[d] = (attendByDate[d] ?? 0) + 1;
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
        _mealTrend      = days;
        _deptMeal       = deptList;
        _attendTrend    = attendDays;
        _totalLunch     = mealRaw.where((r) => r['meal_type'] == 'LUNCH').length;
        _totalDinner    = mealRaw.where((r) => r['meal_type'] == 'DINNER').length;
        _totalEmployees = empCount;
        _deptPeriodDays = days.length.clamp(1, 999);
        _loading        = false;
      });
      _animCtrl.forward();
    } catch (e) {
      debugPrint('TrendScreen 로드 실패: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  // ──────────────────────────────────────────
  // Build
  // ──────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E4AD9),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('동향 분석',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 14),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _PeriodBtn(
                label: '오늘',
                selected: _period == _Period.today,
                onTap: () {
                  if (_period != _Period.today) {
                    setState(() => _period = _Period.today);
                    _loadData();
                  }
                },
              ),
              _PeriodBtn(
                label: '이번주',
                selected: _period == _Period.week,
                onTap: () {
                  if (_period != _Period.week) {
                    setState(() => _period = _Period.week);
                    _loadData();
                  }
                },
              ),
              _PeriodBtn(
                label: '이번달',
                selected: _period == _Period.month,
                onTap: () {
                  if (_period != _Period.month) {
                    setState(() => _period = _Period.month);
                    _loadData();
                  }
                },
              ),
            ]),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF2E6BFF)))
          : FadeTransition(
              opacity: _fadeAnim,
              child: RefreshIndicator(
                color: const Color(0xFF2E6BFF),
                onRefresh: _loadData,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                  children: [
                    _summaryCards(),
                    const SizedBox(height: 20),
                    // 오늘 모드에선 일별 추이 차트 불필요
                    if (_period != _Period.today) ...[
                      _sectionTitle(Icons.restaurant_rounded,
                          const Color(0xFFFF7A2F), '일별 식수 현황'),
                      const SizedBox(height: 12),
                      _mealLineChart(),
                      const SizedBox(height: 24),
                    ],
                    Row(children: [
                      Expanded(child: _sectionTitle(Icons.bar_chart_rounded,
                          const Color(0xFF2E6BFF), '부서별 식수 현황')),
                      // 퍼센트 / 건수 토글
                      GestureDetector(
                        onTap: () => setState(() => _deptShowPercent = !_deptShowPercent),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _deptShowPercent
                                ? const Color(0xFF2E6BFF).withOpacity(0.1)
                                : Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _deptShowPercent
                                  ? const Color(0xFF2E6BFF).withOpacity(0.4)
                                  : Colors.grey.withOpacity(0.3),
                            ),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(
                              _deptShowPercent
                                  ? Icons.percent_rounded
                                  : Icons.format_list_numbered_rounded,
                              size: 13,
                              color: _deptShowPercent
                                  ? const Color(0xFF2E6BFF)
                                  : Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _deptShowPercent ? '참여율' : '건수',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _deptShowPercent
                                    ? const Color(0xFF2E6BFF)
                                    : Colors.grey[600],
                              ),
                            ),
                          ]),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    _deptBarChart(),
                    if (_period != _Period.today) ...[
                      const SizedBox(height: 24),
                      _sectionTitle(Icons.punch_clock_rounded,
                          const Color(0xFF7C5CDB), '일별 출근 현황'),
                      const SizedBox(height: 12),
                      _attendLineChart(),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  // ──────────────────────────────────────────
  // 요약 카드
  // ──────────────────────────────────────────

  Widget _summaryCards() {
    final totalAttend = _attendTrend.isEmpty
        ? 0
        : _attendTrend.map((e) => e.count).reduce((a, b) => a + b);

    final periodLabel = _period == _Period.today ? '오늘'
        : _period == _Period.week ? '이번주' : '이번달';

    return Row(children: [
      Expanded(
          child: _SummaryCard(
              icon: Icons.light_mode_rounded,
              color: Colors.orange,
              label: '$periodLabel 중식',
              value: '$_totalLunch명')),
      const SizedBox(width: 10),
      Expanded(
          child: _SummaryCard(
              icon: Icons.dark_mode_rounded,
              color: Colors.indigo,
              label: '$periodLabel 석식',
              value: '$_totalDinner명')),
      const SizedBox(width: 10),
      Expanded(
          child: _SummaryCard(
              icon: Icons.how_to_reg_rounded,
              color: const Color(0xFF7C5CDB),
              label: '$periodLabel 출근',
              value: '$totalAttend명')),
    ]);
  }

  // ──────────────────────────────────────────
  // 식수 라인 차트
  // ──────────────────────────────────────────

  Widget _mealLineChart() {
    if (_mealTrend.isEmpty) return _emptyChart();

    final lunchSpots = _mealTrend
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.lunch.toDouble()))
        .toList();
    final dinnerSpots = _mealTrend
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.dinner.toDouble()))
        .toList();

    final maxY = (_mealTrend
                .map((e) => e.lunch > e.dinner ? e.lunch : e.dinner)
                .reduce((a, b) => a > b ? a : b) *
            1.3)
        .ceilToDouble();

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
            show: true,
            drawVerticalLine: false,
            horizontalInterval: (maxY / 4).ceilToDouble().clamp(1, 9999),
            getDrawingHorizontalLine: (_) =>
                FlLine(color: Colors.black.withOpacity(0.05), strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: (maxY / 4).ceilToDouble().clamp(1, 9999),
                getTitlesWidget: (v, _) => Text('${v.toInt()}',
                    style: TextStyle(
                        fontSize: 10, color: Colors.black.withOpacity(0.4))),
              ),
            ),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= _mealTrend.length) {
                    return const SizedBox.shrink();
                  }
                  final date = _mealTrend[i].date;
                  final isWeekend =
                      date.weekday == 6 || date.weekday == 7;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _period == _Period.week
                          ? _weekdayLabel(date.weekday) // 월화수목금토일
                          : '${date.day}',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: (_period == _Period.week && isWeekend)
                              ? Colors.red.withOpacity(0.5)
                              : Colors.black.withOpacity(0.5)),
                    ),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => const Color(0xFF1A1D2E),
              getTooltipItems: (spots) => spots.map((s) {
                final label = s.barIndex == 0 ? '중식' : '석식';
                return LineTooltipItem('$label ${s.y.toInt()}명',
                    const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700));
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
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.35,
      color: color,
      barWidth: 2.5,
      dotData: FlDotData(
        show: true,
        getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
            radius: 3.5,
            color: color,
            strokeWidth: 2,
            strokeColor: Colors.white),
      ),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          colors: [color.withOpacity(0.18), color.withOpacity(0.0)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }

  // ──────────────────────────────────────────
  // 부서별 바 차트
  // ──────────────────────────────────────────

  Widget _deptBarChart() {
    if (_deptMeal.isEmpty) return _emptyChart();

    // 퍼센트 모드: 0~100%, 건수 모드: 실제 건수
    final values = _deptShowPercent
        ? _deptMeal.map((e) => e.rateOf(_deptPeriodDays)).toList()
        : _deptMeal.map((e) => e.total.toDouble()).toList();

    final maxRaw = values.isEmpty ? 10.0 : values.reduce((a, b) => a > b ? a : b);
    final maxY   = _deptShowPercent
        ? 100.0
        : (maxRaw * 1.3).ceilToDouble().clamp(5.0, double.infinity);

    const colors = [
      Color(0xFF2E6BFF), Color(0xFFFF7A2F), Color(0xFF7C5CDB),
      Color(0xFF00BCD4), Color(0xFFE91E8C), Color(0xFF4CAF50),
      Color(0xFFFF5722), Color(0xFF607D8B), Color(0xFFFFC107),
      Color(0xFF9C27B0),
    ];

    return Column(children: [
      _ChartCard(
        child: SizedBox(
          height: 240,
          child: BarChart(BarChartData(
            maxY: maxY,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: _deptShowPercent ? 25 : (maxY / 4).ceilToDouble().clamp(1, 9999),
              getDrawingHorizontalLine: (_) =>
                  FlLine(color: Colors.black.withOpacity(0.05), strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 36,
                  interval: _deptShowPercent ? 25 : (maxY / 4).ceilToDouble().clamp(1, 9999),
                  getTitlesWidget: (v, _) => Text(
                    _deptShowPercent ? '${v.toInt()}%' : '${v.toInt()}',
                    style: TextStyle(fontSize: 9, color: Colors.black.withOpacity(0.4)),
                  ),
                ),
              ),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 32,
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= _deptMeal.length) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(_deptShort(_deptMeal[i].dept),
                          style: TextStyle(
                              fontSize: 9,
                              color: Colors.black.withOpacity(0.55),
                              fontWeight: FontWeight.w600)),
                    );
                  },
                ),
              ),
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => const Color(0xFF1A1D2E),
                getTooltipItem: (group, _, rod, __) {
                  final d = _deptMeal[group.x];
                  final pct = d.rateOf(_deptPeriodDays).toStringAsFixed(1);
                  return BarTooltipItem(
                    '${_deptFull(d.dept)}\n'
                    '${d.total}건  |  ${d.headcount}명\n'
                    '참여율 $pct%',
                    const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                  );
                },
              ),
            ),
            barGroups: _deptMeal.asMap().entries.map((e) {
              final color = colors[e.key % colors.length];
              final val   = values[e.key];
              return BarChartGroupData(
                x: e.key,
                barRods: [
                  BarChartRodData(
                    toY: val,
                    color: color,
                    width: 18,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: maxY,
                      color: color.withOpacity(0.05),
                    ),
                  ),
                ],
              );
            }).toList(),
          )),
        ),
      ),
      const SizedBox(height: 12),
      // 부서별 상세 리스트
      ..._deptMeal.asMap().entries.map((e) {
        final color = colors[e.key % colors.length];
        final d = e.value;
        final pct = d.rateOf(_deptPeriodDays);
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.15)),
          ),
          child: Row(children: [
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Text(_deptFull(d.dept),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(width: 6),
            Text('${d.headcount}명',
                style: TextStyle(fontSize: 11, color: Colors.black.withOpacity(0.4))),
            const Spacer(),
            Text('${d.total}건',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: Colors.black.withOpacity(0.5))),
            const SizedBox(width: 10),
            // 퍼센트 바
            SizedBox(
              width: 80,
              child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: (pct / 100).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: color.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
                const SizedBox(height: 3),
                Text('${pct.toStringAsFixed(1)}%',
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w800, color: color)),
              ]),
            ),
          ]),
        );
      }),
    ]);
  }

  // ──────────────────────────────────────────
  // 출근 라인 차트
  // ──────────────────────────────────────────

  Widget _attendLineChart() {
    if (_attendTrend.isEmpty) return _emptyChart();

    final spots = _attendTrend
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.count.toDouble()))
        .toList();

    final maxY = (_attendTrend
                .map((e) => e.count)
                .reduce((a, b) => a > b ? a : b) *
            1.3)
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
            show: true,
            drawVerticalLine: false,
            horizontalInterval: (maxY / 4).ceilToDouble().clamp(1, 9999),
            getDrawingHorizontalLine: (_) =>
                FlLine(color: Colors.black.withOpacity(0.05), strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: (maxY / 4).ceilToDouble().clamp(1, 9999),
                getTitlesWidget: (v, _) => Text('${v.toInt()}',
                    style: TextStyle(
                        fontSize: 10, color: Colors.black.withOpacity(0.4))),
              ),
            ),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= _attendTrend.length) {
                    return const SizedBox.shrink();
                  }
                  final date = _attendTrend[i].date;
                  final isWeekend =
                      date.weekday == 6 || date.weekday == 7;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _period == _Period.week
                          ? _weekdayLabel(date.weekday) // 월화수목금토일
                          : '${date.day}',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: (_period == _Period.week && isWeekend)
                              ? Colors.red.withOpacity(0.5)
                              : Colors.black.withOpacity(0.5)),
                    ),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => const Color(0xFF1A1D2E),
              getTooltipItems: (spots) => spots
                  .map((s) => LineTooltipItem('출근 ${s.y.toInt()}명',
                      const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)))
                  .toList(),
            ),
          ),
          lineBarsData: [_lineBar(spots, const Color(0xFF7C5CDB))],
        )),
      ),
    );
  }

  // ──────────────────────────────────────────
  // 헬퍼
  // ──────────────────────────────────────────

  Widget _sectionTitle(IconData icon, Color color, String title) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 18),
      ),
      const SizedBox(width: 10),
      Text(title,
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1A1D2E))),
    ]);
  }

  Widget _emptyChart() {
    return _ChartCard(
      child: SizedBox(
        height: 120,
        child: Center(
          child: Text('데이터가 없습니다',
              style: TextStyle(
                  color: Colors.black.withOpacity(0.3),
                  fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  // 이번주: 월~일 7칸
  String _weekdayLabel(int wd) {
    const labels = {
      1: '월', 2: '화', 3: '수', 4: '목', 5: '금', 6: '토', 7: '일'
    };
    return labels[wd] ?? '';
  }

  String _deptFull(String dept) {
    const m = {
      'MANAGEMENT': '관리부',
      'PRODUCTION': '생산관리부',
      'SALES': '영업부',
      'RND': '연구소',
      'STEEL': '스틸생산부',
      'BOX': '박스생산부',
      'DELIVERY': '포장납품부',
      'SSG': '에스에스지',
      'CLEANING': '환경미화',
      'NUTRITION': '영양사',
    };
    return m[dept] ?? dept;
  }

  String _deptShort(String dept) {
    const m = {
      'MANAGEMENT': '관리부',
      'PRODUCTION': '생산관리',
      'SALES': '영업부',
      'RND': '연구소',
      'STEEL': '스틸',
      'BOX': '박스',
      'DELIVERY': '납품',
      'SSG': 'SSG',
      'CLEANING': '미화',
      'NUTRITION': '영양사',
    };
    return m[dept] ?? dept;
  }
}

// ══════════════════════════════════════════
// UI 컴포넌트
// ══════════════════════════════════════════

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  const _SummaryCard(
      {required this.icon,
      required this.color,
      required this.label,
      required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 8),
        Text(value,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w900, color: color)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.black.withOpacity(0.4))),
      ]),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final Widget child;
  final Widget? legend;
  const _ChartCard({required this.child, this.legend});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 14,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (legend != null) ...[legend!, const SizedBox(height: 16)],
        child,
      ]),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text(label,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black.withOpacity(0.55))),
    ]);
  }
}

class _PeriodBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _PeriodBtn(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: selected
                  ? const Color(0xFF1E4AD9)
                  : Colors.white.withOpacity(0.75),
            )),
      ),
    );
  }
}