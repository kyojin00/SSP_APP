import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'attendance_helper.dart';
import 'attendance_tab.dart';
import 'leave_status_tab.dart';
import 'leave_history_tab.dart';
import 'leave_realtime_tab.dart';

class AttendanceManagementScreen extends StatefulWidget {
  final bool   isManager;
  /// 'attendance' → 출퇴근 리포트 (근무중/퇴근/휴가/미출근)
  /// 'leave'      → 휴가 리포트 (실시간 현황, 연차기록 등)
  final String mode;
  final int    initialTab;

  const AttendanceManagementScreen({
    Key? key,
    this.isManager  = false,
    this.mode       = 'attendance',
    this.initialTab = 0,
  }) : super(key: key);

  @override
  State<AttendanceManagementScreen> createState() =>
      _AttendanceManagementScreenState();
}

class _AttendanceManagementScreenState
    extends State<AttendanceManagementScreen>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  late TabController _tabController;

  bool _isLoading   = true;
  bool _canApprove  = false;

  List<Map<String, dynamic>> _dailyAttendance = [];
  List<Map<String, dynamic>> _leaveRequests   = [];
  List<Map<String, dynamic>> _onLeaveNow      = [];
  List<Map<String, dynamic>> _upcomingLeaves  = [];
  List<Map<String, dynamic>> _leaveHistory    = [];
  Map<String, List<Map<String, dynamic>>> _profilesByDept = {};

  // 탭 개수 계산
  int get _tabCount {
    if (widget.mode == 'attendance') {
      return 1; // AttendanceTab 자체가 내부 탭 4개를 가짐
    }
    // leave 모드
    if (widget.isManager) return 3; // 실시간 + 휴가현황 + 연차기록
    return 1; // 사원: 실시간만
  }

  @override
  void initState() {
    super.initState();
    final clampedTab = widget.initialTab.clamp(0, _tabCount - 1);
    _tabController = TabController(
        length: _tabCount, vsync: this, initialIndex: clampedTab);
    _refreshData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchAttendance(),
      _fetchLeaveRequests(),
      _fetchLeaveStatus(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchAttendance() async {
    final now   = DateTime.now();
    final end   = DateFormat('yyyy-MM-dd').format(now);
    final start = DateFormat('yyyy-MM-dd').format(
        now.subtract(const Duration(days: kAttendanceRangeDays - 1)));
    try {
      final data = await supabase
          .from('attendance')
          .select('id, user_id, full_name, dept_category, work_date, check_in, check_out')
          .gte('work_date', start)
          .lte('work_date', end)
          .order('work_date', ascending: false)
          .order('check_in',  ascending: false);
      _dailyAttendance = List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint("출퇴근 로드 실패: $e");
    }
  }

  Future<void> _fetchLeaveRequests() async {
  try {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final myProfile = await supabase
        .from('profiles')
        .select('position, role, dept_category')
        .eq('id', user.id)
        .single();
    final myPosition = myProfile['position'] as String? ?? '';
    final myRole     = myProfile['role']     as String? ?? '';

    const mgrRanks = ['과장','차장','부장','이사','본부장','대표이사'];
    _canApprove = myRole == 'ADMIN' || mgrRanks.contains(myPosition);

    if (_canApprove) {
      final data = await supabase
          .from('leave_requests')
          .select('*')           // ← join 제거
          .eq('status', 'PENDING')
          .order('created_at', ascending: false);
      _leaveRequests = List<Map<String, dynamic>>.from(data);
    } else {
      final data = await supabase
          .from('leave_requests')
          .select('*')           // ← join 제거
          .eq('user_id', user.id)
          .order('start_date', ascending: false);
      _leaveRequests = List<Map<String, dynamic>>.from(data);
    }
  } catch (e) {
    debugPrint("휴가 요청 로드 실패: $e");
  }
}

Future<void> _fetchLeaveStatus() async {
  try {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final user  = supabase.auth.currentUser;
    if (user == null) return;

    // 연차 기록
    final historyData = widget.isManager
        ? await supabase
            .from('leave_requests')
            .select('*')         // ← join 제거
            .eq('status', 'APPROVED')
            .order('start_date', ascending: false)
        : await supabase
            .from('leave_requests')
            .select('*')         // ← join 제거
            .eq('user_id', user.id)
            .eq('status', 'APPROVED')
            .order('start_date', ascending: false);
    _leaveHistory = List<Map<String, dynamic>>.from(historyData);

    // 오늘 휴가 중
    final onLeaveData = await supabase
        .from('leave_requests')
        .select('*')             // ← join 제거
        .eq('status', 'APPROVED')
        .lte('start_date', today)
        .gte('end_date',   today);
    _onLeaveNow = List<Map<String, dynamic>>.from(onLeaveData);

    // 예정 휴가
    final upcomingData = await supabase
        .from('leave_requests')
        .select('*')             // ← join 제거
        .eq('status', 'APPROVED')
        .gt('start_date', today)
        .order('start_date');
    _upcomingLeaves = List<Map<String, dynamic>>.from(upcomingData);

    // 부서별 프로필 (별도 조회)
    if (widget.isManager) {
      final profileData = await supabase
          .from('profiles')
          .select('id, full_name, dept_category, position')
          .order('dept_category')
          .order('full_name');
      final profiles = List<Map<String, dynamic>>.from(profileData);
      final map = <String, List<Map<String, dynamic>>>{};
      for (final p in profiles) {
        final dept = p['dept_category'] as String? ?? '기타';
        map.putIfAbsent(dept, () => []).add(p);
      }
      _profilesByDept = map;
    }
  } catch (e) {
    debugPrint("휴가 상태 로드 실패: $e");
  }
}

  Future<void> _updateRequestStatus(
      String requestId, String newStatus) async {
    try {
      await supabase
          .from('leave_requests')
          .update({'status': newStatus})
          .eq('id', requestId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(newStatus == 'APPROVED' ? "승인되었습니다." : "반려되었습니다."),
          behavior: SnackBarBehavior.floating,
          backgroundColor: newStatus == 'APPROVED'
              ? Colors.green
              : Colors.redAccent,
        ));
      }
      _refreshData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("처리 중 오류 발생"),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ──────────────────────────────────
    // 출퇴근 리포트 모드
    // ──────────────────────────────────
    if (widget.mode == 'attendance') {
      return Scaffold(
        backgroundColor: const Color(0xFFF0F2F5),
        appBar: AppBar(
          title: const Text('출퇴근',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          centerTitle: true,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0.5,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : AttendanceTab(
                dailyAttendance: _dailyAttendance,
                profilesByDept:  _profilesByDept,
                onLeaveNow:      _onLeaveNow,
                onRefresh:       _refreshData,
              ),
      );
    }

    // ──────────────────────────────────
    // 휴가 리포트 모드
    // ──────────────────────────────────
    final isManager = widget.isManager;

    // 탭 목록
    final tabs = <Widget>[
      Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.flight_takeoff_rounded, size: 16),
        const SizedBox(width: 4),
        const Text("실시간", style: TextStyle(fontSize: 13)),
        if (_onLeaveNow.isNotEmpty) ...[
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
                color: Colors.indigo,
                borderRadius: BorderRadius.circular(8)),
            child: Text("${_onLeaveNow.length}",
                style: const TextStyle(
                    color: Colors.white, fontSize: 10,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ])),
      if (isManager) ...[
        Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.beach_access_rounded, size: 16),
          const SizedBox(width: 4),
          const Text("휴가 현황", style: TextStyle(fontSize: 13)),
          if (_leaveRequests.isNotEmpty) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(8)),
              child: Text("${_leaveRequests.length}",
                  style: const TextStyle(
                      color: Colors.white, fontSize: 10,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ])),
        Tab(child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.history_rounded, size: 16),
          SizedBox(width: 4),
          Text("연차 기록", style: TextStyle(fontSize: 13)),
        ])),
      ],
    ];

    // 탭 콘텐츠
    final tabViews = <Widget>[
      LeaveRealtimeTab(
        onLeaveToday:   _onLeaveNow,
        upcomingLeaves: _upcomingLeaves,
        onRefresh:      _refreshData,
      ),
      if (isManager) ...[
        LeaveStatusTab(
          leaveRequests:  _leaveRequests,
          onLeaveNow:     _onLeaveNow,
          profilesByDept: _profilesByDept,
          onRefresh:      _refreshData,
          onUpdateStatus: _updateRequestStatus,
          canApprove:     _canApprove,
        ),
        LeaveHistoryTab(
          leaveHistory: _leaveHistory,
          onRefresh:    _refreshData,
        ),
      ],
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('휴가',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        bottom: (isManager && _tabCount > 1)
            ? TabBar(
                controller: _tabController,
                labelColor: const Color(0xFF2E6BFF),
                unselectedLabelColor: Colors.grey,
                indicatorColor: const Color(0xFF2E6BFF),
                indicatorWeight: 3,
                tabs: tabs,
              )
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (isManager && _tabCount > 1)
              ? TabBarView(controller: _tabController, children: tabViews)
              : LeaveRealtimeTab(
                  onLeaveToday:   _onLeaveNow,
                  upcomingLeaves: _upcomingLeaves,
                  onRefresh:      _refreshData,
                ),
    );
  }
}