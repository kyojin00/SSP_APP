import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EmployeeManagementScreen extends StatefulWidget {
  const EmployeeManagementScreen({Key? key}) : super(key: key);

  @override
  State<EmployeeManagementScreen> createState() =>
      _EmployeeManagementScreenState();
}

class _EmployeeManagementScreenState
    extends State<EmployeeManagementScreen> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _filtered  = [];
  bool   _isLoading    = true;
  String _searchQuery  = '';
  String _selectedDept = '전체';

  static const _primary = Color(0xFF2E6BFF);
  static const _red     = Color(0xFFFF4D64);
  static const _bg      = Color(0xFFF4F6FB);
  static const _sub     = Color(0xFF8A93B0);
  static const _text    = Color(0xFF1A1D2E);

  static const _depts = [
    '전체','BOX','CLEANING','DELIVERY','MANAGEMENT',
    'NUTRITION','PRODUCTION','RND','SALES','STEEL','SSG'
  ];

  final _deptColors = const {
    'MANAGEMENT': Color(0xFF2E6BFF),
    'PRODUCTION': Color(0xFF7C5CDB),
    'SALES':      Color(0xFFFF8C42),
    'RND':        Color(0xFF00BCD4),
    'STEEL':      Color(0xFF607D8B),
    'BOX':        Color(0xFF43A047),
    'DELIVERY':   Color(0xFFE91E8C),
    'SSG':        Color(0xFF009688),
    'CLEANING':   Color(0xFF8BC34A),
    'NUTRITION':  Color(0xFFFF7043),
  };

  static const _deptLabels = {
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

  static const _positions = [
    '사원','주임','대리','과장','차장','부장','이사','본부장','대표이사',
  ];

  String _deptLabel(String code) => _deptLabels[code] ?? code;

  Color _lighten(Color c, double a) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + a).clamp(0.0, 1.0)).toColor();
  }

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    setState(() => _isLoading = true);
    try {
      final data = await supabase
          .from('profiles')
          .select('*')
          .order('dept_category')
          .order('full_name');
      _employees = List<Map<String, dynamic>>.from(data);
      _applyFilter();
    } catch (e) {
      debugPrint("직원 로드 실패: $e");
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _applyFilter() {
    setState(() {
      _filtered = _employees.where((e) {
        final deptOk   = _selectedDept == '전체' || e['dept_category'] == _selectedDept;
        final searchOk = _searchQuery.isEmpty ||
            (e['full_name'] ?? '').toString().contains(_searchQuery);
        return deptOk && searchOk;
      }).toList();
    });
  }

  // ── 역할 변경
  Future<void> _changeRole(Map<String, dynamic> emp) async {
    final currentRole = emp['role'] ?? 'USER';
    final newRole     = currentRole == 'ADMIN' ? 'USER' : 'ADMIN';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDialog(
        title: "역할 변경",
        content: "${emp['full_name']}님의 역할을\n$currentRole → $newRole 로 변경할까요?",
        confirmLabel: "변경",
        confirmColor: _primary,
      ),
    );
    if (confirmed != true) return;
    try {
      await supabase.from('profiles').update({'role': newRole}).eq('id', emp['id']);
      _showSnack("역할이 변경되었습니다. ✅");
      _loadEmployees();
    } catch (e) { _showSnack("변경 실패: $e"); }
  }

  // ── 부서 변경
  Future<void> _changeDept(Map<String, dynamic> emp) async {
    String selected = emp['dept_category'] ?? 'MANAGEMENT';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Text("${emp['full_name']} 부서 변경",
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          content: Wrap(
            spacing: 8, runSpacing: 8,
            children: ['MANAGEMENT','PRODUCTION','SALES','RND','STEEL',
                'BOX','DELIVERY','SSG','CLEANING','NUTRITION'].map((d) {
              final isSel = selected == d;
              final color = _deptColors[d] ?? _sub;
              return GestureDetector(
                onTap: () => setS(() => selected = d),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    gradient: isSel ? LinearGradient(
                      colors: [_lighten(color, 0.15), color],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ) : null,
                    color: isSel ? null : color.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withOpacity(isSel ? 0 : 0.2)),
                    boxShadow: isSel ? [BoxShadow(
                        color: color.withOpacity(0.25), blurRadius: 8,
                        offset: const Offset(0, 3))] : [],
                  ),
                  child: Text(_deptLabel(d), style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: isSel ? Colors.white : color)),
                ),
              );
            }).toList(),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false),
                child: const Text("취소")),
            _GradBtn(label: "저장", color: _primary,
                onTap: () => Navigator.pop(ctx, true)),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    try {
      await supabase.from('profiles').update({'dept_category': selected}).eq('id', emp['id']);
      _showSnack("부서가 변경되었습니다. ✅");
      _loadEmployees();
    } catch (e) { _showSnack("변경 실패: $e"); }
  }

  // ── 직급 변경
  Future<void> _changePosition(Map<String, dynamic> emp) async {
    String selected = emp['position'] ?? '사원';
    const color = Color(0xFF7C5CDB);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Text("${emp['full_name']} 직급 변경",
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            // 현재 직급
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_lighten(color, 0.18), color],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                const Icon(Icons.military_tech_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text("현재: ${emp['position'] ?? '사원'}",
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w900)),
              ]),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _positions.map((p) {
                final isSel = selected == p;
                return GestureDetector(
                  onTap: () => setS(() => selected = p),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: isSel ? LinearGradient(
                        colors: [_lighten(color, 0.15), color],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ) : null,
                      color: isSel ? null : color.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: color.withOpacity(isSel ? 0 : 0.2)),
                      boxShadow: isSel ? [BoxShadow(
                          color: color.withOpacity(0.25), blurRadius: 8,
                          offset: const Offset(0, 3))] : [],
                    ),
                    child: Text(p, style: TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 13,
                        color: isSel ? Colors.white : color)),
                  ),
                );
              }).toList(),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false),
                child: const Text("취소")),
            _GradBtn(label: "저장", color: color,
                onTap: () => Navigator.pop(ctx, true)),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    try {
      await supabase.from('profiles').update({'position': selected}).eq('id', emp['id']);
      _showSnack("직급이 변경되었습니다. ✅");
      _loadEmployees();
    } catch (e) { _showSnack("변경 실패: $e"); }
  }

  // ── 직원 삭제
  Future<void> _deleteEmployee(Map<String, dynamic> emp) async {
    final first = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDialog(
        title: "직원 삭제",
        content: "${emp['full_name']}님의 계정을 삭제하면\n모든 데이터가 사라집니다.\n\n정말 삭제하시겠습니까?",
        confirmLabel: "삭제",
        confirmColor: _red,
        isWarning: true,
      ),
    );
    if (first != true) return;

    bool checked = false;
    final second = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Text("최종 확인",
              style: TextStyle(fontWeight: FontWeight.w900, color: _red)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _red.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _red.withOpacity(0.2)),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                      color: _red.withOpacity(0.12), shape: BoxShape.circle),
                  child: const Icon(Icons.person_off_rounded, color: _red, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "${emp['full_name']}님의 계정이\n영구 삭제됩니다.",
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700, color: _red),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () => setS(() => checked = !checked),
              child: Row(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    color: checked ? _red : Colors.transparent,
                    border: Border.all(
                        color: checked ? _red : Colors.grey, width: 2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: checked
                      ? const Icon(Icons.check_rounded, color: Colors.white, size: 15)
                      : null,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text("이 작업은 되돌릴 수 없음을\n확인했습니다.",
                      style: TextStyle(fontSize: 13)),
                ),
              ]),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false),
                child: const Text("취소")),
            _GradBtn(label: "최종 삭제",
                color: checked ? _red : Colors.grey,
                onTap: checked ? () => Navigator.pop(ctx, true) : null),
          ],
        ),
      ),
    );
    if (second != true) return;

    try {
      final session = supabase.auth.currentSession;
      final response = await supabase.functions.invoke(
        'delete-user',
        body: {'userId': emp['id']},
        headers: {'Authorization': 'Bearer ${session?.accessToken ?? ''}'},
      );
      if (response.status == 200) {
        _showSnack("${emp['full_name']}님이 삭제되었습니다. ✅");
        _loadEmployees();
      } else {
        _showSnack("오류: ${response.data?['error'] ?? '삭제 실패'}");
      }
    } catch (e) { _showSnack("삭제 실패: $e"); }
  }

  // ── 직원 상세 바텀시트
  void _showEmployeeDetail(Map<String, dynamic> emp) {
    final role    = emp['role'] ?? 'USER';
    final dept    = emp['dept_category'] ?? '-';
    final dc      = _deptColors[dept] ?? _sub;
    final isAdmin = role == 'ADMIN';
    final name    = emp['full_name'] ?? '?';
    final lighter = _lighten(dc, 0.18);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // 그라디언트 헤더
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [lighter, dc],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Stack(children: [
              Positioned(right: -30, top: -30,
                child: Container(width: 120, height: 120,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.08)))),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                child: Column(children: [
                  Container(width: 36, height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.45),
                        borderRadius: BorderRadius.circular(2))),
                  Row(children: [
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.22),
                          borderRadius: BorderRadius.circular(18)),
                      child: Center(child: Text(name.substring(0, 1),
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.w900,
                              color: Colors.white))),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(name, style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w900,
                          color: Colors.white)),
                      const SizedBox(height: 6),
                      Row(children: [
                        _whiteBadge(_deptLabel(dept)),
                        const SizedBox(width: 6),
                        _whiteBadge(emp['position'] ?? '사원'),
                        const SizedBox(width: 6),
                        _whiteBadge(isAdmin ? '관리자' : '일반',
                            color: isAdmin
                                ? Colors.white.withOpacity(0.3)
                                : Colors.white.withOpacity(0.15)),
                      ]),
                    ])),
                  ]),
                ]),
              ),
            ]),
          ),

          // 액션 버튼
          Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20,
                20 + MediaQuery.of(context).viewInsets.bottom),
            child: Row(children: [
              Expanded(child: _actionBtn(
                icon: Icons.badge_rounded,
                label: isAdmin ? "일반으로\n변경" : "관리자로\n변경",
                color: const Color(0xFFFF8C42),
                onTap: () { Navigator.pop(context); _changeRole(emp); },
              )),
              const SizedBox(width: 8),
              Expanded(child: _actionBtn(
                icon: Icons.apartment_rounded,
                label: "부서\n변경", color: _primary,
                onTap: () { Navigator.pop(context); _changeDept(emp); },
              )),
              const SizedBox(width: 8),
              Expanded(child: _actionBtn(
                icon: Icons.military_tech_rounded,
                label: "직급\n변경", color: const Color(0xFF7C5CDB),
                onTap: () { Navigator.pop(context); _changePosition(emp); },
              )),
              const SizedBox(width: 8),
              Expanded(child: _actionBtn(
                icon: Icons.delete_rounded,
                label: "계정\n삭제", color: _red,
                onTap: () { Navigator.pop(context); _deleteEmployee(emp); },
              )),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _whiteBadge(String label, {Color? color}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
        color: color ?? Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6)),
    child: Text(label, style: const TextStyle(
        fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
  );

  Widget _actionBtn({
    required IconData icon, required String label,
    required Color color, required VoidCallback onTap,
  }) {
    final lighter = _lighten(color, 0.18);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [lighter, color],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
              color: color.withOpacity(0.25), blurRadius: 8,
              offset: const Offset(0, 4))],
        ),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.22), shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      duration: const Duration(seconds: 2),
    ));
  }

  // ══════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final deptGroups = <String, List<Map<String, dynamic>>>{};
    for (final e in _filtered) {
      final d = e['dept_category'] ?? '기타';
      if (d == 'TEST') continue;
      deptGroups.putIfAbsent(d, () => []).add(e);
    }

    final totalCount = _employees
        .where((e) => e['dept_category'] != 'TEST').length;
    final adminCount = _employees
        .where((e) => e['role'] == 'ADMIN').length;

    return Scaffold(
      backgroundColor: _bg,
      body: Column(children: [
        // ── 그라디언트 SliverAppBar를 Container로 구현 (Column 내부이므로)
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A3A8F), _primary, Color(0xFF5B8AFF)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Stack(children: [
              Positioned(right: -40, top: -40,
                child: Container(width: 160, height: 160,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.07)))),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(children: [
                  // 뒤로가기
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('직원 관리', style: TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 17,
                        color: Colors.white)),
                    if (!_isLoading)
                      Text('총 $totalCount명 · 관리자 $adminCount명',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.72),
                              fontWeight: FontWeight.w500)),
                  ])),
                  // 새로고침
                  GestureDetector(
                    onTap: _loadEmployees,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.refresh_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        ),

        // ── 검색 + 필터 영역
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(children: [
            // 검색창
            Container(
              height: 44,
              decoration: BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.black.withOpacity(0.07)),
              ),
              child: TextField(
                onChanged: (v) { _searchQuery = v; _applyFilter(); },
                decoration: const InputDecoration(
                  hintText: "이름으로 검색",
                  hintStyle: TextStyle(fontSize: 13, color: _sub),
                  prefixIcon: Icon(Icons.search_rounded, color: _sub, size: 20),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // 부서 필터 칩
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _depts.map((d) {
                  final sel   = _selectedDept == d;
                  final color = d == '전체' ? _primary : (_deptColors[d] ?? _sub);
                  final count = d == '전체'
                      ? _employees.where((e) => e['dept_category'] != 'TEST').length
                      : _employees.where((e) => e['dept_category'] == d).length;
                  final label = d == '전체' ? '전체' : _deptLabel(d);
                  return GestureDetector(
                    onTap: () { setState(() => _selectedDept = d); _applyFilter(); },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 13, vertical: 7),
                      decoration: BoxDecoration(
                        gradient: sel ? LinearGradient(
                          colors: [_lighten(color, 0.15), color],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ) : null,
                        color: sel ? null : color.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: color.withOpacity(sel ? 0 : 0.22)),
                        boxShadow: sel ? [BoxShadow(
                            color: color.withOpacity(0.25), blurRadius: 6,
                            offset: const Offset(0, 2))] : [],
                      ),
                      child: Text("$label  $count",
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700,
                              color: sel ? Colors.white : color)),
                    ),
                  );
                }).toList(),
              ),
            ),
          ]),
        ),
        Container(height: 1, color: const Color(0xFFF0F2F8)),

        // ── 직원 목록
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: _primary))
              : deptGroups.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                            color: Colors.white, shape: BoxShape.circle,
                            boxShadow: [BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 14, offset: const Offset(0, 4))]),
                        child: Icon(Icons.person_search_rounded,
                            size: 38, color: Colors.grey[300]),
                      ),
                      const SizedBox(height: 14),
                      Text("검색 결과가 없습니다.",
                          style: TextStyle(color: Colors.grey[400],
                              fontWeight: FontWeight.w600)),
                    ]))
                  : RefreshIndicator(
                      onRefresh: _loadEmployees,
                      color: _primary,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                        children: deptGroups.entries.map((entry) {
                          final dept = entry.key;
                          final emps = entry.value;
                          final dc   = _deptColors[dept] ?? _sub;
                          final lighter = _lighten(dc, 0.18);
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 부서 헤더
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10, top: 4),
                                child: Row(children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [lighter, dc],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: [BoxShadow(
                                          color: dc.withOpacity(0.25),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2))],
                                    ),
                                    child: const Icon(Icons.group_rounded,
                                        color: Colors.white, size: 13),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(_deptLabel(dept),
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w900,
                                          color: dc)),
                                  const SizedBox(width: 7),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                        color: dc.withOpacity(0.10),
                                        borderRadius: BorderRadius.circular(8)),
                                    child: Text("${emps.length}명",
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: dc)),
                                  ),
                                ]),
                              ),
                              ...emps.map((emp) =>
                                  _buildEmployeeCard(emp, dc)),
                              const SizedBox(height: 16),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
        ),
      ]),
    );
  }

  Widget _buildEmployeeCard(Map<String, dynamic> emp, Color dc) {
    final role    = emp['role'] ?? 'USER';
    final isAdmin = role == 'ADMIN';
    final name    = emp['full_name'] ?? '?';
    final lighter = _lighten(dc, 0.18);

    return GestureDetector(
      onTap: () => _showEmployeeDetail(emp),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
              color: dc.withOpacity(0.08), blurRadius: 10,
              offset: const Offset(0, 4))],
        ),
        child: Row(children: [
          // 그라디언트 아바타
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [lighter, dc],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(
                  color: dc.withOpacity(0.28), blurRadius: 8,
                  offset: const Offset(0, 3))],
            ),
            child: Center(child: Text(name.substring(0, 1),
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w900,
                    color: Colors.white))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Row(children: [
              Text(name, style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800, color: _text)),
              if (isAdmin) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFB347), Color(0xFFFF8C42)],
                    ),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [BoxShadow(
                        color: Colors.orange.withOpacity(0.25),
                        blurRadius: 4, offset: const Offset(0, 2))],
                  ),
                  child: const Text("ADMIN", style: TextStyle(
                      color: Colors.white, fontSize: 9,
                      fontWeight: FontWeight.w900)),
                ),
              ],
            ]),
            const SizedBox(height: 3),
            Text(
              "${_deptLabel(emp['dept_category'] ?? '')}  ·  ${emp['position'] ?? '사원'}",
              style: const TextStyle(
                  fontSize: 11, color: _sub, fontWeight: FontWeight.w600),
            ),
          ])),
          Icon(Icons.chevron_right_rounded, color: _sub, size: 20),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════
