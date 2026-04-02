// meal_today_tab.dart — 오늘 현황 탭

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'meal_report_models.dart';

class MealTodayTab extends StatefulWidget {
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

  @override
  State<MealTodayTab> createState() => _MealTodayTabState();
}

class _MealTodayTabState extends State<MealTodayTab> {
  static final supabase = Supabase.instance.client;
  static final _today   = DateFormat('yyyy-MM-dd').format(DateTime.now());

  List<Map<String, dynamic>> _guests = [];

  // ── 영양사 제외 필터
  static const _excludedFromMeal = {'NUTRITION'};

  List<Map<String, dynamic>> get _filteredProfiles => widget.allProfiles
      .where((p) => !_excludedFromMeal.contains(p['dept_category'])).toList();

  List<String> get _filteredDepts => widget.depts
      .where((d) => !_excludedFromMeal.contains(d)).toList();

  int get _filteredTotalMembers => _filteredProfiles.length;

  @override
  void initState() {
    super.initState();
    _loadGuests();
  }

  Future<void> _loadGuests() async {
    try {
      final data = await supabase
          .from('meal_guests')
          .select()
          .eq('meal_date', _today);
      if (mounted) setState(() => _guests = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      debugPrint('손님 로드 실패: $e');
    }
  }

  // 손님 추가 다이얼로그
  Future<void> _showAddGuest(BuildContext context) async {
    String mealType = 'LUNCH';
    int guestCount = 1;
    final memoCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [
            Icon(Icons.person_add_rounded, color: mrOrange, size: 20),
            SizedBox(width: 8),
            Text('손님 추가', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            // 식사 구분
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => setS(() => mealType = 'LUNCH'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                      color: mealType == 'LUNCH'
                          ? mrOrange : Colors.grey.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10)),
                  child: Text('점심', textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w800,
                          color: mealType == 'LUNCH' ? Colors.white : Colors.grey)),
                ),
              )),
              const SizedBox(width: 8),
              Expanded(child: GestureDetector(
                onTap: () => setS(() => mealType = 'DINNER'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                      color: mealType == 'DINNER'
                          ? mrTeal : Colors.grey.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10)),
                  child: Text('저녁', textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w800,
                          color: mealType == 'DINNER' ? Colors.white : Colors.grey)),
                ),
              )),
            ]),
            const SizedBox(height: 16),
            // 인원 수
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              GestureDetector(
                onTap: () => setS(() { if (guestCount > 1) guestCount--; }),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.remove_rounded, size: 18)),
              ),
              const SizedBox(width: 20),
              Text('$guestCount 명', style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w900, color: mrText)),
              const SizedBox(width: 20),
              GestureDetector(
                onTap: () => setS(() => guestCount++),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                      color: mrOrange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.add_rounded, size: 18, color: mrOrange)),
              ),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: memoCtrl,
              decoration: InputDecoration(
                labelText: '메모 (소속, 방문 목적 등)',
                filled: true, fillColor: const Color(0xFFF4F6FB),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
              ),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('취소')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: mrOrange,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              onPressed: () async {
                final me = supabase.auth.currentUser;
                String? myDept;
                if (me != null) {
                  final p = await supabase.from('profiles')
                      .select('dept_category').eq('id', me.id).maybeSingle();
                  myDept = p?['dept_category'] as String?;
                }
                await supabase.from('meal_guests').insert({
                  'registered_by': me?.id,
                  'dept_category': myDept,
                  'meal_date':     _today,
                  'meal_type':     mealType,
                  'guest_count':   guestCount,
                  'memo':          memoCtrl.text.trim(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
                _loadGuests();
              },
              child: const Text('추가',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  // ── 명단 바텀시트
  void _showPersonList(
    BuildContext context, {
    required String title,
    required Color color,
    required IconData icon,
    required List<Map<String, dynamic>> persons,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(children: [
            Container(width: 36, height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(children: [
                Container(padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10)),
                    child: Icon(icon, color: color, size: 18)),
                const SizedBox(width: 12),
                Text(title, style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w900, color: mrText)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text('${persons.length}명',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                          color: color)),
                ),
              ]),
            ),
            Divider(height: 1, color: Colors.black.withOpacity(0.06)),
            Expanded(
              child: persons.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.check_circle_outline_rounded,
                          size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 10),
                      Text('해당 인원 없음',
                          style: TextStyle(color: Colors.grey[400], fontSize: 14)),
                    ]))
                  : ListView.separated(
                      controller: ctrl,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      itemCount: persons.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: Colors.black.withOpacity(0.05)),
                      itemBuilder: (_, i) {
                        final p           = persons[i];
                        final name        = p['full_name']     as String? ?? '-';
                        final dept        = p['dept_category'] as String? ?? '';
                        final nationality = p['nationality']   as String? ?? '';
                        final dc          = mrDeptColor(dept);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(children: [
                            Stack(children: [
                              CircleAvatar(radius: 20,
                                  backgroundColor: dc.withOpacity(0.1),
                                  child: Text(name.isNotEmpty ? name[0] : '?',
                                      style: TextStyle(fontSize: 15,
                                          fontWeight: FontWeight.w900, color: dc))),
                              if (nationality.isNotEmpty)
                                Positioned(
                                  right: 0, bottom: 0,
                                  child: Text(_nationalityFlag(nationality),
                                      style: const TextStyle(fontSize: 12)),
                                ),
                            ]),
                            const SizedBox(width: 12),
                            Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(name, style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w700,
                                  color: mrText)),
                              if (nationality.isNotEmpty)
                                Text(nationality, style: TextStyle(
                                    fontSize: 11, color: Colors.grey[500])),
                            ])),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                  color: dc.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6)),
                              child: Text(mrDeptLabel(dept),
                                  style: TextStyle(fontSize: 11,
                                      fontWeight: FontWeight.w700, color: dc)),
                            ),
                          ]),
                        );
                      },
                    ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── 부서 상세 바텀시트
  void _showDeptDetail(
    BuildContext context, {
    required String dept,
    required String mealLabel,
    required Color color,
    required List<Map<String, dynamic>> allRows,
  }) {
    final dc       = mrDeptColor(dept);
    final deptRows = allRows.where((r) => r['dept_category'] == dept).toList();
    final eating   = deptRows.where((r) => r['is_eating'] == true).toList();
    final notEating= deptRows.where((r) => r['is_eating'] == false).toList();
    final deptProfiles = _filteredProfiles
        .where((p) => p['dept_category'] == dept).toList();
    final repliedIds = deptRows.map((r) => r['user_id'] as String).toSet();
    final noReply  = deptProfiles
        .where((p) => !repliedIds.contains(p['id'] as String)).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(children: [
            // 핸들
            Container(width: 36, height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2))),
            // 헤더
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: dc.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(mrDeptLabel(dept), style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800, color: dc)),
                ),
                const SizedBox(width: 8),
                Text('$mealLabel 식수 현황',
                    style: const TextStyle(fontSize: 16,
                        fontWeight: FontWeight.w900, color: mrText)),
                const Spacer(),
                Text('${deptProfiles.length}명',
                    style: const TextStyle(fontSize: 13, color: mrSub,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
            // 요약 바
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(children: [
                _statChip('식사 ${eating.length}', mrOrange),
                const SizedBox(width: 8),
                _statChip('불참 ${notEating.length}', mrSub),
                const SizedBox(width: 8),
                if (noReply.isNotEmpty)
                  _statChip('미응답 ${noReply.length}', mrRed),
              ]),
            ),
            Divider(height: 1, color: Colors.grey.withOpacity(0.1)),
            // 목록
            Expanded(child: ListView(
              controller: ctrl,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                if (eating.isNotEmpty) ...[
                  _deptSectionHeader('🍚 식사', eating.length, mrOrange),
                  ...eating.map((r) => _deptPersonTile(r['full_name'] ?? '-',
                      mrOrange, icon: Icons.check_circle_rounded)),
                ],
                if (notEating.isNotEmpty) ...[
                  _deptSectionHeader('🚫 불참', notEating.length, mrSub),
                  ...notEating.map((r) => _deptPersonTile(r['full_name'] ?? '-',
                      mrSub, icon: Icons.cancel_rounded)),
                ],
                if (noReply.isNotEmpty) ...[
                  _deptSectionHeader('❓ 미응답', noReply.length, mrRed),
                  ...noReply.map((p) => _deptPersonTile(
                      p['full_name'] ?? '-', mrRed,
                      icon: Icons.help_rounded,
                      nationality: p['nationality'] as String?)),
                ],
              ],
            )),
          ]),
        ),
      ),
    );
  }

  Widget _statChip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8)),
    child: Text(label, style: TextStyle(fontSize: 12,
        fontWeight: FontWeight.w700, color: color)),
  );

  Widget _deptSectionHeader(String title, int count, Color color) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 12, 0, 6),
    child: Row(children: [
      Text(title, style: TextStyle(fontSize: 13,
          fontWeight: FontWeight.w800, color: color)),
      const SizedBox(width: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6)),
        child: Text('$count명', style: TextStyle(fontSize: 10,
            fontWeight: FontWeight.w800, color: color)),
      ),
    ]),
  );

  Widget _deptPersonTile(String name, Color color,
      {required IconData icon, String? nationality}) {
    final flag = nationality != null && nationality.isNotEmpty &&
        nationality != '한국' ? _nationalityFlag(nationality) : '';
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
          color: color.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 10),
        Text(name, style: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w700, color: mrText)),
        if (flag.isNotEmpty) ...[
          const SizedBox(width: 6),
          Text(flag, style: const TextStyle(fontSize: 14)),
        ],
      ]),
    );
  }

  Widget _tapBox(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
    required IconData icon,
    required String sheetTitle,
    required List<Map<String, dynamic>> persons,
    String? nationalitySub,
    int guestCount = 0,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _showPersonList(context,
            title: sheetTitle, color: color, icon: icon, persons: persons),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(children: [
            Text(value, style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w900, color: color)),
            if (guestCount > 0) ...[
              const SizedBox(height: 1),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.person_pin_rounded, size: 10,
                    color: color.withOpacity(0.6)),
                const SizedBox(width: 2),
                Text('손님 $guestCount명 포함', style: TextStyle(
                    fontSize: 9, fontWeight: FontWeight.w700,
                    color: color.withOpacity(0.7))),
              ]),
            ],
            if (nationalitySub != null && nationalitySub.isNotEmpty) ...[
              const SizedBox(height: 1),
              Text(nationalitySub, style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w600,
                  color: color.withOpacity(0.65))),
            ],
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11, color: mrSub)),
            const SizedBox(height: 2),
            Icon(Icons.keyboard_arrow_down_rounded,
                size: 14, color: color.withOpacity(0.5)),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stream = supabase
        .from('meal_requests')
        .stream(primaryKey: ['id'])
        .eq('meal_date', _today);

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        final raw        = snap.data ?? [];
        // ── 영양사(NUTRITION) 및 기존 excludedDepts 모두 제외
        final todayAll   = raw.where((r) =>
            !mrExcludedDepts.contains(r['dept_category']) &&
            !_excludedFromMeal.contains(r['dept_category'])).toList();
        final lunchRows  = todayAll.where((r) => r['meal_type'] == 'LUNCH').toList();
        final dinnerRows = todayAll.where((r) => r['meal_type'] == 'DINNER').toList();

        // 손님 수
        final lunchGuests  = _guests.where((g) => g['meal_type'] == 'LUNCH')
            .fold(0, (s, g) => s + ((g['guest_count'] as int?) ?? 0));
        final dinnerGuests = _guests.where((g) => g['meal_type'] == 'DINNER')
            .fold(0, (s, g) => s + ((g['guest_count'] as int?) ?? 0));

        // ── 전체 통계 (영양사 제외된 _filteredTotalMembers 사용)
        MealStat makeTotalStat(List<Map<String, dynamic>> rows, int guests) {
          final e = rows.where((r) => r['is_eating'] == true).length + guests;
          final n = rows.where((r) => r['is_eating'] == false).length;
          return MealStat(eating: e, notEating: n,
              noReply: (_filteredTotalMembers - rows.where((r) =>
                  r['is_eating'] == true).length - n).clamp(0, 99999),
              members: _filteredTotalMembers);
        }

        // profiles nationality 맵 생성
        final nationalityMap = <String, String>{};
        for (final p in _filteredProfiles) {
          final uid = p['id'] as String? ?? '';
          final nat = p['nationality'] as String? ?? '';
          if (nat.isNotEmpty) nationalityMap[uid] = nat;
        }

        List<Map<String, dynamic>> withNationality(
            List<Map<String, dynamic>> rows) {
          return rows.map((r) {
            final uid = r['user_id'] as String? ?? '';
            return {...r, 'nationality': nationalityMap[uid] ?? ''};
          }).toList();
        }

        List<Map<String, dynamic>> eating(List<Map<String, dynamic>> rows) =>
            withNationality(rows.where((r) => r['is_eating'] == true).toList());

        List<Map<String, dynamic>> notEating(List<Map<String, dynamic>> rows) =>
            withNationality(rows.where((r) => r['is_eating'] == false).toList());

        // ── 미응답: 영양사 제외된 _filteredProfiles 기준
        List<Map<String, dynamic>> noReply(List<Map<String, dynamic>> rows) {
          final repliedIds = rows.map((r) => r['user_id'] as String).toSet();
          return _filteredProfiles
              .where((p) => !repliedIds.contains(p['id'] as String))
              .toList();
        }

        // ── 부서별 통계: 영양사 제외된 _filteredDepts 사용
        List<DeptMealStat> makeDeptStats(List<Map<String, dynamic>> rows) {
          return _filteredDepts.map((dept) {
            final members = _filteredProfiles
                .where((p) => p['dept_category'] == dept).length;
            final dr = rows.where((r) => r['dept_category'] == dept).toList();
            final e  = dr.where((r) => r['is_eating'] == true).length;
            final n  = dr.where((r) => r['is_eating'] == false).length;
            return DeptMealStat(dept: dept, members: members, eating: e,
                notEating: n,
                noReply: (members - dr.length).clamp(0, 99999));
          }).toList();
        }

        final lunchStat  = makeTotalStat(lunchRows,  lunchGuests);
        final dinnerStat = makeTotalStat(dinnerRows, dinnerGuests);

        return RefreshIndicator(
          onRefresh: () async { widget.onRefresh(); _loadGuests(); },
          color: mrPrimary,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
            children: [
              // 날짜 + LIVE 뱃지 + 손님 추가 버튼
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: mrPrimary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10)),
                  child: Text(
                    DateFormat('MM월 dd일 (E)', 'ko_KR').format(DateTime.now()),
                    style: const TextStyle(fontWeight: FontWeight.w800,
                        color: mrPrimary, fontSize: 13)),
                ),
                const SizedBox(width: 8),
                const Text("실시간", style: TextStyle(fontSize: 12, color: mrSub)),
                const Spacer(),
                Container(width: 8, height: 8,
                    decoration: BoxDecoration(color: Colors.green,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(
                            color: Colors.green.withOpacity(0.4),
                            blurRadius: 6)])),
                const SizedBox(width: 5),
                const Text("LIVE", style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w800,
                    color: Colors.green)),
                const SizedBox(width: 12),
                // 손님 추가 버튼
                GestureDetector(
                  onTap: () => _showAddGuest(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        color: mrOrange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: mrOrange.withOpacity(0.25))),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.person_add_rounded,
                          size: 13, color: mrOrange),
                      const SizedBox(width: 4),
                      const Text('손님 추가', style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w800,
                          color: mrOrange)),
                      if (lunchGuests + dinnerGuests > 0) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                              color: mrOrange,
                              borderRadius: BorderRadius.circular(8)),
                          child: Text('${lunchGuests + dinnerGuests}',
                              style: const TextStyle(fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white)),
                        ),
                      ],
                    ]),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              // 탭 안내
              Row(children: [
                Icon(Icons.touch_app_rounded, size: 12,
                    color: mrSub.withOpacity(0.6)),
                const SizedBox(width: 4),
                Text('식사/불참/미응답 탭하면 명단을 볼 수 있어요',
                    style: TextStyle(fontSize: 11,
                        color: mrSub.withOpacity(0.8))),
              ]),
              const SizedBox(height: 16),

              // 점심 카드
              _mealSectionCard(context,
                icon: Icons.wb_sunny_rounded, label: "점심", color: mrOrange,
                total: lunchStat,
                deptStats: makeDeptStats(lunchRows),
                eatingList:   eating(lunchRows),
                notEatingList: notEating(lunchRows),
                noReplyList:  noReply(lunchRows),
                mealLabel: '점심',
                allRows: lunchRows,
                guestCount: lunchGuests,
              ),
              const SizedBox(height: 12),

              // 저녁 카드
              _mealSectionCard(context,
                icon: Icons.nights_stay_rounded, label: "저녁", color: mrTeal,
                total: dinnerStat,
                deptStats: makeDeptStats(dinnerRows),
                eatingList:   eating(dinnerRows),
                notEatingList: notEating(dinnerRows),
                noReplyList:  noReply(dinnerRows),
                mealLabel: '저녁',
                allRows: dinnerRows,
                guestCount: dinnerGuests,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _mealSectionCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required MealStat total,
    required List<DeptMealStat> deptStats,
    required List<Map<String, dynamic>> eatingList,
    required List<Map<String, dynamic>> notEatingList,
    required List<Map<String, dynamic>> noReplyList,
    required String mealLabel,
    required List<Map<String, dynamic>> allRows,
    int guestCount = 0,
  }) {
    final rate = total.members > 0
        ? (total.eating + total.notEating) / total.members
        : 0.0;
    final rc = mrRateColor(rate);

    String _natSub(List<Map<String, dynamic>> list, {int guests = 0}) {
      if (list.isEmpty && guests == 0) return '';
      final totalCount = list.length + guests;
      final natCount = <String, int>{};
      for (final p in list) {
        final nat = p['nationality'] as String? ?? '';
        if (nat.isNotEmpty && nat != '한국') {
          natCount[nat] = (natCount[nat] ?? 0) + 1;
        }
      }
      if (guests > 0) natCount['손님'] = guests;
      if (natCount.isEmpty) return '';
      final foreignTotal = natCount.values.fold(0, (a, b) => a + b);
      final domestic = totalCount - foreignTotal;
      final flags = natCount.entries.map((e) {
        final flag = e.key == '손님' ? '👤' : _nationalityFlag(e.key);
        return '$flag${e.value}';
      }).join(' ');
      return domestic > 0 ? '$domestic+$foreignTotal  $flags' : flags;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.15)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
            blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        // 헤더
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(color: color.withOpacity(0.07),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18))),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 16)),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(fontSize: 15,
                fontWeight: FontWeight.w900, color: color)),
            const Spacer(),
            Text("${(rate * 100).toStringAsFixed(0)}%",
                style: TextStyle(fontSize: 22,
                    fontWeight: FontWeight.w900, color: rc)),
          ]),
        ),

        // 탭 가능한 숫자 박스 3개
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Row(children: [
            _tapBox(context,
              label: '식사',
              value: guestCount > 0
                  ? '${total.eating - guestCount}+$guestCount'
                  : '${total.eating}',
              color: mrOrange,
              icon: Icons.restaurant_rounded,
              sheetTitle: '$mealLabel 식사 인원',
              persons: eatingList,
              nationalitySub: _natSub(eatingList, guests: guestCount),
              guestCount: guestCount,
            ),
            const SizedBox(width: 8),
            _tapBox(context,
              label: '불참', value: '${total.notEating}', color: mrSub,
              icon: Icons.do_not_disturb_alt_rounded,
              sheetTitle: '$mealLabel 불참 인원',
              persons: notEatingList,
              nationalitySub: _natSub(notEatingList),
            ),
            const SizedBox(width: 8),
            _tapBox(context,
              label: '미응답', value: '${total.noReply}', color: mrRed,
              icon: Icons.help_outline_rounded,
              sheetTitle: '$mealLabel 미응답 인원',
              persons: noReplyList,
              nationalitySub: _natSub(noReplyList),
            ),
          ]),
        ),

        // 진행 바
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: ClipRRect(borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: rate.clamp(0.0, 1.0), minHeight: 6,
                backgroundColor: Colors.black.withOpacity(0.06),
                valueColor: AlwaysStoppedAnimation(color))),
        ),

        Divider(height: 1, color: Colors.black.withOpacity(0.05)),

        // 부서별
        ...deptStats.asMap().entries.map((entry) {
          final i = entry.key; final s = entry.value;
          final dc  = mrDeptColor(s.dept);
          final r2  = s.members > 0
              ? (s.eating + s.notEating) / s.members : 0.0;
          final rc2 = mrRateColor(r2);
          return Column(children: [
            GestureDetector(
              onTap: () => _showDeptDetail(
                context,
                dept:        s.dept,
                mealLabel:   mealLabel,
                color:       color,
                allRows:     allRows,
              ),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(children: [
                  Container(width: 60,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(color: dc.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6)),
                      child: Text(mrDeptLabel(s.dept),
                          style: TextStyle(fontSize: 11,
                              fontWeight: FontWeight.w800, color: dc),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 10),
                  mrTiny("${s.eating}식", mrOrange), const SizedBox(width: 4),
                  mrTiny("${s.notEating}불", mrSub),
                  if (s.noReply > 0) ...[const SizedBox(width: 4),
                    mrTiny("${s.noReply}무", mrRed)],
                  const Spacer(),
                  SizedBox(width: 60, child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                          value: r2.clamp(0.0, 1.0), minHeight: 5,
                          backgroundColor: Colors.black.withOpacity(0.06),
                          valueColor: AlwaysStoppedAnimation(rc2)))),
                  const SizedBox(width: 8),
                  SizedBox(width: 34,
                      child: Text("${(r2 * 100).toStringAsFixed(0)}%",
                          style: TextStyle(fontSize: 12,
                              fontWeight: FontWeight.w700, color: rc2),
                          textAlign: TextAlign.right)),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded,
                      size: 14, color: Colors.grey[300]),
                ]),
              ),
            ),
            if (i < deptStats.length - 1)
              Divider(height: 1, indent: 16, endIndent: 16,
                  color: Colors.black.withOpacity(0.04)),
          ]);
        }),
        const SizedBox(height: 4),
      ]),
    );
  }
}

String _nationalityFlag(String nationality) {
  return switch (nationality) {
    '한국'      => '🇰🇷',
    '우즈베키스탄' => '🇺🇿',
    '베트남'    => '🇻🇳',
    '캄보디아'  => '🇰🇭',
    '중국'      => '🇨🇳',
    '필리핀'    => '🇵🇭',
    '태국'      => '🇹🇭',
    '인도네시아' => '🇮🇩',
    '미얀마'    => '🇲🇲',
    '몽골'      => '🇲🇳',
    '네팔'      => '🇳🇵',
    '스리랑카'  => '🇱🇰',
    _           => '🌏',
  };
}