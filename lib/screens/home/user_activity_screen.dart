import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'lang_context.dart';
import 'app_strings.dart';

class UserActivityScreen extends StatefulWidget {
  const UserActivityScreen({Key? key}) : super(key: key);

  @override
  State<UserActivityScreen> createState() => _UserActivityScreenState();
}

class _UserActivityScreenState extends State<UserActivityScreen> {
  final supabase = Supabase.instance.client;

  bool _isLoading     = true;
  List<Map<String, dynamic>> _users    = [];
  List<Map<String, dynamic>> _filtered = [];
  String _searchQuery    = '';
  String _sortBy         = 'name';
  String _selectedDept   = 'ALL';
  String _activityFilter = 'ALL';
  bool   _summaryExpanded = false;

  late DateTime _selectedMonth;
  final _now = DateTime.now();

  static const _primary = Color(0xFF2E6BFF);
  static const _bg      = Color(0xFFF4F6FB);
  static const _text    = Color(0xFF1A1D2E);
  static const _sub     = Color(0xFF8A93B0);

  static const _depts = [
    'ALL','MANAGEMENT','PRODUCTION','SALES','RND',
    'STEEL','BOX','DELIVERY','SSG','CLEANING','NUTRITION',
  ];

  Color _lighten(Color c, double a) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + a).clamp(0.0, 1.0)).toColor();
  }

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime(_now.year, _now.month);
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final monthStart = DateFormat('yyyy-MM-dd')
          .format(DateTime(_selectedMonth.year, _selectedMonth.month, 1));
      final monthEnd   = DateFormat('yyyy-MM-dd')
          .format(DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0));

      final profiles = await supabase
          .from('profiles')
          .select('id, full_name, dept_category, position, email')
          .order('full_name');
      final attendances = await supabase
          .from('attendance')
          .select('user_id, work_date, check_in, check_out')
          .gte('work_date', monthStart)
          .lte('work_date', monthEnd);
      final meals = await supabase
          .from('meal_requests')
          .select('user_id')
          .gte('meal_date', monthStart)
          .lte('meal_date', monthEnd);
      final noticeReads = await supabase
          .from('notice_reads')
          .select('user_id');
      final leaves = await supabase
          .from('leave_requests')
          .select('user_id')
          .gte('created_at', '$monthStart 00:00:00')
          .lte('created_at', '$monthEnd 23:59:59');
      final uniforms = await supabase
          .from('uniform_requests')
          .select('user_id');

      final attMap     = <String, List>{};
      final mealMap    = <String, int>{};
      final noticeMap  = <String, int>{};
      final leaveMap   = <String, int>{};
      final uniformMap = <String, int>{};

      for (final a in attendances) { attMap.putIfAbsent(a['user_id'] as String, () => []).add(a); }
      for (final m in meals)       { final uid = m['user_id'] as String; mealMap[uid]    = (mealMap[uid]    ?? 0) + 1; }
      for (final n in noticeReads) { final uid = n['user_id'] as String; noticeMap[uid]  = (noticeMap[uid]  ?? 0) + 1; }
      for (final l in leaves)      { final uid = l['user_id'] as String; leaveMap[uid]   = (leaveMap[uid]   ?? 0) + 1; }
      for (final u in uniforms)    { final uid = u['user_id'] as String; uniformMap[uid] = (uniformMap[uid] ?? 0) + 1; }

      final result = profiles.map((p) {
        final uid  = p['id'] as String;
        final atts = attMap[uid] ?? [];
        String? lastActive;
        if (atts.isNotEmpty) {
          final sorted = List.from(atts)
            ..sort((a, b) => (b['work_date'] as String).compareTo(a['work_date'] as String));
          lastActive = sorted.first['work_date'] as String;
        }
        final attCount     = atts.length;
        final mealCount    = mealMap[uid]    ?? 0;
        final noticeCount  = noticeMap[uid]  ?? 0;
        final leaveCount   = leaveMap[uid]   ?? 0;
        final uniformCount = uniformMap[uid] ?? 0;
        final score = attCount * 3 + mealCount + noticeCount + leaveCount * 2 + uniformCount * 2;
        return {
          ...p,
          'att_count': attCount, 'meal_count': mealCount,
          'notice_count': noticeCount, 'leave_count': leaveCount,
          'uniform_count': uniformCount, 'last_active': lastActive,
          'score': score,
        };
      }).toList();

      if (!mounted) return;
      setState(() { _users = result; _isLoading = false; });
      _applyFilter();
    } catch (e) {
      debugPrint("사용량 로드 실패: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilter() {
    var list = List<Map<String, dynamic>>.from(_users);
    if (_activityFilter != 'ALL') {
      list = list.where((u) {
        final att   = u['att_count']   as int;
        final other = (u['meal_count'] as int) + (u['notice_count'] as int)
                    + (u['leave_count'] as int) + (u['uniform_count'] as int);
        final score = u['score'] as int;
        return switch (_activityFilter) {
          'ACTIVE'    => att > 0 && other > 0,
          'ATT_ONLY'  => att > 0 && other == 0,
          'FEAT_ONLY' => att == 0 && other > 0,
          'INACTIVE'  => score == 0,
          _           => true,
        };
      }).toList();
    }
    if (_selectedDept != 'ALL') {
      list = list.where((u) => u['dept_category'] == _selectedDept).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((u) =>
        (u['full_name'] as String? ?? '').toLowerCase().contains(q) ||
        (u['email']    as String? ?? '').toLowerCase().contains(q)
      ).toList();
    }
    switch (_sortBy) {
      case 'attendance': list.sort((a, b) => (b['att_count'] as int).compareTo(a['att_count'] as int)); break;
      case 'meal':       list.sort((a, b) => (b['meal_count'] as int).compareTo(a['meal_count'] as int)); break;
      case 'score':      list.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int)); break;
      case 'last_active':
        list.sort((a, b) {
          final da = a['last_active'] as String? ?? '';
          final db = b['last_active'] as String? ?? '';
          return db.compareTo(da);
        });
        break;
      default: list.sort((a, b) => (a['full_name'] as String? ?? '').compareTo(b['full_name'] as String? ?? ''));
    }
    setState(() => _filtered = list);
  }

  String _activityFilterLabel() {
    return switch (_activityFilter) {
      'ACTIVE'    => '활동',
      'ATT_ONLY'  => '출근만',
      'FEAT_ONLY' => '기능만',
      'INACTIVE'  => '비활동',
      _           => '전체',
    };
  }

  String _deptLabel(String dept) {
    const m = {
      'MANAGEMENT': '관리부',   'PRODUCTION': '생산관리부',
      'SALES': '영업부',        'RND': '연구소',
      'STEEL': '스틸생산부',    'BOX': '박스생산부',
      'DELIVERY': '포장납품부', 'SSG': '에스에스지',
      'CLEANING': '환경미화',   'NUTRITION': '영양사',
    };
    return m[dept] ?? dept;
  }

  @override
  Widget build(BuildContext context) {
    final totalUsers    = _users.length;
    final activeUsers   = _users.where((u) =>
        (u['att_count'] as int) > 0 &&
        ((u['meal_count'] as int) + (u['notice_count'] as int) +
         (u['leave_count'] as int) + (u['uniform_count'] as int)) > 0).length;
    final attOnlyUsers  = _users.where((u) =>
        (u['att_count'] as int) > 0 &&
        ((u['meal_count'] as int) + (u['notice_count'] as int) +
         (u['leave_count'] as int) + (u['uniform_count'] as int)) == 0).length;
    final featOnlyUsers = _users.where((u) =>
        (u['att_count'] as int) == 0 &&
        ((u['meal_count'] as int) + (u['notice_count'] as int) +
         (u['leave_count'] as int) + (u['uniform_count'] as int)) > 0).length;
    final inactiveUsers = _users.where((u) => (u['score'] as int) == 0).length;
    final monthLabel    = DateFormat('yyyy년 M월').format(_selectedMonth);

    return Scaffold(
      backgroundColor: _bg,
      body: CustomScrollView(
        slivers: [
          // ── 그라디언트 SliverAppBar
          SliverAppBar(
            pinned: true,
            expandedHeight: 120,
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: const Text('사용자 활동 현황',
                style: TextStyle(fontWeight: FontWeight.w900,
                    fontSize: 17, color: Colors.white)),
            actions: [
              GestureDetector(
                onTap: _loadData,
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.refresh_rounded,
                      color: Colors.white, size: 18),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_lighten(_primary, 0.18), _primary,
                        const Color(0xFF1A3FA3)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(children: [
                  Positioned(right: -30, top: -30, child: Container(
                    width: 140, height: 140,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.06)))),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 65, 20, 0),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle),
                        child: const Icon(Icons.analytics_rounded,
                            color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Column(crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        const Text('사용자 활동 현황',
                            style: TextStyle(color: Colors.white,
                                fontSize: 14, fontWeight: FontWeight.w900)),
                        Text('$totalUsers명 등록',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 12, fontWeight: FontWeight.w500)),
                      ]),
                    ]),
                  ),
                ]),
              ),
            ),
          ),

          // ── 바디
          SliverToBoxAdapter(
            child: _isLoading
                ? const SizedBox(
                    height: 300,
                    child: Center(child: CircularProgressIndicator(
                        color: _primary)))
                : Column(children: [
                    // ── 월 선택 + 요약 헤더
                    _buildSummaryHeader(
                      totalUsers, activeUsers, attOnlyUsers,
                      featOnlyUsers, inactiveUsers, monthLabel,
                    ),

                    // ── 검색 + 필터
                    _buildFilterBar(),

                    // ── 활동 필터 활성 표시
                    if (_activityFilter != 'ALL')
                      _buildActiveFilterBadge(),

                    // ── 유저 목록
                    _filtered.isEmpty
                        ? SizedBox(
                            height: 200,
                            child: Center(child: Column(
                                mainAxisSize: MainAxisSize.min, children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                    color: Colors.white, shape: BoxShape.circle,
                                    boxShadow: [BoxShadow(
                                        color: Colors.black.withOpacity(0.06),
                                        blurRadius: 12, offset: const Offset(0, 4))]),
                                child: Icon(Icons.person_off_rounded,
                                    size: 36, color: Colors.grey[300]),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _activityFilter != 'ALL'
                                    ? '${_activityFilterLabel()} 해당 직원이 없습니다'
                                    : '해당하는 사용자가 없습니다',
                                style: const TextStyle(color: _sub,
                                    fontWeight: FontWeight.w600)),
                            ])),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 48),
                            itemCount: _filtered.length,
                            itemBuilder: (_, i) =>
                                _UserCard(user: _filtered[i]),
                          ),
                  ]),
          ),
        ],
      ),
    );
  }

  // ── 요약 헤더 카드
  Widget _buildSummaryHeader(int total, int active, int attOnly,
      int featOnly, int inactive, String monthLabel) {
    return Container(
      color: Colors.white,
      child: Column(children: [
        // 월 선택
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Row(children: [
            GestureDetector(
              onTap: () {
                setState(() => _selectedMonth = DateTime(
                    _selectedMonth.year, _selectedMonth.month - 1));
                _loadData();
              },
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                    color: _bg, borderRadius: BorderRadius.circular(9)),
                child: const Icon(Icons.chevron_left_rounded,
                    color: _primary, size: 18),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Center(child: Text(monthLabel,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w900, color: _text)))),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _selectedMonth.year == _now.year &&
                      _selectedMonth.month == _now.month
                  ? null
                  : () {
                      setState(() => _selectedMonth = DateTime(
                          _selectedMonth.year, _selectedMonth.month + 1));
                      _loadData();
                    },
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                    color: _bg, borderRadius: BorderRadius.circular(9)),
                child: Icon(Icons.chevron_right_rounded,
                    color: _selectedMonth.year == _now.year &&
                            _selectedMonth.month == _now.month
                        ? _sub
                        : _primary,
                    size: 18),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 12),

        // 요약 카드 펼치기/접기 헤더
        GestureDetector(
          onTap: () => setState(() => _summaryExpanded = !_summaryExpanded),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [_lighten(_primary, 0.20), _primary],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(
                    color: _primary.withOpacity(0.25), blurRadius: 10,
                    offset: const Offset(0, 4))],
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.22),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.people_rounded,
                      color: Colors.white, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text('전체 $total명 · 활동 $active명',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14,
                        fontWeight: FontWeight.w900))),
                AnimatedRotation(
                  turns: _summaryExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: Colors.white, size: 20),
                ),
              ]),
            ),
          ),
        ),

        // 펼쳐지는 통계 그리드
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Column(children: [
              Row(children: [
                _summaryBox('전체',   '$total명',   _primary,   sub: '등록계정',    filterKey: 'ALL'),
                const SizedBox(width: 8),
                _summaryBox('활동',   '$active명',  Colors.green, sub: '출근+기능', filterKey: 'ACTIVE'),
                const SizedBox(width: 8),
                _summaryBox('출근만', '$attOnly명', Colors.orange, sub: '기능미사용', filterKey: 'ATT_ONLY'),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                _summaryBox('기능만', '$featOnly명', Colors.purple, sub: '출근없이앱', filterKey: 'FEAT_ONLY'),
                const SizedBox(width: 8),
                _summaryBox('비활동', '$inactive명', Colors.redAccent, sub: '기록없음', filterKey: 'INACTIVE'),
                const SizedBox(width: 8),
                Expanded(child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                      color: _bg, borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black.withOpacity(0.06))),
                  child: Column(children: [
                    Text(
                      '${(total > 0 ? active / total * 100 : 0).toStringAsFixed(0)}%',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900,
                          color: active / (total > 0 ? total : 1) > 0.7
                              ? Colors.green : Colors.orange)),
                    const SizedBox(height: 2),
                    const Text('활동률', style: TextStyle(
                        fontSize: 10, color: _sub, fontWeight: FontWeight.w600)),
                  ]),
                )),
              ]),
            ]),
          ),
          crossFadeState: _summaryExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
        Container(height: 1, color: const Color(0xFFF0F2F8)),
      ]),
    );
  }

  Widget _summaryBox(String label, String value, Color color,
      {String? sub, String filterKey = 'ALL'}) {
    final isActive = _activityFilter == filterKey;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _activityFilter = isActive ? 'ALL' : filterKey);
          _applyFilter();
          if (_summaryExpanded) setState(() => _summaryExpanded = false);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? color.withOpacity(0.15) : color.withOpacity(0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isActive ? color : color.withOpacity(0.2),
                width: isActive ? 1.5 : 1),
          ),
          child: Column(children: [
            if (isActive) ...[
              Icon(Icons.check_circle_rounded, size: 11, color: color),
              const SizedBox(height: 2),
            ],
            Text(value, style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w900, color: color)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(
                fontSize: 10, color: color.withOpacity(0.8),
                fontWeight: FontWeight.w700)),
            if (sub != null) ...[
              const SizedBox(height: 1),
              Text(sub, style: TextStyle(
                  fontSize: 9, color: color.withOpacity(0.5),
                  fontWeight: FontWeight.w500)),
            ],
          ]),
        ),
      ),
    );
  }

  // ── 검색 + 필터 바
  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(children: [
        // 검색
        TextField(
          onChanged: (v) { _searchQuery = v; _applyFilter(); },
          decoration: InputDecoration(
            hintText: '이름 또는 이메일 검색',
            hintStyle: const TextStyle(color: _sub, fontSize: 13),
            prefixIcon: const Icon(Icons.search_rounded, color: _sub, size: 20),
            filled: true, fillColor: _bg,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 10),
        // 부서 필터
        SizedBox(
          height: 32,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: _depts.map((d) {
              final sel = _selectedDept == d;
              return GestureDetector(
                onTap: () { setState(() => _selectedDept = d); _applyFilter(); },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: sel ? _primary : _bg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(d == 'ALL' ? '전체' : _deptLabel(d),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                          color: sel ? Colors.white : _sub)),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 10),
        // 정렬
        Row(children: [
          const Text('정렬: ', style: TextStyle(
              fontSize: 12, color: _sub, fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          ...[
            ['name', '이름'], ['score', '활동점수'],
            ['attendance', '출근'], ['meal', '식수'], ['last_active', '최근활동'],
          ].map((s) {
            final sel = _sortBy == s[0];
            return GestureDetector(
              onTap: () { setState(() => _sortBy = s[0]); _applyFilter(); },
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: sel ? _primary.withOpacity(0.1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: sel ? _primary : Colors.transparent),
                ),
                child: Text(s[1], style: TextStyle(
                    fontSize: 11,
                    fontWeight: sel ? FontWeight.w800 : FontWeight.w500,
                    color: sel ? _primary : _sub)),
              ),
            );
          }),
        ]),
      ]),
    );
  }

  Widget _buildActiveFilterBadge() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [_lighten(_primary, 0.18), _primary],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(9),
            boxShadow: [BoxShadow(color: _primary.withOpacity(0.22),
                blurRadius: 5, offset: const Offset(0, 2))],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.filter_alt_rounded, size: 12, color: Colors.white),
            const SizedBox(width: 4),
            Text('${_activityFilterLabel()} 필터 적용 중',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                    color: Colors.white)),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () { setState(() => _activityFilter = 'ALL'); _applyFilter(); },
              child: const Icon(Icons.close_rounded, size: 13, color: Colors.white),
            ),
          ]),
        ),
        const SizedBox(width: 8),
        Text('${_filtered.length}명 표시',
            style: const TextStyle(fontSize: 12, color: _sub)),
      ]),
    );
  }
}

