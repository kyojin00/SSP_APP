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

  bool _isLoading = true;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filtered = [];
  String _searchQuery = '';
  String _sortBy = 'name';
  String _selectedDept = 'ALL';
  String _activityFilter = 'ALL'; // ALL | ACTIVE | ATT_ONLY | FEAT_ONLY | INACTIVE
  bool _summaryExpanded = false;

  // 월 선택
  late DateTime _selectedMonth;

  static const _primary = Color(0xFF2E6BFF);
  static const _bg      = Color(0xFFF4F6FB);
  static const _text    = Color(0xFF1A1D2E);
  static const _sub     = Color(0xFF8A93B0);

  static const _depts = [
    'ALL','MANAGEMENT','PRODUCTION','SALES','RND',
    'STEEL','BOX','DELIVERY','SSG','CLEANING','NUTRITION',
  ];

  final _now = DateTime.now();

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

      // ── 1. 전체 프로필
      final profiles = await supabase
          .from('profiles')
          .select('id, full_name, dept_category, position, email')
          .order('full_name');

      // ── 2. 이번 달 출퇴근 횟수
      final attendances = await supabase
          .from('attendance')
          .select('user_id, work_date, check_in, check_out')
          .gte('work_date', monthStart)
          .lte('work_date', monthEnd);

      // ── 3. 이번 달 식수 체크 횟수
      final meals = await supabase
          .from('meal_requests')
          .select('user_id')
          .gte('meal_date', monthStart)
          .lte('meal_date', monthEnd);

      // ── 4. 공지 읽음 수
      final noticeReads = await supabase
          .from('notice_reads')
          .select('user_id');

      // ── 5. 이번 달 휴가 신청
      final leaves = await supabase
          .from('leave_requests')
          .select('user_id')
          .gte('created_at', '$monthStart 00:00:00')
          .lte('created_at', '$monthEnd 23:59:59');

      // ── 6. 피복 신청
      final uniforms = await supabase
          .from('uniform_requests')
          .select('user_id');

      // 집계 맵 생성
      final attMap     = <String, List>{};
      final mealMap    = <String, int>{};
      final noticeMap  = <String, int>{};
      final leaveMap   = <String, int>{};
      final uniformMap = <String, int>{};

      for (final a in attendances) {
        final uid = a['user_id'] as String;
        attMap.putIfAbsent(uid, () => []).add(a);
      }
      for (final m in meals) {
        final uid = m['user_id'] as String;
        mealMap[uid] = (mealMap[uid] ?? 0) + 1;
      }
      for (final n in noticeReads) {
        final uid = n['user_id'] as String;
        noticeMap[uid] = (noticeMap[uid] ?? 0) + 1;
      }
      for (final l in leaves) {
        final uid = l['user_id'] as String;
        leaveMap[uid] = (leaveMap[uid] ?? 0) + 1;
      }
      for (final u in uniforms) {
        final uid = u['user_id'] as String;
        uniformMap[uid] = (uniformMap[uid] ?? 0) + 1;
      }

      // 프로필에 통계 합치기
      final result = profiles.map((p) {
        final uid  = p['id'] as String;
        final atts = attMap[uid] ?? [];
        // 마지막 출근일
        String? lastActive;
        if (atts.isNotEmpty) {
          final sorted = List.from(atts)
            ..sort((a, b) => (b['work_date'] as String)
                .compareTo(a['work_date'] as String));
          lastActive = sorted.first['work_date'] as String;
        }
        // 총 사용 점수 (가중치 합산)
        final attCount     = atts.length;
        final mealCount    = mealMap[uid] ?? 0;
        final noticeCount  = noticeMap[uid] ?? 0;
        final leaveCount   = leaveMap[uid] ?? 0;
        final uniformCount = uniformMap[uid] ?? 0;
        final score = attCount * 3 + mealCount + noticeCount + leaveCount * 2 + uniformCount * 2;

        return {
          ...p,
          'att_count':     attCount,
          'meal_count':    mealCount,
          'notice_count':  noticeCount,
          'leave_count':   leaveCount,
          'uniform_count': uniformCount,
          'last_active':   lastActive,
          'score':         score,
        };
      }).toList();

      if (!mounted) return;
      setState(() {
        _users = result;
        _isLoading = false;
      });
      _applyFilter();
    } catch (e) {
      debugPrint("사용량 로드 실패: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilter() {
    var list = List<Map<String, dynamic>>.from(_users);

    // 활동 분류 필터
    if (_activityFilter != 'ALL') {
      list = list.where((u) {
        final att   = u['att_count']   as int;
        final other = (u['meal_count'] as int) + (u['notice_count'] as int) +
                      (u['leave_count'] as int) + (u['uniform_count'] as int);
        final score = u['score'] as int;
        switch (_activityFilter) {
          case 'ACTIVE':    return att > 0 && other > 0;
          case 'ATT_ONLY':  return att > 0 && other == 0;
          case 'FEAT_ONLY': return att == 0 && other > 0;
          case 'INACTIVE':  return score == 0;
          default: return true;
        }
      }).toList();
    }

    // 부서 필터
    if (_selectedDept != 'ALL') {
      list = list.where((u) => u['dept_category'] == _selectedDept).toList();
    }
    // 검색
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((u) =>
        (u['full_name'] as String? ?? '').toLowerCase().contains(q) ||
        (u['email']    as String? ?? '').toLowerCase().contains(q)
      ).toList();
    }
    // 정렬
    switch (_sortBy) {
      case 'attendance':
        list.sort((a, b) => (b['att_count'] as int).compareTo(a['att_count'] as int));
        break;
      case 'meal':
        list.sort((a, b) => (b['meal_count'] as int).compareTo(a['meal_count'] as int));
        break;
      case 'score':
        list.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
        break;
      case 'last_active':
        list.sort((a, b) {
          final da = a['last_active'] as String? ?? '';
          final db = b['last_active'] as String? ?? '';
          return db.compareTo(da);
        });
        break;
      default:
        list.sort((a, b) =>
          (a['full_name'] as String? ?? '').compareTo(b['full_name'] as String? ?? ''));
    }

    setState(() => _filtered = list);
  }

  // 활동 분류 필터 레이블
  String _activityFilterLabel() {
    switch (_activityFilter) {
      case 'ACTIVE':    return '활동';
      case 'ATT_ONLY':  return '출근만';
      case 'FEAT_ONLY': return '기능만';
      case 'INACTIVE':  return '비활동';
      default: return '';
    }
  }

  String _deptLabel(String dept) {
    const m = {
      'MANAGEMENT': '관리부', 'PRODUCTION': '생산관리부',
      'SALES': '영업부',      'RND': '연구소',
      'STEEL': '스틸생산부',  'BOX': '박스생산부',
      'DELIVERY': '포장납품부','SSG': '에스에스지',
      'CLEANING': '환경미화', 'NUTRITION': '영양사',
    };
    return m[dept] ?? dept;
  }

  String _lastActiveLabel(String? date) {
    if (date == null) return '없음';
    try {
      final d    = DateTime.parse(date);
      final diff = _now.difference(d).inDays;
      if (diff == 0) return '오늘';
      if (diff == 1) return '어제';
      if (diff <= 7) return '$diff일 전';
      return DateFormat('MM/dd').format(d);
    } catch (_) { return date; }
  }

  Future<void> _pickMonth() async {
    final years = List.generate(3, (i) => _now.year - i);
    final months = List.generate(12, (i) => i + 1);
    int selYear  = _selectedMonth.year;
    int selMonth = _selectedMonth.month;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(24)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 36, height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                    color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Align(alignment: Alignment.centerLeft,
                  child: Text('월 선택', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
            ),
            // 연도
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: years.map((y) {
                final sel = selYear == y;
                return Expanded(child: GestureDetector(
                  onTap: () => setS(() => selYear = y),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: sel ? _primary : const Color(0xFFF4F6FB),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(child: Text('$y년', style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800,
                        color: sel ? Colors.white : Colors.black87))),
                  ),
                ));
              }).toList()),
            ),
            const SizedBox(height: 14),
            // 월
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.2,
                physics: const NeverScrollableScrollPhysics(),
                children: months.map((m) {
                  final sel = selMonth == m;
                  // 미래 월 비활성
                  final isFuture = DateTime(selYear, m).isAfter(_now);
                  return GestureDetector(
                    onTap: isFuture ? null : () => setS(() => selMonth = m),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: sel ? _primary : const Color(0xFFF4F6FB),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(child: Text('$m월', style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700,
                          color: isFuture
                              ? Colors.grey[300]
                              : sel ? Colors.white : Colors.black87))),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            // 확인 버튼
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() => _selectedMonth = DateTime(selYear, selMonth));
                    _loadData();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('확인', style: TextStyle(
                      color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalUsers    = _users.length;
    // ① 활동: 출근 + 다른 기능 1개 이상 사용
    final activeUsers   = _users.where((u) =>
        (u['att_count'] as int) > 0 &&
        ((u['meal_count'] as int) + (u['notice_count'] as int) +
         (u['leave_count'] as int) + (u['uniform_count'] as int)) > 0
    ).length;
    // ② 출근만: 출근은 했지만 다른 기능 미사용
    final attOnlyUsers  = _users.where((u) =>
        (u['att_count'] as int) > 0 &&
        ((u['meal_count'] as int) + (u['notice_count'] as int) +
         (u['leave_count'] as int) + (u['uniform_count'] as int)) == 0
    ).length;
    // ③ 기능만: 출근 없이 식수/공지 등만 사용
    final featOnlyUsers = _users.where((u) =>
        (u['att_count'] as int) == 0 &&
        ((u['meal_count'] as int) + (u['notice_count'] as int) +
         (u['leave_count'] as int) + (u['uniform_count'] as int)) > 0
    ).length;
    // ④ 비활동: 이달 기록 전무 (score == 0)
    final inactiveUsers = _users.where((u) => (u['score'] as int) == 0).length;
    // 합산 검증: activeUsers + attOnlyUsers + featOnlyUsers + inactiveUsers == totalUsers
    final monthLabel    = DateFormat('yyyy년 M월').format(_selectedMonth);
    final isCurrentMonth = _selectedMonth.year == _now.year &&
        _selectedMonth.month == _now.month;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('사용자 활동 현황',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: _text,
        elevation: 0,
        surfaceTintColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFF0F2F8)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : Column(children: [
              // ── 월 선택 바
              GestureDetector(
                onTap: _pickMonth,
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: Row(children: [
                    // 이전 달
                    GestureDetector(
                      onTap: () {
                        setState(() => _selectedMonth = DateTime(
                            _selectedMonth.year, _selectedMonth.month - 1));
                        _loadData();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                            color: _bg, borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.chevron_left_rounded,
                            color: _sub, size: 20),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Center(
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(monthLabel, style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w900, color: _text)),
                        const SizedBox(width: 6),
                        if (isCurrentMonth)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                                color: _primary, borderRadius: BorderRadius.circular(6)),
                            child: const Text('이번달', style: TextStyle(
                                color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                          ),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down_rounded,
                            color: _sub, size: 18),
                      ]),
                    )),
                    const SizedBox(width: 10),
                    // 다음 달 (미래면 비활성)
                    GestureDetector(
                      onTap: isCurrentMonth ? null : () {
                        setState(() => _selectedMonth = DateTime(
                            _selectedMonth.year, _selectedMonth.month + 1));
                        _loadData();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                            color: isCurrentMonth ? Colors.transparent : _bg,
                            borderRadius: BorderRadius.circular(8)),
                        child: Icon(Icons.chevron_right_rounded,
                            color: isCurrentMonth ? Colors.grey[300] : _sub,
                            size: 20),
                      ),
                    ),
                  ]),
                ),
              ),
              Container(height: 1, color: const Color(0xFFF0F2F8)),
              // ── 요약 카드 (접기/펼치기)
              GestureDetector(
                onTap: () => setState(() => _summaryExpanded = !_summaryExpanded),
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: Row(children: [
                    // 미니 요약 (항상 보임)
                    Expanded(child: Row(children: [
                      _miniChip('전체 $totalUsers', _primary),
                      const SizedBox(width: 6),
                      _miniChip('활동 $activeUsers', Colors.green),
                      const SizedBox(width: 6),
                      _miniChip('비활동 $inactiveUsers', Colors.redAccent),
                    ])),
                    AnimatedRotation(
                      turns: _summaryExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(Icons.keyboard_arrow_down_rounded,
                          color: _sub, size: 20),
                    ),
                  ]),
                ),
              ),
              // 펼쳐지는 상세 카드
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Column(children: [
                    const Divider(height: 1, color: Color(0xFFF0F2F8)),
                    const SizedBox(height: 12),
                    // 1행
                    Row(children: [
                      _summaryCard('전체', '$totalUsers명', _primary,
                          sub: '등록 계정', filterKey: 'ALL'),
                      const SizedBox(width: 8),
                      _summaryCard('활동', '$activeUsers명', Colors.green,
                          sub: '출근+기능', filterKey: 'ACTIVE'),
                      const SizedBox(width: 8),
                      _summaryCard('출근만', '$attOnlyUsers명', Colors.orange,
                          sub: '기능 미사용', filterKey: 'ATT_ONLY'),
                    ]),
                    const SizedBox(height: 8),
                    // 2행
                    Row(children: [
                      _summaryCard('기능만', '$featOnlyUsers명', Colors.purple,
                          sub: '출근 없이 앱 사용', filterKey: 'FEAT_ONLY'),
                      const SizedBox(width: 8),
                      _summaryCard('비활동', '$inactiveUsers명', Colors.redAccent,
                          sub: '이달 기록 없음', filterKey: 'INACTIVE'),
                      const SizedBox(width: 8),
                      Expanded(child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _bg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black.withOpacity(0.06)),
                        ),
                        child: Column(children: [
                          Text(
                            '${activeUsers + attOnlyUsers + featOnlyUsers + inactiveUsers}명',
                            style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w900,
                              color: (activeUsers + attOnlyUsers + featOnlyUsers + inactiveUsers) == totalUsers
                                  ? Colors.green : Colors.redAccent,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text('합산', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF8A93B0))),
                          const SizedBox(height: 1),
                          Text(
                            (activeUsers + attOnlyUsers + featOnlyUsers + inactiveUsers) == totalUsers
                                ? '✓ 일치' : '⚠ 불일치',
                            style: TextStyle(
                              fontSize: 9,
                              color: (activeUsers + attOnlyUsers + featOnlyUsers + inactiveUsers) == totalUsers
                                  ? Colors.green : Colors.redAccent,
                            ),
                          ),
                        ]),
                      )),
                    ]),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                          color: _bg, borderRadius: BorderRadius.circular(10)),
                      child: Text(
                        '💡 활동: 출근+기능  ·  출근만: 출근O 기능X  ·  기능만: 출근X 기능O  ·  비활동: $monthLabel 기록 없음',
                        style: TextStyle(fontSize: 10, color: _sub, height: 1.5),
                      ),
                    ),
                  ]),
                ),
                crossFadeState: _summaryExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),
              Container(height: 1, color: const Color(0xFFF0F2F8)),

              // ── 검색 + 필터
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(children: [
                  // 검색
                  TextField(
                    onChanged: (v) {
                      _searchQuery = v;
                      _applyFilter();
                    },
                    decoration: InputDecoration(
                      hintText: '이름 또는 이메일 검색',
                      hintStyle: TextStyle(color: _sub, fontSize: 13),
                      prefixIcon: const Icon(Icons.search_rounded, color: _sub, size: 20),
                      filled: true,
                      fillColor: _bg,
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
                          onTap: () {
                            setState(() => _selectedDept = d);
                            _applyFilter();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: sel ? _primary : _bg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              d == 'ALL' ? '전체' : _deptLabel(d),
                              style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w700,
                                color: sel ? Colors.white : _sub,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // 정렬
                  Row(children: [
                    Text('정렬: ', style: TextStyle(fontSize: 12, color: _sub, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 6),
                    ...[
                      ['name', '이름'],
                      ['score', '활동점수'],
                      ['attendance', '출근'],
                      ['meal', '식수'],
                      ['last_active', '최근활동'],
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
              ),

              const SizedBox(height: 1),

              // 활성 분류 필터 뱃지
              if (_activityFilter != 'ALL')
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _primary.withOpacity(0.2)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.filter_alt_rounded, size: 13, color: _primary),
                        const SizedBox(width: 5),
                        Text('${_activityFilterLabel()} 필터 적용 중',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700, color: _primary)),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            setState(() => _activityFilter = 'ALL');
                            _applyFilter();
                          },
                          child: const Icon(Icons.close_rounded, size: 14, color: _primary),
                        ),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    Text('${_filtered.length}명 표시 중',
                        style: TextStyle(fontSize: 12, color: _sub)),
                  ]),
                ),

              // ── 유저 목록
              Expanded(
                child: _filtered.isEmpty
                    ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.person_off_rounded, size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 10),
                        Text(
                          _activityFilter != 'ALL'
                              ? '${_activityFilterLabel()} 해당 직원이 없습니다'
                              : '해당하는 사용자가 없습니다',
                          style: TextStyle(color: _sub)),
                      ]))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) => _UserCard(user: _filtered[i]),
                      ),
              ),
            ]),
    );
  }

  Widget _miniChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _summaryCard(String label, String value, Color color,
      {String? sub, String filterKey = 'ALL'}) {
    final isActive = _activityFilter == filterKey;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _activityFilter = isActive ? 'ALL' : filterKey);
          _applyFilter();
          // 펼쳐져 있으면 접기 (목록으로 스크롤 유도)
          if (_summaryExpanded) setState(() => _summaryExpanded = false);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? color.withOpacity(0.18) : color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive ? color : color.withOpacity(0.2),
              width: isActive ? 1.5 : 1,
            ),
          ),
          child: Column(children: [
            if (isActive)
              Icon(Icons.check_circle_rounded, size: 12, color: color),
            if (isActive) const SizedBox(height: 2),
            Text(value, style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w900, color: color)),
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
}

