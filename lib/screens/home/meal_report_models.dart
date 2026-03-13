// meal_report_models.dart — 공유 데이터 클래스 & 상수

import 'package:flutter/material.dart';

const Color mrPrimary = Color(0xFF2E6BFF);
const Color mrOrange  = Color(0xFFFF8C42);
const Color mrTeal    = Color(0xFF0BC5C5);
const Color mrRed     = Color(0xFFFF4D64);
const Color mrBg      = Color(0xFFF4F6FB);
const Color mrSub     = Color(0xFF8A93B0);
const Color mrText    = Color(0xFF1A1D2E);
const List<String> mrExcludedDepts = ['SEYOUNG', 'TEST'];

String mrDeptLabel(String dept) {
  return switch (dept.toUpperCase()) {
    'MANAGEMENT' => '관리부',
    'PRODUCTION'  => '생산관리부',
    'SALES'       => '영업부',
    'RND'         => '연구개발부',
    'STEEL'       => '스틸생산부',
    'BOX'         => '박스생산부',
    'DELIVERY'    => '포장납품',
    'SSG'         => '에스에스지',
    'CLEANING'    => '환경미화',
    'NUTRITION'   => '영양사',
    _ => dept,
  };
}

Color mrDeptColor(String dept) {
  return switch (dept.toUpperCase()) {
    'MANAGEMENT' => mrPrimary,
    'PRODUCTION'  => const Color(0xFF7C5CDB),
    'SALES'       => const Color(0xFFFF8C42),
    'RND'         => const Color(0xFF00BCD4),
    'STEEL'       => const Color(0xFF607D8B),
    'BOX'         => mrOrange,
    'DELIVERY'    => const Color(0xFFE91E8C),
    'SSG'         => const Color(0xFF009688),
    'CLEANING'    => const Color(0xFF8BC34A),
    'NUTRITION'   => const Color(0xFFFF7043),
    _ => mrSub,
  };
}

class MealStat {
  final int eating, notEating, noReply, members;
  const MealStat({required this.eating, required this.notEating, required this.noReply, required this.members});
  int get responded => eating + notEating;
  double get rate => members > 0 ? responded / members : 0.0;
}

class DeptStat {
  final String dept;
  final int members, eating, notEating, noReply;
  const DeptStat({required this.dept, required this.members, required this.eating, required this.notEating, required this.noReply});
}

class DeptMealStat {
  final String dept;
  final int members, eating, notEating, noReply;
  const DeptMealStat({required this.dept, required this.members, required this.eating, required this.notEating, required this.noReply});
}

class DayStat {
  final String date;
  final int total, eating, notEating, noReply;
  final Map<String, DeptStat> byDept;
  final MealStat lunch, dinner;
  final Map<String, MealStat> lunchByDept, dinnerByDept;
  const DayStat({
    required this.date, required this.total, required this.eating,
    required this.notEating, required this.noReply, required this.byDept,
    required this.lunch, required this.dinner,
    required this.lunchByDept, required this.dinnerByDept,
  });
}

// 공용 위젯 헬퍼
Widget mrChip(String label, Color c) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
  decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
  child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: c)),
);

Widget mrTiny(String label, Color c) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
  decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
  child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c)),
);

Widget mrMiniBox(String label, String val, Color c) => Expanded(
  child: Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(color: c.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
    child: Column(children: [
      Text(val, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: c)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(fontSize: 11, color: mrSub)),
    ]),
  ),
);

Widget mrSumCard(String label, String val, Color c, IconData icon) => Expanded(
  child: Container(
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 15, color: c),
      const SizedBox(height: 7),
      Text(val, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: c)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(fontSize: 10, color: mrSub, fontWeight: FontWeight.w600)),
    ]),
  ),
);

Widget mrDropBtn<T>({
  required T value, required List<T> items,
  required String Function(T) label, required void Function(T?) onChanged,
}) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 12),
  decoration: BoxDecoration(color: mrBg, borderRadius: BorderRadius.circular(9),
      border: Border.all(color: const Color(0xFFE0E5F0))),
  child: DropdownButton<T>(
    value: value, underline: const SizedBox(),
    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: mrText),
    items: items.map((e) => DropdownMenuItem(value: e, child: Text(label(e)))).toList(),
    onChanged: onChanged,
  ),
);

Color mrRateColor(double rate) => rate >= 0.7 ? mrTeal : rate >= 0.4 ? mrOrange : mrRed;

String mrWeekdayStr(int weekday) {
  const days = ['월', '화', '수', '목', '금', '토', '일'];
  return days[weekday - 1];
}