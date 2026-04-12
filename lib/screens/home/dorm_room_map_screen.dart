import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DormRoomMapScreen extends StatefulWidget {
  final bool isAdmin;
  const DormRoomMapScreen({Key? key, this.isAdmin = false}) : super(key: key);

  @override
  State<DormRoomMapScreen> createState() => _DormRoomMapScreenState();
}

class _DormRoomMapScreenState extends State<DormRoomMapScreen> {
  final supabase = Supabase.instance.client;

  bool _isLoading = true;
  Map<String, List<_RoomData>> _buildings = {};

  static const _primary = Color(0xFF2E6BFF);
  static const _teal    = Color(0xFF00BCD4);
  static const _tealDk  = Color(0xFF0097A7);
  static const _bg      = Color(0xFFF4F6FB);
  static const _text    = Color(0xFF1A1D2E);
  static const _sub     = Color(0xFF8A93B0);

  Color _lighten(Color c, double a) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + a).clamp(0.0, 1.0)).toColor();
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final rooms = await supabase
          .from('dorm_rooms')
          .select('id, room_number, max_capacity, current_occupancy')
          .order('room_number');

      final residents = await supabase
          .from('dorm_residents')
          .select('id, room_id, room_number, resident_name, user_id');

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

      final roomNumToId = <String, String>{};
      for (final room in rooms) {
        roomNumToId[room['room_number'] as String] = room['id'] as String;
      }

      final residentMap = <String, List<Map<String, dynamic>>>{};
      for (final r in residents) {
        String? rid = r['room_id'] as String?;
        if (rid == null) {
          final roomNum = r['room_number'] as String? ?? '';
          rid = roomNumToId[roomNum];
        }
        if (rid == null) continue;
        final userId = r['user_id'] as String?;
        residentMap.putIfAbsent(rid, () => []).add({
          'id':            r['id'] ?? '',
          'full_name':     r['resident_name'] ?? '-',
          'dept_category': userId != null ? (deptMap[userId] ?? '') : '',
          'user_id':       userId ?? '',
        });
      }

      final buildingMap = <String, List<_RoomData>>{};
      for (final room in rooms) {
        final roomNum   = room['room_number'] as String? ?? '';
        final roomId    = room['id']          as String? ?? '';
        final maxCap    = room['max_capacity']      as int? ?? 0;
        final occupancy = room['current_occupancy'] as int? ?? 0;
        final roomResidents = residentMap[roomId] ?? [];

        final parts    = roomNum.split(' ');
        final building = parts.length > 1
            ? parts.sublist(0, parts.length - 1).join(' ')
            : '기숙사';
        final roomOnly = parts.last;

        buildingMap.putIfAbsent(building, () => []).add(_RoomData(
          id: roomId, roomNumber: roomNum, roomOnly: roomOnly,
          maxCap: maxCap, occupancy: occupancy, residents: roomResidents,
        ));
      }

      if (!mounted) return;
      setState(() { _buildings = buildingMap; _isLoading = false; });
    } catch (e) {
      debugPrint('호실 배치도 로드 실패: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalRooms     = _buildings.values.fold(0, (s, r) => s + r.length);
    final totalResidents = _buildings.values
        .fold(0, (s, r) => s + r.fold(0, (s2, room) => s2 + room.occupancy));
    final totalCap       = _buildings.values
        .fold(0, (s, r) => s + r.fold(0, (s2, room) => s2 + room.maxCap));

    return Scaffold(
      backgroundColor: _bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── 그라디언트 SliverAppBar
          SliverAppBar(
            pinned: true,
            expandedHeight: 130,
            backgroundColor: _tealDk,
            foregroundColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: const Text('호실 배치도',
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
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF005A6A), _tealDk, _teal],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(children: [
                  Positioned(right: -40, top: -40, child: Container(
                    width: 160, height: 160,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.06)))),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 72, 20, 0),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle),
                        child: const Icon(Icons.grid_view_rounded,
                            color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Column(crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        const Text('호실 배치도',
                            style: TextStyle(color: Colors.white,
                                fontSize: 15, fontWeight: FontWeight.w900)),
                        if (!_isLoading)
                          Text(
                            '전체 $totalRooms호실 · 거주 $totalResidents명',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                      ]),
                    ]),
                  ),
                ]),
              ),
            ),
          ),

          // ── 바디
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(
                  child: CircularProgressIndicator(color: _teal)),
            )
          else
            SliverToBoxAdapter(
              child: RefreshIndicator(
                onRefresh: _loadData,
                color: _teal,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(14, 18, 14, 48),
                  child: Column(children: [
                    // 전체 요약 카드
                    _buildSummary(totalRooms, totalResidents, totalCap),
                    const SizedBox(height: 18),

                    // 범례
                    _buildLegend(),
                    const SizedBox(height: 20),

                    // 건물별
                    ..._buildings.entries.map((entry) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildingHeader(entry.key, entry.value),
                            const SizedBox(height: 12),
                            _buildRoomGrid(context, entry.value),
                            const SizedBox(height: 24),
                          ],
                        )),
                  ]),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── 전체 요약 카드
  Widget _buildSummary(int rooms, int residents, int cap) {
    final rate      = cap > 0 ? residents / cap : 0.0;
    final rateColor = rate > 0.9
        ? Colors.redAccent
        : rate > 0.6 ? Colors.orange : Colors.greenAccent;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF005A6A), _tealDk, _teal],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: _tealDk.withOpacity(0.28),
              blurRadius: 18, offset: const Offset(0, 7)),
          BoxShadow(color: Colors.black.withOpacity(0.05),
              blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Stack(children: [
        Positioned(right: -20, top: -20, child: Container(
            width: 100, height: 100,
            decoration: BoxDecoration(shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06)))),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _summaryItem('전체 호실', '$rooms', '개'),
              Container(width: 1, height: 40,
                  color: Colors.white.withOpacity(0.2)),
              _summaryItem('거주 인원', '$residents', '명'),
              Container(width: 1, height: 40,
                  color: Colors.white.withOpacity(0.2)),
              _summaryItem('빈 자리', '${cap - residents}', '석'),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Text('입실률  ${(rate * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.65),
                      fontSize: 11, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('$residents / $cap명',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.65),
                      fontSize: 11, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: rate.clamp(0.0, 1.0), minHeight: 7,
                backgroundColor: Colors.white.withOpacity(0.15),
                valueColor: AlwaysStoppedAnimation(rateColor),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _summaryItem(String label, String value, String unit) {
    return Column(children: [
      RichText(text: TextSpan(children: [
        TextSpan(text: value, style: const TextStyle(
            color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
        TextSpan(text: ' $unit', style: TextStyle(
            color: Colors.white.withOpacity(0.6), fontSize: 12)),
      ])),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(
          color: Colors.white.withOpacity(0.55),
          fontSize: 11, fontWeight: FontWeight.w600)),
    ]);
  }

  // ── 범례
  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(children: [
        const Icon(Icons.info_outline_rounded, size: 14, color: _sub),
        const SizedBox(width: 8),
        _legendItem(_roomColor(1, 1), '만실'),
        const SizedBox(width: 14),
        _legendItem(_roomColor(1, 2), '입실 중'),
        const SizedBox(width: 14),
        _legendItem(_roomColor(0, 2), '공실'),
      ]),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(children: [
      Container(
        width: 12, height: 12,
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [_lighten(color, 0.15), color],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(
          fontSize: 11, color: _sub, fontWeight: FontWeight.w600)),
    ]);
  }

  // ── 건물 헤더
  Widget _buildingHeader(String building, List<_RoomData> rooms) {
    final occupied   = rooms.where((r) => r.occupancy > 0).length;
    final total      = rooms.length;
    final totalRes   = rooms.fold(0, (s, r) => s + r.occupancy);
    final totalCap   = rooms.fold(0, (s, r) => s + r.maxCap);
    final rate       = totalCap > 0 ? totalRes / totalCap : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: _teal.withOpacity(0.08), blurRadius: 10,
              offset: const Offset(0, 3)),
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 5,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [_lighten(_tealDk, 0.15), _tealDk],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: _tealDk.withOpacity(0.25),
                blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: const Icon(Icons.apartment_rounded,
              color: Colors.white, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(building, style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w900, color: _text)),
          const SizedBox(height: 2),
          Text('$occupied / ${total}호실 입실',
              style: const TextStyle(fontSize: 11, color: _sub)),
        ])),
        // 입실률 미니 바
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${(rate * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w900,
                  color: rate > 0.9
                      ? Colors.redAccent
                      : rate > 0.6 ? Colors.orange : _teal)),
          const SizedBox(height: 5),
          SizedBox(
            width: 60,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: rate.clamp(0.0, 1.0), minHeight: 5,
                backgroundColor: Colors.black.withOpacity(0.06),
                valueColor: AlwaysStoppedAnimation(
                    rate > 0.9 ? Colors.redAccent
                        : rate > 0.6 ? Colors.orange : _teal),
              ),
            ),
          ),
        ]),
      ]),
    );
  }

  // ── 호실 그리드
  Widget _buildRoomGrid(BuildContext context, List<_RoomData> rooms) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.05,
      ),
      itemCount: rooms.length,
      itemBuilder: (_, i) => _roomCell(context, rooms[i]),
    );
  }

  Widget _roomCell(BuildContext context, _RoomData room) {
    final color   = _roomColor(room.occupancy, room.maxCap);
    final isEmpty = room.occupancy == 0;
    final isFull  = room.maxCap > 0 && room.occupancy >= room.maxCap;
    final lighter = _lighten(color, 0.18);

    return GestureDetector(
      onTap: () => _showRoomDetail(context, room),
      onLongPress: widget.isAdmin
          ? () => _showAdminSheet(context, room)
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: isEmpty ? Colors.white : color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isEmpty
                ? Colors.grey.withOpacity(0.18)
                : color.withOpacity(isFull ? 0.5 : 0.3),
            width: isFull ? 1.8 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
                color: isEmpty
                    ? Colors.black.withOpacity(0.04)
                    : color.withOpacity(0.10),
                blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
        child: Stack(children: [
          SizedBox.expand(
            child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
            // 호실 번호 (꽉 찬 경우 그라디언트 배지)
            isFull
                ? Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: [lighter, color],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [BoxShadow(
                          color: color.withOpacity(0.25),
                          blurRadius: 5, offset: const Offset(0, 2))],
                    ),
                    child: Text(room.roomOnly,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w900,
                            color: Colors.white)),
                  )
                : Text(room.roomOnly,
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w900,
                        color: isEmpty ? _sub : color)),
            const SizedBox(height: 4),
            // 인원
            Text('${room.occupancy}/${room.maxCap}명',
                style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w600,
                    color: isEmpty
                        ? _sub.withOpacity(0.5)
                        : color.withOpacity(0.8))),
            const SizedBox(height: 5),
            // 이니셜 or 공실
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
                  fontSize: 10, color: _sub.withOpacity(0.45))),
          ],
          ),  // Column
          ),  // SizedBox.expand
        // 어드민 편집 힌트
        if (widget.isAdmin)
          Positioned(
            top: 5, right: 5,
            child: Icon(Icons.edit_rounded,
                size: 10, color: color.withOpacity(0.35)),
          ),
        ]),
      ),
    );
  }

  // ── 어드민 관리 시트 (롱프레스)
  void _showAdminSheet(BuildContext context, _RoomData room) {
    final color   = _roomColor(room.occupancy, room.maxCap);
    final lighter = _lighten(color, 0.18);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Container(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.85),
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24)),
          child: Column(children: [
            // 그라디언트 헤더
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [lighter, color],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              child: Column(children: [
                Container(width: 36, height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.45),
                        borderRadius: BorderRadius.circular(2))),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.22),
                        shape: BoxShape.circle),
                    child: const Icon(Icons.meeting_room_rounded,
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(room.roomNumber,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w900,
                            color: Colors.white)),
                    Text('${room.occupancy}/${room.maxCap}명',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.75))),
                  ]),
                  const Spacer(),
                  // 거주자 추가 버튼
                  if (room.occupancy < room.maxCap)
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        _showAddResidentDialog(room);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.22),
                            borderRadius: BorderRadius.circular(10)),
                        child: const Row(
                            mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.person_add_rounded,
                              color: Colors.white, size: 14),
                          SizedBox(width: 5),
                          Text('추가', style: TextStyle(
                              color: Colors.white, fontSize: 12,
                              fontWeight: FontWeight.w800)),
                        ]),
                      ),
                    ),
                ]),
              ]),
            ),

            // 거주자 목록
            Expanded(
              child: room.residents.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                        Icon(Icons.bed_rounded, size: 40,
                            color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text('현재 거주자가 없습니다',
                            style: TextStyle(
                                color: Colors.grey[400], fontSize: 14,
                                fontWeight: FontWeight.w600)),
                      ]),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: room.residents.length,
                      separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: Colors.black.withOpacity(0.05)),
                      itemBuilder: (_, i) {
                        final r    = room.residents[i];
                        final name = r['full_name']     as String? ?? '-';
                        final dept = r['dept_category'] as String? ?? '';
                        final dc   = _deptColor(dept);
                        final dcL  = _lighten(dc, 0.18);

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(children: [
                            Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                    colors: [dcL, dc],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [BoxShadow(
                                    color: dc.withOpacity(0.22),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2))],
                              ),
                              child: Center(child: Text(
                                name.isNotEmpty ? name[0] : '?',
                                style: const TextStyle(fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white),
                              )),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(name, style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14, color: _text)),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                    color: dc.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6)),
                                child: Text(_deptLabel(dept),
                                    style: TextStyle(fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: dc)),
                              ),
                            ])),
                            // 이동 버튼
                            GestureDetector(
                              onTap: () {
                                Navigator.pop(ctx);
                                _showMoveResidentDialog(r, room);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(
                                    color: _primary.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(9),
                                    border: Border.all(
                                        color: _primary.withOpacity(0.2))),
                                child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                  Icon(Icons.swap_horiz_rounded,
                                      color: _primary, size: 14),
                                  SizedBox(width: 4),
                                  Text('이동', style: TextStyle(
                                      color: _primary, fontSize: 11,
                                      fontWeight: FontWeight.w800)),
                                ]),
                              ),
                            ),
                            // 퇴실 버튼
                            GestureDetector(
                              onTap: () {
                                Navigator.pop(ctx);
                                _removeResident(r, room);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                    color: Colors.redAccent.withOpacity(0.07),
                                    borderRadius: BorderRadius.circular(9),
                                    border: Border.all(
                                        color: Colors.redAccent
                                            .withOpacity(0.2))),
                                child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                  Icon(Icons.logout_rounded,
                                      color: Colors.redAccent, size: 14),
                                  SizedBox(width: 4),
                                  Text('퇴실', style: TextStyle(
                                      color: Colors.redAccent, fontSize: 11,
                                      fontWeight: FontWeight.w800)),
                                ]),
                              ),
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

  // ── 거주자 추가
  Future<void> _showAddResidentDialog(_RoomData room) async {
    final nameCtrl = TextEditingController();
    String? selectedUserId;

    // 이미 입주한 user_id 제외
    final existingIds = room.residents
        .map((r) => r['user_id']?.toString())
        .whereType<String>()
        .toSet();

    List<Map<String, dynamic>> profiles = [];
    try {
      final data = await supabase
          .from('profiles')
          .select('id, full_name, dept_category')
          .order('full_name');
      profiles = List<Map<String, dynamic>>.from(data)
          .where((p) => !existingIds.contains(p['id']?.toString()))
          .toList();
    } catch (_) {}

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: Text('${room.roomNumber} 거주자 추가',
              style: const TextStyle(fontWeight: FontWeight.w900,
                  fontSize: 16)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            if (profiles.isNotEmpty)
              DropdownButtonFormField<String>(
                value: selectedUserId,
                hint: const Text('앱 계정 선택 (선택사항)',
                    style: TextStyle(fontSize: 13)),
                isExpanded: true,
                items: profiles.map((p) {
                  final pName = p['full_name'] as String? ?? '-';
                  final pDept = _deptLabel(p['dept_category'] as String? ?? '');
                  return DropdownMenuItem(
                    value: p['id'] as String,
                    child: Text('$pName  ·  $pDept',
                        style: const TextStyle(fontSize: 13)),
                  );
                }).toList(),
                onChanged: (v) {
                  setS(() {
                    selectedUserId = v;
                    final p = profiles.firstWhere((p) => p['id'] == v);
                    nameCtrl.text = p['full_name'] as String? ?? '';
                  });
                },
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: '이름',
                hintText: '직접 입력 (앱 계정 없는 경우)',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
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
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                try {
                  await supabase.from('dorm_residents').insert({
                    'room_id':       room.id,
                    'room_number':   room.roomNumber,
                    'resident_name': name,
                    if (selectedUserId != null) 'user_id': selectedUserId,
                    'entry_date':    DateTime.now()
                        .toIso8601String().substring(0, 10),
                    'deposit_amount': '0',
                    'agreed_to_rules': 'false',
                  });
                  await supabase.from('dorm_rooms')
                      .update({'current_occupancy': room.occupancy + 1})
                      .eq('id', room.id);
                  Navigator.pop(ctx);
                  _snack('$name 추가 완료 ✅');
                  _loadData();
                } catch (e) {
                  _snack('추가 실패: $e');
                }
              },
              child: const Text('추가'),
            ),
          ],
        ),
      ),
    );
  }

  // ── 거주자 호실 이동
  Future<void> _showMoveResidentDialog(
      Map<String, dynamic> resident, _RoomData fromRoom) async {
    final name = resident['full_name'] as String? ?? '-';

    // 모든 호실 로드 (현재 호실 제외, 빈 자리 있는 것)
    List<_RoomData> availableRooms = [];
    for (final building in _buildings.values) {
      for (final r in building) {
        if (r.id != fromRoom.id && r.occupancy < r.maxCap) {
          availableRooms.add(r);
        }
      }
    }
    availableRooms.sort((a, b) => a.roomNumber.compareTo(b.roomNumber));

    if (!mounted) return;

    _RoomData? selectedRoom;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            const Icon(Icons.swap_horiz_rounded,
                color: _primary, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text('$name 호실 이동',
                style: const TextStyle(fontWeight: FontWeight.w900,
                    fontSize: 16))),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            // 현재 호실
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: const Color(0xFFF4F6FB),
                  borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const Icon(Icons.meeting_room_rounded,
                    color: _sub, size: 16),
                const SizedBox(width: 8),
                Text('현재: ${fromRoom.roomNumber}',
                    style: const TextStyle(
                        fontSize: 13, color: _sub,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
            const SizedBox(height: 6),
            const Icon(Icons.keyboard_arrow_down_rounded,
                color: _sub),
            const SizedBox(height: 6),
            // 이동할 호실 드롭다운
            if (availableRooms.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12)),
                child: const Row(children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.redAccent, size: 16),
                  SizedBox(width: 8),
                  Text('이동 가능한 호실이 없습니다',
                      style: TextStyle(fontSize: 13,
                          color: Colors.redAccent)),
                ]),
              )
            else
              DropdownButtonFormField<_RoomData>(
                value: selectedRoom,
                hint: const Text('이동할 호실 선택',
                    style: TextStyle(fontSize: 13)),
                isExpanded: true,
                items: availableRooms.map((r) {
                  final avail = r.maxCap - r.occupancy;
                  return DropdownMenuItem(
                    value: r,
                    child: Text(
                      '${r.roomNumber}  (빈자리 $avail석)',
                      style: const TextStyle(fontSize: 13),
                    ),
                  );
                }).toList(),
                onChanged: (v) => setS(() => selectedRoom = v),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                ),
              ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('취소')),
            if (availableRooms.isNotEmpty)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                onPressed: selectedRoom == null
                    ? null
                    : () async {
                        final toRoom = selectedRoom!;
                        try {
                          final residentId = resident['id'] as String? ?? '';
                          // 입주자 room_id 업데이트
                          await supabase
                              .from('dorm_residents')
                              .update({
                            'room_id':     toRoom.id,
                            'room_number': toRoom.roomNumber,
                          }).eq('id', residentId);
                          // 이전 호실 -1
                          await supabase.from('dorm_rooms')
                              .update({'current_occupancy':
                                  (fromRoom.occupancy - 1).clamp(0, 999)})
                              .eq('id', fromRoom.id);
                          // 새 호실 +1
                          await supabase.from('dorm_rooms')
                              .update({'current_occupancy':
                                  toRoom.occupancy + 1})
                              .eq('id', toRoom.id);
                          Navigator.pop(ctx);
                          _snack(
                              '$name → ${toRoom.roomNumber} 이동 완료 ✅');
                          _loadData();
                        } catch (e) {
                          _snack('이동 실패: $e');
                        }
                      },
                child: const Text('이동'),
              ),
          ],
        ),
      ),
    );
  }

  // ── 거주자 퇴실
  Future<void> _removeResident(
      Map<String, dynamic> resident, _RoomData room) async {
    final name = resident['full_name'] as String? ?? '-';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
          SizedBox(width: 8),
          Text('퇴실 처리',
              style: TextStyle(fontWeight: FontWeight.w900)),
        ]),
        content: Text('$name 거주자를\n퇴실 처리하시겠습니까?',
            style: const TextStyle(fontSize: 14, height: 1.6)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('퇴실'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final residentId = resident['id'] as String? ?? '';
      await supabase.from('dorm_residents')
          .delete().eq('id', residentId);
      await supabase.from('dorm_rooms')
          .update({'current_occupancy': (room.occupancy - 1).clamp(0, 999)})
          .eq('id', room.id);
      _snack('$name 퇴실 처리 완료');
      _loadData();
    } catch (e) {
      _snack('퇴실 처리 실패: $e');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF1A1D2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ));
  }

  // ── 호실 상세 바텀시트
  void _showRoomDetail(BuildContext context, _RoomData room) {
    final color   = _roomColor(room.occupancy, room.maxCap);
    final lighter = _lighten(color, 0.18);
    final isEmpty = room.occupancy == 0;
    final isFull  = room.maxCap > 0 && room.occupancy >= room.maxCap;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(24)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // 그라디언트 헤더
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [lighter, color],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Stack(children: [
              Positioned(right: -20, top: -20, child: Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.08)))),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                child: Column(children: [
                  Container(width: 36, height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.45),
                          borderRadius: BorderRadius.circular(2))),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.22),
                          shape: BoxShape.circle),
                      child: const Icon(Icons.meeting_room_rounded,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(room.roomNumber,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w900,
                              color: Colors.white)),
                      Text('${room.occupancy}/${room.maxCap}명 입실',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.75))),
                    ]),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.22),
                          borderRadius: BorderRadius.circular(10)),
                      child: Text(
                        isEmpty ? '공실' : isFull ? '만실' : '입실 중',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w900,
                            color: Colors.white),
                      ),
                    ),
                  ]),
                  // 진행 바
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: LinearProgressIndicator(
                      value: room.maxCap > 0
                          ? (room.occupancy / room.maxCap).clamp(0.0, 1.0)
                          : 0.0,
                      minHeight: 6,
                      backgroundColor: Colors.white.withOpacity(0.25),
                      valueColor:
                          const AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                ]),
              ),
            ]),
          ),

          // 입주자 목록
          if (room.residents.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _bg, shape: BoxShape.circle,
                    boxShadow: [BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10, offset: const Offset(0, 3))],
                  ),
                  child: Icon(Icons.bed_rounded, size: 32,
                      color: Colors.grey[300]),
                ),
                const SizedBox(height: 12),
                Text('현재 거주자가 없습니다',
                    style: TextStyle(
                        color: Colors.grey[400], fontSize: 14,
                        fontWeight: FontWeight.w600)),
              ]),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
              itemCount: room.residents.length,
              separatorBuilder: (_, __) => Divider(
                  height: 1, color: Colors.black.withOpacity(0.05)),
              itemBuilder: (_, i) {
                final r    = room.residents[i];
                final name = r['full_name']     as String? ?? '-';
                final dept = r['dept_category'] as String? ?? '';
                final dc   = _deptColor(dept);
                final dcLighter = _lighten(dc, 0.18);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  child: Row(children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                            colors: [dcLighter, dc],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(
                            color: dc.withOpacity(0.25), blurRadius: 7,
                            offset: const Offset(0, 3))],
                      ),
                      child: Center(child: Text(
                        name.isNotEmpty ? name[0] : '?',
                        style: const TextStyle(fontSize: 16,
                            fontWeight: FontWeight.w900, color: Colors.white),
                      )),
                    ),
                    const SizedBox(width: 13),
                    Column(crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(name, style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800,
                          color: _text)),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: dc.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6)),
                        child: Text(_deptLabel(dept), style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700,
                            color: dc)),
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
    if (occupancy == 0) return Colors.grey;
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
      'SALES':      '영업부',   'RND':        '연구소',
      'STEEL':      '스틸생산부','BOX':        '박스생산부',
      'DELIVERY':   '포장납품부','SSG':        '에스에스지',
      'CLEANING':   '환경미화', 'NUTRITION':  '영양사',
    };
    return m[dept] ?? dept;
  }
}

class _RoomData {
  final String id, roomNumber, roomOnly;
  final int maxCap, occupancy;
  final List<Map<String, dynamic>> residents;

  const _RoomData({
    required this.id, required this.roomNumber, required this.roomOnly,
    required this.maxCap, required this.occupancy, required this.residents,
  });
}