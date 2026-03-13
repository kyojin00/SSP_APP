import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class DormEmployeeScreen extends StatefulWidget {
  final Map<String, dynamic> userProfile;
  const DormEmployeeScreen({Key? key, required this.userProfile}) : super(key: key);

  @override
  State<DormEmployeeScreen> createState() => _DormEmployeeScreenState();
}

class _DormEmployeeScreenState extends State<DormEmployeeScreen>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;

  bool _isLoading = true;
  Map<String, dynamic>? _myRoom;
  List<Map<String, dynamic>> _myApplications = [];

  bool _fabOpen = false;
  late AnimationController _fabAnim;

  static const _primary = Color(0xFF2E6BFF);
  static const _red     = Color(0xFFFF4D64);
  static const _bg      = Color(0xFFF4F6FB);
  static const _sub     = Color(0xFF8A93B0);
  static const _text    = Color(0xFF1A1D2E);

  bool get _hasActiveInApplication  =>
      _myApplications.any((a) => a['type'] == 'IN'  && a['status'] == 'PENDING');
  bool get _hasActiveOutApplication =>
      _myApplications.any((a) => a['type'] == 'OUT' && a['status'] == 'PENDING');

  @override
  void initState() {
    super.initState();
    _fabAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _loadData();
  }

  @override
  void dispose() {
    _fabAnim.dispose();
    super.dispose();
  }

  void _toggleFab() {
    setState(() => _fabOpen = !_fabOpen);
    _fabOpen ? _fabAnim.forward() : _fabAnim.reverse();
  }

  void _closeFab() {
    if (_fabOpen) {
      setState(() => _fabOpen = false);
      _fabAnim.reverse();
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final userId = supabase.auth.currentUser?.id;
    try {
      final apps = await supabase
          .from('dorm_applications')
          .select()
          .eq('user_id', userId as Object)
          .order('created_at', ascending: false);

      final residentData = await supabase
          .from('dorm_residents')
          .select('room_id, dorm_rooms(*)')
          .eq('user_id', userId!)
          .maybeSingle();

      if (!mounted) return;
      setState(() {
        _myRoom = (residentData != null && residentData['dorm_rooms'] != null)
            ? residentData['dorm_rooms']
            : null;
        _myApplications = List<Map<String, dynamic>>.from(apps);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("사원 데이터 로드 실패: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openInRequestDialog() {
    _closeFab();
    if (_hasActiveInApplication) return;
    String? selectedRoom;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          return DraggableScrollableSheet(
            initialChildSize: 0.55,
            minChildSize: 0.4,
            maxChildSize: 0.85,
            expand: false,
            builder: (_, scrollController) => Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: Column(children: [
                      Center(
                        child: Container(
                          width: 40, height: 4,
                          decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(2)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: _primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.login_rounded, color: _primary, size: 20),
                        ),
                        const SizedBox(width: 10),
                        const Text("입실 신청",
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                      ]),
                      const SizedBox(height: 20),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text("호실 선택",
                            style: TextStyle(fontSize: 13, color: _sub, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(height: 12),
                    ]),
                  ),
                  Expanded(
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: supabase.from('dorm_rooms').select('room_number').order('room_number'),
                      builder: (_, snap) {
                        if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: _primary));
                        final rooms = snap.data!.map((e) => e['room_number'].toString()).toList();
                        return SingleChildScrollView(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Wrap(
                            spacing: 8, runSpacing: 8,
                            children: rooms.map((room) {
                              final sel = selectedRoom == room;
                              return GestureDetector(
                                onTap: () => setS(() => selectedRoom = room),
                                child: _roomChip(room, sel),
                              );
                            }).toList(),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                        24, 12, 24, MediaQuery.of(ctx).padding.bottom + 24),
                    child: _submitBtn("입실 신청하기", _primary,
                        selectedRoom == null ? null : () async {
                          await supabase.from('dorm_applications').insert({
                            'user_id': supabase.auth.currentUser!.id,
                            'full_name': widget.userProfile['full_name'],
                            'type': 'IN',
                            'room_number': selectedRoom,
                            'status': 'PENDING',
                          });
                          if (ctx.mounted) Navigator.pop(ctx);
                          _loadData();
                        }),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openOutRequestDialog() {
    _closeFab();
    if (_myRoom == null || _hasActiveOutApplication) return;
    final roomNum = _myRoom!['room_number']?.toString() ?? '-';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _sheet(
        title: "퇴실 신청",
        icon: Icons.logout_rounded,
        iconColor: _red,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("퇴실할 호실",
                style: TextStyle(fontSize: 13, color: _sub, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            _roomChip(roomNum, true),
            const SizedBox(height: 6),
            Text("현재 배정된 호실만 퇴실 신청 가능합니다.",
                style: TextStyle(fontSize: 12, color: Colors.grey[400])),
            const SizedBox(height: 24),
            _submitBtn("퇴실 신청하기", _red, () async {
              await supabase.from('dorm_applications').insert({
                'user_id': supabase.auth.currentUser!.id,
                'full_name': widget.userProfile['full_name'],
                'type': 'OUT',
                'room_number': roomNum,
                'status': 'PENDING',
              });
              if (ctx.mounted) Navigator.pop(ctx);
              _loadData();
            }),
          ],
        ),
      ),
    );
  }

  Widget _sheet({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            ]),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }

  Widget _roomChip(String label, bool selected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? _primary : Colors.grey.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: selected ? _primary : Colors.grey.withOpacity(0.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.door_front_door_rounded, size: 14, color: selected ? Colors.white : Colors.grey),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
            color: selected ? Colors.white : Colors.black87)),
      ]),
    );
  }

  Widget _submitBtn(String label, Color color, VoidCallback? onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: onPressed == null ? Colors.grey[200] : color,
          foregroundColor: onPressed == null ? Colors.grey : Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
      ),
    );
  }

  Widget _buildFab() {
    final canIn  = _myRoom == null && !_hasActiveInApplication;
    final canOut = _myRoom != null && !_hasActiveOutApplication;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AnimatedBuilder(
          animation: _fabAnim,
          builder: (_, __) {
            final t = _fabAnim.value;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Transform.translate(
                  offset: Offset(0, 16 * (1 - t)),
                  child: Opacity(
                    opacity: t.clamp(0.0, 1.0),
                    child: _fabSubBtn(
                      label: _hasActiveInApplication ? "입실 대기중"
                           : _myRoom != null ? "이미 거주중" : "입실 신청",
                      icon: Icons.login_rounded,
                      color: canIn ? _primary : _sub,
                      onTap: canIn ? _openInRequestDialog : null,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Transform.translate(
                  offset: Offset(0, 16 * (1 - t)),
                  child: Opacity(
                    opacity: t.clamp(0.0, 1.0),
                    child: _fabSubBtn(
                      label: _hasActiveOutApplication ? "퇴실 대기중"
                           : _myRoom == null ? "배정 없음" : "퇴실 신청",
                      icon: Icons.logout_rounded,
                      color: canOut ? _red : _sub,
                      onTap: canOut ? _openOutRequestDialog : null,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],
            );
          },
        ),
        FloatingActionButton(
          onPressed: _toggleFab,
          backgroundColor: _primary,
          elevation: 6,
          child: AnimatedBuilder(
            animation: _fabAnim,
            builder: (_, __) => Transform.rotate(
              angle: _fabAnim.value * 0.785,
              child: Icon(
                _fabOpen ? Icons.close : Icons.edit_note_rounded,
                color: Colors.white, size: 26,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _fabSubBtn({
    required String label,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Text(label,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                    color: disabled ? _sub : color)),
          ),
          const SizedBox(width: 10),
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: disabled ? Colors.grey.withOpacity(0.15) : color.withOpacity(0.12),
              shape: BoxShape.circle,
              boxShadow: disabled ? [] : [BoxShadow(
                  color: color.withOpacity(0.2),
                  blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: Icon(icon, color: disabled ? _sub : color, size: 20),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _closeFab,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          title: const Text("나의 기숙사",
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
            IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadData),
          ],
        ),
        floatingActionButton: _isLoading ? null : _buildFab(),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: _primary))
            : RefreshIndicator(
                onRefresh: _loadData,
                color: _primary,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildRoomCard(),
                      const SizedBox(height: 28),
                      const Text("⌛ 최근 신청 현황",
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w900, color: _text)),
                      const SizedBox(height: 12),
                      if (_myApplications.isEmpty)
                        _emptyState()
                      else
                        ..._myApplications.map(_buildHistoryCard),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildRoomCard() {
    if (_myRoom == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: _sub.withOpacity(0.08), borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.hotel_rounded, color: _sub, size: 26),
          ),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("배정된 호실 없음",
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: _text)),
            const SizedBox(height: 3),
            Text("우측 하단 버튼으로 신청하세요",
                style: TextStyle(fontSize: 12, color: _sub)),
          ]),
        ]),
      );
    }

    // ✅ room_number 전체를 그대로 표시 ("구기숙사 203" 등)
    final roomNum = _myRoom!['room_number']?.toString() ?? '-';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E6BFF), Color(0xFF6A9FFF)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(
            color: _primary.withOpacity(0.3),
            blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("현재 거주 호실",
                style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            // ✅ room_number 전체 표시, "호" 제거
            Text(
              roomNum,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w900,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 13),
                SizedBox(width: 5),
                Text("입실 완료", style: TextStyle(
                    color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
            ),
          ]),
        ),
        Icon(Icons.meeting_room_rounded, color: Colors.white.withOpacity(0.2), size: 72),
      ]),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> app) {
    final status = app['status'] as String? ?? '';
    final isIn   = app['type'] == 'IN';

    String statusLabel; Color statusColor; IconData statusIcon;
    switch (status) {
      case 'APPROVED': statusLabel = "승인됨"; statusColor = const Color(0xFF0BC5A0); statusIcon = Icons.check_circle_rounded; break;
      case 'REJECTED': statusLabel = "반려됨"; statusColor = _red; statusIcon = Icons.cancel_rounded; break;
      default:         statusLabel = "대기 중"; statusColor = const Color(0xFFFF8C42); statusIcon = Icons.hourglass_top_rounded;
    }

    final typeColor = isIn ? _primary : _red;
    final dateStr = app['created_at'] != null
        ? DateFormat('yyyy.MM.dd HH:mm').format(DateTime.parse(app['created_at']).toLocal()) : '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: typeColor.withOpacity(0.08), borderRadius: BorderRadius.circular(13)),
          child: Icon(isIn ? Icons.login_rounded : Icons.logout_rounded, color: typeColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("${app['room_number']} ${isIn ? '입실' : '퇴실'} 신청",
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: _text)),
          const SizedBox(height: 3),
          Text(dateStr, style: const TextStyle(fontSize: 11, color: _sub)),
        ])),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(statusIcon, color: statusColor, size: 14),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Text(statusLabel, style: TextStyle(color: statusColor, fontWeight: FontWeight.w800, fontSize: 11)),
          ),
        ]),
      ]),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.inbox_rounded, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 10),
          Text("신청 이력이 없습니다.", style: TextStyle(color: Colors.grey[400], fontSize: 13)),
        ]),
      ),
    );
  }
}