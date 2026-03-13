import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ══════════════════════════════════════════
// 지각 기준 상수
// ══════════════════════════════════════════
const int kWorkStartHour    = 8;
const int kWorkStartMinute  = 0;
const int kLateGraceMinutes = 0;
const int kAttendanceRangeDays = 7;

// ══════════════════════════════════════════
// 유틸 함수
// ══════════════════════════════════════════

/// 시간만 있는 문자열(HH:mm:ss)은 work_date와 합쳐서 파싱 + toLocal() UTC 변환
DateTime? toDateTime(dynamic v, {String? workDate}) {
  if (v == null) return null;
  if (v is DateTime) return v.toLocal();
  final str = v.toString().trim();
  if (str.contains('-') || str.contains('T')) {
    return DateTime.tryParse(str)?.toLocal();
  }
  if (workDate != null && workDate.isNotEmpty) {
    return DateTime.tryParse('$workDate $str')?.toLocal();
  }
  return null;
}

/// 지각 분 수 반환 (0이면 정상)
int lateMinutes(Map<String, dynamic> item) {
  final workDateStr = (item['work_date'] as String?) ?? '';
  final cin = toDateTime(item['check_in'], workDate: workDateStr);
  if (cin == null || workDateStr.isEmpty) return 0;

  DateTime workDate;
  try {
    workDate = DateTime.parse(workDateStr);
  } catch (_) {
    workDate = DateTime(cin.year, cin.month, cin.day);
  }

  final base = DateTime(
    workDate.year, workDate.month, workDate.day,
    kWorkStartHour, kWorkStartMinute,
  ).add(const Duration(minutes: kLateGraceMinutes));

  final diff = cin.difference(base).inMinutes;
  return diff > 0 ? diff : 0;
}

/// 지각 여부
bool isLate(Map<String, dynamic> item) => lateMinutes(item) > 0;

// ──────────────────────────────────────────
// 휴게시간 정의 (변경 시 여기만 수정)
// ──────────────────────────────────────────
// { 시작(시,분), 종료(시,분) }
const _kBreaks = [
  (startH: 10, startM: 15, endH: 10, endM: 30), // 오전 휴식 15분
  (startH: 12, startM:  0, endH: 13, endM:  0), // 점심    60분
  (startH: 15, startM: 15, endH: 15, endM: 30), // 오후 휴식 15분
];

/// 출퇴근 시간 사이에 실제로 포함된 휴게시간(분) 계산
int _breakMinutesBetween(DateTime cin, DateTime cout) {
  int total = 0;
  for (final b in _kBreaks) {
    final breakStart = DateTime(
        cin.year, cin.month, cin.day, b.startH, b.startM);
    final breakEnd = DateTime(
        cin.year, cin.month, cin.day, b.endH, b.endM);
    // 체류 시간과 휴게 구간의 겹치는 부분만 차감
    final overlapStart = cin.isAfter(breakStart) ? cin : breakStart;
    final overlapEnd   = cout.isBefore(breakEnd) ? cout : breakEnd;
    if (overlapEnd.isAfter(overlapStart)) {
      total += overlapEnd.difference(overlapStart).inMinutes;
    }
  }
  return total;
}

/// 순수 근무시간 텍스트 (휴게시간 차감)
String workTimeText(Map<String, dynamic> item) {
  final wd   = item['work_date'] as String?;
  final cin  = toDateTime(item['check_in'],  workDate: wd);
  final cout = toDateTime(item['check_out'], workDate: wd);
  if (cin == null) return "-";

  final end = cout ?? DateTime.now();
  final totalMinutes = end.difference(cin).inMinutes;
  if (totalMinutes < 0) return "-";

  // 퇴근 완료 / 근무 중 모두 이미 지난 휴게시간 차감
  final workMinutes = totalMinutes - _breakMinutesBetween(cin, end);

  final h   = workMinutes ~/ 60;
  final m   = workMinutes % 60;
  final dur = h <= 0 ? "${m}분" : "${h}시간 ${m}분";
  return cout == null ? "$dur (근무중)" : dur;
}

/// 시간 포맷 (HH:mm)
String formatTime(dynamic val, {String? workDate}) {
  if (val == null) return '-';
  final dt = toDateTime(val, workDate: workDate);
  if (dt != null) return DateFormat('HH:mm').format(dt);
  final str = val.toString();
  if (str.length >= 16) return str.substring(11, 16);
  if (str.length >= 5)  return str.substring(0, 5);
  return str;
}

/// 날짜 예쁘게 (MM/dd (요일))
String prettyDate(String yyyyMMdd) {
  try {
    return DateFormat('MM/dd (E)', 'ko_KR').format(DateTime.parse(yyyyMMdd));
  } catch (_) {
    return yyyyMMdd;
  }
}

/// 월 포맷 (yyyy년 M월)
String formatMonth(String yyyyMM) {
  try {
    final parts = yyyyMM.split('-');
    return "${parts[0]}년 ${int.parse(parts[1])}월";
  } catch (_) {
    return yyyyMM;
  }
}

/// 부서 색상
Color deptColor(String dept) {
  switch (dept.toUpperCase()) {
    case 'MANAGEMENT': return const Color(0xFF2E6BFF);
    case 'PRODUCTION':  return const Color(0xFF7C5CDB);
    case 'SALES':       return const Color(0xFFFF8C42);
    case 'RND':         return const Color(0xFF00BCD4);
    case 'STEEL':       return const Color(0xFF607D8B);
    case 'BOX':         return const Color(0xFF43A047);
    case 'DELIVERY':    return const Color(0xFFE91E8C);
    case 'SSG':         return const Color(0xFF009688);
    case 'CLEANING':    return const Color(0xFF8BC34A);
    case 'NUTRITION':   return const Color(0xFFFF7043);
    default:        return Colors.grey;
  }
}

/// 일별 출근/퇴근/지각 요약
Map<String, Map<String, int>> buildDailySummary(List<Map<String, dynamic>> rows) {
  final Map<String, Map<String, int>> map = {};
  for (final r in rows) {
    final date = (r['work_date'] as String?) ?? '알 수 없음';
    map.putIfAbsent(date, () => {'in': 0, 'out': 0, 'late': 0});
    if (r['check_in']  != null) map[date]!['in']   = map[date]!['in']!   + 1;
    if (r['check_out'] != null) map[date]!['out']  = map[date]!['out']!  + 1;
    if (isLate(r))              map[date]!['late'] = map[date]!['late']! + 1;
  }
  return map;
}

// ══════════════════════════════════════════
// 공용 위젯
// ══════════════════════════════════════════

Widget attendanceSectionHeader(String title, IconData icon, Color color) {
  return Row(children: [
    Icon(icon, size: 18, color: color),
    const SizedBox(width: 8),
    Text(title,
        style: TextStyle(
            fontSize: 15, fontWeight: FontWeight.bold, color: color)),
  ]);
}

Widget attendanceEmptyGuide(String msg) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Center(
        child: Text(msg,
            style: const TextStyle(color: Colors.grey, fontSize: 13))),
  );
}

Widget attendancePill(String label, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(10)),
    child: Text(label,
        style: TextStyle(
            color: color, fontWeight: FontWeight.w800, fontSize: 12)),
  );
}

Widget attendanceStatusBadge(String label, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8)),
    child: Text(label,
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.bold)),
  );
}