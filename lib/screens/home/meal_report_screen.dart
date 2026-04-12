// meal_report_screen.dart — 메인 (탭 조립 + 데이터 로딩)

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'meal_report_models.dart';
import 'meal_today_tab.dart';
import 'meal_month_tab.dart';
import 'meal_detail_tab.dart';
import 'lang_context.dart';
import 'app_strings.dart';

class MealReportScreen extends StatefulWidget {
  const MealReportScreen({Key? key}) : super(key: key);

  @override
  State<MealReportScreen> createState() => _MealReportScreenState();
}

class _MealReportScreenState extends State<MealReportScreen>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;

  bool _isLoading = true;
  bool _isSendingMealNotice = false;
  static const _webhookSecret = 'notice_secret_2026_sspapp';

  int _selectedYear  = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  final String _today = DateFormat('yyyy-MM-dd').format(DateTime.now());

  List<Map<String, dynamic>> _allProfiles   = [];
  List<Map<String, dynamic>> _allMonthlyRaw = [];
  int _totalMembers = 0;

  List<DayStat> _dayStats = [];
  List<String>  _depts    = [];

  int _monthEating = 0, _monthNotEating = 0, _monthNoReply = 0,
      _monthTotalSlots = 0;

  late TabController _tabController;

  // 색상
  static const _orange   = Color(0xFFFF8C42);
  static const _orangeDk = Color(0xFFE65100);
  static const _teal     = Color(0xFF0BC5C5);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final monthStr   = '$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}';
      final lastDay    = DateUtils.getDaysInMonth(_selectedYear, _selectedMonth);
      final lastDayStr = '$monthStr-${lastDay.toString().padLeft(2, '0')}';

      final results = await Future.wait([
        supabase.from('profiles')
            .select('id, full_name, dept_category, nationality'),
        supabase.from('meal_requests')
            .select('user_id, full_name, dept_category, meal_date, is_eating, meal_type')
            .gte('meal_date', '$monthStr-01')
            .lte('meal_date', lastDayStr),
      ]);

      final allProfiles = List<Map<String, dynamic>>.from(results[0] as List);
      _allProfiles = allProfiles
          .where((p) => !mrExcludedDepts.contains(p['dept_category']))
          .toList();

      final allMonthly = List<Map<String, dynamic>>.from(results[1] as List);
      _allMonthlyRaw = allMonthly
          .where((r) => !mrExcludedDepts.contains(r['dept_category']))
          .toList();

      _totalMembers = _allProfiles.length;
      _depts = _allProfiles
          .map((r) => r['dept_category'] as String)
          .toSet()
          .toList()
        ..sort();

      final allDays = List.generate(lastDay, (i) {
        final d = i + 1;
        return '$monthStr-${d.toString().padLeft(2, '0')}';
      });

      MealStat makeMealStat(List<Map<String, dynamic>> rows) {
        final e = rows.where((r) => r['is_eating'] == true).length;
        final n = rows.where((r) => r['is_eating'] == false).length;
        return MealStat(
            eating: e, notEating: n,
            noReply: (_totalMembers - e - n).clamp(0, 99999),
            members: _totalMembers);
      }

      _dayStats = allDays.map((day) {
        final dayRows    = _allMonthlyRaw.where((r) => r['meal_date'] == day).toList();
        final lunchRows  = dayRows.where((r) => r['meal_type'] == 'LUNCH').toList();
        final dinnerRows = dayRows.where((r) => r['meal_type'] == 'DINNER').toList();

        final eating    = dayRows.where((r) => r['is_eating'] == true).length;
        final notEating = dayRows.where((r) => r['is_eating'] == false).length;
        final noReply   = (_totalMembers * 2 - eating - notEating).clamp(0, 99999);

        final byDept = <String, DeptStat>{};
        for (final d in _depts) {
          final members = _allProfiles
              .where((p) => p['dept_category'] == d).length;
          final dr = dayRows.where((r) => r['dept_category'] == d).toList();
          final de = dr.where((r) => r['is_eating'] == true).length;
          final dn = dr.where((r) => r['is_eating'] == false).length;
          byDept[d] = DeptStat(
              dept: d, members: members, eating: de,
              notEating: dn,
              noReply: (members * 2 - de - dn).clamp(0, 99999));
        }

        final lunchByDept  = <String, MealStat>{};
        final dinnerByDept = <String, MealStat>{};
        for (final d in _depts) {
          final ldr = lunchRows.where((r) => r['dept_category'] == d).toList();
          final ddr = dinnerRows.where((r) => r['dept_category'] == d).toList();
          final m   = _allProfiles
              .where((p) => p['dept_category'] == d).length;
          lunchByDept[d] = MealStat(
              eating: ldr.where((r) => r['is_eating'] == true).length,
              notEating: ldr.where((r) => r['is_eating'] == false).length,
              noReply: 0, members: m);
          dinnerByDept[d] = MealStat(
              eating: ddr.where((r) => r['is_eating'] == true).length,
              notEating: ddr.where((r) => r['is_eating'] == false).length,
              noReply: 0, members: m);
        }

        return DayStat(
          date: day, total: _totalMembers * 2,
          eating: eating, notEating: notEating, noReply: noReply,
          byDept: byDept,
          lunch: makeMealStat(lunchRows), dinner: makeMealStat(dinnerRows),
          lunchByDept: lunchByDept, dinnerByDept: dinnerByDept,
        );
      }).toList();

      _monthEating    = _dayStats.fold(0, (s, d) => s + d.eating);
      _monthNotEating = _dayStats.fold(0, (s, d) => s + d.notEating);
      _monthNoReply   = _dayStats.fold(0, (s, d) => s + d.noReply);
      _monthTotalSlots = _totalMembers * lastDay * 2;
    } catch (e) {
      debugPrint("식수 리포트 로드 실패: $e");
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _sendMealNotice() async {
    if (_isSendingMealNotice) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text(context.tr(AppStrings.mealNotifTitle),
            style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Text(context.tr(AppStrings.mealNotifConfirm)
            .replaceAll('{n}', '$_totalMembers')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: mrPrimary),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.tr(AppStrings.mealNotifSend),
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    setState(() => _isSendingMealNotice = true);

    String? errorMsg;
    try {
      await supabase.functions.invoke('send_notice_push', body: {
        'secret': _webhookSecret,
        'target': 'all',
        'message': '오늘 식수를 아직 체크하지 않으셨어요! 앱에서 확인해주세요 🍽️',
      });
    } catch (e) {
      errorMsg = context.tr(AppStrings.mealNotifFail)
          .replaceAll('{e}', '$e');
    }
    if (!mounted) return;
    setState(() => _isSendingMealNotice = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(errorMsg ?? context.tr(AppStrings.mealNotifDone)),
      backgroundColor: errorMsg != null ? Colors.red : mrPrimary,
    ));
  }

  void _onMonthChanged(int year, int month) {
    setState(() { _selectedYear = year; _selectedMonth = month; });
    _fetchData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: mrBg,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            pinned: true,
            expandedHeight: 130,
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor: _orangeDk,
            foregroundColor: Colors.white,
            title: Text(
              context.tr(AppStrings.mealReportTitle),
              style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                  color: Colors.white),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 12),
                child: _isSendingMealNotice
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        ),
                      )
                    : IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.notifications_outlined,
                              color: Colors.white, size: 18),
                        ),
                        tooltip: '식수 체크 알림 전송',
                        onPressed: _sendMealNotice,
                      ),
              ),
            ],
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
                        child: const Icon(Icons.restaurant_rounded,
                            color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(
                          '${_selectedYear}년 ${_selectedMonth}월',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w900),
                        ),
                        Text(
                          '전체 $_totalMembers명 식수 현황',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ]),
                    ]),
                  ),
                ]),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(46),
              child: Container(
                color: _orangeDk,
                child: TabBar(
                  controller: _tabController,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white.withOpacity(0.55),
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 13),
                  indicatorColor: Colors.white,
                  indicatorWeight: 2.5,
                  dividerColor: Colors.white.withOpacity(0.15),
                  tabs: const [
                    Tab(text: '오늘'),
                    Tab(text: '월별 요약'),
                    Tab(text: '상세 현황'),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: mrPrimary))
            : TabBarView(
                controller: _tabController,
                children: [
                  MealTodayTab(
                    allProfiles:   _allProfiles,
                    depts:         _depts,
                    totalMembers:  _totalMembers,
                    onRefresh:     _fetchData,
                  ),
                  MealMonthTab(
                    selectedYear:   _selectedYear,
                    selectedMonth:  _selectedMonth,
                    allProfiles:    _allProfiles,
                    depts:          _depts,
                    dayStats:       _dayStats,
                    monthEating:    _monthEating,
                    monthNotEating: _monthNotEating,
                    monthNoReply:   _monthNoReply,
                    monthTotalSlots: _monthTotalSlots,
                    today:          _today,
                    onMonthChanged: _onMonthChanged,
                    onRefresh:      _fetchData,
                  ),
                  MealDetailTab(
                    selectedYear:   _selectedYear,
                    selectedMonth:  _selectedMonth,
                    allProfiles:    _allProfiles,
                    allMonthlyRaw:  _allMonthlyRaw,
                    depts:          _depts,
                    dayStats:       _dayStats,
                    onMonthChanged: _onMonthChanged,
                    onRefresh:      _fetchData,
                  ),
                ],
              ),
      ),
    );
  }
}