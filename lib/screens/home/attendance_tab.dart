import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'attendance_helper.dart';

class AttendanceTab extends StatefulWidget {
  final List<Map<String, dynamic>> dailyAttendance;
  final Map<String, List<Map<String, dynamic>>> profilesByDept;
  final List<Map<String, dynamic>> onLeaveNow;
  final Future<void> Function() onRefresh;

  const AttendanceTab({
    Key? key,
    required this.dailyAttendance,
    required this.profilesByDept,
    required this.onLeaveNow,
    required this.onRefresh,
  }) : super(key: key);

  @override
  State<AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<AttendanceTab> {
  final Set<String> _expandedDepts = {};

  static const _primary = Color(0xFF2E6BFF);
  static const _text    = Color(0xFF1A1D2E);
  static const _sub     = Color(0xFF8A93B0);

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

  String _deptLabel(String dept) => _deptLabels[dept] ?? dept;

  @override
  Widget build(BuildContext context) {
    if (widget.dailyAttendance.isEmpty && widget.profilesByDept.isEmpty) {
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

    // ── 미출근 / 휴가 분리 ──
    final todayUserIds   = todayRows.map((r) => r['user_id'] as String?).toSet();
    final onLeaveUserIds = widget.onLeaveNow.map((l) => l['user_id'] as String?).toSet();

    // 휴가 타입 한국어 변환
    String _leaveTypeLabel(String? userId) {
      if (userId == null) return '휴가';
      final leave = widget.onLeaveNow.firstWhere(
          (l) => l['user_id'] == userId, orElse: () => {});
      final type = leave['leave_type'] as String? ?? '';
      return switch (type) {
        'ANNUAL'  => '연차',
        'HALF'    => '반차',
        'PUBLIC'  => '공가',
        'SPECIAL' => '경조사',
        'SICK'    => '병가',
        _         => type.isNotEmpty ? type : '휴가',
      };
    }

    final absentByDept = <String, List<Map<String, dynamic>>>{};
    final onLeaveByDept = <String, List<Map<String, dynamic>>>{};

    for (final entry in widget.profilesByDept.entries) {
      for (final p in entry.value) {
        final uid = p['id'] as String?;
        if (todayUserIds.contains(uid)) continue; // 출근함

        if (onLeaveUserIds.contains(uid)) {
          // 휴가자
          onLeaveByDept.putIfAbsent(entry.key, () => []).add({
            ...p,
            '_leave_type': _leaveTypeLabel(uid),
          });
        } else {
          // 미출근
          absentByDept.putIfAbsent(entry.key, () => []).add(p);
        }
      }
    }

    final totalAbsent  = absentByDept.values.fold(0, (s, l) => s + l.length);
    final totalOnLeave = onLeaveByDept.values.fold(0, (s, l) => s + l.length);

    final workingByDept  = _groupByDept(workingList);
    final finishedByDept = _groupByDept(finishedList);

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _lateInfoBanner(todayLateCount),
          const SizedBox(height: 16),

          attendanceSectionHeader("일별 출퇴근 요약",
              Icons.calendar_today_rounded, _primary),
          const SizedBox(height: 12),
          _dailySummaryCard(dates, summary),
          const SizedBox(height: 24),

          attendanceSectionHeader(
              "오늘 근무 중 (${workingList.length})",
              Icons.sensors, Colors.green),
          const SizedBox(height: 10),
          if (workingList.isEmpty)
            attendanceEmptyGuide("현재 근무 중인 인원이 없습니다.")
          else
            ..._buildDeptSections(workingByDept, isWorking: true),

          const SizedBox(height: 24),

          attendanceSectionHeader(
              "오늘 퇴근 완료 (${finishedList.length})",
              Icons.home_rounded, Colors.blueGrey),
          const SizedBox(height: 10),
          if (finishedList.isEmpty)
            attendanceEmptyGuide("오늘 퇴근한 인원이 아직 없습니다.")
          else
            ..._buildDeptSections(finishedByDept, isWorking: false),

          const SizedBox(height: 24),

          // ── 오늘 휴가 섹션 ──
          attendanceSectionHeader(
              "오늘 휴가 ($totalOnLeave)",
              Icons.beach_access_rounded, Colors.teal),
          const SizedBox(height: 10),
          if (onLeaveByDept.isEmpty)
            attendanceEmptyGuide("오늘 휴가자가 없습니다.")
          else
            ..._buildAbsentSections(onLeaveByDept, isLeave: true),

          const SizedBox(height: 24),

          // ── 미출근 섹션 ──
          attendanceSectionHeader(
              "오늘 미출근 ($totalAbsent)",
              Icons.person_off_rounded, Colors.redAccent),
          const SizedBox(height: 10),
          if (absentByDept.isEmpty)
            attendanceEmptyGuide("전원 출근 완료!")
          else
            ..._buildAbsentSections(absentByDept, isLeave: false),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

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

  List<Widget> _buildAbsentSections(
      Map<String, List<Map<String, dynamic>>> byDept,
      {required bool isLeave}) {
    final accentColor = isLeave ? Colors.teal : Colors.redAccent;

    return byDept.entries.map((entry) {
      final dept    = entry.key;
      final members = entry.value;
      final key     = '${isLeave ? "leave" : "absent"}_$dept';
      final expanded = _expandedDepts.contains(key);
      final color   = deptColor(dept);

      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(children: [
          GestureDetector(
            onTap: () => setState(() {
              expanded ? _expandedDepts.remove(key) : _expandedDepts.add(key);
            }),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.04),
                borderRadius: expanded
                    ? const BorderRadius.vertical(top: Radius.circular(16))
                    : BorderRadius.circular(16),
              ),
              child: Row(children: [
                Container(width: 10, height: 10,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 10),
                Text(_deptLabel(dept), style: TextStyle(
                    fontWeight: FontWeight.w900, fontSize: 14, color: color)),
                const SizedBox(width: 8),
                _badge("${members.length}명", accentColor),
                const Spacer(),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.keyboard_arrow_down_rounded,
                      color: accentColor, size: 20),
                ),
              ]),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Column(
              children: members.asMap().entries.map((e) {
                final p      = e.value;
                final name   = p['full_name'] as String? ?? '-';
                final pos    = p['position']  as String? ?? '';
                final lType  = p['_leave_type'] as String? ?? '';
                final isLast = e.key == members.length - 1;
                final dc     = deptColor(dept);

                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 11),
                  decoration: BoxDecoration(
                    border: !isLast ? Border(bottom: BorderSide(
                        color: Colors.grey.withOpacity(0.08))) : null,
                    borderRadius: isLast
                        ? const BorderRadius.vertical(
                            bottom: Radius.circular(16))
                        : null,
                  ),
                  child: Row(children: [
                    CircleAvatar(radius: 16,
                        backgroundColor: dc.withOpacity(0.1),
                        child: Text(name.isNotEmpty ? name[0] : '?',
                            style: TextStyle(fontSize: 12,
                                fontWeight: FontWeight.w900, color: dc))),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(name, style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13,
                          color: _text)),
                      if (pos.isNotEmpty)
                        Text(pos, style: const TextStyle(
                            fontSize: 11, color: _sub)),
                    ])),
                    // 뱃지: 휴가면 휴가 타입, 미출근이면 미출근
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(7)),
                      child: Text(
                        isLeave
                            ? (lType.isNotEmpty ? lType : '휴가')
                            : '미출근',
                        style: TextStyle(fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: accentColor),
                      ),
                    ),
                  ]),
                );
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
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(children: [
          GestureDetector(
            onTap: () => setState(() {
              expanded ? _expandedDepts.remove(key) : _expandedDepts.add(key);
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
                Container(width: 10, height: 10,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 10),
                Text(_deptLabel(dept),
                    style: TextStyle(fontWeight: FontWeight.w900,
                        fontSize: 14, color: color)),
                const SizedBox(width: 8),
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
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Column(
              children: members.asMap().entries.map((e) {
                return _memberRow(e.value, isWorking, e.key == members.length - 1);
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

  Widget _memberRow(Map<String, dynamic> item, bool isWorking, bool isLast) {
    final statusColor = isWorking ? Colors.green : Colors.blueGrey;
    final late        = isLate(item);
    final lateMin     = lateMinutes(item);
    final wd          = item['work_date'] as String?;

    return GestureDetector(
      onTap: () => _openMonthlySheet(context, item),
      behavior: HitTestBehavior.opaque,
      child: Container(
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
          Container(width: 8, height: 8,
              decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(item['full_name'] ?? '-',
                    style: const TextStyle(fontWeight: FontWeight.w700,
                        fontSize: 13, color: _text)),
                if (late) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text(
                      lateMin > 0 ? "지각 +${lateMin}분" : "지각",
                      style: const TextStyle(color: Colors.redAccent,
                          fontSize: 10, fontWeight: FontWeight.w900),
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
            ]),
          ),
          attendanceStatusBadge(isWorking ? "근무중" : "퇴근완료", statusColor),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, size: 16, color: _sub),
        ]),
      ),
    );
  }

  void _openMonthlySheet(BuildContext context, Map<String, dynamic> item) {
    final userId = item['user_id'] as String? ?? item['id'] as String? ?? '';
    final name   = item['full_name'] as String? ?? '-';
    final dept   = item['dept_category'] as String? ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MonthlyAttendanceSheet(
        userId: userId, name: name, dept: dept,
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
          color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }

  Widget _lateInfoBanner(int todayLateCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03),
            blurRadius: 8, offset: const Offset(0, 3))],
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
              style: const TextStyle(color: Colors.redAccent,
                  fontWeight: FontWeight.w800, fontSize: 12)),
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03),
            blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        children: dates.map((d) {
          final inCnt   = summary[d]?['in']   ?? 0;
          final outCnt  = summary[d]?['out']  ?? 0;
          final lateCnt = summary[d]?['late'] ?? 0;
          // 해당 날짜에 휴가 중인 인원 (start_date <= d <= end_date)
          final leaveCnt = widget.onLeaveNow.where((l) {
            final start = l['start_date'] as String? ?? '';
            final end   = l['end_date']   as String? ?? '';
            return start.compareTo(d) <= 0 && end.compareTo(d) >= 0;
          }).length;
          // 해당 날짜 출근자 user_id 집합
          final dayUserIds = widget.dailyAttendance
              .where((a) => a['work_date'] == d)
              .map((a) => a['user_id'] as String?)
              .toSet();
          final leaveUserIds = widget.onLeaveNow.where((l) {
            final start = l['start_date'] as String? ?? '';
            final end   = l['end_date']   as String? ?? '';
            return start.compareTo(d) <= 0 && end.compareTo(d) >= 0;
          }).map((l) => l['user_id'] as String?).toSet();
          final totalMembers = widget.profilesByDept.values
              .fold(0, (s, list) => s + list.length);
          final absentCnt = (totalMembers - dayUserIds.length - leaveCnt)
              .clamp(0, totalMembers);

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Expanded(child: Text(prettyDate(d),
                  style: const TextStyle(fontWeight: FontWeight.w700))),
              attendancePill("출근 $inCnt",  Colors.green),
              const SizedBox(width: 6),
              attendancePill("퇴근 $outCnt", Colors.blueGrey),
              const SizedBox(width: 6),
              if (lateCnt > 0) ...[
                attendancePill("지각 $lateCnt", Colors.redAccent),
                const SizedBox(width: 6),
              ],
              if (leaveCnt > 0) ...[
                attendancePill("휴가 $leaveCnt", Colors.teal),
                const SizedBox(width: 6),
              ],
              if (absentCnt > 0)
                attendancePill("미참여 $absentCnt", Colors.grey),
            ]),
          );
        }).toList(),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// 개인 월별 출퇴근 바텀시트
