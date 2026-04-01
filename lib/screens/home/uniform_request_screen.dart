// uniform_request_screen.dart — 피복 신청

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'lang_context.dart';
import 'app_strings.dart';

part 'uniform_request_card.dart';
part 'uniform_request_dept_section.dart';
part 'uniform_request_sheet.dart';

const _kClothingItems = [
  // 하계
  '춘추잠바', '춘추바지', '반팔카라티', '청잠바', '청바지',
  // 동계
  '동잠바', '동바지', '동조끼', '긴팔카라티', '동청잠바', '동청바지',
];
const _kSafetyItems = ['안전화', '면장갑', '반코팅장갑', '코팅장갑', '안전모'];
const _kItems       = [..._kClothingItems, ..._kSafetyItems];
const _uPrimary = Color(0xFF2E6BFF);
const _uBg      = Color(0xFFF0F2F7);

// ══════════════════════════════════════════
// UniformRequestScreen
// ══════════════════════════════════════════

class UniformRequestScreen extends StatefulWidget {
  final Map<String, dynamic> userProfile;
  final bool isAdmin;
  const UniformRequestScreen({Key? key, required this.userProfile, required this.isAdmin}) : super(key: key);
  @override
  State<UniformRequestScreen> createState() => _UniformRequestScreenState();
}

