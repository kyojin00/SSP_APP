import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DormRoomMapScreen extends StatefulWidget {
  const DormRoomMapScreen({Key? key}) : super(key: key);

  @override
  State<DormRoomMapScreen> createState() => _DormRoomMapScreenState();
}

class _DormRoomMapScreenState extends State<DormRoomMapScreen> {
  final supabase = Supabase.instance.client;

  bool _isLoading = true;
  // 건물별 그룹: { '구기숙사': [ {room, residents} ] }
  Map<String, List<_RoomData>> _buildings = {};

  static const _primary = Color(0xFF2E6BFF);
  static const _bg      = Color(0xFFF4F6FB);
  static const _text    = Color(0xFF1A1D2E);
  static const _sub     = Color(0xFF8A93B0);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      // 호실 목록
      final rooms = await supabase
          .from('dorm_rooms')
          .select('id, room_number, max_capacity, current_occupancy')
          .order('room_number');

      // 입주자 목록 (resident_name 직접 사용, room_number로 매칭)
      final residents = await supabase
          .from('dorm_residents')
          .select('room_id, room_number, resident_name, user_id');

      // profiles에서 dept_category 가져오기 (user_id 있는 경우)
      final userIds = residents
          .where((r) => r['user_id'] != null)
          .map((r) => r['user_id'] as String)
          .toList();

      final deptMap = <String, String>{};
      if (userIds.isNotEmpty) {
        final profiles = await supabase
            .from('profiles')
            .select('id, dept_category')
            .inFilter('id', userIds);
        for (final p in profiles) {
          deptMap[p['id'] as String] = p['dept_category'] as String? ?? '';
        }
      }

      // room_id → 입주자 리스트 (room_id 없으면 room_number로 매칭)
      // 먼저 room_number → room_id 맵 생성
      final roomNumToId = <String, String>{};
      for (final room in rooms) {
        roomNumToId[room['room_number'] as String] =
            room['id'] as String;
      }

      final residentMap = <String, List<Map<String, dynamic>>>{};
      for (final r in residents) {
        // room_id 우선, 없으면 room_number로 찾기
        String? rid = r['room_id'] as String?;
        if (rid == null) {
          final roomNum = r['room_number'] as String? ?? '';
          rid = roomNumToId[roomNum];
        }
        if (rid == null) continue;

        final userId = r['user_id'] as String?;
        residentMap.putIfAbsent(rid, () => []).add({
          'full_name':     r['resident_name'] ?? '-',
          'dept_category': userId != null ? (deptMap[userId] ?? '') : '',
        });
      }

      // 건물별 그룹핑 (room_number 앞부분으로 구분 e.g. "구기숙사 203" → "구기숙사")
      final buildingMap = <String, List<_RoomData>>{};
      for (final room in rooms) {
        final roomNum  = room['room_number'] as String? ?? '';
        final roomId   = room['id']          as String? ?? '';
        final maxCap   = room['max_capacity']      as int? ?? 0;
        final occupancy = room['current_occupancy'] as int? ?? 0;
        final roomResidents = residentMap[roomId] ?? [];

        // 건물명: 마지막 공백+숫자 이전 부분
        final parts   = roomNum.split(' ');
        final building = parts.length > 1 ? parts.sublist(0, parts.length - 1).join(' ') : '기숙사';
        final roomOnly = parts.last;

        buildingMap.putIfAbsent(building, () => []).add(_RoomData(
          id:         roomId,
          roomNumber: roomNum,
          roomOnly:   roomOnly,
          maxCap:     maxCap,
          occupancy:  occupancy,
          residents:  roomResidents,
        ));
      }

