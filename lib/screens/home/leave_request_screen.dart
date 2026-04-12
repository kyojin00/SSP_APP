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

  static const _primary  = Color(0xFF2E6BFF);
  static const _lighter  = Color(0xFF6B9FFF);
  static const _success  = Color(0xFF00C853);
  static const _bg       = Color(0xFFF4F6FB);
  static const _text     = Color(0xFF1A1D2E);
  static const _sub      = Color(0xFF8A93B0);

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
          .from('profiles').select('full_name, dept_category')
          .eq('id', user.id).single();
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

  String _typeLabel(String type) => switch (type) {
    'HALF'     => context.tr(AppStrings.leaveHalf),
    'PUBLIC'   => context.tr(AppStrings.leavePublic),
    'EVENT'    => context.tr(AppStrings.leaveSpecial),
    'TRAINING' => context.tr({'ko': '교육', 'en': 'Training', 'vi': 'Dao tao', 'uz': "Ta'lim", 'km': 'បណ្តុះបណ្តាល'}),
    'SICK'     => context.tr({'ko': '병가', 'en': 'Sick Leave', 'vi': 'Nghi benh', 'uz': 'Kasal ta\'til', 'km': 'ច្ឈប់ជំងឺ'}),
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

  // ══════════════════════════════════════════
  // Build
  // ══════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
          backgroundColor: _bg,
          body: Center(child: CircularProgressIndicator(color: _primary)));
    }

    final remaining = _totalLeave - _usedLeave;
    final ratio     = _totalLeave > 0 ? _usedLeave / _totalLeave : 0.0;
    final dayUnit   = context.tr({'ko': '일', 'en': 'd', 'vi': 'n', 'uz': 'k', 'km': 'ថ្ងៃ'});

    final pending  = _myLeaves.where((l) => l['status'] == 'PENDING').toList();
    final approved = _myLeaves.where((l) => l['status'] == 'APPROVED').toList();
    final rejected = _myLeaves.where((l) => l['status'] == 'REJECTED').toList();

    return Scaffold(
      backgroundColor: _bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── 그라디언트 헤더
          SliverAppBar(
            expandedHeight: 230,
            pinned: true,
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            title: Text(
              context.tr(AppStrings.leaveRequest),
              style: const TextStyle(
                  fontWeight: FontWeight.w900, fontSize: 17, color: Colors.white),
            ),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1229A8), _primary, _lighter],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(children: [
                  Positioned(
                    right: -50, top: -50,
                    child: Container(width: 200, height: 200,
                        decoration: BoxDecoration(shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.07))),
                  ),
                  Positioned(
                    left: -30, bottom: -40,
                    child: Container(width: 150, height: 150,
                        decoration: BoxDecoration(shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.05))),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 90, 22, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 이름 + 남은 연차
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withOpacity(0.25)),
                            ),
                            child: Text(
                              context.tr({'ko': '연차 관리', 'en': 'Leave', 'vi': 'Nghi phep', 'uz': "Ta'til", 'km': 'ច្បាប់휴가'}),
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                          ),
                          const Spacer(),
                          // 잔여 연차 강조
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: remaining <= 3
                                  ? const Color(0xFFFF4D64).withOpacity(0.3)
                                  : Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withOpacity(0.3)),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(
                                remaining <= 3
                                    ? Icons.warning_amber_rounded
                                    : Icons.beach_access_rounded,
                                color: Colors.white, size: 13,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                context.tr({'ko': '잔여 ${_fmt(remaining)}$dayUnit', 'en': '${_fmt(remaining)}$dayUnit left', 'vi': 'Con ${_fmt(remaining)}$dayUnit', 'uz': '${_fmt(remaining)}$dayUnit qoldi', 'km': 'នៅសល់ ${_fmt(remaining)}$dayUnit'}),
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
                              ),
                            ]),
                          ),
                        ]),
                        const SizedBox(height: 14),
                        // 연차 통계 3개
                        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                          _headerStat(context.tr({'ko': '전체 연차', 'en': 'Total', 'vi': 'Tong', 'uz': 'Jami', 'km': 'សរុប'}),
                              '${_fmt(_totalLeave)}$dayUnit', Colors.white),
                          Container(width: 1, height: 32, color: Colors.white24),
                          _headerStat(context.tr({'ko': '사용 연차', 'en': 'Used', 'vi': 'Da dung', 'uz': 'Ishlatilgan', 'km': 'បានប្រើ'}),
                              '${_fmt(_usedLeave)}$dayUnit', Colors.white),
                          Container(width: 1, height: 32, color: Colors.white24),
                          _headerStat(context.tr({'ko': '잔여 연차', 'en': 'Left', 'vi': 'Con lai', 'uz': 'Qolgan', 'km': 'នៅសល់'}),
                              '${_fmt(remaining)}$dayUnit',
                              remaining <= 3 ? const Color(0xFFFF6B6B) : const Color(0xFF69F0AE)),
                        ]),
                        const SizedBox(height: 12),
                        // 진행 바
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: ratio.clamp(0.0, 1.0),
                            minHeight: 6,
                            backgroundColor: Colors.white.withOpacity(0.15),
                            valueColor: AlwaysStoppedAnimation<Color>(
                                ratio > 0.8 ? const Color(0xFFFF4D64) : _success),
                          ),
                        ),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
          ),

          // ── 본문
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 48),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ── 신청 버튼
                _RequestButton(onTap: _showLeaveSheet, context: context),
                const SizedBox(height: 24),

                // ── 대기중
                if (pending.isNotEmpty) ...[
                  _SectionTitle(
                    label: "⏳ ${context.tr({'ko': '승인 대기 중', 'en': 'Pending', 'vi': 'Cho duyet', 'uz': 'Kutilmoqda', 'km': 'កំពុងរង់ចាំ'})}",
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 10),
                  ...pending.map(_leaveCard),
                  const SizedBox(height: 24),
                ],
                // ── 승인됨
                if (approved.isNotEmpty) ...[
                  _SectionTitle(
                    label: "✅ ${context.tr({'ko': '승인된 휴가', 'en': 'Approved', 'vi': 'Da duyet', 'uz': 'Tasdiqlandi', 'km': 'បានអនុម័ត'})}",
                    color: Colors.green,
                  ),
                  const SizedBox(height: 10),
                  ...approved.map(_leaveCard),
                  const SizedBox(height: 24),
                ],
                // ── 반려됨
                if (rejected.isNotEmpty) ...[
                  _SectionTitle(
                    label: "❌ ${context.tr({'ko': '반려된 휴가', 'en': 'Rejected', 'vi': 'Da tu choi', 'uz': 'Rad etildi', 'km': 'បានបដិសេធ'})}",
                    color: Colors.redAccent,
                  ),
                  const SizedBox(height: 10),
                  ...rejected.map(_leaveCard),
                ],
                // ── 비어있을 때
                if (_myLeaves.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Column(children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 4))],
                          ),
                          child: Icon(Icons.event_busy_rounded, size: 40, color: Colors.grey.withOpacity(0.4)),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          context.tr({'ko': '신청한 휴가가 없습니다.', 'en': 'No leave requests.', 'vi': 'Chua co yeu cau nghi.', 'uz': "Hech qanday ta'til so'rovi yo'q.", 'km': 'គ្មានការស្នើសុំ휴가ទេ។'}),
                          style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
                        ),
                      ]),
                    ),
                  ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerStat(String label, String value, Color valueColor) {
    return Column(children: [
      Text(label, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11, fontWeight: FontWeight.w600)),
      const SizedBox(height: 5),
      Text(value, style: TextStyle(color: valueColor, fontSize: 20, fontWeight: FontWeight.w900)),
    ]);
  }

  // ── 휴가 카드
  Widget _leaveCard(Map<String, dynamic> item) {
    final status    = item['status']     as String? ?? '';
    final leaveType = item['leave_type'] as String? ?? 'ANNUAL';
    final dept      = (item['dept_category'] as String?)?.isNotEmpty == true
        ? item['dept_category'] as String
        : (widget.userProfile['dept_category'] as String? ?? '');
    final days   = (item['leave_days'] as num?)?.toDouble() ?? 0;
    final start  = item['start_date']    as String? ?? '';
    final end    = item['end_date']      as String? ?? '';
    final reason = item['reason']        as String? ?? '';
    final step1  = item['step1_status']  as String? ?? 'PENDING';
    final step2  = item['step2_status']  as String? ?? 'WAITING';

    final step1Name = (item['step1_approver_name'] as String?)?.isNotEmpty == true
        ? item['step1_approver_name'] as String : _step1Position(dept);
    final step2Name = (item['step2_approver_name'] as String?)?.isNotEmpty == true
        ? item['step2_approver_name'] as String : _step2Position(dept);

    final Color statusColor;
    final String statusLabel;
    final IconData statusIcon;

    switch (status) {
      case 'APPROVED':
        statusColor = Colors.green;
        statusLabel = context.tr({'ko': '승인완료', 'en': 'Approved', 'vi': 'Da duyet', 'uz': 'Tasdiqlandi', 'km': 'អនុម័តហើយ'});
        statusIcon  = Icons.check_circle_rounded;
        break;
      case 'REJECTED':
        statusColor = Colors.redAccent;
        statusLabel = context.tr({'ko': '반려', 'en': 'Rejected', 'vi': 'Tu choi', 'uz': 'Rad etildi', 'km': 'បដិសេធ'});
        statusIcon  = Icons.cancel_rounded;
        break;
      default: // PENDING
        if (step1 == 'PENDING') {
          statusColor = Colors.orange;
          statusLabel = context.tr({'ko': '$step1Name 검토중', 'en': '$step1Name reviewing', 'vi': '$step1Name dang xem', 'uz': "$step1Name ko'rib chiqmoqda", 'km': '$step1Name កំពុងពិនិត្យ'});
        } else if (step1 == 'APPROVED' && step2 == 'PENDING') {
          statusColor = const Color(0xFF7C5CDB);
          statusLabel = context.tr({'ko': '$step2Name 검토중', 'en': '$step2Name reviewing', 'vi': '$step2Name dang xem', 'uz': "$step2Name ko'rib chiqmoqda", 'km': '$step2Name កំពុងពិនិត្យ'});
        } else {
          statusColor = Colors.orange;
          statusLabel = context.tr({'ko': '대기중', 'en': 'Waiting', 'vi': 'Cho', 'uz': 'Kutilmoqda', 'km': 'រង់ចាំ'});
        }
        statusIcon = Icons.hourglass_top_rounded;
    }

    final typeColor = _typeColor(leaveType);
    final typeIcon  = _typeIcon(leaveType);
    final deducts   = _typeDeducts(leaveType);
    final dayUnit   = context.tr({'ko': '일', 'en': 'd', 'vi': 'n', 'uz': 'k', 'km': 'ថ្ងៃ'});

    String fmtDate(String d) {
      if (d.length < 10) return d;
      return '${d.substring(5, 7)}/${d.substring(8, 10)}';
    }

    final dateStr = start == end
        ? fmtDate(start)
        : '${fmtDate(start)} ~ ${fmtDate(end)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.10),
            blurRadius: 14, offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6, offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: [
        // ── 카드 상단: 아이콘 + 날짜 + 상태
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Row(children: [
            // 타입 그라디언트 아이콘
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _lighten(typeColor, 0.18),
                    typeColor,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(typeIcon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(
                    _typeLabel(leaveType),
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: typeColor),
                  ),
                  const SizedBox(width: 6),
                  if (!deducts)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: typeColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: typeColor.withOpacity(0.2)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.shield_rounded, size: 9, color: typeColor),
                        const SizedBox(width: 2),
                        Text(context.tr({'ko': '차감없음', 'en': 'No deduct', 'vi': 'Khong tru', 'uz': 'Ayrilmaydi', 'km': 'មិនកាត់'}),
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: typeColor)),
                      ]),
                    ),
                ]),
                const SizedBox(height: 3),
                Text(
                  '$dateStr  ·  ${_fmt(days)}$dayUnit',
                  style: const TextStyle(fontSize: 12, color: _sub, fontWeight: FontWeight.w600),
                ),
              ]),
            ),
            // 상태 뱃지
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(statusIcon, size: 12, color: statusColor),
                const SizedBox(width: 4),
                Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w800)),
              ]),
            ),
          ]),
        ),

        // ── 결재 단계 인디케이터 (PENDING일 때만)
        if (status == 'PENDING') ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F6FB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                _stepDot(step1Name, step1),
                Expanded(child: Container(height: 2, color: step1 == 'APPROVED' ? Colors.green : Colors.grey.shade200)),
                _stepDot(step2Name, step2),
              ]),
            ),
          ),
          const SizedBox(height: 10),
        ],

        // ── 사유
        if (reason.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.fromLTRB(16, status == 'PENDING' ? 0 : 0, 16, 0),
            child: Row(children: [
              Icon(Icons.notes_rounded, size: 13, color: _sub),
              const SizedBox(width: 6),
              Expanded(child: Text(reason, style: const TextStyle(fontSize: 12, color: _sub))),
            ]),
          ),
          const SizedBox(height: 12),
        ] else ...[
          const SizedBox(height: 2),
        ],

        // ── 구분선 + 취소 버튼 (PENDING일 때만)
        if (status == 'PENDING') ...[
          Divider(height: 1, color: Colors.black.withOpacity(0.06)),
          TextButton(
            onPressed: () => _cancelLeave(item['id'] as String),
            style: TextButton.styleFrom(
              foregroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(vertical: 12),
              minimumSize: const Size(double.infinity, 0),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
            ),
            child: Text(
              context.tr({'ko': '신청 취소', 'en': 'Cancel Request', 'vi': 'Huy don', 'uz': 'Bekor qilish', 'km': 'បោះបង់ការស្នើ'}),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ] else
          const SizedBox(height: 14),
      ]),
    );
  }

  Widget _stepDot(String name, String status) {
    final Color c = status == 'APPROVED'
        ? Colors.green
        : status == 'PENDING' ? Colors.orange
        : status == 'REJECTED' ? Colors.redAccent
        : Colors.grey.shade300;
    final IconData icon = status == 'APPROVED'
        ? Icons.check_circle_rounded
        : status == 'REJECTED' ? Icons.cancel_rounded
        : status == 'PENDING' ? Icons.radio_button_checked_rounded
        : Icons.radio_button_unchecked_rounded;
    return Column(children: [
      Icon(icon, color: c, size: 20),
      const SizedBox(height: 3),
      Text(name, style: TextStyle(fontSize: 10, color: c, fontWeight: FontWeight.w700)),
    ]);
  }

  Future<void> _cancelLeave(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(context.tr({'ko': '신청 취소', 'en': 'Cancel Request', 'vi': 'Huy don', 'uz': 'Bekor qilish', 'km': 'បោះបង់'}),
            style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Text(context.tr({'ko': '휴가 신청을 취소하시겠습니까?', 'en': 'Cancel this leave request?', 'vi': 'Ban co muon huy don nghi khong?', 'uz': "Ta'til so'rovini bekor qilasizmi?", 'km': 'តើអ្នកចង់បោះបង់ការស្នើសុំ휴가ទេ?'}),
            style: const TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr(AppStrings.no2), style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.tr({'ko': '취소하기', 'en': 'Cancel', 'vi': 'Huy', 'uz': 'Bekor', 'km': 'បោះបង់'}),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await supabase.from('leave_requests').delete().eq('id', id);
      await _fetchLeaveData();
      _showSnackBar(context.tr({'ko': '신청이 취소되었습니다.', 'en': 'Request cancelled.', 'vi': 'Da huy don.', 'uz': 'Bekor qilindi.', 'km': 'បានបោះបង់ការស្នើ។'}));
    } catch (e) {
      _showSnackBar(context.tr({'ko': '취소 중 오류가 발생했습니다.', 'en': 'Error cancelling request.', 'vi': 'Co loi khi huy.', 'uz': 'Xato yuz berdi.', 'km': 'មានកំហុសកើតឡើង។'}));
    }
  }

  // 색상 밝게 헬퍼
  Color _lighten(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
  }
}

