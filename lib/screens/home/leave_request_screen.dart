import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'leave_calendar_sheet.dart';
import 'app_strings.dart';
import 'lang_context.dart';

class LeaveRequestScreen extends StatefulWidget {
  final Map<String, dynamic> userProfile;
  const LeaveRequestScreen({Key? key, required this.userProfile}) : super(key: key);

  @override
  State<LeaveRequestScreen> createState() => _LeaveRequestScreenState();
}

class _LeaveRequestScreenState extends State<LeaveRequestScreen> {
  final supabase = Supabase.instance.client;

  bool   _isLoading  = true;
  double _totalLeave = 0;
  double _usedLeave  = 0;
  List<Map<String, dynamic>> _myLeaves = [];

  static const _primary = Color(0xFF2E6BFF);
  static const _success = Color(0xFF00C853);
  static const _bg      = Color(0xFFF4F6FB);
  static const _text    = Color(0xFF1A1D2E);
  static const _sub     = Color(0xFF8A93B0);

  String _step1Position(String dept) {
    switch (dept) {
      case 'MANAGEMENT': return '과장';
      case 'PRODUCTION': return '차장';
      default:           return '과장';
    }
  }

  String _step2Position(String dept) {
    switch (dept) {
      case 'MANAGEMENT': return '대표이사';
      case 'PRODUCTION': return '이사';
      default:           return '대표이사';
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchLeaveData();
  }

  Future<void> _fetchLeaveData() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      final results = await Future.wait([
        supabase.from('profiles').select('total_leave, used_leave')
            .eq('id', user.id).single(),
        supabase.from('leave_requests').select()
            .eq('user_id', user.id)
            .order('start_date', ascending: false),
      ]);
      if (mounted) {
        final profile = results[0] as Map<String, dynamic>;
        final leaves  = results[1] as List<dynamic>;
        setState(() {
          _totalLeave = (profile['total_leave'] as num?)?.toDouble() ?? 0;
          _usedLeave  = (profile['used_leave']  as num?)?.toDouble() ?? 0;
          _myLeaves   = List<Map<String, dynamic>>.from(leaves);
          _isLoading  = false;
        });
      }
    } catch (e) {
      debugPrint("연차 로드 실패: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showLeaveSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LeaveCalendarSheet(
        totalLeave: _totalLeave,
        usedLeave:  _usedLeave,
        onSubmit:   _submitLeaveRequest,
      ),
    );
  }

  Future<void> _submitLeaveRequest(
    DateTime start, DateTime end, double days, String reason, String type,
  ) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      final myProfile = await supabase
          .from('profiles')
          .select('full_name, dept_category')
          .eq('id', user.id)
          .single();
      final fullName = (myProfile['full_name'] as String?) ?? '';
      final dept     = (myProfile['dept_category'] as String?) ?? '';

      final step1Position = _step1Position(dept);
      final step2Position = _step2Position(dept);

      final approverResults = await Future.wait([
        supabase.from('profiles').select('id, full_name')
            .eq('position', step1Position).limit(1),
        supabase.from('profiles').select('id, full_name')
            .eq('position', step2Position).limit(1),
      ]);

      final step1List = approverResults[0] as List;
      final step2List = approverResults[1] as List;

      String? step1ApproverId;
      String  step1ApproverName = step1Position;
      String? step2ApproverId;
      String  step2ApproverName = step2Position;

      if (step1List.isNotEmpty) {
        final a = step1List.first as Map<String, dynamic>;
        step1ApproverId   = a['id'] as String?;
        step1ApproverName = (a['full_name'] as String?) ?? step1Position;
      }
      if (step2List.isNotEmpty) {
        final a = step2List.first as Map<String, dynamic>;
        step2ApproverId   = a['id'] as String?;
        step2ApproverName = (a['full_name'] as String?) ?? step2Position;
      }

      await supabase.from('leave_requests').insert({
        'user_id':             user.id,
        'full_name':           fullName,
        'dept_category':       dept,
        'start_date':          DateFormat('yyyy-MM-dd').format(start),
        'end_date':            DateFormat('yyyy-MM-dd').format(end),
        'leave_days':          days,
        'reason':              reason,
        'leave_type':          type,
        'status':              'PENDING',
        'step1_status':        'PENDING',
        'step1_approver_id':   step1ApproverId,
        'step1_approver_name': step1ApproverName,
        'step2_status':        'WAITING',
        'step2_approver_id':   step2ApproverId,
        'step2_approver_name': step2ApproverName,
      });

      await _fetchLeaveData();
      _showSnackBar(context.tr({
        'ko': '신청 완료! $step1ApproverName 승인을 기다려주세요. ✅',
        'en': 'Submitted! Waiting for $step1ApproverName\'s approval. ✅',
        'vi': 'Da gui! Cho $step1ApproverName phe duyet. ✅',
        'uz': 'Yuborildi! $step1ApproverName tasdiqlashi kutilmoqda. ✅',
        'km': 'បានដាក់ស្នើ! កំពុងរង់ចាំការអនុម័តពី $step1ApproverName។ ✅',
      }));
    } catch (e) {
      debugPrint("휴가 신청 실패: $e");
      _showSnackBar(context.tr({
        'ko': '신청 중 오류가 발생했습니다.',
        'en': 'An error occurred. Please try again.',
        'vi': 'Co loi xay ra. Vui long thu lai.',
        'uz': 'Xato yuz berdi. Qayta urining.',
        'km': 'មានកំហុសកើតឡើង។ សូមព្យាយាមម្តងទៀត។',
      }));
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ));
  }

  String _fmt(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toString();

  // ── 휴가 종류별 라벨 / 색상 / 아이콘 ──────────────
  String _typeLabel(String type) => switch (type) {
    'HALF'     => context.tr(AppStrings.leaveHalf),
    'PUBLIC'   => context.tr(AppStrings.leavePublic),
    'EVENT'    => context.tr(AppStrings.leaveSpecial),
    'TRAINING' => context.tr({'ko': '교육', 'en': 'Training',
                               'vi': 'Dao tao', 'uz': "Ta'lim",
                               'km': 'បណ្តុះបណ្តាល'}),
    'SICK'     => context.tr({'ko': '병가', 'en': 'Sick Leave',
                               'vi': 'Nghi benh', 'uz': 'Kasal ta\'til',
                               'km': 'ច្ឈប់ជំងឺ'}),
    _          => context.tr(AppStrings.leaveAnnual),
  };

  Color _typeColor(String type) => switch (type) {
    'HALF'     => const Color(0xFFFF9500),
    'PUBLIC'   => const Color(0xFF7C5CDB),
    'EVENT'    => const Color(0xFFFF4D64),
    'TRAINING' => const Color(0xFF00897B),
    'SICK'     => Colors.blue,
    _          => _primary,
  };

  IconData _typeIcon(String type) => switch (type) {
    'HALF'     => Icons.wb_sunny_rounded,
    'PUBLIC'   => Icons.account_balance_rounded,
    'EVENT'    => Icons.favorite_rounded,
    'TRAINING' => Icons.school_rounded,
    'SICK'     => Icons.local_hospital_rounded,
    _          => Icons.calendar_month_rounded,
  };

  bool _typeDeducts(String type) => type == 'ANNUAL' || type == 'HALF';

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator(color: _primary)));
    }

    final remaining = _totalLeave - _usedLeave;
    final ratio     = _totalLeave > 0 ? _usedLeave / _totalLeave : 0.0;

    final pending  = _myLeaves.where((l) => l['status'] == 'PENDING').toList();
    final approved = _myLeaves.where((l) => l['status'] == 'APPROVED').toList();
    final rejected = _myLeaves.where((l) => l['status'] == 'REJECTED').toList();

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: Text(context.tr(AppStrings.leaveRequest),
            style: const TextStyle(
                fontWeight: FontWeight.w900, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: _text,
        elevation: 0,
        surfaceTintColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFF0F2F8)),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchLeaveData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _leaveSummaryCard(remaining, ratio),
              const SizedBox(height: 16),
              _leaveRequestButton(),
              const SizedBox(height: 28),

              if (pending.isNotEmpty) ...[
                _sectionTitle(
                    "⏳ ${context.tr({'ko': '승인 대기 중', 'en': 'Pending',
                                     'vi': 'Cho duyet', 'uz': 'Kutilmoqda',
                                     'km': 'កំពុងរង់ចាំ'})}",
                    Colors.orange),
                const SizedBox(height: 10),
                ...pending.map(_leaveCard),
                const SizedBox(height: 24),
              ],
              if (approved.isNotEmpty) ...[
                _sectionTitle(
                    "✅ ${context.tr({'ko': '승인된 휴가', 'en': 'Approved',
                                     'vi': 'Da duyet', 'uz': 'Tasdiqlandi',
                                     'km': 'បានអនុម័ត'})}",
                    Colors.green),
                const SizedBox(height: 10),
                ...approved.map(_leaveCard),
                const SizedBox(height: 24),
              ],
              if (rejected.isNotEmpty) ...[
                _sectionTitle(
                    "❌ ${context.tr({'ko': '반려된 휴가', 'en': 'Rejected',
                                     'vi': 'Da tu choi', 'uz': 'Rad etildi',
                                     'km': 'បានបដិសេធ'})}",
                    Colors.redAccent),
                const SizedBox(height: 10),
                ...rejected.map(_leaveCard),
              ],
              if (_myLeaves.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Column(children: [
                      Icon(Icons.event_busy_rounded,
                          size: 48,
                          color: Colors.grey.withOpacity(0.4)),
                      const SizedBox(height: 12),
                      Text(
                          context.tr({'ko': '신청한 휴가가 없습니다.',
                                      'en': 'No leave requests.',
                                      'vi': 'Chua co yeu cau nghi.',
                                      'uz': "Hech qanday ta'til so'rovi yo'q.",
                                      'km': 'គ្មានការស្នើសុំ휴가ទេ។'}),
                          style: const TextStyle(color: Colors.grey)),
                    ]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, Color color) {
    return Row(children: [
      Container(width: 4, height: 18,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(title,
          style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w900, color: _text)),
    ]);
  }

  Widget _leaveCard(Map<String, dynamic> item) {
    final status    = item['status']        as String? ?? '';
    final leaveType = item['leave_type']    as String? ?? 'ANNUAL';
    final dept      = (item['dept_category'] as String?)?.isNotEmpty == true
        ? item['dept_category'] as String
        : (widget.userProfile['dept_category'] as String? ?? '');
    final days  = (item['leave_days'] as num?)?.toDouble() ?? 0;
    final start = item['start_date']   as String? ?? '';
    final end   = item['end_date']     as String? ?? '';
    final reason = item['reason']      as String? ?? '';
    final step1  = item['step1_status'] as String? ?? 'PENDING';
    final step2  = item['step2_status'] as String? ?? 'WAITING';

    final step1Name = (item['step1_approver_name'] as String?)?.isNotEmpty == true
        ? item['step1_approver_name'] as String
        : _step1Position(dept);
    final step2Name = (item['step2_approver_name'] as String?)?.isNotEmpty == true
        ? item['step2_approver_name'] as String
        : _step2Position(dept);

    final Color statusColor;
    final String statusLabel;

    switch (status) {
      case 'APPROVED':
        statusColor = Colors.green;
        statusLabel = context.tr({'ko': '승인완료', 'en': 'Approved',
                                  'vi': 'Da duyet', 'uz': 'Tasdiqlandi',
                                  'km': 'អនុម័តហើយ'});
        break;
      case 'REJECTED':
        statusColor = Colors.redAccent;
        statusLabel = context.tr({'ko': '반려', 'en': 'Rejected',
                                  'vi': 'Tu choi', 'uz': 'Rad etildi',
                                  'km': 'បដិសេធ'});
        break;
      case 'PENDING':
        if (step1 == 'PENDING') {
          statusColor = Colors.orange;
          statusLabel = context.tr({'ko': '$step1Name 검토중',
                                    'en': '$step1Name reviewing',
                                    'vi': '$step1Name dang xem',
                                    'uz': "$step1Name ko'rib chiqmoqda",
                                    'km': '$step1Name កំពុងពិនិត្យ'});
        } else if (step1 == 'APPROVED' && step2 == 'PENDING') {
          statusColor = const Color(0xFF7C5CDB);
          statusLabel = context.tr({'ko': '$step2Name 검토중',
                                    'en': '$step2Name reviewing',
                                    'vi': '$step2Name dang xem',
                                    'uz': "$step2Name ko'rib chiqmoqda",
                                    'km': '$step2Name កំពុងពិនិត្យ'});
        } else {
          statusColor = Colors.orange;
          statusLabel = context.tr({'ko': '대기중', 'en': 'Waiting',
                                    'vi': 'Cho', 'uz': 'Kutilmoqda',
                                    'km': 'រង់ចាំ'});
        }
        break;
      default:
        statusColor = Colors.grey;
        statusLabel = status;
    }

    final typeLabel = _typeLabel(leaveType);
    final typeColor = _typeColor(leaveType);
    final typeIcon  = _typeIcon(leaveType);
    final deducts   = _typeDeducts(leaveType);

    String fmtDate(String d) {
      if (d.length < 10) return d;
      return '${d.substring(5, 7)}/${d.substring(8, 10)}';
    }

    final dateStr = start == end
        ? fmtDate(start)
        : '${fmtDate(start)} ~ ${fmtDate(end)}';

    final dayUnit = context.tr(
        {'ko': '일', 'en': 'd', 'vi': 'n', 'uz': 'k', 'km': 'ថ្ងៃ'});

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3))],
        border: Border.all(color: statusColor.withOpacity(0.15)),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
              color: typeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(typeIcon, color: typeColor, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6)),
                child: Text(typeLabel,
                    style: TextStyle(
                        color: typeColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w800)),
              ),
              if (!deducts) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    context.tr({'ko': '연차 미차감', 'en': 'No deduction',
                                'vi': 'Khong tru phep',
                                'uz': 'Chegirmaydi', 'km': 'មិនកាត់'}),
                    style: const TextStyle(
                        color: _sub,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
                ),
              ],
              const SizedBox(width: 6),
              Text(dateStr,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: _text)),
            ]),
            const SizedBox(height: 4),
            Text(
              deducts
                  ? "${_fmt(days)}$dayUnit${reason.isNotEmpty ? '  ·  $reason' : ''}"
                  : reason.isNotEmpty
                      ? reason
                      : "${_fmt(days)}$dayUnit",
              style: const TextStyle(fontSize: 12, color: _sub),
            ),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10)),
          child: Text(statusLabel,
              style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }

  Widget _leaveSummaryCard(double remaining, double ratio) {
    final dayUnit = context.tr(
        {'ko': '일', 'en': 'd', 'vi': 'n', 'uz': 'k', 'km': 'ថ្ងៃ'});
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF334155)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(
            color: const Color(0xFF1E293B).withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 8))],
      ),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _statUnit(
              context.tr({'ko': '전체 연차', 'en': 'Total', 'vi': 'Tong',
                          'uz': 'Jami', 'km': 'សរុប'}),
              "${_fmt(_totalLeave)}$dayUnit"),
          Container(width: 1, height: 32, color: Colors.white12),
          _statUnit(
              context.tr({'ko': '사용 연차', 'en': 'Used', 'vi': 'Da dung',
                          'uz': 'Ishlatilgan', 'km': 'បានប្រើ'}),
              "${_fmt(_usedLeave)}$dayUnit"),
          Container(width: 1, height: 32, color: Colors.white12),
          _statUnit(
              context.tr({'ko': '잔여 연차', 'en': 'Left', 'vi': 'Con lai',
                          'uz': 'Qolgan', 'km': 'នៅសល់'}),
              "${_fmt(remaining)}$dayUnit",
              highlight: remaining <= 3),
        ]),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(
              "${context.tr({'ko': '사용률', 'en': 'Usage', 'vi': 'Ti le',
                             'uz': 'Foydalanish', 'km': 'ការប្រើប្រាស់'})} "
              "${(ratio * 100).toStringAsFixed(0)}%",
              style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          Text("${_fmt(_usedLeave)} / ${_fmt(_totalLeave)}$dayUnit",
              style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0),
            minHeight: 5,
            backgroundColor: Colors.white.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(
                ratio > 0.8 ? const Color(0xFFFF4D64) : _success),
          ),
        ),
      ]),
    );
  }

  Widget _statUnit(String label, String value, {bool highlight = false}) {
    return Column(children: [
      Text(label,
          style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 11,
              fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Text(value,
          style: TextStyle(
              color: highlight ? const Color(0xFFFF4D64) : Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900)),
    ]);
  }

  Widget _leaveRequestButton() {
    return GestureDetector(
      onTap: _showLeaveSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _primary.withOpacity(0.15)),
          boxShadow: [BoxShadow(
              color: _primary.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4))],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.edit_calendar_rounded,
              color: _primary, size: 20),
          const SizedBox(width: 10),
          Text(
              context.tr({'ko': '휴가 신청하기', 'en': 'Request Leave',
                          'vi': 'Dang ky nghi', 'uz': "Ta'til so'rash",
                          'km': 'ស្នើសុំ휴가'}),
              style: const TextStyle(
                  color: _primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 15)),
        ]),
      ),
    );
  }
}