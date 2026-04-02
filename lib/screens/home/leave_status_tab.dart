import 'package:flutter/material.dart';
import 'attendance_helper.dart';

class LeaveStatusTab extends StatefulWidget {
  final List<Map<String, dynamic>> leaveRequests;
  final List<Map<String, dynamic>> onLeaveNow;
  final Map<String, List<Map<String, dynamic>>> profilesByDept;
  final Future<void> Function() onRefresh;
  final Future<void> Function(String id, String status) onUpdateStatus;
  final bool canApprove;

  const LeaveStatusTab({
    Key? key,
    required this.leaveRequests,
    required this.onLeaveNow,
    required this.profilesByDept,
    required this.onRefresh,
    required this.onUpdateStatus,
    this.canApprove = false,
  }) : super(key: key);

  @override
  State<LeaveStatusTab> createState() => _LeaveStatusTabState();
}

class _LeaveStatusTabState extends State<LeaveStatusTab> {
  final Set<String> _collapsedDepts = {};

  static const Map<String, String> _deptLabels = {
    'MANAGEMENT': '관리부',
    'PRODUCTION': '생산관리부',
    'SALES':      '영업부',
    'RND':        '연구소',
    'STEEL':      '스틸생산부',
    'BOX':        '박스생산부',
    'DELIVERY':   '포장납품부',
    'SSG':        '에스에스지',
    'CLEANING':   '환경미화',
    'NUTRITION':  '영양사',
  };

  static const _annualTypes = {'ANNUAL', 'HALF'};
  static bool _isAnnualDeduct(String? t) => _annualTypes.contains(t ?? 'ANNUAL');

  static String _leaveTypeLabel(String? type) => switch (type) {
    'ANNUAL'   => '연차',
    'HALF'     => '반차',
    'PUBLIC'   => '공가',
    'EVENT'    => '경조사',
    'TRAINING' => '교육',
    'SICK'     => '병가',
    _          => '연차',
  };

  static Color _leaveTypeColor(String? type) => switch (type) {
    'ANNUAL'   => Colors.orange,
    'HALF'     => Colors.deepOrange,
    'PUBLIC'   => Colors.teal,
    'EVENT'    => const Color(0xFFFF4D64),
    'TRAINING' => const Color(0xFF00897B),
    'SICK'     => Colors.blue,
    _          => Colors.orange,
  };

  static IconData _leaveTypeIcon(String? type) => switch (type) {
    'ANNUAL'   => Icons.calendar_month_rounded,
    'HALF'     => Icons.wb_sunny_rounded,
    'PUBLIC'   => Icons.account_balance_rounded,
    'EVENT'    => Icons.favorite_rounded,
    'TRAINING' => Icons.school_rounded,
    'SICK'     => Icons.local_hospital_rounded,
    _          => Icons.calendar_month_rounded,
  };

