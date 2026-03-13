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

  List<Map<String, dynamic>> _allProfiles    = [];
  List<Map<String, dynamic>> _allMonthlyRaw  = [];
  int _totalMembers = 0;

  List<DayStat> _dayStats = [];
  List<String>  _depts    = [];

  int _monthEating = 0, _monthNotEating = 0, _monthNoReply = 0, _monthTotalSlots = 0;

  late TabController _tabController;

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
        supabase.from('profiles').select('id, full_name, dept_category'),
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
      _depts = _allProfiles.map((r) => r['dept_category'] as String).toSet().toList()..sort();

      final allDays = List.generate(lastDay, (i) {
        final d = i + 1;
        return '$monthStr-${d.toString().padLeft(2, '0')}';
      });

      _dayStats = allDays.map((day) {
        final dayRows    = _allMonthlyRaw.where((r) => r['meal_date'] == day).toList();
        final lunchRows  = dayRows.where((r) => r['meal_type'] == 'LUNCH').toList();
        final dinnerRows = dayRows.where((r) => r['meal_type'] == 'DINNER').toList();

        final eating    = dayRows.where((r) => r['is_eating'] == true).length;
        final notEating = dayRows.where((r) => r['is_eating'] == false).length;
        final noReply   = (_totalMembers * 2 - eating - notEating).clamp(0, 99999);

        final byDept = <String, DeptStat>{};
        for (final d in _depts) {
          final members = _allProfiles.where((p) => p['dept_category'] == d).length;
          final dr = dayRows.where((r) => r['dept_category'] == d).toList();
          final de = dr.where((r) => r['is_eating'] == true).length;
          final dn = dr.where((r) => r['is_eating'] == false).length;
          byDept[d] = DeptStat(dept: d, members: members, eating: de, notEating: dn,
              noReply: (members * 2 - dr.length).clamp(0, 99999));
        }

        MealStat makeMealStat(List<Map<String, dynamic>> rows) {
          final e = rows.where((r) => r['is_eating'] == true).length;
          final n = rows.where((r) => r['is_eating'] == false).length;
          return MealStat(eating: e, notEating: n,
              noReply: (_totalMembers - e - n).clamp(0, 99999), members: _totalMembers);
        }

        final lunchByDept = <String, MealStat>{};
        final dinnerByDept = <String, MealStat>{};
        for (final d in _depts) {
          final members = _allProfiles.where((p) => p['dept_category'] == d).length;
          MealStat deptStat(List<Map<String, dynamic>> rows) {
            final dr = rows.where((r) => r['dept_category'] == d).toList();
            final de = dr.where((r) => r['is_eating'] == true).length;
            final dn = dr.where((r) => r['is_eating'] == false).length;
            return MealStat(eating: de, notEating: dn,
                noReply: (members - dr.length).clamp(0, 99999), members: members);
          }
          lunchByDept[d]  = deptStat(lunchRows);
          dinnerByDept[d] = deptStat(dinnerRows);
        }

        return DayStat(
          date: day, total: _totalMembers * 2,
          eating: eating, notEating: notEating, noReply: noReply,
          byDept: byDept, lunch: makeMealStat(lunchRows), dinner: makeMealStat(dinnerRows),
          lunchByDept: lunchByDept, dinnerByDept: dinnerByDept,
        );
      }).toList();

      _monthEating     = _dayStats.fold(0, (s, d) => s + d.eating);
      _monthNotEating  = _dayStats.fold(0, (s, d) => s + d.notEating);
      _monthNoReply    = _dayStats.fold(0, (s, d) => s + d.noReply);
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
        title: Text(context.tr(AppStrings.mealNotifTitle),
            style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Text(context.tr(AppStrings.mealNotifConfirm)
            .replaceAll('{n}', '$_totalMembers')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
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
      await supabase.functions.invoke(
        'send_notice_push',
        body: {
          'secret': _webhookSecret,
          'target': 'all',
          'message': '오늘 식수를 아직 체크하지 않으셨어요! 앱에서 확인해주세요 🍽️',
        },
      );
    } catch (e) {
      errorMsg = context.tr(AppStrings.mealNotifFail).replaceAll('{e}', '$e');
      debugPrint(errorMsg);
    }

    if (!mounted) return;
    setState(() => _isSendingMealNotice = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(errorMsg ?? context.tr(AppStrings.mealNotifDone)),
        backgroundColor: errorMsg != null ? Colors.red : mrPrimary,
      ),
    );
  }

  void _onMonthChanged(int year, int month) {
    setState(() { _selectedYear = year; _selectedMonth = month; });
    _fetchData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: mrBg,
      appBar: AppBar(
        title: const Text("식수 리포트",
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: mrText,
        elevation: 0,
        surfaceTintColor: Colors.white,
        actions: [
          _isSendingMealNotice
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: mrPrimary),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  tooltip: '식수 체크 알림 전송',
                  onPressed: _sendMealNotice,
                ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(49),
          child: Column(children: [
            const Divider(height: 1, color: Color(0xFFF0F2F8)),
            TabBar(
              controller: _tabController,
              labelColor: mrPrimary,
              unselectedLabelColor: mrSub,
              labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              indicatorColor: mrPrimary,
              indicatorWeight: 2.5,
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: "오늘"),
                Tab(text: "월별 요약"),
                Tab(text: "상세 현황"),
              ],
            ),
          ]),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: mrPrimary))
          : TabBarView(
              controller: _tabController,
              children: [
                MealTodayTab(
                  allProfiles: _allProfiles,
                  depts: _depts,
                  totalMembers: _totalMembers,
                  onRefresh: _fetchData,
                ),
                MealMonthTab(
                  selectedYear: _selectedYear,
                  selectedMonth: _selectedMonth,
                  allProfiles: _allProfiles,
                  depts: _depts,
                  dayStats: _dayStats,
                  monthEating: _monthEating,
                  monthNotEating: _monthNotEating,
                  monthNoReply: _monthNoReply,
                  monthTotalSlots: _monthTotalSlots,
                  today: _today,
                  onMonthChanged: _onMonthChanged,
                  onRefresh: _fetchData,
                ),
                MealDetailTab(
                  selectedYear: _selectedYear,
                  selectedMonth: _selectedMonth,
                  allProfiles: _allProfiles,
                  allMonthlyRaw: _allMonthlyRaw,
                  depts: _depts,
                  dayStats: _dayStats,
                  onMonthChanged: _onMonthChanged,
                  onRefresh: _fetchData,
                ),
              ],
            ),
    );
  }
}