part of 'cleaning_screen.dart';

// ══════════════════════════════════════════
// 식당 청소 탭
// ══════════════════════════════════════════

class _CleaningCafeteriaTab extends StatefulWidget {
  final _CleaningScreenState state;
  const _CleaningCafeteriaTab({required this.state});

  @override
  State<_CleaningCafeteriaTab> createState() => _CleaningCafeteriaTabState();
}

class _CleaningCafeteriaTabState extends State<_CleaningCafeteriaTab> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _cafeteriaRooms = [];
  bool _isLoading = true;

  static const _color = Color(0xFFE91E8C);

  @override
  void initState() {
    super.initState();
    _loadCafeteriaRooms();
  }

  Future<void> _loadCafeteriaRooms() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      // 식당 청소 담당 방 조회
      final rooms = await supabase
          .from('dorm_rooms')
          .select('id, room_number')
          .eq('is_cafeteria_cleaner', true)
          .order('room_number');

      // 각 방의 입주자 조회
      final roomIds =
          (rooms as List).map((r) => r['id'] as String).toList();

      List<Map<String, dynamic>> residents = [];
      if (roomIds.isNotEmpty) {
        residents = List<Map<String, dynamic>>.from(
          await supabase
              .from('dorm_residents')
              .select('room_id, resident_name')
              .inFilter('room_id', roomIds),
        );
      }

      // 방별 입주자 그룹핑
      final residentMap = <String, List<String>>{};
      for (final r in residents) {
        final rid = r['room_id'] as String? ?? '';
        if (rid.isEmpty) continue;
        residentMap
            .putIfAbsent(rid, () => [])
            .add(r['resident_name'] as String? ?? '-');
      }

      if (mounted) {
        setState(() {
          _cafeteriaRooms =
              List<Map<String, dynamic>>.from(rooms).map((room) {
            return {
              ...room,
              'residents': residentMap[room['id'] as String] ?? <String>[],
            };
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('식당 청소 로드 실패: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _removeCafeteria(String roomId) async {
    await supabase
        .from('dorm_rooms')
        .update({'is_cafeteria_cleaner': false})
        .eq('id', roomId);
    await _loadCafeteriaRooms();
    await widget.state._loadRotations(); // 베란다 순번 갱신
  }

  Future<void> _showAddSheet() async {
    // 현재 식당청소 아닌 방 목록 조회
    final rooms = await supabase
        .from('dorm_rooms')
        .select('id, room_number')
        .eq('is_cafeteria_cleaner', false)
        .order('room_number');

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: _color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.add_rounded,
                    color: _color, size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                context.tr(AppStrings.cleaningCafeteriaChange),
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w900),
              ),
            ]),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: (rooms as List).length,
              itemBuilder: (_, i) {
                final room = rooms[i] as Map<String, dynamic>;
                return ListTile(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  title: Text(room['room_number'] as String,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700)),
                  trailing: const Icon(Icons.add_rounded, color: _color),
                  onTap: () async {
                    await supabase
                        .from('dorm_rooms')
                        .update({'is_cafeteria_cleaner': true})
                        .eq('id', room['id']);
                    if (mounted) Navigator.pop(context);
                    await _loadCafeteriaRooms();
                    await widget.state._loadRotations();
                  },
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  void _showRemoveConfirm(String roomId, String roomNum) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('담당 해제',
            style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text(
          '$roomNum을(를) 식당 청소 담당에서 해제하시겠습니까?\n베란다 청소 순번에 다시 포함됩니다.',
          style: const TextStyle(fontSize: 14, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소',
                style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _removeCafeteria(roomId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('해제',
                style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadCafeteriaRooms,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── 안내 카드
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: _color.withOpacity(0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _color.withOpacity(0.2)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: _color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.restaurant_rounded,
                    color: _color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr(AppStrings.cleaningCafeteriaTitle),
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: _color),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        context.tr(AppStrings.cleaningCafeteriaDesc),
                        style: TextStyle(
                            fontSize: 12,
                            color: _color.withOpacity(0.7)),
                      ),
                    ]),
              ),
            ]),
          ),

          // ── 담당 방 목록
          if (_cafeteriaRooms.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 48),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.restaurant_outlined,
                    size: 52, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text(
                  context.tr(AppStrings.cleaningCafeteriaEmpty),
                  style:
                      TextStyle(color: Colors.grey[400], fontSize: 14),
                ),
              ]),
            )
          else
            ..._cafeteriaRooms.map((room) {
              final roomNum = room['room_number'] as String;
              final residents = room['residents'] as List<String>;
              final roomId = room['id'] as String;
              final roomOnly = roomNum.split(' ').last;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 3))
                  ],
                ),
                child: Row(children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                        color: _color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14)),
                    child: Center(
                      child: Text(
                        roomOnly,
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: _color,
                            fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            roomNum,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          if (residents.isEmpty)
                            Text(
                              context.tr(
                                  AppStrings.cleaningNoResidents),
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            )
                          else
                            Text(
                              residents.join(', '),
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.black54),
                            ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius:
                                    BorderRadius.circular(6)),
                            child: Text(
                              context.tr(
                                  AppStrings.cleaningCafeteriaExclude),
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.orange),
                            ),
                          ),
                        ]),
                  ),
                  // 관리자만 제거 버튼 표시
                  if (widget.state._isAdmin)
                    GestureDetector(
                      onTap: () =>
                          _showRemoveConfirm(roomId, roomNum),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.08),
                            borderRadius:
                                BorderRadius.circular(10)),
                        child: const Icon(
                            Icons.remove_circle_outline_rounded,
                            color: Colors.redAccent,
                            size: 20),
                      ),
                    ),
                ]),
              );
            }),

          // ── 관리자: 방 추가 버튼
          if (widget.state._isAdmin) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _showAddSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _color.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _color.withOpacity(0.25)),
                ),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_rounded, color: _color, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        context.tr(
                            AppStrings.cleaningCafeteriaChange),
                        style: TextStyle(
                            color: _color,
                            fontWeight: FontWeight.w800,
                            fontSize: 13),
                      ),
                    ]),
              ),
            ),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