      if (!mounted) return;
      setState(() {
        _buildings  = buildingMap;
        _isLoading  = false;
      });
    } catch (e) {
      debugPrint('호실 배치도 로드 실패: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalRooms     = _buildings.values.fold(0, (s, r) => s + r.length);
    final totalResidents = _buildings.values.fold(0,
        (s, r) => s + r.fold(0, (s2, room) => s2 + room.occupancy));
    final totalCap       = _buildings.values.fold(0,
        (s, r) => s + r.fold(0, (s2, room) => s2 + room.maxCap));

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('호실 배치도',
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
          : RefreshIndicator(
              onRefresh: _loadData,
              color: _primary,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                children: [
                  // 전체 요약
                  _buildSummary(totalRooms, totalResidents, totalCap),
                  const SizedBox(height: 24),

                  // 범례
                  _buildLegend(),
                  const SizedBox(height: 20),

                  // 건물별 그리드
                  ..._buildings.entries.map((entry) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildingHeader(entry.key, entry.value),
                      const SizedBox(height: 12),
                      _buildRoomGrid(context, entry.value),
                      const SizedBox(height: 24),
                    ],
                  )),
                ],
              ),
            ),
    );
  }

  Widget _buildSummary(int rooms, int residents, int cap) {
    final rate = cap > 0 ? residents / cap : 0.0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E6BFF), Color(0xFF6A9FFF)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
            color: _primary.withOpacity(0.3),
            blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _summaryItem('전체 호실', '$rooms개', Colors.white),
          Container(width: 1, height: 36,
              color: Colors.white.withOpacity(0.2)),
          _summaryItem('거주 인원', '$residents명', Colors.white),
          Container(width: 1, height: 36,
              color: Colors.white.withOpacity(0.2)),
          _summaryItem('빈 자리', '${cap - residents}석', Colors.white),
        ]),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('입실률  ${(rate * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 11, fontWeight: FontWeight.w600)),
            Text('$residents / $cap명',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: rate.clamp(0.0, 1.0), minHeight: 5,
            backgroundColor: Colors.white.withOpacity(0.2),
            valueColor: const AlwaysStoppedAnimation(Colors.white),
          ),
        ),
      ]),
    );
  }

  Widget _summaryItem(String label, String value, Color color) {
    return Column(children: [
      Text(value, style: TextStyle(
          fontSize: 22, fontWeight: FontWeight.w900, color: color)),
      const SizedBox(height: 3),
      Text(label, style: TextStyle(
          fontSize: 11, color: color.withOpacity(0.7),
          fontWeight: FontWeight.w600)),
    ]);
  }

  Widget _buildLegend() {
    return Row(children: [
      _legendItem(_roomColor(1, 1), '만실'),
      const SizedBox(width: 12),
      _legendItem(_roomColor(1, 2), '일부 입실'),
      const SizedBox(width: 12),
      _legendItem(_roomColor(0, 2), '공실'),
    ]);
  }

  Widget _legendItem(Color color, String label) {
    return Row(children: [
      Container(width: 14, height: 14,
          decoration: BoxDecoration(color: color,
              borderRadius: BorderRadius.circular(4))),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(fontSize: 11, color: _sub,
          fontWeight: FontWeight.w600)),
    ]);
  }

  Widget _buildingHeader(String building, List<_RoomData> rooms) {
    final occupied = rooms.where((r) => r.occupancy > 0).length;
    final total    = rooms.length;
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: _primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10)),
        child: const Icon(Icons.apartment_rounded, color: _primary, size: 18),
      ),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(building, style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w900, color: _text)),
        Text('$occupied / $total호실 입실',
            style: TextStyle(fontSize: 11, color: _sub)),
      ]),
    ]);
  }

  Widget _buildRoomGrid(BuildContext context, List<_RoomData> rooms) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.1,
      ),
      itemCount: rooms.length,
      itemBuilder: (_, i) => _roomCell(context, rooms[i]),
    );
  }

  Widget _roomCell(BuildContext context, _RoomData room) {
    final color    = _roomColor(room.occupancy, room.maxCap);
    final isEmpty  = room.occupancy == 0;
    final isFull   = room.maxCap > 0 && room.occupancy >= room.maxCap;

    return GestureDetector(
      onTap: () => _showRoomDetail(context, room),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: isEmpty ? Colors.white : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isEmpty ? Colors.grey.withOpacity(0.2) : color.withOpacity(0.4),
            width: isFull ? 1.5 : 1,
          ),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 호실 번호
            Text(room.roomOnly,
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w900,
                    color: isEmpty ? _sub : color)),
            const SizedBox(height: 4),
            // 인원 표시
            Text('${room.occupancy}/${room.maxCap}명',
                style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w600,
                    color: isEmpty ? _sub.withOpacity(0.5) : color.withOpacity(0.8))),
            const SizedBox(height: 6),
            // 입주자 이니셜 (최대 3명)
            if (room.residents.isNotEmpty)
              Wrap(
                spacing: 2,
                children: room.residents.take(3).map((r) {
                  final name = r['full_name'] as String? ?? '?';
                  return CircleAvatar(
                    radius: 9,
                    backgroundColor: color.withOpacity(0.15),
                    child: Text(
                      name.isNotEmpty ? name[0] : '?',
                      style: TextStyle(fontSize: 9,
                          fontWeight: FontWeight.w900, color: color),
                    ),
                  );
                }).toList(),
              )
            else
              Text('공실', style: TextStyle(
                  fontSize: 10, color: _sub.withOpacity(0.5))),
          ],
        ),
      ),
    );
  }

  void _showRoomDetail(BuildContext context, _RoomData room) {
    final color = _roomColor(room.occupancy, room.maxCap);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(24)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2))),
          // 헤더
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.meeting_room_rounded, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(room.roomNumber, style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w900, color: _text)),
                Text('${room.occupancy}/${room.maxCap}명 입실',
                    style: TextStyle(fontSize: 12, color: _sub)),
              ]),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: Text(
                  room.occupancy == 0 ? '공실'
                      : room.occupancy >= room.maxCap ? '만실' : '입실 중',
                  style: TextStyle(fontSize: 13,
                      fontWeight: FontWeight.w800, color: color),
                ),
              ),
            ]),
          ),
          const Divider(height: 1),
          // 입주자 목록
          if (room.residents.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(children: [
                Icon(Icons.bed_rounded, size: 40, color: Colors.grey[300]),
                const SizedBox(height: 10),
                Text('현재 거주자가 없습니다',
                    style: TextStyle(color: Colors.grey[400], fontSize: 14)),
              ]),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              itemCount: room.residents.length,
              separatorBuilder: (_, __) => Divider(height: 1,
                  color: Colors.black.withOpacity(0.05)),
              itemBuilder: (_, i) {
                final r    = room.residents[i];
                final name = r['full_name']     as String? ?? '-';
                final dept = r['dept_category'] as String? ?? '';
                final dc   = _deptColor(dept);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: dc.withOpacity(0.1),
                      child: Text(name.isNotEmpty ? name[0] : '?',
                          style: TextStyle(fontSize: 16,
                              fontWeight: FontWeight.w900, color: dc)),
                    ),
                    const SizedBox(width: 14),
                    Column(crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(name, style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800,
                          color: _text)),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: dc.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6)),
                        child: Text(_deptLabel(dept),
                            style: TextStyle(fontSize: 11,
                                fontWeight: FontWeight.w700, color: dc)),
                      ),
                    ]),
                  ]),
                );
              },
            ),
        ]),
      ),
    );
  }

  Color _roomColor(int occupancy, int maxCap) {
    if (occupancy == 0)             return Colors.grey;
    if (maxCap > 0 && occupancy >= maxCap) return const Color(0xFFFF4D64);
    return const Color(0xFF2E6BFF);
  }

  Color _deptColor(String dept) {
    const m = {
      'MANAGEMENT': Color(0xFF2E6BFF), 'PRODUCTION': Color(0xFFFF7A2F),
      'SALES':      Color(0xFF7C5CDB), 'RND':        Color(0xFF00BCD4),
      'STEEL':      Color(0xFFE91E8C), 'BOX':        Color(0xFF4CAF50),
      'DELIVERY':   Color(0xFFFF5722), 'SSG':        Color(0xFF607D8B),
      'CLEANING':   Color(0xFFFFC107), 'NUTRITION':  Color(0xFF9C27B0),
    };
    return m[dept] ?? const Color(0xFF2E6BFF);
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
}

class _RoomData {
  final String id;
  final String roomNumber;
  final String roomOnly;
  final int maxCap;
  final int occupancy;
  final List<Map<String, dynamic>> residents;

  const _RoomData({
    required this.id,
    required this.roomNumber,
    required this.roomOnly,
    required this.maxCap,
    required this.occupancy,
    required this.residents,
  });
}