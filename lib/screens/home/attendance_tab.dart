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

class _AttendanceTabState extends State<AttendanceTab>
    with SingleTickerProviderStateMixin {

  static const _primary  = Color(0xFF2E6BFF);
  static const _excludedDepts = {'NUTRITION'};

  late TabController _tabCtrl;

  Map<String, List<Map<String, dynamic>>> get _filteredProfiles =>
      Map.fromEntries(widget.profilesByDept.entries
          .where((e) => !_excludedDepts.contains(e.key)));

  Color _lighten(Color c, double a) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + a).clamp(0.0, 1.0)).toColor();
  }

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final today      = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final todayRows  = widget.dailyAttendance
        .where((a) => a['work_date'] == today)
        .where((a) => !_excludedDepts.contains(a['dept_category'] as String?))
        .toList();

    final workingList  = todayRows.where((a) => a['check_out'] == null).toList();
    final finishedList = todayRows.where((a) => a['check_out'] != null).toList();

    final todayUserIds   = todayRows.map((r) => r['user_id'] as String?).toSet();
    final onLeaveUserIds = widget.onLeaveNow.map((l) => l['user_id'] as String?).toSet();

    String leaveTypeLabel(String? uid) {
      if (uid == null) return '휴가';
      final leave = widget.onLeaveNow.firstWhere(
          (l) => l['user_id'] == uid, orElse: () => {});
      final type = leave['leave_type'] as String? ?? '';
      return switch (type) {
        'ANNUAL'  => '연차',  'HALF'    => '반차',
        'PUBLIC'  => '공가',  'SPECIAL' => '경조사',
        'SICK'    => '병가',
        _ => type.isNotEmpty ? type : '휴가',
      };
    }

    final absentByDept  = <String, List<Map<String, dynamic>>>{};
    final onLeaveByDept = <String, List<Map<String, dynamic>>>{};

    for (final entry in _filteredProfiles.entries) {
      for (final p in entry.value) {
        final uid = p['id'] as String?;
        if (todayUserIds.contains(uid)) continue;
        if (onLeaveUserIds.contains(uid)) {
          onLeaveByDept.putIfAbsent(entry.key, () => []).add({
            ...p, '_leave_type': leaveTypeLabel(uid),
          });
        } else {
          absentByDept.putIfAbsent(entry.key, () => []).add(p);
        }
      }
    }

    final todayLateCount = todayRows.where(isLate).length;
    final leaveCount     = onLeaveByDept.values.fold(0, (s, l) => s + l.length);
    final absentCount    = absentByDept.values.fold(0, (s, l) => s + l.length);

    // 탭 색상
    const tColors = [Colors.green, Color(0xFF5B8AFF), Colors.teal, Colors.redAccent];

    return Column(children: [
      // ── 그라디언트 요약 헤더
      Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_lighten(_primary, 0.22), _primary],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
        ),
        child: Column(children: [
          // 날짜
          Row(children: [
            const Icon(Icons.today_rounded, size: 14, color: Colors.white70),
            const SizedBox(width: 6),
            Text(
              DateFormat('yyyy년 MM월 dd일 (E)', 'ko_KR').format(DateTime.now()),
              style: const TextStyle(
                  fontSize: 12, color: Colors.white70,
                  fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            if (todayLateCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  const Icon(Icons.alarm_rounded, size: 13, color: Colors.white),
                  const SizedBox(width: 4),
                  Text('지각 $todayLateCount명',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 11,
                          fontWeight: FontWeight.w900)),
                ]),
              ),
          ]),
          const SizedBox(height: 10),
          // 통계 4칸
          Row(children: [
            _statBox('근무중', workingList.length,  Colors.green),
            const SizedBox(width: 8),
            _statBox('퇴근',   finishedList.length, const Color(0xFF5B8AFF)),
            const SizedBox(width: 8),
            _statBox('휴가',   leaveCount,           Colors.teal),
            const SizedBox(width: 8),
            _statBox('미출근', absentCount,          Colors.redAccent),
          ]),
        ]),
      ),

      // ── 흰 탭바
      Container(
        color: Colors.white,
        child: TabBar(
          controller: _tabCtrl,
          labelColor: _primary,
          unselectedLabelColor: const Color(0xFF8A93B0),
          indicatorColor: _primary,
          indicatorWeight: 2.5,
          dividerColor: const Color(0xFFF0F2F8),
          labelStyle: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w800),
          tabs: [
            _tab('근무중', workingList.length,  Colors.green),
            _tab('퇴근',   finishedList.length, const Color(0xFF5B8AFF)),
            _tab('휴가',   leaveCount,           Colors.teal),
            _tab('미출근', absentCount,          Colors.redAccent),
          ],
        ),
      ),

      // ── 탭 뷰
      Expanded(
        child: TabBarView(
          controller: _tabCtrl,
          children: [
            _DeptListTab(
              byDept:          _groupByDept(workingList),
              isWorking:       true,
              emptyMsg:        '현재 근무 중인 인원이 없습니다.',
              onRefresh:       widget.onRefresh,
              dailyAttendance: widget.dailyAttendance,
              filteredProfiles: _filteredProfiles,
              onLeaveNow:      widget.onLeaveNow,
            ),
            _DeptListTab(
              byDept:          _groupByDept(finishedList),
              isWorking:       false,
              emptyMsg:        '오늘 퇴근한 인원이 아직 없습니다.',
              onRefresh:       widget.onRefresh,
              dailyAttendance: widget.dailyAttendance,
              filteredProfiles: _filteredProfiles,
              onLeaveNow:      widget.onLeaveNow,
            ),
            _AbsentListTab(
              byDept:    onLeaveByDept,
              isLeave:   true,
              emptyMsg:  '오늘 휴가자가 없습니다.',
              onRefresh: widget.onRefresh,
            ),
            _AbsentListTab(
              byDept:    absentByDept,
              isLeave:   false,
              emptyMsg:  '전원 출근 완료! 🎉',
              onRefresh: widget.onRefresh,
            ),
          ],
        ),
      ),
    ]);
  }

  Widget _statBox(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          Text('$count',
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w900,
                  color: Colors.white)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withOpacity(0.75),
                  fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _tab(String label, int count, Color color) {
    return Tab(
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(label),
        const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6)),
          child: Text('$count',
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w900, color: color)),
        ),
      ]),
    );
  }

  Map<String, List<Map<String, dynamic>>> _groupByDept(
      List<Map<String, dynamic>> rows) {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final r in rows) {
      final dept = (r['dept_category'] as String?) ?? '기타';
      if (_excludedDepts.contains(dept)) continue;
      map.putIfAbsent(dept, () => []).add(r);
    }
    return Map.fromEntries(
        map.entries.toList()
          ..sort((a, b) => b.value.length.compareTo(a.value.length)));
  }
}