// ══════════════════════════════════════════════════════════
class _MonthlyAttendanceSheet extends StatefulWidget {
  final String userId;
  final String name;
  final String dept;

  const _MonthlyAttendanceSheet({
    required this.userId, required this.name, required this.dept,
  });

  @override
  State<_MonthlyAttendanceSheet> createState() => _MonthlyAttendanceSheetState();
}

class _MonthlyAttendanceSheetState extends State<_MonthlyAttendanceSheet> {
  static const _text = Color(0xFF1A1D2E);
  static const _sub  = Color(0xFF8A93B0);
  static const _bg   = Color(0xFFF5F6FA);

  late int _year;
  late int _month;
  bool _loading = false;
  List<Map<String, dynamic>> _records = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year  = now.year;
    _month = now.month;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final from    = '$_year-${_month.toString().padLeft(2, '0')}-01';
      final lastDay = DateTime(_year, _month + 1, 0).day;
      final to      = '$_year-${_month.toString().padLeft(2, '0')}-${lastDay.toString().padLeft(2, '0')}';

      final data = await Supabase.instance.client
          .from('attendance')
          .select('work_date, check_in, check_out')
          .eq('user_id', widget.userId)
          .gte('work_date', from)
          .lte('work_date', to)
          .order('work_date', ascending: false);

