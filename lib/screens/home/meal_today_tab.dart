// meal_today_tab.dart — 오늘 현황 탭

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'meal_report_models.dart';

class MealTodayTab extends StatelessWidget {
  final List<Map<String, dynamic>> allProfiles;
  final List<String> depts;
  final int totalMembers;
  final VoidCallback onRefresh;

  const MealTodayTab({
    Key? key,
    required this.allProfiles,
    required this.depts,
    required this.totalMembers,
    required this.onRefresh,
  }) : super(key: key);

  static final supabase = Supabase.instance.client;
  static final _today = DateFormat('yyyy-MM-dd').format(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final stream = supabase
        .from('meal_requests')
        .stream(primaryKey: ['id'])
        .eq('meal_date', _today);

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        final raw      = snap.data ?? [];
        final todayAll = raw.where((r) => !mrExcludedDepts.contains(r['dept_category'])).toList();
        final lunchRows  = todayAll.where((r) => r['meal_type'] == 'LUNCH').toList();
        final dinnerRows = todayAll.where((r) => r['meal_type'] == 'DINNER').toList();

        MealStat makeTotalStat(List<Map<String, dynamic>> rows) {
          final e = rows.where((r) => r['is_eating'] == true).length;
          final n = rows.where((r) => r['is_eating'] == false).length;
          return MealStat(eating: e, notEating: n,
              noReply: (totalMembers - e - n).clamp(0, 99999), members: totalMembers);
        }

        List<DeptMealStat> makeDeptStats(List<Map<String, dynamic>> rows) {
          return depts.map((dept) {
            final members = allProfiles.where((p) => p['dept_category'] == dept).length;
            final dr = rows.where((r) => r['dept_category'] == dept).toList();
            final e  = dr.where((r) => r['is_eating'] == true).length;
            final n  = dr.where((r) => r['is_eating'] == false).length;
            return DeptMealStat(dept: dept, members: members, eating: e, notEating: n,
                noReply: (members - dr.length).clamp(0, 99999));
          }).toList();
        }

        return RefreshIndicator(
          onRefresh: () async => onRefresh(),
          color: mrPrimary,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
            children: [
              // 날짜 + LIVE 뱃지
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: mrPrimary.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                  child: Text(DateFormat('MM월 dd일 (E)', 'ko_KR').format(DateTime.now()),
                      style: const TextStyle(fontWeight: FontWeight.w800, color: mrPrimary, fontSize: 13)),
                ),
                const SizedBox(width: 8),
                const Text("실시간", style: TextStyle(fontSize: 12, color: mrSub)),
                const Spacer(),
                Container(width: 8, height: 8,
                    decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.4), blurRadius: 6)])),
                const SizedBox(width: 5),
                const Text("LIVE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.green)),
              ]),
              const SizedBox(height: 16),
              _mealSectionCard(icon: Icons.wb_sunny_rounded, label: "점심", color: mrOrange,
                  total: makeTotalStat(lunchRows), deptStats: makeDeptStats(lunchRows)),
              const SizedBox(height: 12),
              _mealSectionCard(icon: Icons.nights_stay_rounded, label: "저녁", color: mrTeal,
                  total: makeTotalStat(dinnerRows), deptStats: makeDeptStats(dinnerRows)),
            ],
          ),
        );
      },
    );
  }

  Widget _mealSectionCard({
    required IconData icon, required String label, required Color color,
    required MealStat total, required List<DeptMealStat> deptStats,
  }) {
    final rate = total.members > 0 ? (total.eating + total.notEating) / total.members : 0.0;
    final rc   = mrRateColor(rate);
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.15)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(color: color.withOpacity(0.07),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18))),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 16)),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color)),
            const Spacer(),
            Text("${(rate * 100).toStringAsFixed(0)}%",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: rc)),
          ]),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(children: [
              mrMiniBox("식사", "${total.eating}", mrOrange),
              const SizedBox(width: 8),
              mrMiniBox("불참", "${total.notEating}", mrSub),
              const SizedBox(width: 8),
              mrMiniBox("미응답", "${total.noReply}", mrRed),
            ])),
        Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: ClipRRect(borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(value: rate.clamp(0.0, 1.0), minHeight: 6,
                    backgroundColor: Colors.black.withOpacity(0.06), valueColor: AlwaysStoppedAnimation(color)))),
        Divider(height: 1, color: Colors.black.withOpacity(0.05)),
        ...deptStats.asMap().entries.map((entry) {
          final i = entry.key; final s = entry.value; final dc = mrDeptColor(s.dept);
          final r2 = s.members > 0 ? (s.eating + s.notEating) / s.members : 0.0;
          final rc2 = mrRateColor(r2);
          return Column(children: [
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(children: [
                  Container(width: 60,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(color: dc.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                      child: Text(mrDeptLabel(s.dept), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: dc),
                          textAlign: TextAlign.center, overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 10),
                  mrTiny("${s.eating}식", mrOrange), const SizedBox(width: 4),
                  mrTiny("${s.notEating}불", mrSub),
                  if (s.noReply > 0) ...[const SizedBox(width: 4), mrTiny("${s.noReply}무", mrRed)],
                  const Spacer(),
                  SizedBox(width: 60, child: ClipRRect(borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(value: r2.clamp(0.0, 1.0), minHeight: 5,
                          backgroundColor: Colors.black.withOpacity(0.06), valueColor: AlwaysStoppedAnimation(rc2)))),
                  const SizedBox(width: 8),
                  SizedBox(width: 34, child: Text("${(r2 * 100).toStringAsFixed(0)}%",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: rc2), textAlign: TextAlign.right)),
                ])),
            if (entry.key < deptStats.length - 1)
              Divider(height: 1, indent: 16, endIndent: 16, color: Colors.black.withOpacity(0.04)),
          ]);
        }),
        const SizedBox(height: 4),
      ]),
    );
  }
}