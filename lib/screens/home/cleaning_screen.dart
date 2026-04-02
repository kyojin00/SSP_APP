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

  // ── 공통 데이터
  List<Map<String, dynamic>> _schedules = [];
  Map<String, dynamic?> _records = {};
  bool _isLoading = true;

  // ── 관리자 전용
  List<Map<String, dynamic>> _rotations2 = [];
  List<Map<String, dynamic>> _rotations3 = [];
  bool _isGenerating = false;

  String get _thisMonday {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return DateFormat('yyyy-MM-dd').format(monday);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _isAdmin ? 3 : 1, vsync: this);
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
        .gte('week_start', _thisMonday) // 이번 주 이후 전체
        .order('week_start')
        .order('floor');

    if (!mounted) return;
    final schedules = List<Map<String, dynamic>>.from(data);
    final recordMap = <String, dynamic?>{};
    for (final s in schedules) {
      final recs = s['cleaning_records'] as List?;
      recordMap[s['id']] =
          (recs != null && recs.isNotEmpty) ? recs.first : null;
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

  Future<void> _generateSchedule() async {
    setState(() => _isGenerating = true);
    try {
      const weekCount = 7; // 항상 7주씩 생성

      for (final floor in [2, 3]) {
        final rotations = floor == 2 ? _rotations2 : _rotations3;
        if (rotations.isEmpty) continue;

        // 해당 층 마지막 스케줄 조회
        final lastRes = await supabase
            .from('cleaning_schedule')
            .select('week_start, order_index')
            .eq('floor', floor)
            .order('week_start', ascending: false)
            .limit(1);

        DateTime nextMonday;
        int startOrderIndex;

        if ((lastRes as List).isEmpty) {
          // 처음 생성 → 이번 주부터
          nextMonday = DateTime.parse(_thisMonday);
          startOrderIndex = 0;
        } else {
          final lastWeek =
              DateTime.parse(lastRes.first['week_start'] as String);
          final lastOrder = (lastRes.first['order_index'] as int?) ?? 1;
          // 마지막 주 다음 주부터
          nextMonday = lastWeek.add(const Duration(days: 7));
          // 다음 순번
          startOrderIndex = lastOrder % rotations.length;
        }

        // 7주치 생성
        for (int i = 0; i < weekCount; i++) {
          final weekStart = nextMonday.add(Duration(days: 7 * i));
          final sunday = weekStart.add(const Duration(days: 6));
          final slot =
              rotations[(startOrderIndex + i) % rotations.length];

          await supabase.from('cleaning_schedule').insert({
            'week_start':    DateFormat('yyyy-MM-dd').format(weekStart),
            'assigned_date': DateFormat('yyyy-MM-dd').format(sunday),
            'rotation_id':   slot['id'],
            'floor':         floor,
            'room_label':    slot['room_label'],
            'room_number':   slot['room_label'],
            'order_index':   slot['order_index'],
          });
        }
      }

      await _loadSchedules();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.tr(AppStrings.cleaningGenerated)),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      debugPrint('스케줄 생성 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '${context.tr(AppStrings.cleaningGenerateFail)}: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _changeDate(Map<String, dynamic> schedule) async {
    final current = DateTime.parse(schedule['assigned_date']);
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.parse(_thisMonday),
      lastDate:
          DateTime.parse(_thisMonday).add(const Duration(days: 13)),
    );
    if (picked == null) return;
    await supabase
        .from('cleaning_schedule')
        .update(
            {'assigned_date': DateFormat('yyyy-MM-dd').format(picked)})
        .eq('id', schedule['id']);
    await _loadSchedules();
  }

  Future<void> _toggleComplete(Map<String, dynamic> schedule) async {
    final scheduleId = schedule['id'] as String;
    final existing = _records[scheduleId];
    if (existing != null) {
      await supabase
          .from('cleaning_records')
          .delete()
          .eq('schedule_id', scheduleId);
    } else {
      final user = supabase.auth.currentUser;
      await supabase.from('cleaning_records').insert({
        'schedule_id': scheduleId,
        'checked_by':  user?.id,
      });
    }
    await _loadSchedules();
  }

  Future<void> _uploadPhoto(Map<String, dynamic> schedule) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 70);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final fileName =
        'cleaning_${schedule['id']}_${DateTime.now().millisecondsSinceEpoch}.jpg';

    try {
      await supabase.storage
          .from('cleaning-photos')
          .uploadBinary(fileName, bytes);
      final url = supabase.storage
          .from('cleaning-photos')
          .getPublicUrl(fileName);

      final existing = _records[schedule['id']];
      if (existing != null) {
        await supabase
            .from('cleaning_records')
            .update({'photo_url': url})
            .eq('schedule_id', schedule['id']);
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
    } catch (e) {
      debugPrint('사진 업로드 실패: $e');
    }
  }

  Future<void> _saveRotationOrder(int floor) async {
    final list = floor == 2 ? _rotations2 : _rotations3;
    for (int i = 0; i < list.length; i++) {
      await supabase
          .from('cleaning_rotation')
          .update({'order_index': i + 1})
          .eq('id', list[i]['id']);
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
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
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
        bottom: _isAdmin
            ? TabBar(
                controller: _tabController,
                labelColor: Colors.teal,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.teal,
                tabs: [
                  Tab(text: context.tr(AppStrings.cleaningTabThisWeek)),
                  Tab(text: context.tr(AppStrings.cleaningTabRotation)),
                  Tab(text: context.tr(AppStrings.cleaningTabHistory)),
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
                    _CleaningThisWeekTab(state: this),
                    _CleaningRotationTab(state: this),
                    _CleaningHistoryTab(state: this),
                  ],
                )
              : _CleaningThisWeekTab(state: this),
    );
  }
}