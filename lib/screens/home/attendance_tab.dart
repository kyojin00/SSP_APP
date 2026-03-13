import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'attendance_helper.dart';

class AttendanceTab extends StatefulWidget {
  final List<Map<String, dynamic>> dailyAttendance;
  final Future<void> Function() onRefresh;

  const AttendanceTab({
    Key? key,
    required this.dailyAttendance,
    required this.onRefresh,
  }) : super(key: key);

  @override
  State<AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<AttendanceTab> {
  // 펼쳐진 부서 키 추적 (기본: 전체 접힘)
  final Set<String> _expandedDepts = {};

  static const _primary = Color(0xFF2E6BFF);
  static const _text    = Color(0xFF1A1D2E);
  static const _sub     = Color(0xFF8A93B0);

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

  @override
  Widget build(BuildContext context) {
    if (widget.dailyAttendance.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: const [
          Icon(Icons.inbox_rounded, size: 48, color: Colors.grey),
          SizedBox(height: 12),
          Text("최근 기록된 출근 인원이 없습니다.",
              style: TextStyle(color: Colors.grey)),
        ]),
      );
    }

    final summary        = buildDailySummary(widget.dailyAttendance);
    final dates          = summary.keys.toList()..sort((a, b) => b.compareTo(a));
    final today          = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final todayRows      = widget.dailyAttendance
        .where((a) => a['work_date'] == today).toList();
    final workingList    = todayRows.where((a) => a['check_out'] == null).toList();
    final finishedList   = todayRows.where((a) => a['check_out'] != null).toList();
    final todayLateCount = todayRows.where(isLate).length;

    final workingByDept  = _groupByDept(workingList);
    final finishedByDept = _groupByDept(finishedList);

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _lateInfoBanner(todayLateCount),
          const SizedBox(height: 16),

          // 일별 요약
          attendanceSectionHeader("일별 출퇴근 요약",
              Icons.calendar_today_rounded, _primary),
          const SizedBox(height: 12),
          _dailySummaryCard(dates, summary),
          const SizedBox(height: 24),

          // 오늘 근무 중
          attendanceSectionHeader(
              "오늘 근무 중 (${workingList.length})",
              Icons.sensors, Colors.green),
          const SizedBox(height: 10),
          if (workingList.isEmpty)
            attendanceEmptyGuide("현재 근무 중인 인원이 없습니다.")
          else
            ..._buildDeptSections(workingByDept, isWorking: true),

          const SizedBox(height: 24),

          // 오늘 퇴근 완료
          attendanceSectionHeader(
              "오늘 퇴근 완료 (${finishedList.length})",
              Icons.home_rounded, Colors.blueGrey),
          const SizedBox(height: 10),
          if (finishedList.isEmpty)
            attendanceEmptyGuide("오늘 퇴근한 인원이 아직 없습니다.")
          else
            ..._buildDeptSections(finishedByDept, isWorking: false),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // ── 부서별 그룹화 (인원 많은 순) ──
  Map<String, List<Map<String, dynamic>>> _groupByDept(
      List<Map<String, dynamic>> rows) {
    final Map<String, List<Map<String, dynamic>>> map = {};
    for (final r in rows) {
      final dept = (r['dept_category'] as String?) ?? '기타';
      map.putIfAbsent(dept, () => []);
      map[dept]!.add(r);
    }
    return Map.fromEntries(
      map.entries.toList()
        ..sort((a, b) => b.value.length.compareTo(a.value.length)),
    );
  }

