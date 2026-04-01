import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DormAdminAssignScreen extends StatefulWidget {
  const DormAdminAssignScreen({Key? key}) : super(key: key);

  @override
  State<DormAdminAssignScreen> createState() => _DormAdminAssignScreenState();
}

class _DormAdminAssignScreenState extends State<DormAdminAssignScreen> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _rooms = [];
  List<Map<String, dynamic>> _pendingApplications = [];

  static const _primary = Color(0xFF2E6BFF);
  static const _red     = Color(0xFFFF4D64);
  static const _green   = Color(0xFF0BC5A0);
  static const _orange  = Color(0xFFFF8C42);
  static const _bg      = Color(0xFFF4F6FB);
  static const _sub     = Color(0xFF8A93B0);
  static const _text    = Color(0xFF1A1D2E);

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    await Future.wait([_fetchRooms(), _fetchPendingApplications()]);
  }

  Future<void> _fetchRooms() async {
    try {
      final data = await supabase.from('dorm_rooms').select('*').order('room_number');
      setState(() {
        _rooms = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("방 목록 로드 실패: $e");
    }
  }

  Future<void> _fetchPendingApplications() async {
    try {
      final data = await supabase
          .from('dorm_applications')
          .select('*')
          .eq('status', 'PENDING')
          .order('created_at', ascending: false);
      setState(() {
        _pendingApplications = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      debugPrint("신청 목록 로드 실패: $e");
    }
  }

  Future<void> _updateOccupancy(String roomId, int current, int delta, int max) async {
    final newValue = current + delta;
    if (newValue < 0 || newValue > max) return;
    try {
      await supabase.from('dorm_rooms').update({'current_occupancy': newValue}).eq('id', roomId);
      _fetchRooms();
    } catch (e) {
      _showSnack("인원수 업데이트 중 오류가 발생했습니다.");
    }
  }

  Future<void> _handleApplication(Map<String, dynamic> app, String status) async {
    try {
      await supabase.from('dorm_applications').update({'status': status}).eq('id', app['id']);

      if (status == 'APPROVED') {
        final cleanNum = app['room_number'].toString().replaceAll('호', '').trim();
        final room = _rooms.firstWhere(
          (r) => r['room_number'].toString().replaceAll('호', '').trim() == cleanNum,
          orElse: () => throw Exception("방 번호 [$cleanNum]를 찾을 수 없습니다."),
        );
        final roomId       = room['id'].toString();
        final targetUserId = app['user_id'];

        if (app['type'] == 'IN') {
          await supabase.from('dorm_residents').insert({
            'room_id': roomId,
            'resident_name': app['full_name'],
            'user_id': targetUserId,
          });
          await _updateOccupancy(roomId, room['current_occupancy'], 1, room['max_capacity']);
        } else {
          await supabase.from('dorm_residents').delete().eq('user_id', targetUserId);
          await _updateOccupancy(roomId, room['current_occupancy'], -1, room['max_capacity']);
        }
      }

      _showSnack(status == 'APPROVED' ? "처리가 완료되었습니다. ✅" : "신청이 반려되었습니다.");
      _refreshData();
    } catch (e) {
      _showSnack("오류 발생: ${e.toString()}");
    }
  }

  void _showResidentManager(Map<String, dynamic> room) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ResidentManagerSheet(
        room: room,
        supabase: supabase,
        onSnack: _showSnack,
        onRefresh: _refreshData,
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final totalRooms     = _rooms.length;
    final totalResidents = _rooms.fold<int>(0, (s, r) => s + ((r['current_occupancy'] as int?) ?? 0));
    final totalCapacity  = _rooms.fold<int>(0, (s, r) => s + ((r['max_capacity'] as int?) ?? 0));

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text("기숙사 배정 관리",
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
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _refreshData),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : RefreshIndicator(
              onRefresh: _refreshData,
              color: _primary,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                children: [
                  _buildSummaryCard(totalRooms, totalResidents, totalCapacity),
                  const SizedBox(height: 20),
                  if (_pendingApplications.isNotEmpty) ...[
                    _sectionHeader("승인 대기", "${_pendingApplications.length}건",
                        _orange, Icons.notifications_active_rounded),
                    const SizedBox(height: 10),
                    ..._pendingApplications.map(_buildApplicationCard),
                    const SizedBox(height: 20),
                  ],
                  _sectionHeader("호실별 현황", "$totalRooms개 호실",
                      _primary, Icons.meeting_room_rounded),
                  const SizedBox(height: 10),
                  ..._rooms.map(_buildRoomCard),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCard(int rooms, int residents, int capacity) {
    final rate = capacity > 0 ? residents / capacity : 0.0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E6BFF), Color(0xFF4FB2FF)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: _primary.withOpacity(0.25),
            blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _statItem("전체 호실", "$rooms개"),
          Container(width: 1, height: 32, color: Colors.white.withOpacity(0.2)),
          _statItem("거주 인원", "$residents명"),
          Container(width: 1, height: 32, color: Colors.white.withOpacity(0.2)),
          _statItem("잔여 공석", "${capacity - residents}석"),
        ]),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text("입실률  ${(rate * 100).toStringAsFixed(0)}%",
              style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
          Text("$residents / $capacity명",
              style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: rate.clamp(0.0, 1.0),
                minHeight: 6, backgroundColor: Colors.white.withOpacity(0.2),
                valueColor: const AlwaysStoppedAnimation(Colors.white))),
      ]),
    );
  }

  Widget _statItem(String label, String value) => Column(children: [
    Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
    const SizedBox(height: 3),
    Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
  ]);

  Widget _sectionHeader(String title, String badge, Color color, IconData icon) {
    return Row(children: [
      Container(padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 16)),
      const SizedBox(width: 10),
      Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _text)),
      const SizedBox(width: 8),
      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8)),
          child: Text(badge, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color))),
    ]);
  }

  Widget _buildApplicationCard(Map<String, dynamic> app) {
    final isIn  = app['type'] == 'IN';
    final color = isIn ? _primary : _red;
    final icon  = isIn ? Icons.login_rounded : Icons.logout_rounded;
    final label = isIn ? '입실' : '퇴실';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _orange.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(children: [
        Container(width: 42, height: 42,
            decoration: BoxDecoration(color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 20)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(app['full_name'] ?? '-',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _text)),
            const SizedBox(width: 6),
            Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(5)),
                child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color))),
          ]),
          const SizedBox(height: 3),
          Text("${app['room_number']}호 $label 요청",
              style: const TextStyle(fontSize: 12, color: _sub)),
        ])),
        Row(mainAxisSize: MainAxisSize.min, children: [
          _actionChip("반려", _red, () => _handleApplication(app, 'REJECTED')),
          const SizedBox(width: 6),
          _actionChip("승인", _green, () => _handleApplication(app, 'APPROVED'), filled: true),
        ]),
      ]),
    );
  }

  Widget _actionChip(String label, Color color, VoidCallback onTap, {bool filled = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: filled ? color : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: filled ? null : Border.all(color: color.withOpacity(0.3)),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
            color: filled ? Colors.white : color)),
      ),
    );
  }

  Widget _buildRoomCard(Map<String, dynamic> room) {
    final id      = room['id'].toString();
    final roomNum = room['room_number'].toString();
    final current = int.tryParse(room['current_occupancy'].toString()) ?? 0;
    final max     = int.tryParse(room['max_capacity'].toString()) ?? 0;
    final rate    = max > 0 ? current / max : 0.0;
    final isFull  = current >= max;
    final isEmpty = current == 0;
    final barColor = isFull ? _red : rate >= 0.5 ? _orange : _green;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(children: [
        Row(children: [
          Container(width: 48, height: 48,
              decoration: BoxDecoration(
                  color: isFull ? _red.withOpacity(0.08) : _primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14)),
              child: Icon(Icons.meeting_room_rounded,
                  color: isFull ? _red : _primary, size: 22)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(roomNum, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _text)),
              const SizedBox(width: 8),
              if (isFull) _badge("만실", _red) else if (isEmpty) _badge("공실", _sub),
            ]),
            const SizedBox(height: 3),
            Text("$current / $max명 거주 중",
                style: const TextStyle(fontSize: 12, color: _sub)),
          ])),
        ]),
        const SizedBox(height: 12),
        ClipRRect(borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: rate.clamp(0.0, 1.0),
                minHeight: 5, backgroundColor: Colors.black.withOpacity(0.05),
                valueColor: AlwaysStoppedAnimation(barColor))),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => _showResidentManager(room),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
                color: _primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _primary.withOpacity(0.15))),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.people_rounded, color: _primary, size: 15),
              const SizedBox(width: 6),
              const Text("거주자 명단",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _primary)),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _badge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
    child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color)),
  );

  Widget _roundBtn(IconData icon, Color color, VoidCallback? onTap) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
            color: disabled ? Colors.grey.withOpacity(0.08) : color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(9)),
        child: Icon(icon, size: 16, color: disabled ? Colors.grey[300] : color),
      ),
    );
  }
}