// 공통 확인 다이얼로그
// ══════════════════════════════════════════

class _ConfirmDialog extends StatelessWidget {
  final String title, content, confirmLabel;
  final Color confirmColor;
  final bool isWarning;

  const _ConfirmDialog({
    required this.title,
    required this.content,
    required this.confirmLabel,
    required this.confirmColor,
    this.isWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Row(children: [
        if (isWarning) ...[
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
                color: const Color(0xFFFF4D64).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.warning_amber_rounded,
                color: Color(0xFFFF4D64), size: 18),
          ),
          const SizedBox(width: 10),
        ],
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      ]),
      content: Text(content, style: const TextStyle(fontSize: 14, height: 1.6)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false),
            child: const Text("취소",
                style: TextStyle(color: Color(0xFF8A93B0),
                    fontWeight: FontWeight.w700))),
        _GradBtn(label: confirmLabel, color: confirmColor,
            onTap: () => Navigator.pop(context, true)),
      ],
    );
  }
}

// ── 그라디언트 버튼 (다이얼로그용)
class _GradBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _GradBtn({required this.label, required this.color, this.onTap});

  Color _lighten(Color c, double a) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + a).clamp(0.0, 1.0)).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final isActive = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          gradient: isActive ? LinearGradient(
            colors: [_lighten(color, 0.15), color],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ) : null,
          color: isActive ? null : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
          boxShadow: isActive ? [BoxShadow(
              color: color.withOpacity(0.28), blurRadius: 8,
              offset: const Offset(0, 3))] : [],
        ),
        child: Text(label,
            style: TextStyle(
                color: isActive ? Colors.white : Colors.grey,
                fontWeight: FontWeight.w900,
                fontSize: 14)),
      ),
    );
  }
}