import 'package:flutter/material.dart';
import 'attendance_helper.dart';

class LeaveStatusTab extends StatelessWidget {
  final List<Map<String, dynamic>> leaveRequests;
  final List<Map<String, dynamic>> onLeaveNow;
  final Map<String, List<Map<String, dynamic>>> profilesByDept;
  final Future<void> Function() onRefresh;
  final Future<void> Function(String id, String status) onUpdateStatus;
  final bool canApprove; // 과장급 이상만 true

  const LeaveStatusTab({
    Key? key,
    required this.leaveRequests,
    required this.onLeaveNow,
    required this.profilesByDept,
    required this.onRefresh,
    required this.onUpdateStatus,
    this.canApprove = false,
  }) : super(key: key);

  // ✅ 부서 라벨 매핑 (영문 코드 → 한글 표시)
  static const Map<String, String> _deptLabels = {
    'MANAGEMENT': '관리부',
    'PRODUCTION': '생산관리부',
    'SALES':      '영업부',
    'RND':        '연구소',
    'STEEL':      '스틸생산부',
    'BOX':        '박스생산부',
    'DELIVERY':   '포장납품부',
  };

  String _deptLabel(String dept) => _deptLabels[dept] ?? dept;

  String _fmtD(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toString();

  bool _isOnLeave(String userId) =>
      onLeaveNow.any((l) => l['user_id'] == userId);

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 승인 대기
          if (leaveRequests.isNotEmpty) ...[
            attendanceSectionHeader("승인 대기 (${leaveRequests.length})",
                Icons.pending_actions_rounded, Colors.orange),
            const SizedBox(height: 12),
            ...leaveRequests.map((req) => _requestCard(context, req, canApprove)),
            const SizedBox(height: 28),
          ],

          // 현재 휴가 중
          if (onLeaveNow.isNotEmpty) ...[
            attendanceSectionHeader("현재 휴가 중 (${onLeaveNow.length})",
                Icons.flight_takeoff_rounded, Colors.indigo),
            const SizedBox(height: 12),
            ...onLeaveNow.map(_onLeaveCard),
            const SizedBox(height: 28),
          ],

          // 부서별 연차 현황
          attendanceSectionHeader("부서별 연차 현황",
              Icons.people_rounded, const Color(0xFF2E6BFF)),
          const SizedBox(height: 12),
          ...profilesByDept.entries
              .map((e) => _deptSection(e.key, e.value)),
        ],
      ),
    );
  }

  // ── 승인 대기 카드 ──
  Widget _requestCard(BuildContext context, Map<String, dynamic> item, bool canApprove) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.orange.withOpacity(0.4)),
      ),
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item['full_name'] ?? '-',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(_stepLabel(item),
                    style: TextStyle(fontSize: 12, color: _stepColor(item), fontWeight: FontWeight.w700)),
              ]),
              Text("${item['leave_days']}일 신청",
                  style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          // 결재 단계 표시
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
          const SizedBox(height: 14),
          if (canApprove)
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => onUpdateStatus(item['id'], 'REJECTED'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red)),
                  child: const Text("반려"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => onUpdateStatus(item['id'], 'APPROVED'),
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
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text("열람 전용 (결재 권한 없음)",
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ),
            ),
        ]),
      ),
    );
  }

  // ── 현재 휴가 중 카드 ──
  Widget _onLeaveCard(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.indigo.withOpacity(0.08),
            Colors.indigo.withOpacity(0.02),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.indigo.withOpacity(0.2)),
      ),
      child: Row(children: [
        const Icon(Icons.flight_takeoff_rounded, color: Colors.indigo, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item['full_name'] ?? '-',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 2),
            Text(
                "${item['start_date']} ~ ${item['end_date']}  (${item['leave_days']}일)",
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ]),
        ),
        attendanceStatusBadge("휴가중", Colors.indigo),
      ]),
    );
  }

  // ── 부서별 섹션 ──
  Widget _deptSection(String dept, List<Map<String, dynamic>> profiles) {
    final color = deptColor(dept);
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 부서 헤더
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: Row(children: [
            Container(
                width: 8, height: 8,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(
              _deptLabel(dept), // ✅ 한글 라벨 표시
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: color),
            ),
            const Spacer(),
            Text("${profiles.length}명",
                style:
                    TextStyle(fontSize: 12, color: color.withOpacity(0.7))),
          ]),
        ),
        ...profiles.map((p) => _profileRow(p)),
      ]),
    );
  }

  Widget _profileRow(Map<String, dynamic> profile) {
    final total     = (profile['total_leave'] as num?)?.toDouble() ?? 0;
    final used      = (profile['used_leave']  as num?)?.toDouble() ?? 0;
    final remaining = total - used;
    final onLeave   = _isOnLeave(profile['id'] ?? '');
    final ratio     = total > 0 ? used / total : 0.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: onLeave ? Colors.indigo.withOpacity(0.04) : null,
        border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.08))),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(profile['full_name'] ?? '-',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(width: 8),
          if (onLeave)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                  color: Colors.indigo,
                  borderRadius: BorderRadius.circular(6)),
              child: const Text("휴가중",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
            ),
          const Spacer(),
          RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              children: [
                TextSpan(
                  text: "${_fmtD(remaining)}일 남음",
                  style: TextStyle(
                      color: remaining <= 3 ? Colors.redAccent : Colors.green,
                      fontWeight: FontWeight.bold),
                ),
                TextSpan(text: "  (${_fmtD(used)}/${_fmtD(total)})"),
              ],
            ),
          ),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0),
            minHeight: 5,
            backgroundColor: Colors.grey.withOpacity(0.12),
            valueColor: AlwaysStoppedAnimation<Color>(
              ratio > 0.8
                  ? Colors.redAccent
                  : ratio > 0.5
                      ? Colors.orange
                      : Colors.green,
            ),
          ),
        ),
      ]),
    );
  }

  String _stepLabel(Map<String, dynamic> item) {
    final step1 = item['step1_status'] as String? ?? 'PENDING';
    final step2 = item['step2_status'] as String? ?? 'WAITING';
    final s1Name = item['step1_approver_name'] as String? ?? '과장';
    final s2Name = item['step2_approver_name'] as String? ?? '본부장';
    if (step1 == 'PENDING') return '1차 결재 대기 ($s1Name)';
    if (step1 == 'APPROVED' && step2 == 'PENDING') return '2차 결재 대기 ($s2Name)';
    return '결재 진행 중';
  }

  Color _stepColor(Map<String, dynamic> item) {
    final step1 = item['step1_status'] as String? ?? 'PENDING';
    if (step1 == 'PENDING') return Colors.orange;
    return const Color(0xFF7C5CDB);
  }

  Widget _stepIndicator(Map<String, dynamic> item) {
    final step1 = item['step1_status'] as String? ?? 'PENDING';
    final step2 = item['step2_status'] as String? ?? 'WAITING';
    final s1Name = item['step1_approver_name'] as String? ?? '과장';
    final s2Name = item['step2_approver_name'] as String? ?? '본부장';

    Widget _dot(String label, String status) {
      final Color c = status == 'APPROVED' ? Colors.green
          : status == 'PENDING' ? Colors.orange
          : status == 'REJECTED' ? Colors.redAccent
          : Colors.grey.shade300;
      final IconData icon = status == 'APPROVED' ? Icons.check_circle_rounded
          : status == 'REJECTED' ? Icons.cancel_rounded
          : status == 'PENDING' ? Icons.radio_button_checked_rounded
          : Icons.radio_button_unchecked_rounded;
      return Column(children: [
        Icon(icon, color: c, size: 20),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10, color: c, fontWeight: FontWeight.w700)),
      ]);
    }

    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      _dot(s1Name, step1),
      Expanded(child: Divider(color: step1 == 'APPROVED' ? Colors.green : Colors.grey.shade300, thickness: 2)),
      _dot(s2Name, step2),
    ]);
  }
}