// ══════════════════════════════════════════
// ① ② 근무중 / 퇴근완료 탭
// ══════════════════════════════════════════

class _DeptListTab extends StatefulWidget {
  final Map<String, List<Map<String, dynamic>>> byDept;
  final bool isWorking;
  final String emptyMsg;
  final Future<void> Function() onRefresh;
  final List<Map<String, dynamic>> dailyAttendance;
  final Map<String, List<Map<String, dynamic>>> filteredProfiles;
  final List<Map<String, dynamic>> onLeaveNow;

  const _DeptListTab({
    required this.byDept, required this.isWorking,
    required this.emptyMsg, required this.onRefresh,
    required this.dailyAttendance, required this.filteredProfiles,
    required this.onLeaveNow,
  });

  @override
  State<_DeptListTab> createState() => _DeptListTabState();
}

class _DeptListTabState extends State<_DeptListTab>
    with AutomaticKeepAliveClientMixin {
  @override bool get wantKeepAlive => true;

  final Set<String> _expanded = {};

  static const _text = Color(0xFF1A1D2E);
  static const _sub  = Color(0xFF8A93B0);
  static const _bg   = Color(0xFFF4F6FB);

  static const _deptLabels = {
    'MANAGEMENT': '관리부', 'PRODUCTION': '생산관리부', 'SALES': '영업부',
    'RND': '연구소', 'STEEL': '스틸생산부', 'BOX': '박스생산부',
    'DELIVERY': '포장납품부', 'SSG': '에스에스지',
    'CLEANING': '환경미화', 'NUTRITION': '영양사',
  };
  String _dl(String d) => _deptLabels[d] ?? d;

  Color _lighten(Color c, double a) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + a).clamp(0.0, 1.0)).toColor();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (widget.byDept.isEmpty) {
      return RefreshIndicator(
        onRefresh: widget.onRefresh,
        child: ListView(children: [
          const SizedBox(height: 80),
          Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white, shape: BoxShape.circle,
                boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 14, offset: const Offset(0, 4))],
              ),
              child: Icon(
                widget.isWorking
                    ? Icons.sensors_off_rounded
                    : Icons.home_rounded,
                size: 38, color: Colors.grey[300]),
            ),
            const SizedBox(height: 14),
            Text(widget.emptyMsg,
                style: TextStyle(
                    color: Colors.grey[400],
                    fontWeight: FontWeight.w600)),
          ])),
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      color: const Color(0xFF2E6BFF),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 40),
        children: widget.byDept.entries.map((entry) {
          final dept    = entry.key;
          final members = entry.value;
          final color   = deptColor(dept);
          final lighter = _lighten(color, 0.18);
          final lateCount = members.where(isLate).length;
          final key       = dept;
          final expanded  = _expanded.contains(key);

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                    color: color.withOpacity(0.10), blurRadius: 12,
                    offset: const Offset(0, 4)),
                BoxShadow(
                    color: Colors.black.withOpacity(0.04), blurRadius: 6,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Column(children: [
                // ── 그라디언트 헤더
                GestureDetector(
                  onTap: () => setState(() =>
                      expanded ? _expanded.remove(key) : _expanded.add(key)),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 13),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_lighten(color, 0.25), color],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ),
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
                      Text(_dl(dept),
                          style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14, color: Colors.white)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.22),
                            borderRadius: BorderRadius.circular(8)),
                        child: Text('${members.length}명',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 11,
                                fontWeight: FontWeight.w800)),
                      ),
                      if (lateCount > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.22),
                              borderRadius: BorderRadius.circular(8)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.alarm_rounded,
                                size: 11, color: Colors.white),
                            const SizedBox(width: 3),
                            Text('지각 $lateCount',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 11,
                                    fontWeight: FontWeight.w800)),
                          ]),
                        ),
                      ],
                      const Spacer(),
                      AnimatedRotation(
                        turns: expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(Icons.keyboard_arrow_down_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ]),
                  ),
                ),

                // ── 멤버 목록
                AnimatedCrossFade(
                  firstChild: const SizedBox(width: double.infinity),
                  secondChild: Column(
                    children: members.asMap().entries.map((e) =>
                        _memberRow(e.value, widget.isWorking,
                            e.key == members.length - 1)).toList(),
                  ),
                  crossFadeState: expanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 200),
                ),
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _memberRow(Map<String, dynamic> item, bool isWorking, bool isLast) {
    final color     = isWorking ? Colors.green : Colors.blueGrey;
    final late      = isLate(item);
    final lateMin   = lateMinutes(item);
    final wd        = item['work_date'] as String?;
    final dc        = deptColor(item['dept_category'] as String? ?? '');
    final name      = item['full_name'] as String? ?? '-';

    return GestureDetector(
      onTap: () => _openMonthlySheet(item),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: !isLast
              ? Border(bottom: BorderSide(
                  color: Colors.black.withOpacity(0.05)))
              : null,
          color: late ? Colors.redAccent.withOpacity(0.03) : Colors.white,
        ),
        child: Row(children: [
          // 아바타
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: dc.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: Text(
              name.isNotEmpty ? name.substring(0, 1) : '?',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900,
                  color: dc),
            )),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(name, style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 13, color: _text)),
              if (late) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFFFF5252), Color(0xFFC62828)]),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(lateMin > 0 ? '지각 +${lateMin}분' : '지각',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 10,
                          fontWeight: FontWeight.w900)),
                ),
              ],
            ]),
            const SizedBox(height: 3),
            Row(children: [
              const Icon(Icons.login_rounded, size: 11, color: _sub),
              const SizedBox(width: 3),
              Text(formatTime(item['check_in'], workDate: wd),
                  style: const TextStyle(fontSize: 11, color: _sub)),
              if (!isWorking) ...[
                const Text('  →  ',
                    style: TextStyle(fontSize: 11, color: _sub)),
                const Icon(Icons.logout_rounded, size: 11, color: _sub),
                const SizedBox(width: 3),
                Text(formatTime(item['check_out'], workDate: wd),
                    style: const TextStyle(fontSize: 11, color: _sub)),
              ],
              const SizedBox(width: 8),
              const Icon(Icons.timer_outlined, size: 11, color: _sub),
              const SizedBox(width: 3),
              Text(workTimeText(item),
                  style: const TextStyle(fontSize: 11, color: _sub)),
            ]),
          ])),
          // 상태 뱃지
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_lighten(color, 0.15), color],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(
                  color: color.withOpacity(0.22), blurRadius: 6,
                  offset: const Offset(0, 2))],
            ),
            child: Text(isWorking ? '근무중' : '퇴근',
                style: const TextStyle(
                    color: Colors.white, fontSize: 11,
                    fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, size: 16, color: Colors.grey[300]),
        ]),
      ),
    );
  }

  void _openMonthlySheet(Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MonthlyAttendanceSheet(
        userId: item['user_id'] as String? ?? '',
        name:   item['full_name'] as String? ?? '-',
        dept:   item['dept_category'] as String? ?? '',
      ),
    );
  }
}