  String _deptLabel(String dept) => _deptLabels[dept] ?? dept;
  String _fmtD(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toString();
  bool _isOnLeave(String userId) =>
      widget.onLeaveNow.any((l) => l['user_id'] == userId);

  String _step2PositionByDept(String dept) => switch (dept) {
    'MANAGEMENT' => '대표이사',
    'PRODUCTION' => '이사',
    _            => '대표이사',
  };

  String _s1Name(Map<String, dynamic> item) {
    final saved = item['step1_approver_name'] as String?;
    if (saved != null && saved.isNotEmpty) return saved;
    return switch (item['dept_category'] as String? ?? '') {
      'MANAGEMENT' => '과장',
      'PRODUCTION' => '차장',
      _            => '과장',
    };
  }

  String _s2Name(Map<String, dynamic> item) {
    final saved = item['step2_approver_name'] as String?;
    if (saved != null && saved.isNotEmpty) return saved;
    return _step2PositionByDept(item['dept_category'] as String? ?? '');
  }

  void _toggleDept(String dept) => setState(() {
    _collapsedDepts.contains(dept)
        ? _collapsedDepts.remove(dept)
        : _collapsedDepts.add(dept);
  });

  void _collapseAll() =>
      setState(() => _collapsedDepts.addAll(widget.profilesByDept.keys));
  void _expandAll() => setState(() => _collapsedDepts.clear());

  @override
  Widget build(BuildContext context) {
    final allCollapsed =
        _collapsedDepts.length == widget.profilesByDept.length;

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.leaveRequests.isNotEmpty) ...[
            attendanceSectionHeader(
                "승인 대기 (${widget.leaveRequests.length})",
                Icons.pending_actions_rounded, Colors.orange),
            const SizedBox(height: 12),
            ...widget.leaveRequests
                .map((req) => _requestCard(context, req, widget.canApprove)),
            const SizedBox(height: 28),
          ],

          if (widget.onLeaveNow.isNotEmpty) ...[
            attendanceSectionHeader(
                "현재 휴가 중 (${widget.onLeaveNow.length})",
                Icons.flight_takeoff_rounded, Colors.indigo),
            const SizedBox(height: 12),
            ...widget.onLeaveNow.map(_onLeaveCard),
            const SizedBox(height: 28),
          ],

          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(
              child: attendanceSectionHeader(
                  "부서별 연차 현황",
                  Icons.people_rounded, const Color(0xFF2E6BFF)),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: allCollapsed ? _expandAll : _collapseAll,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E6BFF).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    allCollapsed
                        ? Icons.unfold_more_rounded
                        : Icons.unfold_less_rounded,
                    size: 14, color: const Color(0xFF2E6BFF),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    allCollapsed ? '전체 펼치기' : '전체 접기',
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: Color(0xFF2E6BFF)),
                  ),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          ...widget.profilesByDept.entries
              .map((e) => _deptSection(e.key, e.value)),
        ],
      ),
    );
  }

  Widget _requestCard(
      BuildContext context, Map<String, dynamic> item, bool canApprove) {
    final leaveType = item['leave_type'] as String? ?? 'ANNUAL';
    final isDeduct  = _isAnnualDeduct(leaveType);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.orange.withOpacity(0.4)),
      ),
      elevation: 0, color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item['full_name'] ?? '-',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text(_stepLabel(item),
                  style: TextStyle(fontSize: 12,
                      color: _stepColor(item), fontWeight: FontWeight.w700)),
            ]),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              _leaveTypeBadge(leaveType),
              const SizedBox(height: 4),
              Text("${item['leave_days']}일 신청",
                  style: const TextStyle(
                      color: Colors.orange, fontWeight: FontWeight.bold)),
            ]),
          ]),
          const SizedBox(height: 8),
          _stepIndicator(item),
          const SizedBox(height: 8),
          Text("기간: ${item['start_date']} ~ ${item['end_date']}",
              style: const TextStyle(fontSize: 13)),
          if (item['reason']?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text("사유: ${item['reason']}",
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(children: [
              Icon(
                isDeduct
                    ? Icons.remove_circle_outline_rounded
                    : Icons.check_circle_outline_rounded,
                size: 14,
                color: isDeduct ? Colors.orange : Colors.teal,
              ),
              const SizedBox(width: 5),
              Text(
                isDeduct
                    ? '연차 ${item['leave_days']}일 차감'
                    : '${_leaveTypeLabel(leaveType)} — 연차 미차감',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: isDeduct ? Colors.orange : Colors.teal),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          if (canApprove)
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => widget.onUpdateStatus(item['id'], 'REJECTED'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red)),
                  child: const Text("반려"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => widget.onUpdateStatus(item['id'], 'APPROVED'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text("승인",
                      style: TextStyle(color: Colors.white)),
                ),
              ),
            ])
          else
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8)),
              child: const Center(
                child: Text("열람 전용 (결재 권한 없음)",
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _onLeaveCard(Map<String, dynamic> item) {
    final leaveType = item['leave_type'] as String? ?? 'ANNUAL';
    final isDeduct  = _isAnnualDeduct(leaveType);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.withOpacity(0.08),
                   Colors.indigo.withOpacity(0.02)],
          begin: Alignment.centerLeft, end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.indigo.withOpacity(0.2)),
      ),
      child: Row(children: [
        const Icon(Icons.flight_takeoff_rounded, color: Colors.indigo, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(item['full_name'] ?? '-',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(width: 8),
              _leaveTypeBadge(leaveType),
            ]),
            const SizedBox(height: 2),
            Text("${item['start_date']} ~ ${item['end_date']}  (${item['leave_days']}일)",
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            if (!isDeduct)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text('연차 미차감',
                    style: TextStyle(fontSize: 11,
                        fontWeight: FontWeight.w700, color: Colors.teal[600])),
              ),
          ]),
        ),
        attendanceStatusBadge("휴가중", Colors.indigo),
      ]),
    );
  }

  Widget _deptSection(String dept, List<Map<String, dynamic>> profiles) {
    final color       = deptColor(dept);
    final isCollapsed = _collapsedDepts.contains(dept);
    final onLeaveCount = profiles
        .where((p) => _isOnLeave(p['id'] ?? '')).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
            blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GestureDetector(
          onTap: () => _toggleDept(dept),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: isCollapsed
                  ? BorderRadius.circular(18)
                  : const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(children: [
              Container(width: 8, height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(_deptLabel(dept),
                  style: TextStyle(fontWeight: FontWeight.w900,
                      fontSize: 14, color: color)),
              const SizedBox(width: 8),
              if (onLeaveCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: Colors.indigo, borderRadius: BorderRadius.circular(6)),
                  child: Text('휴가 $onLeaveCount명',
                      style: const TextStyle(color: Colors.white,
                          fontSize: 10, fontWeight: FontWeight.w800)),
                ),
              const Spacer(),
              Text("${profiles.length}명",
                  style: TextStyle(fontSize: 12, color: color.withOpacity(0.7))),
              const SizedBox(width: 8),
              AnimatedRotation(
                turns: isCollapsed ? 0 : 0.5,
                duration: const Duration(milliseconds: 200),
                child: Icon(Icons.keyboard_arrow_down_rounded,
                    color: color.withOpacity(0.7), size: 20),
              ),
            ]),
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState: isCollapsed
              ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: Column(children: profiles.map(_profileRow).toList()),
          secondChild: const SizedBox.shrink(),
        ),
      ]),
    );
  }

  Widget _profileRow(Map<String, dynamic> profile) {
    final total     = (profile['total_leave'] as num?)?.toDouble() ?? 0;
    final used      = (profile['used_leave']  as num?)?.toDouble() ?? 0;
    final remaining = total - used;
    final onLeave   = _isOnLeave(profile['id'] ?? '');
    final ratio     = total > 0 ? used / total : 0.0;

    final currentLeave = widget.onLeaveNow
        .where((l) => l['user_id'] == profile['id']).toList();
    final currentType = currentLeave.isNotEmpty
        ? currentLeave.first['leave_type'] as String? : null;
    final isNonDeduct = onLeave && !_isAnnualDeduct(currentType);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: onLeave ? Colors.indigo.withOpacity(0.04) : null,
        border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.08))),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(profile['full_name'] ?? '-',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(width: 8),
          if (onLeave) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                  color: Colors.indigo, borderRadius: BorderRadius.circular(6)),
              child: const Text("휴가중",
                  style: TextStyle(color: Colors.white,
                      fontSize: 10, fontWeight: FontWeight.bold)),
            ),
            if (currentType != null) ...[
              const SizedBox(width: 4),
              _leaveTypeBadge(currentType, small: true),
            ],
          ],
          const Spacer(),
          RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              children: [
                TextSpan(
                  text: "${_fmtD(remaining)}일",
                  style: TextStyle(
                      color: remaining <= 3 ? Colors.redAccent : Colors.green,
                      fontWeight: FontWeight.bold),
                ),
                TextSpan(text: "  (${_fmtD(used)}/${_fmtD(total)} 연차)"),
              ],
            ),
          ),
        ]),
        const SizedBox(height: 6),
        if (isNonDeduct)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '${_leaveTypeLabel(currentType)} 중 — 연차 차감 없음',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                  color: Colors.teal[600]),
            ),
          ),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0), minHeight: 5,
            backgroundColor: Colors.grey.withOpacity(0.12),
            valueColor: AlwaysStoppedAnimation<Color>(
              ratio > 0.8 ? Colors.redAccent
                  : ratio > 0.5 ? Colors.orange : Colors.green,
            ),
          ),
        ),
      ]),
    );
  }

  Widget _leaveTypeBadge(String? leaveType, {bool small = false}) {
    final label    = _leaveTypeLabel(leaveType);
    final color    = _leaveTypeColor(leaveType);
    final icon     = _leaveTypeIcon(leaveType);
    final isDeduct = _isAnnualDeduct(leaveType);
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: small ? 5 : 7, vertical: small ? 1 : 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: small ? 9 : 11, color: color),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(fontSize: small ? 9 : 11,
                fontWeight: FontWeight.w800, color: color)),
        if (!isDeduct) ...[
          const SizedBox(width: 3),
          Icon(Icons.shield_outlined, size: small ? 9 : 11, color: color),
        ],
      ]),
    );
  }

  String _stepLabel(Map<String, dynamic> item) {
    final step1 = item['step1_status'] as String? ?? 'PENDING';
    final step2 = item['step2_status'] as String? ?? 'WAITING';
    if (step1 == 'PENDING') return '1차 결재 대기 (${_s1Name(item)})';
    if (step1 == 'APPROVED' && step2 == 'PENDING') return '2차 결재 대기 (${_s2Name(item)})';
    return '결재 진행 중';
  }

  Color _stepColor(Map<String, dynamic> item) {
    if ((item['step1_status'] as String? ?? 'PENDING') == 'PENDING') return Colors.orange;
    return const Color(0xFF7C5CDB);
  }

  Widget _stepIndicator(Map<String, dynamic> item) {
    final step1 = item['step1_status'] as String? ?? 'PENDING';
    final step2 = item['step2_status'] as String? ?? 'WAITING';

    Widget dot(String label, String status) {
      final Color c = status == 'APPROVED' ? Colors.green
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
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10, color: c,
            fontWeight: FontWeight.w700)),
      ]);
    }

    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      dot(_s1Name(item), step1),
      Expanded(child: Divider(
          color: step1 == 'APPROVED' ? Colors.green : Colors.grey.shade300,
          thickness: 2)),
      dot(_s2Name(item), step2),
    ]);
  }
}