// ══════════════════════════════════════════
// 섹션 타이틀
// ══════════════════════════════════════════
class _SectionTitle extends StatelessWidget {
  final String label;
  final Color color;
  const _SectionTitle({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 4, height: 18,
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(2)),
      ),
      const SizedBox(width: 8),
      Text(label, style: const TextStyle(
          fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF1A1D2E))),
    ]);
  }
}

// ══════════════════════════════════════════
// 휴가 신청하기 버튼
// ══════════════════════════════════════════
class _RequestButton extends StatefulWidget {
  final VoidCallback onTap;
  final BuildContext context;
  const _RequestButton({required this.onTap, required this.context});

  @override
  State<_RequestButton> createState() => _RequestButtonState();
}

class _RequestButtonState extends State<_RequestButton> {
  bool _pressed = false;

  static const _primary  = Color(0xFF2E6BFF);
  static const _lighter  = Color(0xFF6B9FFF);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapUp:     (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: ()  => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_lighter, _primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: _pressed
                ? []
                : [BoxShadow(
                    color: _primary.withOpacity(0.38),
                    blurRadius: 14, offset: const Offset(0, 6))],
          ),
          child: Stack(children: [
            Positioned(
              top: -20, right: -10,
              child: Container(
                width: 70, height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.10),
                ),
              ),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.22),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.edit_calendar_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                context.tr({'ko': '휴가 신청하기', 'en': 'Request Leave', 'vi': 'Dang ky nghi', 'uz': "Ta'til so'rash", 'km': 'ស្នើសុំ휴가'}),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}