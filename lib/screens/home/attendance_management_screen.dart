import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'attendance_helper.dart';
import 'attendance_tab.dart';
import 'leave_status_tab.dart';
import 'leave_history_tab.dart';

class AttendanceManagementScreen extends StatefulWidget {
  const AttendanceManagementScreen({Key? key}) : super(key: key);

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
  bool _canApprove  = false; // 과장급 이상만 true
  List<Map<String, dynamic>> _dailyAttendance = [];
  List<Map<String, dynamic>> _leaveRequests   = [];
  List<Map<String, dynamic>> _onLeaveNow      = [];
  List<Map<String, dynamic>> _leaveHistory    = [];
  Map<String, List<Map<String, dynamic>>> _profilesByDept = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
    final start = DateFormat('yyyy-MM-dd')
        .format(now.subtract(const Duration(days: kAttendanceRangeDays - 1)));
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

      const step1Ranks = ['과장', '차장', '부장'];
      const step2Ranks = ['이사', '본부장', '대표이사'];
      final isAdmin    = myRole == 'ADMIN';
      _canApprove = isAdmin || step1Ranks.contains(myPosition) || step2Ranks.contains(myPosition);

      List<Map<String, dynamic>> data = [];

      // 내 부서도 조회
      final myDept = myProfile['dept_category'] as String? ?? '';

      debugPrint("=== _fetchLeaveRequests ===");
      debugPrint("myPosition: $myPosition / myRole: $myRole / myDept: $myDept");
      debugPrint("step1Ranks.contains: ${step1Ranks.contains(myPosition)}");
      debugPrint("step2Ranks.contains: ${step2Ranks.contains(myPosition)}");

      if (isAdmin) {
        // 어드민: 전체 PENDING
        final rows = await supabase
            .from('leave_requests')
            .select()
            .eq('status', 'PENDING')
            .order('created_at', ascending: false);
        data = List<Map<String, dynamic>>.from(rows);
      } else if (step1Ranks.contains(myPosition)) {
        // 과장/차장/부장: 같은 부서의 step1 PENDING 건만
        final rows = await supabase
            .from('leave_requests')
            .select()
            .eq('status', 'PENDING')
            .eq('step1_status', 'PENDING')
            .eq('dept_category', myDept)
            .order('created_at', ascending: false);
        data = List<Map<String, dynamic>>.from(rows);
      } else if (step2Ranks.contains(myPosition)) {
        debugPrint("=== 본부장 분기 진입 ===");
        debugPrint("myPosition: '$myPosition'");
        debugPrint("step2Ranks: $step2Ranks");
        // 이사/본부장/대표이사: step1 완료 후 step2 대기 건 (부서 무관, 전체)
        final rows = await supabase
            .from('leave_requests')
            .select()
            .eq('status', 'PENDING')
            .eq('step1_status', 'APPROVED')
            .eq('step2_status', 'PENDING')
            .order('created_at', ascending: false);
        debugPrint("결과 건수: ${rows.length}");
        data = List<Map<String, dynamic>>.from(rows);
      }

      _leaveRequests = data;
    } catch (e) {
      debugPrint("휴가 신청 로드 실패: \$e");
    }
  }

  Future<void> _fetchLeaveStatus() async {
    final today     = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final yearStart = '${DateTime.now().year}-01-01';
    try {
      final profiles = await supabase
          .from('profiles')
          .select('id, full_name, dept_category, role, total_leave, used_leave')
          .order('dept_category');

      final activeLeave = await supabase
          .from('leave_requests')
          .select()
          .eq('status', 'APPROVED')
          .lte('start_date', today)
          .gte('end_date', today);

      final history = await supabase
          .from('leave_requests')
          .select()
          .eq('status', 'APPROVED')
          .gte('start_date', yearStart)
          .order('start_date', ascending: false);

      _onLeaveNow   = List<Map<String, dynamic>>.from(activeLeave);
      _leaveHistory = List<Map<String, dynamic>>.from(history);

      _profilesByDept = {};
      for (final p in List<Map<String, dynamic>>.from(profiles)) {
        final dept = p['dept_category'] ?? '기타';
        _profilesByDept.putIfAbsent(dept, () => []);
        _profilesByDept[dept]!.add(p);
      }
    } catch (e) {
      debugPrint("연차 현황 로드 실패: $e");
    }
  }

  Future<void> _updateRequestStatus(String requestId, String newStatus) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // 현재 요청 데이터 조회
      final req = await supabase
          .from('leave_requests')
          .select()
          .eq('id', requestId)
          .single();

      final step1Status = req['step1_status'] as String? ?? 'PENDING';
      final now  = DateTime.now().toIso8601String();

      // 내 직급 조회
      final myProfile = await supabase
          .from('profiles')
          .select('position, role, dept_category')
          .eq('id', user.id)
          .single();
      final myPosition = myProfile['position'] as String? ?? '';
      final myRole     = myProfile['role']     as String? ?? '';
      const step1Ranks = ['과장', '차장', '부장'];
      final isAdmin    = myRole == 'ADMIN';
      final isStep1Actor = isAdmin || step1Ranks.contains(myPosition);

      Map<String, dynamic> updateData = {};

      if (newStatus == 'REJECTED') {
        if (isStep1Actor && step1Status == 'PENDING') {
          updateData = {'status': 'REJECTED', 'step1_status': 'REJECTED', 'step1_at': now};
        } else {
          updateData = {'status': 'REJECTED', 'step2_status': 'REJECTED', 'step2_at': now};
        }
      } else if (newStatus == 'APPROVED') {
        if (isStep1Actor && step1Status == 'PENDING') {
          // step1 승인 → step2 PENDING으로
          updateData = {
            'step1_status': 'APPROVED',
            'step1_at': now,
            'step2_status': 'PENDING',
          };
        } else if (!isStep1Actor || step1Status == 'APPROVED') {
          // step2 최종 승인
          updateData = {
            'step2_status': 'APPROVED',
            'step2_at': now,
            'status': 'APPROVED',
          };
        } else if (isAdmin) {
          updateData = {'status': 'APPROVED', 'step1_status': 'APPROVED', 'step2_status': 'APPROVED'};
        }
      }

      await supabase
          .from('leave_requests')
          .update(updateData)
          .eq('id', requestId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(newStatus == 'APPROVED' ? "승인되었습니다." : "반려되었습니다."),
          behavior: SnackBarBehavior.floating,
          backgroundColor: newStatus == 'APPROVED' ? Colors.green : Colors.redAccent,
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
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text("근태 통합 관제",
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF2E6BFF),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF2E6BFF),
          indicatorWeight: 3,
          tabs: [
            const Tab(
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.punch_clock_rounded, size: 16),
                SizedBox(width: 4),
                Text("출퇴근", style: TextStyle(fontSize: 13)),
              ]),
            ),
            Tab(
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
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
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ]),
            ),
            const Tab(
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.history_rounded, size: 16),
                SizedBox(width: 4),
                Text("연차 기록", style: TextStyle(fontSize: 13)),
              ]),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                AttendanceTab(
                  dailyAttendance: _dailyAttendance,
                  onRefresh: _refreshData,
                ),
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
            ),
    );
  }
}