import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

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

  bool get _isAdmin => widget.userProfile['is_admin'] == true;

  // ── 공통 데이터
  List<Map<String, dynamic>> _schedules = [];   // 이번 주 스케줄 (floor 2, 3)
  Map<String, dynamic?> _records = {};          // schedule_id → record
  bool _isLoading = true;

  // ── 관리자 전용
  List<Map<String, dynamic>> _rotations2 = [];  // 2층 순번
  List<Map<String, dynamic>> _rotations3 = [];  // 3층 순번
  bool _isGenerating = false;

  String get _thisMonday {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return DateFormat('yyyy-MM-dd').format(monday);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
        length: _isAdmin ? 3 : 1, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _loadSchedules(),
        if (_isAdmin) _loadRotations(),
      ]);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSchedules() async {
    final data = await supabase
        .from('cleaning_schedule')
        .select('*, cleaning_records(*)')
        .eq('week_start', _thisMonday)
        .order('floor');

    if (!mounted) return;
    final schedules = List<Map<String, dynamic>>.from(data);
    final recordMap = <String, dynamic?>{};
    for (final s in schedules) {
      final recs = s['cleaning_records'] as List?;
      recordMap[s['id']] = (recs != null && recs.isNotEmpty) ? recs.first : null;
    }
    setState(() {
      _schedules = schedules;
      _records = recordMap;
    });
  }

  Future<void> _loadRotations() async {
    final data = await supabase
        .from('cleaning_rotation')
        .select()
        .eq('active', true)
        .order('floor')
        .order('order_index');

    final all = List<Map<String, dynamic>>.from(data);
    if (mounted) {
      setState(() {
        _rotations2 = all.where((r) => r['floor'] == 2).toList();
        _rotations3 = all.where((r) => r['floor'] == 3).toList();
      });
    }
  }

  // ─────────────────────────────────────────
  // 이번 주 스케줄 생성
  // ─────────────────────────────────────────
  Future<void> _generateSchedule() async {
    setState(() => _isGenerating = true);
    try {
      // 이미 존재하면 스킵
      final existing = await supabase
          .from('cleaning_schedule')
          .select('floor')
          .eq('week_start', _thisMonday);

      final existingFloors = (existing as List).map((e) => e['floor']).toSet();

      for (final floor in [2, 3]) {
        if (existingFloors.contains(floor)) continue;

        final rotations = floor == 2 ? _rotations2 : _rotations3;
        if (rotations.isEmpty) continue;

        // 지금까지 생성된 스케줄 수 → 다음 순번 계산
        final countRes = await supabase
            .from('cleaning_schedule')
            .select('id')
            .eq('floor', floor);
        final count = (countRes as List).length;
        final nextIndex = count % rotations.length;
        final slot = rotations[nextIndex];

        await supabase.from('cleaning_schedule').insert({
          'week_start':    _thisMonday,
          'assigned_date': _thisMonday, // 기본 월요일, 관리자가 변경 가능
          'rotation_id':   slot['id'],
          'floor':         floor,
          'room_label':    slot['room_label'],
        });
      }

      await _loadSchedules();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('이번 주 스케줄이 생성되었습니다 ✅'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      debugPrint('스케줄 생성 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('생성 실패: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  // ─────────────────────────────────────────
  // 날짜 변경 (관리자)
  // ─────────────────────────────────────────
  Future<void> _changeDate(Map<String, dynamic> schedule) async {
    final current = DateTime.parse(schedule['assigned_date']);
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.parse(_thisMonday),
      lastDate: DateTime.parse(_thisMonday).add(const Duration(days: 13)),
    );
    if (picked == null) return;
    await supabase.from('cleaning_schedule')
        .update({'assigned_date': DateFormat('yyyy-MM-dd').format(picked)})
        .eq('id', schedule['id']);
    await _loadSchedules();
  }

  // ─────────────────────────────────────────
  // 완료 체크 (관리자)
  // ─────────────────────────────────────────
  Future<void> _toggleComplete(Map<String, dynamic> schedule) async {
    final scheduleId = schedule['id'] as String;
    final existing = _records[scheduleId];

    if (existing != null) {
      // 완료 취소
      await supabase.from('cleaning_records')
          .delete().eq('schedule_id', scheduleId);
    } else {
      final user = supabase.auth.currentUser;
      await supabase.from('cleaning_records').insert({
        'schedule_id': scheduleId,
        'checked_by':  user?.id,
      });
    }
    await _loadSchedules();
  }

  // ─────────────────────────────────────────
  // 사진 업로드 (관리자)
  // ─────────────────────────────────────────
  Future<void> _uploadPhoto(Map<String, dynamic> schedule) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final fileName = 'cleaning_${schedule['id']}_${DateTime.now().millisecondsSinceEpoch}.jpg';

    try {
      await supabase.storage.from('cleaning-photos').uploadBinary(fileName, bytes);
      final url = supabase.storage.from('cleaning-photos').getPublicUrl(fileName);

      final existing = _records[schedule['id']];
      if (existing != null) {
        await supabase.from('cleaning_records')
            .update({'photo_url': url}).eq('schedule_id', schedule['id']);
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('사진이 등록되었습니다 📸'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      debugPrint('사진 업로드 실패: $e');
    }
  }

  // ─────────────────────────────────────────
  // 순번 변경 저장 (관리자)
  // ─────────────────────────────────────────
  Future<void> _saveRotationOrder(int floor) async {
    final list = floor == 2 ? _rotations2 : _rotations3;
    for (int i = 0; i < list.length; i++) {
      await supabase.from('cleaning_rotation')
          .update({'order_index': i + 1}).eq('id', list[i]['id']);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('순번이 저장되었습니다 💾'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  // ─────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: const Text('베란다 청소 로테이션',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true, elevation: 0,
        backgroundColor: Colors.white, foregroundColor: Colors.black,
        bottom: _isAdmin
            ? TabBar(
                controller: _tabController,
                labelColor: Colors.teal,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.teal,
                tabs: const [
                  Tab(text: '이번 주'),
                  Tab(text: '순번 관리'),
                  Tab(text: '전체 기록'),
                ],
              )
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isAdmin
              ? TabBarView(
                  controller: _tabController,
                  children: [
                    _buildThisWeekTab(isAdmin: true),
                    _buildRotationTab(),
                    _buildHistoryTab(),
                  ],
                )
              : _buildThisWeekTab(isAdmin: false),
    );
  }

  // ─────────────────────────────────────────
  // 탭1: 이번 주 현황
  // ─────────────────────────────────────────
  Widget _buildThisWeekTab({required bool isAdmin}) {
    final monday = DateTime.parse(_thisMonday);
    final sunday = monday.add(const Duration(days: 6));

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          // 주차 헤더
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.teal.withOpacity(0.2)),
            ),
            child: Row(children: [
              const Icon(Icons.calendar_month_rounded,
                  color: Colors.teal, size: 20),
              const SizedBox(width: 10),
              Text(
                '${DateFormat('MM/dd').format(monday)} ~ ${DateFormat('MM/dd').format(sunday)} 청소 담당',
                style: const TextStyle(fontSize: 14,
                    fontWeight: FontWeight.w800, color: Colors.teal),
              ),
            ]),
          ),

          const SizedBox(height: 16),

          // 스케줄 없을 때
          if (_schedules.isEmpty) ...[
            const SizedBox(height: 40),
            Icon(Icons.cleaning_services_rounded,
                size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              isAdmin
                  ? '이번 주 스케줄이 없습니다.\n아래 버튼으로 생성해주세요.'
                  : '이번 주 스케줄이 아직 없습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
            if (isAdmin) ...[
              const SizedBox(height: 24),
              _buildGenerateButton(),
            ],
          ] else ...[
            // 층별 카드
            for (final schedule in _schedules)
              _buildScheduleCard(schedule, isAdmin: isAdmin),

            if (isAdmin) ...[
              const SizedBox(height: 12),
              _buildGenerateButton(),
            ],
          ],
        ]),
      ),
    );
  }

  Widget _buildGenerateButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isGenerating ? null : _generateSchedule,
        icon: _isGenerating
            ? const SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.auto_awesome_rounded, size: 18),
        label: Text(_isGenerating ? '생성 중...' : '이번 주 스케줄 생성'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildScheduleCard(Map<String, dynamic> schedule,
      {required bool isAdmin}) {
    final floor = schedule['floor'] as int;
    final roomLabel = schedule['room_label'] as String;
    final assignedDate = DateTime.parse(schedule['assigned_date']);
    final record = _records[schedule['id']];
    final isDone = record != null;
    final photoUrl = record?['photo_url'] as String?;
    final isWeekend = assignedDate.weekday >= 6;

    final floorColor = floor == 2 ? Colors.blue : Colors.purple;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isDone
                ? Colors.green.withOpacity(0.3)
                : floorColor.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04),
              blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(children: [
        // 상단 헤더
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: floorColor.withOpacity(0.06),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: floorColor,
                  borderRadius: BorderRadius.circular(8)),
              child: Text('${floor}층',
                  style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.w800, fontSize: 12)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(roomLabel,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900,
                      color: floorColor)),
            ),
            // 완료 뱃지
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: isDone
                      ? Colors.green.withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(isDone ? Icons.check_circle_rounded : Icons.pending_rounded,
                    size: 14,
                    color: isDone ? Colors.green : Colors.orange),
                const SizedBox(width: 4),
                Text(isDone ? '완료' : '대기중',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                        color: isDone ? Colors.green : Colors.orange)),
              ]),
            ),
          ]),
        ),

        // 날짜 + 액션
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Row(children: [
              Icon(Icons.event_rounded, size: 16, color: Colors.grey[500]),
              const SizedBox(width: 6),
              Text(
                '청소일: ${DateFormat('MM월 dd일 (E)', 'ko').format(assignedDate)}',
                style: TextStyle(fontSize: 13, color: Colors.grey[700],
                    fontWeight: FontWeight.w600),
              ),
              if (isWeekend) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6)),
                  child: const Text('주말',
                      style: TextStyle(fontSize: 10,
                          color: Colors.red, fontWeight: FontWeight.w700)),
                ),
              ],
              if (isAdmin) ...[
                const Spacer(),
                GestureDetector(
                  onTap: () => _changeDate(schedule),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: const Text('날짜 변경',
                        style: TextStyle(fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ]),

            // 사진
            if (photoUrl != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(photoUrl,
                    height: 160, width: double.infinity,
                    fit: BoxFit.cover),
              ),
            ],

            // 관리자 액션
            if (isAdmin) ...[
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _toggleComplete(schedule),
                    icon: Icon(
                      isDone ? Icons.cancel_outlined : Icons.check_circle_outline,
                      size: 16,
                      color: isDone ? Colors.red : Colors.green,
                    ),
                    label: Text(isDone ? '완료 취소' : '완료 체크',
                        style: TextStyle(
                            color: isDone ? Colors.red : Colors.green,
                            fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: isDone ? Colors.red : Colors.green),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _uploadPhoto(schedule),
                    icon: const Icon(Icons.photo_camera_rounded,
                        size: 16, color: Colors.teal),
                    label: const Text('사진 등록',
                        style: TextStyle(
                            color: Colors.teal,
                            fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.teal),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ]),
            ],
          ]),
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────
  // 탭2: 순번 관리 (드래그)
  // ─────────────────────────────────────────
  Widget _buildRotationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        _buildFloorRotation(2, _rotations2),
        const SizedBox(height: 24),
        _buildFloorRotation(3, _rotations3),
      ]),
    );
  }

  Widget _buildFloorRotation(int floor, List<Map<String, dynamic>> rotations) {
    final color = floor == 2 ? Colors.blue : Colors.purple;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(children: [
        // 헤더
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.06),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(children: [
            Icon(Icons.layers_rounded, color: color, size: 20),
            const SizedBox(width: 8),
            Text('$floor층 로테이션 (${rotations.length}개 호실)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900,
                    color: color)),
            const Spacer(),
            GestureDetector(
              onTap: () => _saveRotationOrder(floor),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: Text('저장',
                    style: TextStyle(fontSize: 13,
                        fontWeight: FontWeight.w800, color: color)),
              ),
            ),
          ]),
        ),

        // 드래그 리스트
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: rotations.length,
          onReorder: (oldIndex, newIndex) {
            setState(() {
              if (newIndex > oldIndex) newIndex--;
              final list = floor == 2 ? _rotations2 : _rotations3;
              final item = list.removeAt(oldIndex);
              list.insert(newIndex, item);
            });
          },
          itemBuilder: (context, index) {
            final r = rotations[index];
            return ListTile(
              key: ValueKey(r['id']),
              leading: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: Center(
                  child: Text('${index + 1}',
                      style: TextStyle(fontWeight: FontWeight.w800,
                          color: color, fontSize: 13)),
                ),
              ),
              title: Text(r['room_label'],
                  style: const TextStyle(fontWeight: FontWeight.w700,
                      fontSize: 14)),
              subtitle: r['is_merged'] == true
                  ? const Text('1인실 묶음',
                      style: TextStyle(fontSize: 11, color: Colors.orange))
                  : null,
              trailing: const Icon(Icons.drag_handle_rounded,
                  color: Colors.grey),
            );
          },
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────
  // 탭3: 전체 완료 기록
  // ─────────────────────────────────────────
  Widget _buildHistoryTab() {
    return FutureBuilder(
      future: supabase.from('cleaning_schedule')
          .select('*, cleaning_records(*)')
          .order('week_start', ascending: false)
          .limit(40),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final all = List<Map<String, dynamic>>.from(snapshot.data as List);
        if (all.isEmpty) {
          return const Center(
              child: Text('기록이 없습니다.',
                  style: TextStyle(color: Colors.grey)));
        }

        // week_start 기준 그룹핑
        final grouped = <String, List<Map<String, dynamic>>>{};
        for (final s in all) {
          final w = s['week_start'] as String;
          grouped.putIfAbsent(w, () => []).add(s);
        }

        return ListView(
          padding: const EdgeInsets.all(20),
          children: grouped.entries.map((entry) {
            final monday = DateTime.parse(entry.key);
            final sunday = monday.add(const Duration(days: 6));
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    '${DateFormat('MM/dd').format(monday)} ~ ${DateFormat('MM/dd').format(sunday)}',
                    style: const TextStyle(fontSize: 13,
                        fontWeight: FontWeight.w800, color: Colors.grey),
                  ),
                ),
                for (final s in entry.value)
                  _buildHistoryTile(s),
                const Divider(),
              ],
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildHistoryTile(Map<String, dynamic> schedule) {
    final floor = schedule['floor'] as int;
    final recs = schedule['cleaning_records'] as List?;
    final record = (recs != null && recs.isNotEmpty) ? recs.first : null;
    final isDone = record != null;
    final photoUrl = record?['photo_url'] as String?;
    final color = floor == 2 ? Colors.blue : Colors.purple;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDone
            ? Colors.green.withOpacity(0.05)
            : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDone
                ? Colors.green.withOpacity(0.2)
                : Colors.grey.withOpacity(0.2)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6)),
          child: Text('${floor}층',
              style: TextStyle(fontSize: 11,
                  fontWeight: FontWeight.w800, color: color)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(schedule['room_label'],
                style: const TextStyle(fontWeight: FontWeight.w700,
                    fontSize: 13)),
            Text(
              DateFormat('MM/dd (E)', 'ko')
                  .format(DateTime.parse(schedule['assigned_date'])),
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ]),
        ),
        if (photoUrl != null)
          GestureDetector(
            onTap: () => _showPhotoDialog(photoUrl),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.photo_rounded,
                  size: 16, color: Colors.teal),
            ),
          ),
        const SizedBox(width: 8),
        Icon(
          isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
          color: isDone ? Colors.green : Colors.grey[300],
          size: 22,
        ),
      ]),
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
}
