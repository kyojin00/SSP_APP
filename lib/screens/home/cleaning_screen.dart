import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'app_strings.dart';
import 'lang_context.dart';

part 'cleaning_this_week_tab.dart';
part 'cleaning_rotation_tab.dart';
part 'cleaning_history_tab.dart';
part 'cleaning_residents_sheet.dart';
part 'cleaning_cafeteria_tab.dart';

class CleaningScreen extends StatefulWidget {
  final Map<String, dynamic> userProfile;
  const CleaningScreen({Key? key, required this.userProfile}) : super(key: key);

  @override
  State<CleaningScreen> createState() => _CleaningScreenState();
}

class _CleaningScreenState extends State<CleaningScreen>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  late TabController _tabController;

  bool get _isAdmin => widget.userProfile['role'] == 'ADMIN';

  // ── 이번 주 스케줄 (cleaning_records 포함)
  List<Map<String, dynamic>> _schedules = [];
  Map<String, dynamic?> _records = {};
  bool _isLoading = true;

  // ── 참여 방 목록 (cafeteria 제외 + 빈 방 제외)
  List<Map<String, dynamic>> _rotations2 = [];
  List<Map<String, dynamic>> _rotations3 = [];

  // ── 전체 배정 이력 (사이클 계산용, week_start ASC + order_index ASC)
  List<Map<String, dynamic>> _allHistory2 = [];
  List<Map<String, dynamic>> _allHistory3 = [];

  // ── 방별 거주자 이름 (room_label → names)
  Map<String, List<String>> _residentNames = {};

  String get _thisMonday {
    final now    = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return DateFormat('yyyy-MM-dd').format(monday);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _isAdmin ? 4 : 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      await Future.wait([_loadRotations(), _loadAllHistory()]);
      await _checkAndAutoAssign();
      await _loadSchedules();
      await _loadResidentNames();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ════════════════════════════════════════
  // 데이터 로드
  // ════════════════════════════════════════

  Future<void> _loadSchedules() async {
    final data = await supabase
        .from('cleaning_schedule')
        .select('*, cleaning_records(*)')
        .eq('week_start', _thisMonday)
        .order('floor')
        .order('order_index');

    if (!mounted) return;
    final schedules = List<Map<String, dynamic>>.from(data);
    final recordMap = <String, dynamic?>{};
    for (final s in schedules) {
      final recs = s['cleaning_records'] as List?;
      recordMap[s['id']] =
          (recs != null && recs.isNotEmpty) ? recs.first : null;
    }
    if (mounted) setState(() { _schedules = schedules; _records = recordMap; });
  }

  Future<void> _loadRotations() async {
    // ① cafeteria 제외
    final cafeteriaRooms = await supabase
        .from('dorm_rooms')
        .select('room_number')
        .eq('is_cafeteria_cleaner', true);
    final cafeteriaLabels = (cafeteriaRooms as List)
        .map((r) => r['room_number'] as String)
        .toSet();

    // ② 입주자 있는 방 (빈 방 제외)
    final residentsData = await supabase
        .from('dorm_residents')
        .select('room_number');
    final occupiedRooms = (residentsData as List)
        .map((r) => r['room_number'] as String? ?? '')
        .toSet();

    // ③ rotation 목록
    final data = await supabase
        .from('cleaning_rotation')
        .select()
        .eq('active', true)
        .order('floor')
        .order('order_index');

    // "신기숙사 201 / 신기숙사 207" 같은 병합 슬롯 처리
    // 구성 방 중 하나라도 입주자 있으면 포함
    bool hasResidents(String label) {
      if (label.contains(' / ')) {
        return label.split(' / ').any((r) => occupiedRooms.contains(r.trim()));
      }
      return occupiedRooms.contains(label);
    }

    final all = List<Map<String, dynamic>>.from(data);
    if (mounted) {
      setState(() {
        _rotations2 = all.where((r) =>
            r['floor'] == 2 &&
            !cafeteriaLabels.contains(r['room_label']) &&
            hasResidents(r['room_label'] as String)).toList();
        _rotations3 = all.where((r) =>
            r['floor'] == 3 &&
            !cafeteriaLabels.contains(r['room_label']) &&
            hasResidents(r['room_label'] as String)).toList();
      });
    }
  }

  // ── 이번 주 배정된 방의 거주자 이름 로드
  Future<void> _loadResidentNames() async {
    if (_schedules.isEmpty) return;
    try {
      // inFilter 매칭 이슈 방지 → 전체 로드 후 클라이언트 매칭
      final data = await supabase
          .from('dorm_residents')
          .select('room_number, resident_name');

      // room_number → 이름 목록 (trim 처리)
      final byRoom = <String, List<String>>{};
      for (final r in data as List) {
        final num  = (r['room_number']    as String?)?.trim() ?? '';
        final name = (r['resident_name'] as String?)?.trim() ?? '';
        if (num.isNotEmpty && name.isNotEmpty) {
          byRoom.putIfAbsent(num, () => []).add(name);
        }
      }

      // room_label → 이름 목록 (병합 슬롯 합산)
      final labelSet = _schedules.map((s) => s['room_label'] as String).toSet();
      final result   = <String, List<String>>{};
      for (final label in labelSet) {
        final trimmed = label.trim();
        if (trimmed.contains(' / ')) {
          final names = <String>[];
          for (final part in trimmed.split(' / ').map((r) => r.trim())) {
            names.addAll(byRoom[part] ?? []);
          }
          result[label] = names;
        } else {
          result[label] = byRoom[trimmed] ?? [];
        }
      }

      if (mounted) setState(() => _residentNames = result);
    } catch (e) {
      debugPrint('거주자 이름 로드 실패: $e');
    }
  }

  Future<void> _loadAllHistory() async {
    final data = await supabase
        .from('cleaning_schedule')
        .select('id, floor, room_label, week_start, order_index')
        .order('week_start', ascending: true)
        .order('order_index', ascending: true);

    final all = List<Map<String, dynamic>>.from(data);
    if (mounted) {
      setState(() {
        _allHistory2 = all.where((s) => s['floor'] == 2).toList();
        _allHistory3 = all.where((s) => s['floor'] == 3).toList();
      });
    }
  }

  // ════════════════════════════════════════
  // 사이클 계산 헬퍼
  // ════════════════════════════════════════

  ({int cycleNumber, int progress, int total, bool isAutoMode})
      _getCycleInfo(int floor) {
    final rotations = floor == 2 ? _rotations2 : _rotations3;
    final history   = floor == 2 ? _allHistory2 : _allHistory3;
    final total = rotations.length;
    if (total == 0) return (cycleNumber:1, progress:0, total:0, isAutoMode:false);
    final progress    = history.length % total;
    final cycleNumber = (history.length ~/ total) + 1;
    final isAutoMode  = history.length >= total;
    return (cycleNumber:cycleNumber, progress:progress, total:total, isAutoMode:isAutoMode);
  }

  /// 현재 사이클에서 아직 배정 안 된 방
  List<Map<String, dynamic>> _getRemainingRooms(int floor) {
    final rotations = floor == 2 ? _rotations2 : _rotations3;
    final history   = floor == 2 ? _allHistory2 : _allHistory3;
    if (rotations.isEmpty) return [];
    final total      = rotations.length;
    final cycleStart = (history.length ~/ total) * total;
    final assigned   = history.skip(cycleStart).map((s) => s['room_label'] as String).toSet();
    return rotations.where((r) => !assigned.contains(r['room_label'])).toList();
  }

  // ════════════════════════════════════════
  // 자동 배정 (2사이클 이상, 2개씩)
  // ════════════════════════════════════════

  Future<void> _checkAndAutoAssign() async {
    bool didAssign = false;

    for (final floor in [2, 3]) {
      final rotations = floor == 2 ? _rotations2 : _rotations3;
      var   history   = floor == 2 ? _allHistory2 : _allHistory3;
      if (rotations.isEmpty) continue;
      final total = rotations.length;
      if (history.length < total) continue; // 첫 사이클 미완료
      if (history.any((s) => s['week_start'] == _thisMonday)) continue; // 이미 배정

      final pos1 = history.length % total;
      final pos2 = (history.length + 1) % total; // 항상 wrap (홀수 방도 2개 보장)

      final label1 = history[pos1]['room_label'] as String;
      final label2 = history[pos2]['room_label'] as String;
      final room1  = rotations.firstWhere((r) => r['room_label'] == label1,
          orElse: () => rotations.first);
      final room2  = rotations.firstWhere((r) => r['room_label'] == label2,
          orElse: () => rotations.last);

      await _assignRoom(floor, room1, history.length,     silent: true);
      await _assignRoom(floor, room2, history.length + 1, silent: true);

      didAssign = true;

      // 이력 갱신
      final newData = await supabase
          .from('cleaning_schedule')
          .select('id, floor, room_label, week_start, order_index')
          .eq('floor', floor)
          .order('week_start', ascending: true)
          .order('order_index', ascending: true);
      history = List<Map<String, dynamic>>.from(newData);
      if (mounted) {
        setState(() {
          if (floor == 2) _allHistory2 = history;
          else            _allHistory3 = history;
        });
      }
    }

    if (didAssign) await _loadAllHistory();
  }

  // ════════════════════════════════════════
  // 방 배정 (DB insert)
  // ════════════════════════════════════════

  Future<void> _assignRoom(
    int floor,
    Map<String, dynamic> rotation,
    int orderIndex, {
    bool silent = false,
  }) async {
    await supabase.from('cleaning_schedule').insert({
      'week_start':    _thisMonday,
      'assigned_date': DateFormat('yyyy-MM-dd')
          .format(DateTime.parse(_thisMonday).add(const Duration(days: 6))),
      'rotation_id':   rotation['id'],
      'floor':         floor,
      'room_label':    rotation['room_label'],
      'room_number':   rotation['room_label'],
      'order_index':   orderIndex,
    });
    if (!silent && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${rotation['room_label']} 배정 완료 ✅'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  // ════════════════════════════════════════
  // 이번 주 선택 풀 (항상 2개 목표, 부족하면 다음 순번 포함)
  // ════════════════════════════════════════

  List<Map<String, dynamic>> _getSelectionPool(int floor) {
    final remaining = _getRemainingRooms(floor);
    if (remaining.length >= 2) return remaining;

    // 1개 이하 남음 → 다음 사이클 방을 추가해서 2개 맞춤
    final rotations = floor == 2 ? _rotations2 : _rotations3;
    final history   = floor == 2 ? _allHistory2 : _allHistory3;
    if (rotations.isEmpty) return remaining;

    final result = remaining
        .map((r) => Map<String, dynamic>.from(r)..['_isNextCycle'] = false)
        .toList();

    // 첫 사이클 순서대로 (혹은 rotation 순서대로) 다음 방 추가
    final assignedLabels = result.map((r) => r['room_label'] as String).toSet();
    final orderedSource  = history.isNotEmpty ? history : rotations;

    for (final src in orderedSource) {
      if (result.length >= 2) break;
      final label = src['room_label'] as String;
      if (assignedLabels.contains(label)) continue;
      final rot = rotations.firstWhere(
        (r) => r['room_label'] == label,
        orElse: () => <String, dynamic>{},
      );
      if (rot.isEmpty) continue;
      result.add(Map<String, dynamic>.from(rot)..['_isNextCycle'] = true);
      assignedLabels.add(label);
    }

    return result;
  }

  // ════════════════════════════════════════
  // 방 선택 팝업 (첫 사이클, 2개 선택)
  // ════════════════════════════════════════

  Future<void> _showRoomSelector(int floor) async {
    final pool = _getSelectionPool(floor);
    if (pool.isEmpty) return;
    final info     = _getCycleInfo(floor);
    final history  = floor == 2 ? _allHistory2 : _allHistory3;
    final color    = floor == 2 ? Colors.blue : Colors.purple;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _RoomSelectorSheet(
        floor:     floor,
        pool:      pool,
        info:      info,
        color:     color,
        baseIndex: history.length,
        onConfirm: (selected, baseIdx) async {
          for (int i = 0; i < selected.length; i++) {
            await _assignRoom(floor, selected[i], baseIdx + i);
          }
          await _loadAllHistory();
          await _loadSchedules();
          await _loadResidentNames();
        },
      ),
    );
  }

  // ════════════════════════════════════════
  // 청소 완료 체크
  // ════════════════════════════════════════

  Future<void> _toggleComplete(Map<String, dynamic> schedule) async {
    final scheduleId = schedule['id'] as String;
    final existing   = _records[scheduleId];
    if (existing != null) {
      await supabase.from('cleaning_records').delete().eq('schedule_id', scheduleId);
    } else {
      final user = supabase.auth.currentUser;
      await supabase.from('cleaning_records').insert({
        'schedule_id': scheduleId,
        'checked_by':  user?.id,
      });
    }
    await _loadSchedules();
  }

  Future<void> _changeDate(Map<String, dynamic> schedule) async {
    final current = DateTime.parse(schedule['assigned_date']);
    final picked  = await showDatePicker(
      context:     context,
      initialDate: current,
      firstDate:   DateTime.parse(_thisMonday),
      lastDate:    DateTime.parse(_thisMonday).add(const Duration(days: 13)),
    );
    if (picked == null) return;
    await supabase
        .from('cleaning_schedule')
        .update({'assigned_date': DateFormat('yyyy-MM-dd').format(picked)})
        .eq('id', schedule['id']);
    await _loadSchedules();
  }

  Future<void> _uploadPhoto(Map<String, dynamic> schedule) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked == null) return;

    final bytes    = await picked.readAsBytes();
    final fileName = 'cleaning_${schedule['id']}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    try {
      await supabase.storage.from('cleaning-photos').uploadBinary(fileName, bytes);
      final url      = supabase.storage.from('cleaning-photos').getPublicUrl(fileName);
      final existing = _records[schedule['id']];
      if (existing != null) {
        await supabase.from('cleaning_records').update({'photo_url': url}).eq('schedule_id', schedule['id']);
      } else {
        final user = supabase.auth.currentUser;
        await supabase.from('cleaning_records').insert({
          'schedule_id': schedule['id'],
          'photo_url':   url,
          'checked_by':  user?.id,
        });
      }
      await _loadSchedules();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.tr(AppStrings.cleaningPhotoUploaded)),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) { debugPrint('사진 업로드 실패: $e'); }
  }

  Future<void> _saveRotationOrder(int floor) async {
    final list = floor == 2 ? _rotations2 : _rotations3;
    for (int i = 0; i < list.length; i++) {
      await supabase.from('cleaning_rotation').update({'order_index': i + 1}).eq('id', list[i]['id']);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.tr(AppStrings.cleaningOrderSaved)),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  void _showResidents(String roomLabel) {
    final rooms = roomLabel.split(' / ').map((r) => r.trim()).toList();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ResidentsSheet(rooms: rooms),
    );
  }

  void _showPhotoDialog(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.network(url, fit: BoxFit.contain),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: Text(context.tr(AppStrings.cleaningTitle),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.teal,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.teal,
          isScrollable: _isAdmin,
          tabAlignment: _isAdmin ? TabAlignment.start : TabAlignment.fill,
          tabs: [
            Tab(text: context.tr(AppStrings.cleaningTabThisWeek)),
            Tab(text: context.tr(AppStrings.cleaningTabCafeteria)),
            if (_isAdmin) ...[
              Tab(text: context.tr(AppStrings.cleaningTabRotation)),
              Tab(text: context.tr(AppStrings.cleaningTabHistory)),
            ],
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _CleaningThisWeekTab(state: this),
                _CleaningCafeteriaTab(state: this),
                if (_isAdmin) ...[
                  _CleaningRotationTab(state: this),
                  _CleaningHistoryTab(state: this),
                ],
              ],
            ),
    );
  }
}