// ══════════════════════════════════════════
// 접기/펼치기 유저 카드
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
  late Animation<double> _rotation;

  static const _primary = Color(0xFF2E6BFF);
  static const _text    = Color(0xFF1A1D2E);
  static const _sub     = Color(0xFF8A93B0);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _rotation = Tween(begin: 0.0, end: 0.5).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _ctrl.forward() : _ctrl.reverse();
  }

  Color _scoreColor(int attCount, int otherCount, int score) {
    if (score == 0)                               return Colors.grey;
    if (attCount > 0 && otherCount > 0 && score >= 15) return Colors.green;
    if (attCount > 0 && otherCount > 0)           return Colors.blue;
    if (attCount > 0)                             return Colors.orange;
    if (otherCount > 0)                           return Colors.purple;
    return Colors.grey;
  }

  String _scoreLabel(int attCount, int otherCount, int score) {
    if (score == 0)                               return '비활동';
    if (attCount > 0 && otherCount > 0 && score >= 15) return '활발';
    if (attCount > 0 && otherCount > 0)           return '활동';
    if (attCount > 0)                             return '출근만';
    if (otherCount > 0)                           return '기능만';
    return '비활동';
  }

  String _scoreSub(int attCount, int otherCount) {
    if (attCount == 0 && otherCount == 0) return '이달 기록 없음';
    if (attCount > 0 && otherCount > 0)   return '출근+기능 사용';
    if (attCount > 0)                     return '다른 기능 미사용';
    return '출근 없이 앱 사용';
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
      final d    = DateTime.parse(date);
      final diff = DateTime.now().difference(d).inDays;
      if (diff == 0) return '오늘';
      if (diff == 1) return '어제';
      if (diff <= 7) return '$diff일 전';
      return DateFormat('MM/dd').format(d);
    } catch (_) { return date; }
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
    final scoreSub     = _scoreSub(attCount, otherCount);

    return GestureDetector(
      onTap: _toggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _expanded ? _primary.withOpacity(0.2) : Colors.transparent,
          ),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Column(children: [
          // ── 항상 보이는 헤더
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(children: [
              // 아바타
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                    color: _primary.withOpacity(0.1), shape: BoxShape.circle),
                child: Center(child: Text(
                  name.isNotEmpty ? name[0] : '?',
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w900, color: _primary),
                )),
              ),
              const SizedBox(width: 12),
              // 이름 + 부서
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800, color: _text)),
                const SizedBox(height: 2),
                Text('${_deptLabel(dept)}${position.isNotEmpty ? ' · $position' : ''}',
                    style: TextStyle(fontSize: 11, color: _sub)),
              ])),
              // 활동 뱃지 + 최근 활동
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                      color: scoreColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(7)),
                  child: Text(scoreLabel, style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w800, color: scoreColor)),
                ),
                const SizedBox(height: 2),
                Text(scoreSub, style: TextStyle(fontSize: 9, color: scoreColor.withOpacity(0.7))),
                const SizedBox(height: 1),
                Text('최근 ${_lastActiveLabel(lastActive)}',
                    style: TextStyle(fontSize: 10, color: _sub)),
              ]),
              const SizedBox(width: 8),
              // 화살표
              RotationTransition(
                turns: _rotation,
                child: Icon(Icons.keyboard_arrow_down_rounded,
                    color: _sub, size: 20),
              ),
            ]),
          ),

          // ── 접히는 상세 영역
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(children: [
                const Divider(height: 1, color: Color(0xFFF0F2F8)),
                const SizedBox(height: 14),
                // 통계 그리드
                Row(children: [
                  _statItem(Icons.punch_clock_rounded, Colors.blue,   '출근',  '$attCount회',     '이번달'),
                  _statItem(Icons.restaurant_rounded,  Colors.orange, '식수',  '$mealCount회',    '이번달'),
                  _statItem(Icons.campaign_rounded,    Colors.purple, '공지',  '$noticeCount건',  '읽음'),
                  _statItem(Icons.flight_takeoff_rounded, Colors.teal,'휴가',  '$leaveCount건',   '신청'),
                  _statItem(Icons.checkroom_rounded,   Colors.green,  '피복',  '$uniformCount건', '신청'),
                ]),
                const SizedBox(height: 14),
                // 활동 점수 바
                Row(children: [
                  Text('활동 점수  ',
                      style: TextStyle(fontSize: 11, color: _sub, fontWeight: FontWeight.w600)),
                  Text('$score점',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: scoreColor)),
                  const SizedBox(width: 8),
                  Expanded(child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (score / 60).clamp(0.0, 1.0),
                      minHeight: 5,
                      backgroundColor: scoreColor.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation(scoreColor),
                    ),
                  )),
                ]),
              ]),
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ]),
      ),
    );
  }

  Widget _statItem(IconData icon, Color color, String label, String value, String sub) {
    return Expanded(
      child: Column(children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 17, color: color),
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w900, color: _text)),
        Text(label, style: TextStyle(fontSize: 10, color: _sub)),
      ]),
    );
  }
}