      final fetched      = List<Map<String, dynamic>>.from(data);
      final fetchedDates = fetched.map((r) => r['work_date'] as String).toSet();

      final today   = DateTime.now();
      final allDays = <Map<String, dynamic>>[];
      for (int d = lastDay; d >= 1; d--) {
        final dt      = DateTime(_year, _month, d);
        if (dt.isAfter(today)) continue;
        final dateStr = '$_year-${_month.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
        if (fetchedDates.contains(dateStr)) {
          allDays.add(fetched.firstWhere((r) => r['work_date'] == dateStr));
        } else {
          final isWeekend = dt.weekday == 6 || dt.weekday == 7;
          allDays.add({'work_date': dateStr, 'check_in': null, 'check_out': null,
            '_type': isWeekend ? 'weekend' : 'absent'});
        }
      }

      if (mounted) setState(() => _records = allDays);
    } catch (e) {
      debugPrint('월별 출퇴근 로드 오류: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _workDays  => _records.where((r) => r['_type'] == null).length;
  int get _lateCount => _records.where((r) => r['_type'] == null && isLate(r)).length;

  int _timeToMinutes(String t) {
    final parts = t.split(':');
    if (parts.length < 2) return 0;
    return int.tryParse(parts[0])! * 60 + int.tryParse(parts[1])!;
  }

  static const int _breakMinutes = 90;

  int _workMinutes(Map<String, dynamic> r) {
    final inTime  = r['check_in']  as String?;
    final outTime = r['check_out'] as String?;
    if (inTime == null || outTime == null) return 0;
    final diff = _timeToMinutes(outTime) - _timeToMinutes(inTime) - _breakMinutes;
    return diff < 0 ? 0 : diff;
  }

  int get _totalMinutes =>
      _records.where((r) => r['_type'] == null)
          .fold(0, (sum, r) => sum + _workMinutes(r));

  String get _totalWorkStr {
    final h = _totalMinutes ~/ 60;
    final m = _totalMinutes % 60;
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final dc = deptColor(widget.dept);

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)))),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
            child: Row(children: [
              CircleAvatar(radius: 22, backgroundColor: dc.withOpacity(0.12),
                  child: Text(widget.name.isNotEmpty ? widget.name[0] : '?',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: dc))),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.name, style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w900, color: _text)),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: dc.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6)),
                  child: Text(_deptLabel(widget.dept),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: dc)),
                ),
              ]),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              _dropBtn<int>(value: _year,
                  items: List.generate(3, (i) => DateTime.now().year - i),
                  label: (y) => '$y년',
                  onChanged: (v) { setState(() => _year = v!); _load(); }),
              const SizedBox(width: 8),
              _dropBtn<int>(value: _month,
                  items: List.generate(12, (i) => i + 1),
                  label: (m) => '$m월',
                  onChanged: (v) { setState(() => _month = v!); _load(); }),
            ]),
          ),
          const SizedBox(height: 12),
          if (!_loading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                _summaryChip(Icons.calendar_month_rounded, "출근", "$_workDays일", Colors.green),
                const SizedBox(width: 8),
                _summaryChip(Icons.alarm_rounded, "지각", "$_lateCount회", Colors.redAccent),
                const SizedBox(width: 8),
                _summaryChip(Icons.timer_rounded, "근무", _totalWorkStr, const Color(0xFF2E6BFF)),
              ]),
            ),
          const SizedBox(height: 12),
          Divider(height: 1, color: Colors.black.withOpacity(0.05)),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    itemCount: _records.length,
                    itemBuilder: (_, i) => _recordRow(_records[i]),
                  ),
          ),
        ]),
      ),
    );
  }

  Widget _recordRow(Map<String, dynamic> record) {
    final wd   = record['work_date'] as String? ?? '';
    final type = record['_type']     as String?;
    final late    = type == null && isLate(record);
    final lateMin = type == null ? lateMinutes(record) : 0;
    final hasOut  = record['check_out'] != null;

    final parts = wd.split('-');
    final dt = parts.length == 3
        ? DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]))
        : DateTime.now();
    final weekday   = _weekdayStr(dt.weekday);
    final dd        = parts.length == 3 ? parts[2] : '';
    final isSat     = dt.weekday == 6;
    final isSun     = dt.weekday == 7;
    final dateColor = isSun ? Colors.red : isSat ? Colors.blue : _text;

    if (type == 'weekend') {
      return Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: const Color(0xFFF5F6FA),
            borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Container(width: 44, padding: const EdgeInsets.symmetric(vertical: 5),
            child: Column(children: [
              Text(dd, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                  color: dateColor.withOpacity(0.5))),
              Text(weekday, style: TextStyle(fontSize: 10,
                  color: dateColor.withOpacity(0.4))),
            ])),
          const SizedBox(width: 12),
          Text("주말", style: TextStyle(fontSize: 12, color: _sub.withOpacity(0.5))),
        ]),
      );
    }

    if (type == 'absent') {
      return Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: Colors.grey.withOpacity(0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withOpacity(0.1))),
        child: Row(children: [
          Container(width: 44, padding: const EdgeInsets.symmetric(vertical: 5),
              decoration: BoxDecoration(color: Colors.grey.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10)),
              child: Column(children: [
                Text(dd, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                    color: _sub.withOpacity(0.6))),
                Text(weekday, style: TextStyle(fontSize: 10, color: _sub.withOpacity(0.5))),
              ])),
          const SizedBox(width: 12),
          const Icon(Icons.remove_circle_outline_rounded, size: 14, color: Colors.grey),
          const SizedBox(width: 6),
          Text("출근 기록 없음", style: TextStyle(fontSize: 12,
              color: _sub.withOpacity(0.7), fontWeight: FontWeight.w600)),
        ]),
      );
    }

    String workDuration = '-';
    if (hasOut) {
      final mins = _workMinutes(record);
      if (mins > 0) workDuration = '${mins ~/ 60}h ${mins % 60}m';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: late ? Colors.redAccent.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: late ? Colors.redAccent.withOpacity(0.15)
              : Colors.black.withOpacity(0.06),
        ),
      ),
      child: Row(children: [
        Container(width: 44, padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(color: _bg,
                borderRadius: BorderRadius.circular(10)),
            child: Column(children: [
              Text(dd, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900,
                  color: dateColor)),
              Text(weekday, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                  color: dateColor.withOpacity(0.6))),
            ])),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _timeChip(icon: Icons.login_rounded,
                label: formatTime(record['check_in'], workDate: wd),
                color: Colors.green),
            const SizedBox(width: 6),
            if (hasOut)
              _timeChip(icon: Icons.logout_rounded,
                  label: formatTime(record['check_out'], workDate: wd),
                  color: Colors.blueGrey)
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(7)),
                child: const Text("근무중", style: TextStyle(fontSize: 11,
                    fontWeight: FontWeight.w800, color: Colors.orange)),
              ),
          ]),
          const SizedBox(height: 5),
          Row(children: [
            const Icon(Icons.timer_outlined, size: 12, color: _sub),
            const SizedBox(width: 4),
            Text(hasOut ? workDuration : '-',
                style: const TextStyle(fontSize: 11, color: _sub)),
          ]),
        ])),
        if (late)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Text(lateMin > 0 ? "+${lateMin}분" : "지각",
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900,
                    color: Colors.redAccent)),
          ),
      ]),
    );
  }

  Widget _timeChip({required IconData icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(7)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
      ]),
    );
  }

  Widget _summaryChip(IconData icon, String label, String value, Color color) {
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color)),
        Text(label, style: TextStyle(fontSize: 10, color: color.withOpacity(0.7))),
      ]),
    ));
  }

  Widget _dropBtn<T>({
    required T value, required List<T> items,
    required String Function(T) label, required void Function(T?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.black.withOpacity(0.07))),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value, isDense: true,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _text),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(label(e)))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  String _deptLabel(String dept) => const {
    'MANAGEMENT': '관리부', 'PRODUCTION': '생산관리부', 'SALES': '영업부',
    'RND': '연구소', 'STEEL': '스틸생산부', 'BOX': '박스생산부',
    'DELIVERY': '포장납품부', 'SSG': '에스에스지',
    'CLEANING': '환경미화', 'NUTRITION': '영양사',
  }[dept] ?? dept;

  String _weekdayStr(int w) => ['월', '화', '수', '목', '금', '토', '일'][w - 1];
}