  // ── 부서별 섹션 목록 ──
  List<Widget> _buildDeptSections(
    Map<String, List<Map<String, dynamic>>> byDept, {
    required bool isWorking,
  }) {
    return byDept.entries.map((entry) {
      final dept      = entry.key;
      final members   = entry.value;
      final lateCount = members.where(isLate).length;
      final key       = '${isWorking ? "w" : "f"}_$dept';
      final expanded  = _expandedDepts.contains(key);
      final color     = deptColor(dept);

      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(children: [
          // ── 부서 헤더 ──
          GestureDetector(
            onTap: () => setState(() {
              expanded
                  ? _expandedDepts.remove(key)
                  : _expandedDepts.add(key);
            }),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: color.withOpacity(0.06),
                borderRadius: expanded
                    ? const BorderRadius.vertical(top: Radius.circular(16))
                    : BorderRadius.circular(16),
              ),
              child: Row(children: [
                Container(
                    width: 10, height: 10,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 10),
                Text(
                  _deptLabel(dept), // ✅ 한글 라벨 표시
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: color),
                ),
                const SizedBox(width: 8),
                // 인원 뱃지
                _badge("${members.length}명", color),
                if (lateCount > 0) ...[
                  const SizedBox(width: 6),
                  _badge("지각 $lateCount", Colors.redAccent),
                ],
                const Spacer(),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.keyboard_arrow_down_rounded,
                      color: color, size: 20),
                ),
              ]),
            ),
          ),

          // ── 멤버 리스트 (펼쳐질 때) ──
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Column(
              children: members.asMap().entries.map((e) {
                return _memberRow(
                    e.value, isWorking, e.key == members.length - 1);
              }).toList(),
            ),
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ]),
      );
    }).toList();
  }

  // ── 멤버 한 행 ──
  Widget _memberRow(
      Map<String, dynamic> item, bool isWorking, bool isLast) {
    final statusColor = isWorking ? Colors.green : Colors.blueGrey;
    final late        = isLate(item);
    final lateMin     = lateMinutes(item);
    final wd          = item['work_date'] as String?;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        border: !isLast
            ? Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.08)))
            : null,
        borderRadius: isLast
            ? const BorderRadius.vertical(bottom: Radius.circular(16))
            : null,
      ),
      child: Row(children: [
        // 상태 도트
        Container(
            width: 8, height: 8,
            decoration:
                BoxDecoration(color: statusColor, shape: BoxShape.circle)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(item['full_name'] ?? '-',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: _text)),
                if (late) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text(
                      lateMin > 0 ? "지각 +${lateMin}분" : "지각",
                      style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ]),
              const SizedBox(height: 2),
              Text(
                isWorking
                    ? "출근 ${formatTime(item['check_in'], workDate: wd)}  ·  ${workTimeText(item)} 근무중"
                    : "출근 ${formatTime(item['check_in'], workDate: wd)} → ${formatTime(item['check_out'], workDate: wd)}  ·  ${workTimeText(item)}",
                style: const TextStyle(fontSize: 11, color: _sub),
              ),
            ],
          ),
        ),
        attendanceStatusBadge(isWorking ? "근무중" : "퇴근완료", statusColor),
      ]),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8)),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }

  Widget _lateInfoBanner(int todayLateCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: Row(children: [
        const Icon(Icons.info_outline_rounded, size: 18, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            "지각 기준: ${kWorkStartHour.toString().padLeft(2, '0')}:${kWorkStartMinute.toString().padLeft(2, '0')}"
            "${kLateGraceMinutes > 0 ? " (+${kLateGraceMinutes}분 유예)" : ""}",
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10)),
          child: Text("오늘 지각 $todayLateCount",
              style: const TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w800,
                  fontSize: 12)),
        ),
      ]),
    );
  }

  Widget _dailySummaryCard(
      List<String> dates, Map<String, Map<String, int>> summary) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        children: dates.map((d) {
          final inCnt   = summary[d]?['in']   ?? 0;
          final outCnt  = summary[d]?['out']  ?? 0;
          final lateCnt = summary[d]?['late'] ?? 0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Expanded(
                child: Text(prettyDate(d),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              attendancePill("출근 $inCnt",  Colors.green),
              const SizedBox(width: 8),
              attendancePill("퇴근 $outCnt", Colors.blueGrey),
              const SizedBox(width: 8),
              attendancePill("지각 $lateCnt", Colors.redAccent),
            ]),
          );
        }).toList(),
      ),
    );
  }
}