// ══════════════════════════════════════════
// 유저 카드
// ══════════════════════════════════════════
class _UserCard extends StatefulWidget {
  final Map<String, dynamic> user;
  const _UserCard({required this.user});

  @override
  State<_UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<_UserCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _ctrl;

  static const _primary = Color(0xFF2E6BFF);
  static const _text    = Color(0xFF1A1D2E);
  static const _sub     = Color(0xFF8A93B0);
  static const _bg      = Color(0xFFF4F6FB);

  Color _lighten(Color c, double a) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + a).clamp(0.0, 1.0)).toColor();
  }

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _ctrl.forward() : _ctrl.reverse();
  }

  Color _scoreColor(int att, int other, int score) {
    if (score == 0)                            return Colors.grey;
    if (att > 0 && other > 0 && score >= 15)  return Colors.green;
    if (att > 0 && other > 0)                 return const Color(0xFF2E6BFF);
    if (att > 0)                              return Colors.orange;
    if (other > 0)                            return Colors.purple;
    return Colors.grey;
  }

  String _scoreLabel(int att, int other, int score) {
    if (score == 0)                           return '비활동';
    if (att > 0 && other > 0 && score >= 15) return '활발';
    if (att > 0 && other > 0)                return '활동';
    if (att > 0)                              return '출근만';
    if (other > 0)                            return '기능만';
    return '비활동';
  }

  String _deptLabel(String dept) {
    const m = {
      'MANAGEMENT': '관리부',   'PRODUCTION': '생산관리부',
      'SALES': '영업부',        'RND': '연구소',
      'STEEL': '스틸생산부',    'BOX': '박스생산부',
      'DELIVERY': '포장납품부', 'SSG': '에스에스지',
      'CLEANING': '환경미화',   'NUTRITION': '영양사',
    };
    return m[dept] ?? dept;
  }

  String _lastActiveLabel(String? date) {
    if (date == null) return '없음';
    try {
      final d = DateTime.parse(date);
      final diff = DateTime.now().difference(d).inDays;
      if (diff == 0) return '오늘';
      if (diff == 1) return '어제';
      if (diff <= 7) return '$diff일 전';
      return DateFormat('MM/dd').format(d);
    } catch (_) { return date; }
  }

  Color _deptColor(String dept) {
    const m = {
      'MANAGEMENT': Color(0xFF2E6BFF), 'PRODUCTION': Color(0xFFFF7A2F),
      'SALES': Color(0xFF7C5CDB),      'RND': Color(0xFF00BCD4),
      'STEEL': Color(0xFF607D8B),      'BOX': Color(0xFF4CAF50),
      'DELIVERY': Color(0xFFE91E8C),   'SSG': Color(0xFF009688),
      'CLEANING': Color(0xFFFFC107),   'NUTRITION': Color(0xFF9C27B0),
    };
    return m[dept] ?? _primary;
  }

  @override
  Widget build(BuildContext context) {
    final u            = widget.user;
    final name         = u['full_name']     as String? ?? '-';
    final dept         = u['dept_category'] as String? ?? '';
    final position     = u['position']      as String? ?? '';
    final attCount     = u['att_count']     as int;
    final mealCount    = u['meal_count']    as int;
    final noticeCount  = u['notice_count']  as int;
    final leaveCount   = u['leave_count']   as int;
    final uniformCount = u['uniform_count'] as int;
    final lastActive   = u['last_active']   as String?;
    final score        = u['score']         as int;
    final otherCount   = mealCount + noticeCount + leaveCount + uniformCount;
    final scoreColor   = _scoreColor(attCount, otherCount, score);
    final scoreLabel   = _scoreLabel(attCount, otherCount, score);
    final dc           = _deptColor(dept);
    final dcL          = _lighten(dc, 0.18);

    return GestureDetector(
      onTap: _toggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _expanded ? _primary.withOpacity(0.25) : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
                color: _expanded
                    ? _primary.withOpacity(0.08)
                    : Colors.black.withOpacity(0.04),
                blurRadius: 10, offset: const Offset(0, 4)),
            BoxShadow(color: Colors.black.withOpacity(0.03),
                blurRadius: 5, offset: const Offset(0, 2)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Column(children: [
            // ── 상단 컬러 바 (활성 시)
            if (_expanded)
              Container(
                height: 3,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [_lighten(scoreColor, 0.15), scoreColor]),
                ),
              ),

            Padding(
              padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
              child: Row(children: [
                // 그라디언트 아바타
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [dcL, dc],
                        begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: [BoxShadow(
                        color: dc.withOpacity(0.25), blurRadius: 7,
                        offset: const Offset(0, 3))],
                  ),
                  child: Center(child: Text(
                    name.isNotEmpty ? name[0] : '?',
                    style: const TextStyle(fontSize: 17,
                        fontWeight: FontWeight.w900, color: Colors.white),
                  )),
                ),
                const SizedBox(width: 11),
                // 이름 + 부서
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800, color: _text)),
                  const SizedBox(height: 3),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                          color: dc.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6)),
                      child: Text(_deptLabel(dept), style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w700, color: dc)),
                    ),
                    if (position.isNotEmpty) ...[
                      const SizedBox(width: 5),
                      Text(position, style: const TextStyle(
                          fontSize: 11, color: _sub)),
                    ],
                  ]),
                ])),
                const SizedBox(width: 8),
                // 활동 뱃지
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [_lighten(scoreColor, 0.15), scoreColor],
                        begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: [BoxShadow(
                        color: scoreColor.withOpacity(0.25), blurRadius: 6,
                        offset: const Offset(0, 2))],
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('$score', style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w900,
                        color: Colors.white)),
                    Text(scoreLabel, style: const TextStyle(
                        fontSize: 9, fontWeight: FontWeight.w700,
                        color: Colors.white)),
                  ]),
                ),
                const SizedBox(width: 6),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: _sub, size: 20),
                ),
              ]),
            ),

            // ── 펼쳐지는 상세
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Container(
                decoration: BoxDecoration(
                    color: _bg,
                    border: Border(top: BorderSide(
                        color: Colors.black.withOpacity(0.05)))),
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(children: [
                  // 통계 5칸 그리드
                  Row(children: [
                    _statChip('출근', '$attCount회',
                        Icons.punch_clock_rounded, Colors.green),
                    const SizedBox(width: 6),
                    _statChip('식수', '$mealCount회',
                        Icons.restaurant_rounded, Colors.orange),
                    const SizedBox(width: 6),
                    _statChip('공지', '$noticeCount회',
                        Icons.campaign_rounded, Colors.purple),
                    const SizedBox(width: 6),
                    _statChip('휴가', '$leaveCount회',
                        Icons.flight_takeoff_rounded, const Color(0xFF3D5AFE)),
                    const SizedBox(width: 6),
                    _statChip('피복', '$uniformCount회',
                        Icons.checkroom_rounded, Colors.teal),
                  ]),
                  const SizedBox(height: 10),
                  // 마지막 활동
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Colors.black.withOpacity(0.06))),
                    child: Row(children: [
                      const Icon(Icons.history_rounded, size: 14, color: _sub),
                      const SizedBox(width: 7),
                      const Text('마지막 출근',
                          style: TextStyle(fontSize: 12, color: _sub,
                              fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text(
                        _lastActiveLabel(lastActive),
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w800,
                            color: lastActive == null
                                ? Colors.redAccent
                                : _text),
                      ),
                    ]),
                  ),
                ]),
              ),
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _statChip(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
          boxShadow: [BoxShadow(
              color: color.withOpacity(0.06), blurRadius: 4,
              offset: const Offset(0, 2))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(height: 3),
          Text(value, style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w900, color: color)),
          Text(label, style: TextStyle(
              fontSize: 9, color: color.withOpacity(0.7),
              fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}