// ══════════════════════════════════════════
// ③ ④ 휴가 / 미출근 탭
// ══════════════════════════════════════════

class _AbsentListTab extends StatefulWidget {
  final Map<String, List<Map<String, dynamic>>> byDept;
  final bool isLeave;
  final String emptyMsg;
  final Future<void> Function() onRefresh;

  const _AbsentListTab({
    required this.byDept, required this.isLeave,
    required this.emptyMsg, required this.onRefresh,
  });

  @override
  State<_AbsentListTab> createState() => _AbsentListTabState();
}

class _AbsentListTabState extends State<_AbsentListTab>
    with AutomaticKeepAliveClientMixin {
  @override bool get wantKeepAlive => true;

  final Set<String> _expanded = {};

  static const _deptLabels = {
    'MANAGEMENT': '관리부', 'PRODUCTION': '생산관리부', 'SALES': '영업부',
    'RND': '연구소', 'STEEL': '스틸생산부', 'BOX': '박스생산부',
    'DELIVERY': '포장납품부', 'SSG': '에스에스지',
    'CLEANING': '환경미화', 'NUTRITION': '영양사',
  };
  String _dl(String d) => _deptLabels[d] ?? d;

  Color _lighten(Color c, double a) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + a).clamp(0.0, 1.0)).toColor();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final accentColor = widget.isLeave ? Colors.teal : Colors.redAccent;

    if (widget.byDept.isEmpty) {
      return RefreshIndicator(
        onRefresh: widget.onRefresh,
        child: ListView(children: [
          const SizedBox(height: 80),
          Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white, shape: BoxShape.circle,
                boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 14, offset: const Offset(0, 4))],
              ),
              child: Icon(
                widget.isLeave
                    ? Icons.flight_takeoff_rounded
                    : Icons.check_circle_outline_rounded,
                size: 38,
                color: widget.isLeave
                    ? Colors.teal.shade200
                    : Colors.green.shade200),
            ),
            const SizedBox(height: 14),
            Text(widget.emptyMsg,
                style: TextStyle(
                    color: Colors.grey[400],
                    fontWeight: FontWeight.w600)),
          ])),
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      color: accentColor,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 40),
        children: widget.byDept.entries.map((entry) {
          final dept    = entry.key;
          final members = entry.value;
          final color   = deptColor(dept);
          final key     = dept;
          final expanded = _expanded.contains(key);

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                    color: color.withOpacity(0.10), blurRadius: 12,
                    offset: const Offset(0, 4)),
                BoxShadow(
                    color: Colors.black.withOpacity(0.04), blurRadius: 6,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Column(children: [
                // 그라디언트 헤더
                GestureDetector(
                  onTap: () => setState(() =>
                      expanded ? _expanded.remove(key) : _expanded.add(key)),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 13),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_lighten(color, 0.25), color],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ),
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
                      Text(_dl(dept),
                          style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14, color: Colors.white)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.22),
                            borderRadius: BorderRadius.circular(8)),
                        child: Text('${members.length}명',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 11,
                                fontWeight: FontWeight.w800)),
                      ),
                      const Spacer(),
                      AnimatedRotation(
                        turns: expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(Icons.keyboard_arrow_down_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ]),
                  ),
                ),

                // 멤버 목록
                AnimatedCrossFade(
                  firstChild: const SizedBox(width: double.infinity),
                  secondChild: Column(
                    children: members.asMap().entries.map((e) {
                      final p        = e.value;
                      final isLast   = e.key == members.length - 1;
                      final lType    = p['_leave_type'] as String? ?? '';
                      final name     = p['full_name'] as String? ?? '-';
                      final dc       = deptColor(dept);

                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 11),
                        decoration: BoxDecoration(
                          border: !isLast
                              ? Border(bottom: BorderSide(
                                  color: Colors.black.withOpacity(0.05)))
                              : null,
                        ),
                        child: Row(children: [
                          Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                                color: dc.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10)),
                            child: Center(child: Text(
                              name.isNotEmpty ? name.substring(0, 1) : '?',
                              style: TextStyle(fontSize: 14,
                                  fontWeight: FontWeight.w900, color: dc),
                            )),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13, color: Color(0xFF1A1D2E)))),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: widget.isLeave
                                    ? [Colors.teal.shade300, Colors.teal.shade600]
                                    : [Colors.redAccent.shade100, Colors.redAccent],
                                begin: Alignment.topLeft, end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [BoxShadow(
                                  color: accentColor.withOpacity(0.22),
                                  blurRadius: 6, offset: const Offset(0, 2))],
                            ),
                            child: Text(
                              widget.isLeave
                                  ? (lType.isNotEmpty ? lType : '휴가')
                                  : '미출근',
                              style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w800,
                                  color: Colors.white),
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
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ══════════════════════════════════════════
// 개인 월별 출퇴근 바텀시트
// ══════════════════════════════════════════

