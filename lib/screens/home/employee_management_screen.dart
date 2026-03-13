import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EmployeeManagementScreen extends StatefulWidget {
  const EmployeeManagementScreen({Key? key}) : super(key: key);

  @override
  State<EmployeeManagementScreen> createState() => _EmployeeManagementScreenState();
}

class _EmployeeManagementScreenState extends State<EmployeeManagementScreen> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _filtered  = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedDept = '전체';

  static const _primary = Color(0xFF2E6BFF);
  static const _red     = Color(0xFFFF4D64);
  static const _bg      = Color(0xFFF4F6FB);
  static const _sub     = Color(0xFF8A93B0);
  static const _text    = Color(0xFF1A1D2E);

  // TEST 부서 제거
  static const _depts = ['전체', 'BOX', 'CLEANING', 'DELIVERY', 'MANAGEMENT', 'NUTRITION', 'PRODUCTION', 'RND', 'SALES', 'STEEL', 'SSG'];

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
    '사원', '주임', '대리', '과장', '차장', '부장', '이사', '본부장', '대표이사',
  ];

  String _deptLabel(String code) => _deptLabels[code] ?? code;

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

  // ─── 역할 변경 ───
  Future<void> _changeRole(Map<String, dynamic> emp) async {
    final currentRole = emp['role'] ?? 'USER';
    final newRole     = currentRole == 'ADMIN' ? 'USER' : 'ADMIN';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("역할 변경", style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text(
          "${emp['full_name']}님의 역할을\n$currentRole → $newRole 로 변경할까요?",
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("취소")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("변경"),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await supabase.from('profiles').update({'role': newRole}).eq('id', emp['id']);
      _showSnack("역할이 변경되었습니다. ✅");
      _loadEmployees();
    } catch (e) {
      _showSnack("변경 실패: $e");
    }
  }

  // ─── 부서 변경 ───
  Future<void> _changeDept(Map<String, dynamic> emp) async {
    String selected = emp['dept_category'] ?? 'MANAGEMENT';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text("${emp['full_name']} 부서 변경",
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          content: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['MANAGEMENT', 'PRODUCTION', 'SALES', 'RND', 'STEEL', 'BOX', 'DELIVERY', 'SSG', 'CLEANING', 'NUTRITION'].map((d) {
              final isSel = selected == d;
              final color = _deptColors[d] ?? _sub;
              return GestureDetector(
                onTap: () => setS(() => selected = d),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  decoration: BoxDecoration(
                    color: isSel ? color : color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.withOpacity(0.3)),
                  ),
                  child: Text(_deptLabel(d), style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: isSel ? Colors.white : color)),
                ),
              );
            }).toList(),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("취소")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("저장"),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    try {
      await supabase.from('profiles').update({'dept_category': selected}).eq('id', emp['id']);
      _showSnack("부서가 변경되었습니다. ✅");
      _loadEmployees();
    } catch (e) {
      _showSnack("변경 실패: $e");
    }
  }

  // ─── 직급 변경 ───
  Future<void> _changePosition(Map<String, dynamic> emp) async {
    String selected = emp['position'] ?? '사원';
    const color = Color(0xFF7C5CDB);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text("${emp['full_name']} 직급 변경",
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("현재 직급",
                  style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(emp['position'] ?? '사원',
                    style: const TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 14)),
              ),
              const SizedBox(height: 16),
              const Text("변경할 직급",
                  style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _positions.map((p) {
                  final isSel = selected == p;
                  return GestureDetector(
                    onTap: () => setS(() => selected = p),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSel ? color : color.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: color.withOpacity(isSel ? 0 : 0.2)),
                      ),
                      child: Text(p, style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: isSel ? Colors.white : color)),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("취소")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: color, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("저장"),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    try {
      await supabase.from('profiles').update({'position': selected}).eq('id', emp['id']);
      _showSnack("직급이 변경되었습니다. ✅");
      _loadEmployees();
    } catch (e) {
      _showSnack("변경 실패: $e");
    }
  }

  // ─── 직원 삭제 ───
  Future<void> _deleteEmployee(Map<String, dynamic> emp) async {
    // 1차 확인
    final first = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: _red),
          const SizedBox(width: 8),
          const Text("직원 삭제", style: TextStyle(fontWeight: FontWeight.w900)),
        ]),
        content: Text(
          "${emp['full_name']}님의 계정을 삭제하면\n모든 데이터가 사라집니다.\n\n정말 삭제하시겠습니까?",
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("취소")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _red, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("삭제"),
          ),
        ],
      ),
    );
    if (first != true) return;

    // 2차 확인 (체크박스)
    bool checked = false;
    final second = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("최종 확인",
              style: TextStyle(fontWeight: FontWeight.w900, color: Colors.red)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: _red.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  const Icon(Icons.person_off_rounded, color: _red, size: 20),
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
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("취소")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: checked ? _red : Colors.grey[300],
                foregroundColor: checked ? Colors.white : Colors.grey,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: checked ? () => Navigator.pop(ctx, true) : null,
              child: const Text("최종 삭제"),
            ),
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
        final msg = response.data?['error'] ?? '삭제 실패';
        _showSnack("오류: $msg");
      }
    } catch (e) {
      _showSnack("삭제 실패: $e");
    }
  }

  // ─── 직원 상세 바텀시트 ───
  void _showEmployeeDetail(Map<String, dynamic> emp) {
    final role    = emp['role'] ?? 'USER';
    final dept    = emp['dept_category'] ?? '-';
    final dc      = _deptColors[dept] ?? _sub;
    final isAdmin = role == 'ADMIN';
    final name    = emp['full_name'] ?? '?';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: EdgeInsets.fromLTRB(20, 0, 20,
            20 + MediaQuery.of(context).viewInsets.bottom),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 핸들
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
            // 프로필 헤더
            Row(children: [
              Container(
                width: 58, height: 58,
                decoration: BoxDecoration(
                    color: dc.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(18)),
                child: Center(
                  child: Text(name.substring(0, 1),
                      style: TextStyle(
                          fontSize: 26, fontWeight: FontWeight.w900, color: dc)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w900, color: _text)),
                    const SizedBox(height: 6),
                    Row(children: [
                      // 부서 뱃지
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: dc.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6)),
                        child: Text(_deptLabel(dept),
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w800, color: dc)),
                      ),
                      const SizedBox(width: 6),
                      // 직급 뱃지
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E6BFF).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(emp['position'] ?? '사원',
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF2E6BFF))),
                      ),
                      const SizedBox(width: 6),
                      // 역할 뱃지
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isAdmin
                              ? Colors.orangeAccent.withOpacity(0.15)
                              : _primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(isAdmin ? 'ADMIN' : 'USER',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: isAdmin ? Colors.orangeAccent : _primary,
                            )),
                      ),
                    ]),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 24),
            // 액션 버튼 4개
            Row(children: [
              Expanded(
                child: _actionBtn(
                  icon: Icons.badge_rounded,
                  label: isAdmin ? "일반으로\n변경" : "관리자로\n변경",
                  color: Colors.orangeAccent,
                  onTap: () { Navigator.pop(context); _changeRole(emp); },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _actionBtn(
                  icon: Icons.apartment_rounded,
                  label: "부서\n변경",
                  color: _primary,
                  onTap: () { Navigator.pop(context); _changeDept(emp); },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _actionBtn(
                  icon: Icons.military_tech_rounded,
                  label: "직급\n변경",
                  color: const Color(0xFF7C5CDB),
                  onTap: () { Navigator.pop(context); _changePosition(emp); },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _actionBtn(
                  icon: Icons.delete_rounded,
                  label: "계정\n삭제",
                  color: _red,
                  onTap: () { Navigator.pop(context); _deleteEmployee(emp); },
                ),
              ),
            ]),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 5),
          Text(label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      duration: const Duration(seconds: 2),
    ));
  }

  // ══════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    // TEST 부서 제외하고 그룹핑
    final deptGroups = <String, List<Map<String, dynamic>>>{};
    for (final e in _filtered) {
      final d = e['dept_category'] ?? '기타';
      if (d == 'TEST') continue; // TEST 숨김
      deptGroups.putIfAbsent(d, () => []).add(e);
    }

    // 요약 통계
    final totalCount = _employees.where((e) => e['dept_category'] != 'TEST').length;
    final adminCount = _employees.where((e) => e['role'] == 'ADMIN').length;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text("직원 관리",
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
            onPressed: _loadEmployees,
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── 검색 + 필터 영역 ───
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(children: [
              // 요약 숫자
              if (!_isLoading)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(children: [
                    _statPill("전체", "$totalCount명", _primary),
                    const SizedBox(width: 8),
                    _statPill("관리자", "$adminCount명", Colors.orangeAccent),
                    const Spacer(),
                    Text("총 ${deptGroups.length}개 부서",
                        style: const TextStyle(fontSize: 11, color: _sub)),
                  ]),
                ),
              // 검색창
              Container(
                height: 42,
                decoration: BoxDecoration(
                    color: _bg, borderRadius: BorderRadius.circular(12)),
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
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: sel ? color : color.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: color.withOpacity(sel ? 0 : 0.25)),
                        ),
                        child: Text(
                          "$label  $count",
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: sel ? Colors.white : color),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ]),
          ),

          // ─── 직원 목록 ───
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: _primary))
                : deptGroups.isEmpty
                    ? Center(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.person_search_rounded,
                            size: 52, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text("검색 결과가 없습니다.",
                            style: TextStyle(color: Colors.grey[400])),
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
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 부서 헤더
                                Padding(
                                  padding: const EdgeInsets.only(
                                      bottom: 10, top: 4),
                                  child: Row(children: [
                                    Container(
                                      width: 4, height: 16,
                                      decoration: BoxDecoration(
                                          color: dc,
                                          borderRadius:
                                              BorderRadius.circular(2)),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(_deptLabel(dept),
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w900,
                                            color: dc)),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                          color: dc.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(8)),
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
        ],
      ),
    );
  }

  Widget _statPill(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        const SizedBox(width: 5),
        Text(value,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w900, color: color)),
      ]),
    );
  }

  Widget _buildEmployeeCard(Map<String, dynamic> emp, Color dc) {
    final role    = emp['role'] ?? 'USER';
    final isAdmin = role == 'ADMIN';
    final name    = emp['full_name'] ?? '?';

    return GestureDetector(
      onTap: () => _showEmployeeDetail(emp),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 3))
          ],
        ),
        child: Row(children: [
          // 아바타
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
                color: dc.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14)),
            child: Center(
              child: Text(name.substring(0, 1),
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w900, color: dc)),
            ),
          ),
          const SizedBox(width: 12),
          // 이름 + 뱃지
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(name,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w800, color: _text)),
                  if (isAdmin) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: Colors.orangeAccent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(5)),
                      child: const Text("ADMIN",
                          style: TextStyle(
                              color: Colors.orangeAccent,
                              fontSize: 9, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ]),
                const SizedBox(height: 3),
                Text(
                  "${_deptLabel(emp['dept_category'] ?? '')}  ·  ${emp['position'] ?? '사원'}",
                  style: const TextStyle(fontSize: 11, color: _sub, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          // 화살표
          const Icon(Icons.chevron_right_rounded, color: _sub, size: 20),
        ]),
      ),
    );
  }
}