// ══════════════════════════════════════════
// 거주자 명단 + 추가 + 벌점 관리 바텀시트
// ══════════════════════════════════════════
class _ResidentManagerSheet extends StatefulWidget {
  final Map<String, dynamic> room;
  final SupabaseClient supabase;
  final void Function(String) onSnack;
  final VoidCallback onRefresh;

  const _ResidentManagerSheet({
    required this.room,
    required this.supabase,
    required this.onSnack,
    required this.onRefresh,
  });

  @override
  State<_ResidentManagerSheet> createState() => _ResidentManagerSheetState();
}

class _ResidentManagerSheetState extends State<_ResidentManagerSheet> {
  List<Map<String, dynamic>> _residents = [];
  bool _loading = true;
  String? _expandedUserId;
  int _refreshKey = 0;

  static const _primary = Color(0xFF2E6BFF);
  static const _red     = Color(0xFFFF4D64);
  static const _green   = Color(0xFF0BC5A0);
  static const _bg      = Color(0xFFF4F6FB);
  static const _sub     = Color(0xFF8A93B0);
  static const _text    = Color(0xFF1A1D2E);

  String get _roomId     => widget.room['id'].toString();
  String get _roomNumber => widget.room['room_number'].toString();
  int    get _current    => int.tryParse(widget.room['current_occupancy'].toString()) ?? 0;
  int    get _max        => int.tryParse(widget.room['max_capacity'].toString()) ?? 0;