class _MonthlyAttendanceSheet extends StatefulWidget {
  final String userId, name, dept;
  const _MonthlyAttendanceSheet({
    required this.userId, required this.name, required this.dept,
  });

  @override
  State<_MonthlyAttendanceSheet> createState() =>
      _MonthlyAttendanceSheetState();
}

class _MonthlyAttendanceSheetState
    extends State<_MonthlyAttendanceSheet> {
  static const _sub = Color(0xFF8A93B0);
  static const _bg  = Color(0xFFF4F6FB);

  late int _year, _month;
  bool _loading = false;
  List<Map<String, dynamic>> _records = [];

  Color _lighten(Color c, double a) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + a).clamp(0.0, 1.0)).toColor();
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year; _month = now.month;
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
      final today        = DateTime.now();
      final allDays      = <Map<String, dynamic>>[];

      for (int d = lastDay; d >= 1; d--) {
        final dt      = DateTime(_year, _month, d);
        if (dt.isAfter(today)) continue;
        final dateStr = '$_year-${_month.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
        if (fetchedDates.contains(dateStr)) {
          allDays.add(fetched.firstWhere((r) => r['work_date'] == dateStr));
        } else {
          final isWeekend = dt.weekday == 6 || dt.weekday == 7;
          allDays.add({
            'work_date': dateStr,
            'check_in': null, 'check_out': null,
            '_type': isWeekend ? 'weekend' : 'absent',
          });
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
  int get _lateCount =>
      _records.where((r) => r['_type'] == null && isLate(r)).length;

  int _timeToMinutes(String t) {
    final parts = t.split(':');
    if (parts.length < 2) return 0;
    return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
  }
  static const int _breakMinutes = 90;
  int _workMinutes(Map<String, dynamic> r) {
    final inT  = r['check_in']  as String?;
    final outT = r['check_out'] as String?;
    if (inT == null || outT == null) return 0;
    final diff = _timeToMinutes(outT) - _timeToMinutes(inT) - _breakMinutes;
    return diff < 0 ? 0 : diff;
  }
  int get _totalMinutes => _records
      .where((r) => r['_type'] == null)
      .fold(0, (s, r) => s + _workMinutes(r));
  String get _totalWorkStr {
    final h = _totalMinutes ~/ 60; final m = _totalMinutes % 60;
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final dc      = deptColor(widget.dept);
    final lighter = _lighten(dc, 0.18);

    return DraggableScrollableSheet(
      initialChildSize: 0.92, minChildSize: 0.45, maxChildSize: 0.95,
      expand: false,
      builder: (_, sc) => Container(
        decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: Column(children: [
          // ── 그라디언트 헤더
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [lighter, dc],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Stack(children: [
              Positioned(right: -30, top: -30, child: Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.08)))),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                child: Column(children: [
                  Container(width: 36, height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.45),
                          borderRadius: BorderRadius.circular(2))),
                  Row(children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.white.withOpacity(0.22),
                      child: Text(widget.name.isNotEmpty ? widget.name[0] : '?',
                          style: const TextStyle(fontSize: 18,
                              fontWeight: FontWeight.w900, color: Colors.white)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(widget.name, style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w900,
                          color: Colors.white)),
                      const SizedBox(height: 4),
                      // 월 선택 드롭다운
                      Row(children: [
                        _dropChip(_year, List.generate(3, (i) => DateTime.now().year - i),
                            (v) => setState(() { _year = v!; _load(); }), (v) => '$v년'),
                        const SizedBox(width: 6),
                        _dropChip(_month, List.generate(12, (i) => i + 1),
                            (v) => setState(() { _month = v!; _load(); }), (v) => '$v월'),
                      ]),
                    ])),
                  ]),
                  const SizedBox(height: 14),
                  // 요약 통계
                  Row(children: [
                    _hStatBox('출근일', '$_workDays일'),
                    _hStatBox('지각',   '$_lateCount회'),
                    _hStatBox('총근무', _totalWorkStr),
                  ]),
                ]),
              ),
            ]),
          ),

          // ── 일별 목록
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: sc,
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 32),
                    itemCount: _records.length,
                    itemBuilder: (_, i) => _recordRow(_records[i]),
                  ),
          ),
        ]),
      ),
    );
  }

  Widget _dropChip<T>(T value, List<T> items,
      void Function(T?) onChanged, String Function(T) label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.22),
          borderRadius: BorderRadius.circular(8)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items.map((e) => DropdownMenuItem(
              value: e,
              child: Text(label(e),
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: Colors.white)))).toList(),
          onChanged: onChanged,
          isDense: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: Colors.white, size: 14),
          dropdownColor: const Color(0xFF2E6BFF),
          style: const TextStyle(color: Colors.white,
              fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _hStatBox(String label, String value) {
    return Expanded(child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Text(value, style: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(
            fontSize: 10, color: Colors.white.withOpacity(0.75),
            fontWeight: FontWeight.w600)),
      ]),
    ));
  }

  Widget _recordRow(Map<String, dynamic> record) {
    final wd      = record['work_date'] as String? ?? '';
    final type    = record['_type']     as String?;
    final late    = type == null && isLate(record);
    final lateMin = type == null ? lateMinutes(record) : 0;
    final hasOut  = record['check_out'] != null;

    final parts = wd.split('-');
    final dt = parts.length == 3
        ? DateTime(int.parse(parts[0]), int.parse(parts[1]),
            int.parse(parts[2]))
        : DateTime.now();
    final weekday   = _weekdayStr(dt.weekday);
    final dd        = parts.length == 3 ? parts[2] : '';
    final isSat     = dt.weekday == 6;
    final isSun     = dt.weekday == 7;
    final dateColor = isSun ? Colors.red : isSat ? Colors.blue : const Color(0xFF1A1D2E);

    // 주말 / 미출근 / 정상
    if (type == 'weekend') {
      return Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
            color: _bg, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          _dateBox(dd, weekday, dateColor),
          const SizedBox(width: 12),
          Text('휴무', style: TextStyle(
              fontSize: 12, color: Colors.grey[400],
              fontWeight: FontWeight.w600)),
        ]),
      );
    }

    if (type == 'absent') {
      return Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.redAccent.withOpacity(0.12)),
        ),
        child: Row(children: [
          _dateBox(dd, weekday, dateColor),
          const SizedBox(width: 12),
          const Text('미출근',
              style: TextStyle(fontSize: 12, color: Colors.redAccent,
                  fontWeight: FontWeight.w700)),
        ]),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: late ? Colors.redAccent.withOpacity(0.03) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: late
              ? Colors.redAccent.withOpacity(0.15)
              : Colors.black.withOpacity(0.06),
        ),
      ),
      child: Row(children: [
        _dateBox(dd, weekday, dateColor),
        const SizedBox(width: 12),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _timeChip(icon: Icons.login_rounded, color: Colors.green,
                label: formatTime(record['check_in'], workDate: wd)),
            const SizedBox(width: 6),
            if (hasOut)
              _timeChip(icon: Icons.logout_rounded, color: Colors.blueGrey,
                  label: formatTime(record['check_out'], workDate: wd))
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6)),
                child: const Text('근무중', style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w800,
                    color: Colors.orange)),
              ),
          ]),
          if (hasOut) ...[
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.timer_outlined, size: 11, color: _sub),
              const SizedBox(width: 3),
              Text(workTimeText(record),
                  style: const TextStyle(fontSize: 11, color: _sub)),
            ]),
          ],
        ])),
        if (late)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFFFF5252), Color(0xFFC62828)]),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(lateMin > 0 ? '+${lateMin}분' : '지각',
                style: const TextStyle(
                    color: Colors.white, fontSize: 10,
                    fontWeight: FontWeight.w900)),
          ),
      ]),
    );
  }

  Widget _dateBox(String dd, String weekday, Color color) {
    return Container(
      width: 40,
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
          color: _bg, borderRadius: BorderRadius.circular(9)),
      child: Column(children: [
        Text(dd, style: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w900, color: color)),
        Text(weekday, style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w600,
            color: color.withOpacity(0.6))),
      ]),
    );
  }

  Widget _timeChip({required IconData icon, required Color color,
      required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(7)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }

  String _weekdayStr(int w) =>
      ['월','화','수','목','금','토','일'][w - 1];
}