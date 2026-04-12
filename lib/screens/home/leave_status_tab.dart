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

  static const _primary = Color(0xFF3D5AFE);
  static const _text    = Color(0xFF1A1D2E);
  static const _sub     = Color(0xFF8A93B0);
  static const _bg      = Color(0xFFF4F6FB);

  static const Map<String, String> _deptLabels = {
    'MANAGEMENT': '관리부',   'PRODUCTION': '생산관리부',
    'SALES':      '영업부',   'RND':        '연구소',
    'STEEL':      '스틸생산부','BOX':        '박스생산부',
    'DELIVERY':   '포장납품부','SSG':        '에스에스지',
    'CLEANING':   '환경미화', 'NUTRITION':  '영양사',
  };

  static const _annualTypes = {'ANNUAL', 'HALF'};
  static bool _isAnnualDeduct(String? t) => _annualTypes.contains(t ?? 'ANNUAL');

  static String _leaveTypeLabel(String? type) => switch (type) {
    'ANNUAL'   => '연차',  'HALF'     => '반차',
    'PUBLIC'   => '공가',  'EVENT'    => '경조사',
    'TRAINING' => '교육',  'SICK'     => '병가',
    _          => '연차',
  };
  static Color _leaveTypeColor(String? type) => switch (type) {
    'ANNUAL'   => const Color(0xFFFF8C42),
    'HALF'     => Colors.deepOrange,
    'PUBLIC'   => Colors.teal,
    'EVENT'    => const Color(0xFFFF4D64),
    'TRAINING' => const Color(0xFF00897B),
    'SICK'     => const Color(0xFF2E6BFF),
    _          => const Color(0xFFFF8C42),
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

  String _dl(String dept) => _deptLabels[dept] ?? dept;
  String _fmtD(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toString();
  bool _isOnLeave(String userId) =>
      widget.onLeaveNow.any((l) => l['user_id'] == userId);

  Color _lighten(Color c, double a) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + a).clamp(0.0, 1.0)).toColor();
  }

  String _s1Name(Map<String, dynamic> item) {
    final saved = item['step1_approver_name'] as String?;
    if (saved != null && saved.isNotEmpty) return saved;
    return switch (item['dept_category'] as String? ?? '') {
      'MANAGEMENT' => '과장', 'PRODUCTION' => '차장', _ => '과장',
    };
  }
  String _s2Name(Map<String, dynamic> item) {
    final saved = item['step2_approver_name'] as String?;
    if (saved != null && saved.isNotEmpty) return saved;
    return switch (item['dept_category'] as String? ?? '') {
      'MANAGEMENT' => '대표이사', 'PRODUCTION' => '이사', _ => '대표이사',
    };
  }

  void _toggleDept(String dept) => setState(() =>
      _collapsedDepts.contains(dept)
          ? _collapsedDepts.remove(dept)
          : _collapsedDepts.add(dept));
  void _collapseAll() =>
      setState(() => _collapsedDepts.addAll(widget.profilesByDept.keys));
  void _expandAll() => setState(() => _collapsedDepts.clear());

  @override
  Widget build(BuildContext context) {
    final allCollapsed =
        _collapsedDepts.length == widget.profilesByDept.length;

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      color: _primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 40),
        children: [
          // ── 승인 대기
          if (widget.leaveRequests.isNotEmpty) ...[
            _sectionHeader(
                '승인 대기 ${widget.leaveRequests.length}건',
                Icons.pending_actions_rounded,
                Colors.orange),
            const SizedBox(height: 10),
            ...widget.leaveRequests.map(
                (req) => _requestCard(context, req, widget.canApprove)),
            const SizedBox(height: 24),
          ],

          // ── 현재 휴가 중
          if (widget.onLeaveNow.isNotEmpty) ...[
            _sectionHeader(
                '현재 휴가 중 ${widget.onLeaveNow.length}명',
                Icons.flight_takeoff_rounded,
                Colors.indigo),
            const SizedBox(height: 10),
            ...widget.onLeaveNow.map(_onLeaveCard),
            const SizedBox(height: 24),
          ],

          // ── 부서별 연차 현황 헤더
          Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_lighten(_primary, 0.15), _primary],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [BoxShadow(
                    color: _primary.withOpacity(0.25), blurRadius: 6,
                    offset: const Offset(0, 2))],
              ),
              child: const Icon(Icons.people_rounded,
                  color: Colors.white, size: 15),
            ),
            const SizedBox(width: 10),
            const Text('부서별 연차 현황',
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w900, color: _text)),
            const Spacer(),
            GestureDetector(
              onTap: allCollapsed ? _expandAll : _collapseAll,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: _primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    allCollapsed
                        ? Icons.unfold_more_rounded
                        : Icons.unfold_less_rounded,
                    size: 14, color: _primary),
                  const SizedBox(width: 4),
                  Text(allCollapsed ? '전체 펼치기' : '전체 접기',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700,
                          color: _primary)),
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

  Widget _sectionHeader(String title, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_lighten(color, 0.20), color],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
            color: color.withOpacity(0.25), blurRadius: 8,
            offset: const Offset(0, 3))],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.22),
              shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 15),
        ),
        const SizedBox(width: 10),
        Text(title,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w900,
                color: Colors.white)),
      ]),
    );
  }

  // ── 승인 대기 카드
  Widget _requestCard(
      BuildContext context, Map<String, dynamic> item, bool canApprove) {
    final leaveType = item['leave_type'] as String? ?? 'ANNUAL';
    final isDeduct  = _isAnnualDeduct(leaveType);
    final tc        = _leaveTypeColor(leaveType);
    final name      = item['full_name']  as String? ?? '-';
    final dept      = item['dept_category'] as String? ?? '';
    final dc        = deptColor(dept);
    final step1     = item['step1_status'] as String? ?? 'PENDING';
    final step2     = item['step2_status'] as String? ?? 'WAITING';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.orange.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(color: Colors.orange.withOpacity(0.08),
              blurRadius: 12, offset: const Offset(0, 4)),
          BoxShadow(color: Colors.black.withOpacity(0.04),
              blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(children: [
          // 상단 컬러 바
          Container(height: 3,
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [_lighten(tc, 0.15), tc]))),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(children: [
              Row(children: [
                // 아바타
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [_lighten(dc, 0.18), dc],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(
                        color: dc.withOpacity(0.25), blurRadius: 6,
                        offset: const Offset(0, 2))],
                  ),
                  child: Center(child: Text(
                    name.isNotEmpty ? name.substring(0, 1) : '?',
                    style: const TextStyle(fontSize: 16,
                        fontWeight: FontWeight.w900, color: Colors.white),
                  )),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(name, style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 14, color: _text)),
                    const SizedBox(width: 7),
                    _leaveTypeBadge(leaveType),
                  ]),
                  const SizedBox(height: 3),
                  Text(
                    '${item['start_date']} ~ ${item['end_date']}  '
                    '(${item['leave_days']}일)',
                    style: const TextStyle(fontSize: 11, color: _sub)),
                ])),
                // 대기 뱃지
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [_lighten(Colors.orange, 0.15),
                            Colors.orange.shade600],
                        begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [BoxShadow(
                        color: Colors.orange.withOpacity(0.22),
                        blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                  child: const Text('대기중',
                      style: TextStyle(color: Colors.white,
                          fontSize: 11, fontWeight: FontWeight.w900)),
                ),
              ]),

              // 결재 단계 표시
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _stepIndicator(item),
              ),

              // 승인/반려 버튼
              if (canApprove) ...[
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: GestureDetector(
                    onTap: () => widget.onUpdateStatus(
                        item['id'] as String, 'REJECTED'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                          color: const Color(0xFFFF4D64).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFFFF4D64).withOpacity(0.25))),
                      child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                        Icon(Icons.close_rounded,
                            color: Color(0xFFFF4D64), size: 16),
                        SizedBox(width: 6),
                        Text('반려', style: TextStyle(
                            color: Color(0xFFFF4D64),
                            fontWeight: FontWeight.w900, fontSize: 14)),
                      ]),
                    ),
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: GestureDetector(
                    onTap: () => widget.onUpdateStatus(
                        item['id'] as String, 'APPROVED'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                            colors: [_lighten(Colors.green, 0.12),
                                Colors.green.shade600],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(
                            color: Colors.green.withOpacity(0.28),
                            blurRadius: 8, offset: const Offset(0, 3))],
                      ),
                      child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                        Icon(Icons.check_rounded,
                            color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Text('승인', style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900, fontSize: 14)),
                      ]),
                    ),
                  )),
                ]),
              ],
            ]),
          ),
        ]),
      ),
    );
  }

  // ── 현재 휴가 중 카드
  Widget _onLeaveCard(Map<String, dynamic> item) {
    final leaveType = item['leave_type'] as String? ?? 'ANNUAL';
    final tc        = _leaveTypeColor(leaveType);
    final name      = item['full_name']  as String? ?? '-';
    final dept      = item['dept_category'] as String? ?? '';
    final dc        = deptColor(dept);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.indigo.withOpacity(0.15)),
        boxShadow: [BoxShadow(
            color: Colors.indigo.withOpacity(0.06), blurRadius: 10,
            offset: const Offset(0, 3))],
      ),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [_lighten(dc, 0.18), dc],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(
                color: dc.withOpacity(0.25), blurRadius: 5,
                offset: const Offset(0, 2))],
          ),
          child: Center(child: Text(
            name.isNotEmpty ? name.substring(0, 1) : '?',
            style: const TextStyle(fontSize: 15,
                fontWeight: FontWeight.w900, color: Colors.white),
          )),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(name, style: const TextStyle(
                fontWeight: FontWeight.w800, fontSize: 13, color: _text)),
            const SizedBox(width: 6),
            _leaveTypeBadge(leaveType, small: true),
          ]),
          const SizedBox(height: 3),
          Text('${item['start_date']} ~ ${item['end_date']}',
              style: const TextStyle(fontSize: 11, color: _sub)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF7B8CFF), Colors.indigo],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(
                color: Colors.indigo.withOpacity(0.22),
                blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: const Text('휴가중', style: TextStyle(
              color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
        ),
      ]),
    );
  }

  // ── 부서 섹션
  Widget _deptSection(String dept, List<Map<String, dynamic>> profiles) {
    final color        = deptColor(dept);
    final lighter      = _lighten(color, 0.18);
    final isCollapsed  = _collapsedDepts.contains(dept);
    final onLeaveCount = profiles
        .where((p) => _isOnLeave(p['id'] ?? '')).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.10), blurRadius: 12,
              offset: const Offset(0, 4)),
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(children: [
          // 그라디언트 헤더
          GestureDetector(
            onTap: () => _toggleDept(dept),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [_lighten(color, 0.25), color],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.22),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.group_rounded,
                      color: Colors.white, size: 14),
                ),
                const SizedBox(width: 10),
                Text(_dl(dept), style: const TextStyle(
                    fontWeight: FontWeight.w900, fontSize: 14,
                    color: Colors.white)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text('${profiles.length}명', style: const TextStyle(
                      color: Colors.white, fontSize: 11,
                      fontWeight: FontWeight.w800)),
                ),
                if (onLeaveCount > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.22),
                        borderRadius: BorderRadius.circular(8)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.flight_takeoff_rounded,
                          size: 10, color: Colors.white),
                      const SizedBox(width: 3),
                      Text('휴가 $onLeaveCount',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11,
                              fontWeight: FontWeight.w800)),
                    ]),
                  ),
                ],
                const Spacer(),
                AnimatedRotation(
                  turns: isCollapsed ? 0 : 0.5,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: Colors.white, size: 20),
                ),
              ]),
            ),
          ),

          // 직원 목록
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: isCollapsed
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: Column(children: profiles.map(_profileRow).toList()),
            secondChild: const SizedBox.shrink(),
          ),
        ]),
      ),
    );
  }

  Widget _profileRow(Map<String, dynamic> profile) {
    final total     = (profile['total_leave'] as num?)?.toDouble() ?? 0;
    final used      = (profile['used_leave']  as num?)?.toDouble() ?? 0;
    final remaining = total - used;
    final onLeave   = _isOnLeave(profile['id'] ?? '');
    final ratio     = total > 0 ? used / total : 0.0;
    final dc        = deptColor(
        profile['dept_category'] as String? ?? '');

    final currentLeave = widget.onLeaveNow
        .where((l) => l['user_id'] == profile['id']).toList();
    final currentType  = currentLeave.isNotEmpty
        ? currentLeave.first['leave_type'] as String? : null;
    final isNonDeduct  = onLeave && !_isAnnualDeduct(currentType);

    final rateColor = ratio > 0.8
        ? Colors.redAccent
        : ratio > 0.5 ? Colors.orange : Colors.green;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      decoration: BoxDecoration(
        color: onLeave ? Colors.indigo.withOpacity(0.03) : null,
        border: Border(top: BorderSide(
            color: Colors.black.withOpacity(0.05))),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
                color: dc.withOpacity(0.1),
                borderRadius: BorderRadius.circular(9)),
            child: Center(child: Text(
              (profile['full_name'] as String? ?? '?').isNotEmpty
                  ? (profile['full_name'] as String)[0] : '?',
              style: TextStyle(fontSize: 13,
                  fontWeight: FontWeight.w900, color: dc),
            )),
          ),
          const SizedBox(width: 9),
          Expanded(child: Text(profile['full_name'] ?? '-',
              style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 13, color: _text))),
          if (onLeave) ...[
            _leaveTypeBadge(currentType, small: true),
            const SizedBox(width: 6),
          ],
          // 잔여 연차
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: _fmtD(remaining),
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w900,
                      color: rateColor),
                ),
                const TextSpan(
                  text: '일 남음',
                  style: TextStyle(
                      fontSize: 11, color: _sub,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ]),
        const SizedBox(height: 8),
        // 연차 진행 바
        Row(children: [
          Text('${_fmtD(used)}/${_fmtD(total)}일 사용',
              style: const TextStyle(fontSize: 10, color: _sub)),
          const Spacer(),
          Text('${(ratio * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700,
                  color: rateColor)),
        ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0), minHeight: 5,
            backgroundColor: Colors.black.withOpacity(0.06),
            valueColor: AlwaysStoppedAnimation(rateColor),
          ),
        ),
      ]),
    );
  }

  Widget _leaveTypeBadge(String? leaveType, {bool small = false}) {
    final label = _leaveTypeLabel(leaveType);
    final color = _leaveTypeColor(leaveType);
    final icon  = _leaveTypeIcon(leaveType);
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: small ? 5 : 7, vertical: small ? 2 : 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: small ? 9 : 11, color: color),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(
            fontSize: small ? 9 : 11,
            fontWeight: FontWeight.w800, color: color)),
      ]),
    );
  }

  Widget _stepIndicator(Map<String, dynamic> item) {
    final step1 = item['step1_status'] as String? ?? 'PENDING';
    final step2 = item['step2_status'] as String? ?? 'WAITING';

    Widget dot(String label, String status) {
      final Color c = status == 'APPROVED' ? Colors.green
          : status == 'PENDING'  ? Colors.orange
          : status == 'REJECTED' ? Colors.redAccent
          : Colors.grey.shade300;
      final IconData ic = status == 'APPROVED'
          ? Icons.check_circle_rounded
          : status == 'REJECTED' ? Icons.cancel_rounded
          : status == 'PENDING'  ? Icons.radio_button_checked_rounded
          : Icons.radio_button_unchecked_rounded;
      return Column(children: [
        Icon(ic, color: c, size: 20),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(
            fontSize: 10, color: c, fontWeight: FontWeight.w700)),
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