  @override
  void initState() {
    super.initState();
    _loadResidents();
  }

  Future<void> _loadResidents() async {
    setState(() => _loading = true);
    try {
      final data = await widget.supabase
          .from('dorm_residents')
          .select('*')
          .eq('room_id', _roomId);
      setState(() {
        _residents = List<Map<String, dynamic>>.from(data);
        _loading   = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  // ── 거주자 직접 추가
  Future<void> _showAddResidentDialog() async {
    final nameCtrl = TextEditingController();
    String? selectedUserId;
    List<Map<String, dynamic>> profiles = [];

    // 이미 입주한 user_id 제외하고 profiles 로드
    try {
      final data = await widget.supabase
          .from('profiles')
          .select('id, full_name, dept_category, position')
          .order('full_name');
      final existingIds = _residents
          .map((r) => r['user_id']?.toString())
          .whereType<String>()
          .toSet();
      profiles = List<Map<String, dynamic>>.from(data)
          .where((p) => !existingIds.contains(p['id']?.toString()))
          .toList();
    } catch (e) {
      debugPrint('profiles 로드 실패: $e');
    }

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text("$_roomNumber 거주자 추가",
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // 앱 계정 선택
              if (profiles.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: selectedUserId,
                  hint: const Text('앱 계정 선택 (선택사항)', style: TextStyle(fontSize: 13)),
                  isExpanded: true,
                  items: profiles.map((p) {
                    final name = p['full_name'] as String? ?? '-';
                    final dept = _deptLabel(p['dept_category'] as String? ?? '');
                    return DropdownMenuItem(
                      value: p['id'] as String,
                      child: Text('$name  ·  $dept',
                          style: const TextStyle(fontSize: 13)),
                    );
                  }).toList(),
                  onChanged: (v) {
                    setS(() {
                      selectedUserId = v;
                      // 선택 시 이름 자동 입력
                      final profile = profiles.firstWhere((p) => p['id'] == v);
                      nameCtrl.text = profile['full_name'] as String? ?? '';
                    });
                  },
                  decoration: InputDecoration(
                    labelText: '직원 선택',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              const SizedBox(height: 12),
              // 이름 직접 입력 (앱 계정 없는 외국인 등)
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: '이름',
                  hintText: '직접 입력 (앱 계정 없는 경우)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('취소')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;

                try {
                  // 입주자 추가
                  await widget.supabase.from('dorm_residents').insert({
                    'room_id':       _roomId,
                    'room_number':   _roomNumber,
                    'resident_name': name,
                    if (selectedUserId != null) 'user_id': selectedUserId,
                    'entry_date':    DateTime.now().toIso8601String().substring(0, 10),
                    'deposit_amount': '0',
                    'agreed_to_rules': 'false',
                  });

                  // 호실 인원 +1
                  final newOccupancy = _current + 1;
                  await widget.supabase
                      .from('dorm_rooms')
                      .update({'current_occupancy': newOccupancy})
                      .eq('id', _roomId);

                  Navigator.pop(ctx);
                  widget.onSnack('$name 거주자 추가 완료 ✅');
                  widget.onRefresh(); // 상위 호실 목록 갱신
                  _loadResidents();
                } catch (e) {
                  widget.onSnack('추가 실패: $e');
                }
              },
              child: const Text('추가'),
            ),
          ],
        ),
      ),
    );
  }

  // ── 거주자 삭제
  Future<void> _removeResident(Map<String, dynamic> resident) async {
    final name = resident['resident_name'] as String? ?? '-';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('거주자 퇴실', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text('$name 거주자를\n퇴실 처리하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _red, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('퇴실'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await widget.supabase.from('dorm_residents').delete().eq('id', resident['id']);
      // 호실 인원 -1
      final newOccupancy = (_current - 1).clamp(0, _max);
      await widget.supabase
          .from('dorm_rooms')
          .update({'current_occupancy': newOccupancy})
          .eq('id', _roomId);

      widget.onSnack('$name 퇴실 처리 완료');
      widget.onRefresh();
      _loadResidents();
    } catch (e) {
      widget.onSnack('퇴실 처리 실패: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _fetchDemerits(String userId) async {
    final data = await widget.supabase
        .from('dorm_demerits')
        .select('*')
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> _deleteDemerit(String demeritId, String userName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text("벌점 삭제", style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text("$userName 사원의 벌점을\n삭제하시겠습니까?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("취소")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _red, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("삭제"),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await widget.supabase.from('dorm_demerits').delete().eq('id', demeritId);
      widget.onSnack("벌점이 삭제되었습니다. ✅");
      setState(() => _refreshKey++);
    } catch (e) {
      widget.onSnack("삭제 실패: $e");
    }
  }

  Future<void> _addDemerit(String userId, String userName) async {
    int points = 1;
    final reasonCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text("$userName 벌점 부여",
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<int>(
              value: points,
              items: [1, 2, 3].map((p) => DropdownMenuItem(value: p, child: Text("$p 점"))).toList(),
              onChanged: (v) => setS(() => points = v!),
              decoration: const InputDecoration(labelText: "벌점 점수"),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(labelText: "사유", hintText: "예: 실내 흡연, 소음 등"),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("취소")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () async {
                if (reasonCtrl.text.trim().isEmpty) return;
                await widget.supabase.from('dorm_demerits').insert({
                  'user_id': userId,
                  'resident_name': userName,
                  'points': points,
                  'reason': reasonCtrl.text.trim(),
                  'given_by': widget.supabase.auth.currentUser!.id,
                });
                Navigator.pop(ctx);
                widget.onSnack("$userName 사원에게 벌점 $points점 부과 ✅");
                setState(() => _refreshKey++);
              },
              child: const Text("부과"),
            ),
          ],
        ),
      ),
    );
  }

  String _deptLabel(String dept) {
    const m = {
      'MANAGEMENT': '관리부', 'PRODUCTION': '생산관리부', 'SALES': '영업부',
      'RND': '연구소', 'STEEL': '스틸생산부', 'BOX': '박스생산부',
      'DELIVERY': '포장납품부', 'SSG': '에스에스지',
      'CLEANING': '환경미화', 'NUTRITION': '영양사',
    };
    return m[dept] ?? dept;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      child: Column(children: [
        Container(width: 40, height: 4,
            margin: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 16, 12),
          child: Row(children: [
            const Icon(Icons.meeting_room_rounded, color: _primary, size: 20),
            const SizedBox(width: 8),
            Text("$_roomNumber 거주자 명단",
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: _text)),
            const Spacer(),
            if (!_loading)
              Text("${_residents.length}/$_max명",
                  style: const TextStyle(fontSize: 13, color: _sub, fontWeight: FontWeight.w600)),
            const SizedBox(width: 10),
            // ── 추가 버튼
            GestureDetector(
              onTap: _current < _max ? _showAddResidentDialog : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: _current < _max ? _primary : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.person_add_rounded, size: 14,
                      color: _current < _max ? Colors.white : Colors.grey[400]),
                  const SizedBox(width: 4),
                  Text('추가', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
                      color: _current < _max ? Colors.white : Colors.grey[400])),
                ]),
              ),
            ),
          ]),
        ),
        const Divider(height: 1),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _primary))
              : _residents.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.person_off_rounded, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 10),
                      Text("거주자가 없습니다.",
                          style: TextStyle(color: Colors.grey[400])),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: _showAddResidentDialog,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                              color: _primary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _primary.withOpacity(0.2))),
                          child: Row(mainAxisSize: MainAxisSize.min, children: const [
                            Icon(Icons.person_add_rounded, color: _primary, size: 16),
                            SizedBox(width: 6),
                            Text('첫 거주자 추가', style: TextStyle(
                                color: _primary, fontWeight: FontWeight.w700)),
                          ]),
                        ),
                      ),
                    ]))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: _residents.length,
                      itemBuilder: (_, i) => _buildResidentTile(_residents[i]),
                    ),
        ),
      ]),
    );
  }

  Widget _buildResidentTile(Map<String, dynamic> person) {
    final userId = person['user_id']?.toString() ?? '';
    final name   = person['resident_name'] as String? ?? '-';
    final isExp  = _expandedUserId == userId && userId.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(14)),
      child: Column(children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: _primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12)),
            child: Center(child: Text(name.isNotEmpty ? name[0] : '?',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _primary))),
          ),
          title: Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: _text)),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            // 퇴실 버튼
            _tileBtn("퇴실", Colors.orange, () => _removeResident(person)),
            const SizedBox(width: 6),
            if (userId.isNotEmpty) ...[
              _tileBtn("벌점 부여", _red, () => _addDemerit(userId, name)),
              const SizedBox(width: 6),
              _tileBtn(isExp ? "접기" : "벌점 보기", _primary,
                  () => setState(() => _expandedUserId = isExp ? null : userId)),
            ],
          ]),
        ),
        if (isExp && userId.isNotEmpty)
          FutureBuilder<List<Map<String, dynamic>>>(
            key: ValueKey('$userId-$_refreshKey'),
            future: _fetchDemerits(userId),
            builder: (_, snap) {
              if (!snap.hasData) {
                return const Padding(padding: EdgeInsets.all(12),
                    child: Center(child: CircularProgressIndicator(color: _primary, strokeWidth: 2)));
              }
              final demerits = snap.data!;
              if (demerits.isEmpty) {
                return Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                    child: Text("부과된 벌점이 없습니다.",
                        style: TextStyle(fontSize: 12, color: _sub.withOpacity(0.7))));
              }
              return Column(children: demerits.map((d) {
                final demeritId = d['id']?.toString() ?? '';
                final points    = d['points'] ?? 0;
                final reason    = d['reason'] ?? '-';
                final createdAt = d['created_at'] != null
                    ? DateTime.parse(d['created_at']).toLocal() : null;
                final dateStr = createdAt != null
                    ? "${createdAt.month}/${createdAt.day}" : '';

                return Container(
                  margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _red.withOpacity(0.15))),
                  child: Row(children: [
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: _red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6)),
                        child: Text("-$points점",
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: _red))),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(reason, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      if (dateStr.isNotEmpty)
                        Text(dateStr, style: const TextStyle(fontSize: 11, color: _sub)),
                    ])),
                    GestureDetector(
                      onTap: () => _deleteDemerit(demeritId, name),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: _red.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.delete_outline_rounded, color: _red, size: 16),
                      ),
                    ),
                  ]),
                );
              }).toList());
            },
          ),
      ]),
    );
  }

  Widget _tileBtn(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8)),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      ),
    );
  }
}