class _UniformRequestScreenState extends State<UniformRequestScreen>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  TabController? _tabCtrl;

  bool _isLoading = true;
  List<Map<String, dynamic>> _myRequests    = [];
  List<Map<String, dynamic>> _adminRequests = [];

  // 연도/월 필터
  int _selectedYear  = DateTime.now().year;
  int _selectedMonth = DateTime.now().month; // 0 = 전체

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: widget.isAdmin ? 2 : 1, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabCtrl?.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final myData = await supabase.from('uniform_requests').select()
          .eq('user_id', user.id).order('created_at', ascending: false);
      final all = List<Map<String, dynamic>>.from(myData as List);

      List<Map<String, dynamic>> adminData = [];
      if (widget.isAdmin) {
        final rows = await supabase.from('uniform_requests').select()
            .order('created_at', ascending: false);
        adminData = List<Map<String, dynamic>>.from(rows as List);
      }

      if (!mounted) return;
      setState(() {
        _myRequests    = all;
        _adminRequests = adminData;
        _isLoading     = false;
      });
    } catch (e) {
      debugPrint('피복 신청 로드 실패: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _snack(String msg, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
      behavior: SnackBarBehavior.floating,
      backgroundColor: color ?? const Color(0xFF1A1D2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
    ));
  }

  Future<void> _updateStatus(String id, String status, {String? rejectReason}) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final myProfile = await supabase.from('profiles').select('full_name')
          .eq('id', user.id).single();
      await supabase.from('uniform_requests').update({
        'status':        status,
        'approver_id':   user.id,
        'approver_name': myProfile['full_name'] ?? '관리자',
        'approved_at':   DateTime.now().toIso8601String(),
        if (rejectReason != null) 'reject_reason': rejectReason,
      }).eq('id', id);
      await _loadData();
      _snack(status == 'APPROVED' ? context.tr(AppStrings.uniformApproveOk) : context.tr(AppStrings.uniformRejectOk),
          color: status == 'APPROVED' ? Colors.green : Colors.redAccent);
    } catch (e) {
      _snack(context.tr(AppStrings.uniformError));
    }
  }

  Future<void> _showRejectDialog(String id) async {
    final ctrl   = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(context.tr(AppStrings.uniformRejectReason), style: const TextStyle(fontWeight: FontWeight.w900)),
        content: TextField(
          controller: ctrl, maxLines: 3,
          decoration: InputDecoration(
            hintText: context.tr(AppStrings.uniformRejectReason), filled: true,
            fillColor: const Color(0xFFF4F6FB),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: Text(context.tr(AppStrings.cancel), style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w700))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: Text(context.tr(AppStrings.reject), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (result != null) await _updateStatus(id, 'REJECTED', rejectReason: result);
  }

  Future<void> _submitRequest({required List<Map<String, dynamic>> items, required String reason}) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      for (final item in items) {
        await supabase.from('uniform_requests').insert({
          'user_id':       user.id,
          'full_name':     widget.userProfile['full_name'] ?? '',
          'dept_category': widget.userProfile['dept_category'] ?? '',
          'item':     item['item'],
          'size':     item['size'],
          'quantity': item['quantity'],
          'reason':   reason,
          'status':   'PENDING',
        });
      }
      await _loadData();
      _snack('피복 신청 완료! (${items.length}개 품목) ✅', color: _uPrimary);
    } catch (e) {
      _snack(context.tr(AppStrings.uniformSubmitError));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_tabCtrl == null) return const SizedBox.shrink();

    final pendingCount = _adminRequests.where((r) => r['status'] == 'PENDING').length;

    return Scaffold(
      backgroundColor: _uBg,
      appBar: AppBar(
        title: Text(context.tr(AppStrings.uniformTitle), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1D2E),
        elevation: 0,
        surfaceTintColor: Colors.white,
        bottom: widget.isAdmin
            ? TabBar(
                controller: _tabCtrl!,
                labelColor: _uPrimary,
                unselectedLabelColor: Colors.grey,
                indicatorColor: _uPrimary,
                indicatorWeight: 3,
                tabs: [
                  Tab(text: context.tr(AppStrings.uniformTabMy)),
                  Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(context.tr(AppStrings.uniformTabAll)),
                    if (pendingCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(8)),
                        child: Text('$pendingCount',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ])),
                ],
              )
            : PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(height: 1, color: const Color(0xFFF0F2F8)),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                backgroundColor: Colors.transparent,
                builder: (_) => UniformRequestSheet(
                    userProfile: widget.userProfile, onSubmit: _submitRequest),
              ),
              backgroundColor: _uPrimary,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text('신청하기',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              Expanded(
                child: widget.isAdmin
                    ? TabBarView(
                        controller: _tabCtrl!,
                        children: [_myRequestList(), _adminRequestList()],
                      )
                    : _myRequestList(),
              ),
            ]),
    );
  }

  // ── 필터 헬퍼
  List<Map<String, dynamic>> _filtered(List<Map<String, dynamic>> src) {
    return src.where((r) {
      final d = r['created_at']?.toString() ?? '';
      try {
        final dt = DateTime.parse(d);
        if (dt.year != _selectedYear) return false;
        if (_selectedMonth != 0 && dt.month != _selectedMonth) return false;
        return true;
      } catch (_) { return false; }
    }).toList();
  }

  // 연도/월 선택 바
  Widget _filterBar() {
    final years  = List.generate(5, (i) => 2025 + i);
    final months = [context.tr(AppStrings.uniformMonthAll),'1월','2월','3월','4월','5월','6월',
                    '7월','8월','9월','10월','11월','12월'];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        // 연도 선택 버튼
        Expanded(child: GestureDetector(
          onTap: () async {
            final result = await showModalBottomSheet<int>(
              context: context,
              backgroundColor: Colors.transparent,
              builder: (_) => _PickerSheet(
                title: context.tr(AppStrings.uniformYearSelect),
                items: years.map((y) => '$y년').toList(),
                selectedIndex: years.indexOf(_selectedYear).clamp(0, years.length - 1),
              ),
            );
            if (result != null) setState(() => _selectedYear = years[result]);
          },
          child: _pickerBtn('${_selectedYear}년', Icons.calendar_today_rounded),
        )),
        const SizedBox(width: 10),
        // 월 선택 버튼
        Expanded(child: GestureDetector(
          onTap: () async {
            final months2 = ['전체','1월','2월','3월','4월','5월','6월',
                             '7월','8월','9월','10월','11월','12월'];
            final result = await showModalBottomSheet<int>(
              context: context,
              backgroundColor: Colors.transparent,
              builder: (_) => _PickerSheet(
                title: context.tr(AppStrings.uniformMonthSelect),
                items: months2,
                selectedIndex: _selectedMonth,
              ),
            );
            if (result != null) setState(() => _selectedMonth = result);
          },
          child: _pickerBtn(months[_selectedMonth], Icons.date_range_rounded),
        )),
      ]),
    );
  }

  Widget _pickerBtn(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: _uPrimary.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _uPrimary.withOpacity(0.2)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 14, color: _uPrimary),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w800, color: _uPrimary)),
        const SizedBox(width: 4),
        Icon(Icons.keyboard_arrow_down_rounded, size: 16,
            color: _uPrimary.withOpacity(0.6)),
      ]),
    );
  }

  // 월별 그룹핑
  Map<String, List<Map<String, dynamic>>> _groupByMonth(List<Map<String, dynamic>> src) {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final r in src) {
      try {
        final dt  = DateTime.parse(r['created_at']?.toString() ?? '');
        final key = '${dt.year}년 ${dt.month}월';
        map.putIfAbsent(key, () => []).add(r);
      } catch (_) {}
    }
    return map;
  }

  Widget _myRequestList() {
    final filtered = _filtered(_myRequests);
    final grouped  = _selectedMonth == 0 ? _groupByMonth(filtered) : null;

    return RefreshIndicator(
      color: _uPrimary,
      onRefresh: _loadData,
      child: Column(children: [
        _filterBar(),
        Expanded(
          child: filtered.isEmpty
              ? ListView(children: [
                  const SizedBox(height: 80),
                  Center(child: Column(children: [
                    Icon(Icons.checkroom_rounded, size: 48, color: Colors.grey.withOpacity(0.4)),
                    const SizedBox(height: 12),
                    Text(context.tr(AppStrings.uniformNoData),
                        style: TextStyle(color: Colors.black.withOpacity(0.35), fontWeight: FontWeight.w600)),
                  ])),
                ])
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  children: grouped != null
                      ? grouped.entries.expand((e) => [
                          _monthHeader(e.key, e.value.length),
                          const SizedBox(height: 8),
                          ...e.value.map((r) => UniformRequestCard(
                              request: r, isAdmin: false, onApprove: null, onReject: null)),
                          const SizedBox(height: 16),
                        ]).toList()
                      : filtered.map((r) => UniformRequestCard(
                          request: r, isAdmin: false, onApprove: null, onReject: null)).toList(),
                ),
        ),
      ]),
    );
  }

  Widget _adminRequestList() {
    final filtered = _filtered(_adminRequests);

    // 부서별 그룹핑
    final deptOrder = ['MANAGEMENT','PRODUCTION','SALES','RND','STEEL','BOX','DELIVERY','SSG','CLEANING','NUTRITION'];
    final deptMap = <String, List<Map<String, dynamic>>>{};
    for (final r in filtered) {
      final dept = r['dept_category']?.toString() ?? '기타';
      deptMap.putIfAbsent(dept, () => []).add(r);
    }
    // 부서 순서 정렬
    final depts = [...deptOrder.where((d) => deptMap.containsKey(d)),
                   ...deptMap.keys.where((d) => !deptOrder.contains(d))];

    return RefreshIndicator(
      color: _uPrimary,
      onRefresh: _loadData,
      child: Column(children: [
        _filterBar(),
        Expanded(
          child: filtered.isEmpty
              ? ListView(children: [
                  const SizedBox(height: 80),
                  Center(child: Text(context.tr(AppStrings.uniformNoData),
                      style: TextStyle(color: Colors.black.withOpacity(0.35), fontWeight: FontWeight.w600))),
                ])
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  children: depts.map((dept) {
                    final items = deptMap[dept]!;
                    final pendingCount = items.where((r) => r['status'] == 'PENDING').length;
                    return _DeptSection(
                      dept:         dept,
                      items:        items,
                      pendingCount: pendingCount,
                      onApprove:    (id) => _updateStatus(id, 'APPROVED'),
                      onReject:     (id) => _showRejectDialog(id),
                    );
                  }).toList(),
                ),
        ),
      ]),
    );
  }

  Widget _monthHeader(String label, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Container(width: 4, height: 18,
            decoration: BoxDecoration(color: _uPrimary, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF1A1D2E))),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(color: _uPrimary.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
          child: Text('$count건', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _uPrimary)),
        ),
      ]),
    );
  }

  Widget _sectionHeader(String title, Color color) {
    return Row(children: [
      Container(width: 4, height: 18,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF1A1D2E))),
    ]);
  }
}

// ══════════════════════════════════════════
// 신청 카드
// ══════════════════════════════════════════


// ══════════════════════════════════════════
// 선택 바텀시트 (연도/월 공용)
// ══════════════════════════════════════════

class _PickerSheet extends StatelessWidget {
  final String title;
  final List<String> items;
  final int selectedIndex;

  const _PickerSheet({
    required this.title,
    required this.items,
    required this.selectedIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 36, height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
                color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Row(children: [
            Text(title, style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.w900,
                color: Color(0xFF1A1D2E))),
          ]),
        ),
        const Divider(height: 1),
        ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: items.length,
            itemBuilder: (_, i) {
              final sel = i == selectedIndex;
              return InkWell(
                onTap: () => Navigator.pop(context, i),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  color: sel ? _uPrimary.withOpacity(0.06) : null,
                  child: Row(children: [
                    Text(items[i], style: TextStyle(
                        fontSize: 15,
                        fontWeight: sel ? FontWeight.w800 : FontWeight.w500,
                        color: sel ? _uPrimary : const Color(0xFF1A1D2E))),
                    const Spacer(),
                    if (sel) const Icon(Icons.check_rounded, color: _uPrimary, size: 18),
                  ]),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ]),
    );
  }
}