// ══════════════════════════════════════════
// 방 선택 시트 (2개 멀티셀렉트)
// ══════════════════════════════════════════

// ══════════════════════════════════════════
// 방 선택 시트 (2개 선택, 다음 순번 표시)
// ══════════════════════════════════════════

class _RoomSelectorSheet extends StatefulWidget {
  final int    floor;
  final List<Map<String, dynamic>> pool; // _isNextCycle 키 포함
  final ({int cycleNumber, int progress, int total, bool isAutoMode}) info;
  final Color  color;
  final int    baseIndex;
  final Future<void> Function(List<Map<String, dynamic>>, int) onConfirm;

  const _RoomSelectorSheet({
    required this.floor,
    required this.pool,
    required this.info,
    required this.color,
    required this.baseIndex,
    required this.onConfirm,
  });

  @override
  State<_RoomSelectorSheet> createState() => _RoomSelectorSheetState();
}

class _RoomSelectorSheetState extends State<_RoomSelectorSheet> {
  final List<Map<String, dynamic>> _selected = [];
  bool _isConfirming = false;

  static const _maxSelect = 2;

  @override
  Widget build(BuildContext context) {
    final color       = widget.color;
    final canConfirm  = _selected.isNotEmpty && !_isConfirming;
    final hasNextCycle = widget.pool.any((r) => r['_isNextCycle'] == true);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // 핸들
        Container(
          width: 36, height: 4,
          margin: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
              color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
        ),
        // 헤더
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.layers_rounded, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${widget.floor}층 이번 주 청소 방 선택',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                Text(
                  '${_selected.length}/$_maxSelect개 선택  ·  사이클 ${widget.info.cycleNumber}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ]),
            ),
          ]),
        ),

        // 다음 순번 안내 배너
        if (hasNextCycle)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.withOpacity(0.25)),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded, color: Colors.orange, size: 14),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '이번 사이클 마지막! 2개를 맞추기 위해 다음 순번 방도 표시됩니다.',
                  style: TextStyle(fontSize: 11, color: Colors.orange[700],
                      fontWeight: FontWeight.w600),
                ),
              ),
            ]),
          ),

        const Divider(height: 1),

        // 방 목록
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            itemCount: widget.pool.length,
            itemBuilder: (_, i) {
              final room        = widget.pool[i];
              final label       = room['room_label'] as String;
              final isNextCycle = room['_isNextCycle'] == true;
              final isSelected  = _selected.any((r) => r['room_label'] == label);
              final isFull      = _selected.length >= _maxSelect && !isSelected;

              return GestureDetector(
                onTap: isFull ? null : () {
                  setState(() {
                    if (isSelected) {
                      _selected.removeWhere((r) => r['room_label'] == label);
                    } else {
                      _selected.add(room);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withOpacity(0.08)
                        : isFull
                            ? Colors.grey.withOpacity(0.03)
                            : isNextCycle
                                ? Colors.orange.withOpacity(0.04)
                                : const Color(0xFFF4F6FB),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: isSelected
                            ? color.withOpacity(0.5)
                            : isNextCycle
                                ? Colors.orange.withOpacity(0.2)
                                : Colors.transparent,
                        width: 1.5),
                  ),
                  child: Row(children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                          color: isSelected
                              ? color.withOpacity(0.15)
                              : isNextCycle
                                  ? Colors.orange.withOpacity(0.1)
                                  : Colors.grey.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10)),
                      child: Center(
                        child: Text(
                          label.split(' ').last,
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: isSelected
                                  ? color
                                  : isNextCycle
                                      ? Colors.orange
                                      : Colors.grey[500],
                              fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label,
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 14,
                                  color: isFull ? Colors.grey[400] : Colors.black87)),
                          if (isNextCycle)
                            Text('다음 순번 시작',
                                style: TextStyle(fontSize: 11,
                                    color: Colors.orange[600],
                                    fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 150),
                      child: isSelected
                          ? Icon(Icons.check_circle_rounded,
                              color: color, size: 22, key: const ValueKey(true))
                          : Icon(Icons.radio_button_unchecked,
                              color: isFull ? Colors.grey[300] : Colors.grey[400],
                              size: 22, key: const ValueKey(false)),
                    ),
                  ]),
                ),
              );
            },
          ),
        ),

        // 확인 버튼
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: canConfirm ? () async {
                setState(() => _isConfirming = true);
                Navigator.pop(context);
                await widget.onConfirm(_selected, widget.baseIndex);
              } : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: canConfirm ? color : Colors.grey[200],
                foregroundColor: canConfirm ? Colors.white : Colors.grey[400],
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                _isConfirming
                    ? '배정 중...'
                    : _selected.isEmpty
                        ? '방을 선택해 주세요'
                        : '${_selected.map((r) => r['room_label'].toString().split(' ').last).join(', ')} 배정하기',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}