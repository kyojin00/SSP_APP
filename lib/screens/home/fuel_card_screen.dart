import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class FuelCardScreen extends StatefulWidget {
  final bool isAdmin;
  const FuelCardScreen({Key? key, required this.isAdmin}) : super(key: key);
  @override
  State<FuelCardScreen> createState() => _FuelCardScreenState();
}

class _FuelCardScreenState extends State<FuelCardScreen>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  late TabController _tab;

  static const _primary = Color(0xFF2E6BFF);
  static const _orange  = Color(0xFFFF8C42);
  static const _green   = Color(0xFF00C896);
  static const _red     = Color(0xFFFF4D64);
  static const _bg      = Color(0xFFF4F6FB);
  static const _text    = Color(0xFF1A1D2E);
  static const _sub     = Color(0xFF8A93B0);

  bool _loading = true;
  List<Map<String, dynamic>> _vehicles = [];
  List<Map<String, dynamic>> _logs     = [];
  String? _selectedVehicleId;

  int get pendingCount => _logs.where((l) => l['status'] == 'PENDING').length;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: widget.isAdmin ? 2 : 1, vsync: this);
    _loadAll();
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        supabase.from('vehicles')
            .select('id, name, plate_number')
            .eq('vehicle_type', 'DELIVERY')
            .order('name'),
        supabase.from('fuel_logs')
            .select('*, vehicles(name, plate_number)')
            .order('fueled_at', ascending: false)
            .limit(300),
      ]);
      if (mounted) setState(() {
        _vehicles = List<Map<String, dynamic>>.from(results[0] as List);
        _logs     = List<Map<String, dynamic>>.from(results[1] as List);
        if (_vehicles.isNotEmpty && _selectedVehicleId == null) {
          _selectedVehicleId = _vehicles.first['id'] as String;
        }
        _loading = false;
      });
    } catch (e) {
      debugPrint('로드 실패: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateStatus(String id, String status) async {
    await supabase.from('fuel_logs').update({'status': status}).eq('id', id);
    _loadAll();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(status == 'APPROVED' ? '✅ 주유 신청을 승인했습니다' : '❌ 신청이 반려됐습니다'),
        backgroundColor: status == 'APPROVED' ? _green : _red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('주유 신청',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: _text,
        elevation: 0,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadAll),
        ],
        bottom: widget.isAdmin ? TabBar(
          controller: _tab,
          labelColor: _orange,
          unselectedLabelColor: _sub,
          indicatorColor: _orange,
          indicatorWeight: 2.5,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          tabs: [
            const Tab(text: '내역'),
            Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('신청 관리'),
              if (pendingCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                      color: _red, borderRadius: BorderRadius.circular(10)),
                  child: Text('$pendingCount',
                      style: const TextStyle(fontSize: 10,
                          fontWeight: FontWeight.w900, color: Colors.white)),
                ),
              ],
            ])),
          ],
        ) : null,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _orange))
          : widget.isAdmin
              ? TabBarView(
                  controller: _tab,
                  children: [
                    _HistoryView(
                        vehicles: _vehicles, logs: _logs,
                        selectedVehicleId: _selectedVehicleId,
                        onSelectVehicle: (id) =>
                            setState(() => _selectedVehicleId = id),
                        isAdmin: true,
                        onDelete: (log) => _confirmDelete(log),
                    ),
                    _PendingView(
                        logs: _logs.where((l) =>
                            l['status'] == 'PENDING').toList(),
                        onApprove: (id) => _updateStatus(id, 'APPROVED'),
                        onReject:  (id) => _updateStatus(id, 'REJECTED'),
                    ),
                  ],
                )
              : _HistoryView(
                  vehicles: _vehicles, logs: _logs,
                  selectedVehicleId: _selectedVehicleId,
                  onSelectVehicle: (id) =>
                      setState(() => _selectedVehicleId = id),
                  isAdmin: false,
                  onDelete: (_) {},
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddLog,
        backgroundColor: _orange,
        icon: const Icon(Icons.local_gas_station_rounded, color: Colors.white),
        label: const Text('주유 신청',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
      ),
    );
  }

  Future<void> _confirmDelete(Map<String, dynamic> log) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('삭제', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text('${log['fueled_at']}  '
            '${(log['liters'] as num?)?.toDouble().toStringAsFixed(1) ?? '-'}L\n'
            '이 주유 내역을 삭제할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await supabase.from('fuel_logs').delete().eq('id', log['id']);
    _loadAll();
  }

  void _showAddLog() {
    String? selectedVehicleId = _selectedVehicleId;
    final literCtrl = TextEditingController();
    final memoCtrl  = TextEditingController();
    final dateCtrl  = TextEditingController(
        text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 36, height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2))),
              Row(children: [
                Container(padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: _orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.local_gas_station_rounded,
                        color: _orange, size: 20)),
                const SizedBox(width: 10),
                const Text('주유 신청', style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w900, color: _text)),
              ]),
              const SizedBox(height: 6),
              Text('관리자 승인 후 내역에 반영됩니다',
                  style: TextStyle(fontSize: 12, color: _sub)),
              const SizedBox(height: 20),
              // 차량
              DropdownButtonFormField<String>(
                value: selectedVehicleId,
                hint: const Text('차량 선택 *'),
                items: _vehicles.map((v) {
                  final name  = v['name']         as String? ?? '-';
                  final plate = v['plate_number'] as String? ?? '';
                  return DropdownMenuItem(
                    value: v['id'] as String,
                    child: Text(plate.isNotEmpty ? '$name  ·  $plate' : name),
                  );
                }).toList(),
                onChanged: (v) => setS(() => selectedVehicleId = v),
                decoration: _deco('차량 *', Icons.local_shipping_rounded),
              ),
              const SizedBox(height: 12),
              // 날짜
              TextField(
                controller: dateCtrl, readOnly: true,
                decoration: _deco('날짜 *', Icons.calendar_today_rounded),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    dateCtrl.text = DateFormat('yyyy-MM-dd').format(picked);
                  }
                },
              ),
              const SizedBox(height: 12),
              // 리터
              TextField(
                controller: literCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 22,
                    fontWeight: FontWeight.w900, color: _orange),
                textAlign: TextAlign.center,
                decoration: _deco('주유량 *', Icons.opacity_rounded).copyWith(
                  hintText: '0.0',
                  hintStyle: TextStyle(fontSize: 22,
                      color: Colors.grey[300], fontWeight: FontWeight.w900),
                  suffix: const Text('L', style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800, color: _orange)),
                ),
              ),
              const SizedBox(height: 12),
              // 메모
              TextField(controller: memoCtrl,
                  decoration: _deco('메모 (선택)', Icons.note_rounded)),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _orange,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                  onPressed: saving ? null : () async {
                    if (selectedVehicleId == null ||
                        literCtrl.text.trim().isEmpty) return;
                    setS(() => saving = true);
                    try {
                      final me = supabase.auth.currentUser;
                      String? myName;
                      if (me != null) {
                        final p = await supabase.from('profiles')
                            .select('full_name').eq('id', me.id).maybeSingle();
                        myName = p?['full_name'] as String?;
                      }
                      await supabase.from('fuel_logs').insert({
                        'vehicle_id':      selectedVehicleId,
                        'fueled_at':       dateCtrl.text.trim(),
                        'liters':          double.tryParse(literCtrl.text.trim()),
                        'registered_by':   me?.id,
                        'registered_name': myName ?? me?.email ?? '',
                        'memo':            memoCtrl.text.trim(),
                        'status':          'PENDING',
                      });
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        _loadAll();
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('주유 신청이 접수됐어요 ✅'),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                        ));
                      }
                    } catch (e) {
                      setS(() => saving = false);
                    }
                  },
                  child: saving
                      ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : const Text('신청', style: TextStyle(
                          color: Colors.white, fontSize: 16,
                          fontWeight: FontWeight.w900)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  InputDecoration _deco(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, size: 18, color: Colors.grey[400]),
    filled: true, fillColor: _bg,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none),
    labelStyle: const TextStyle(fontSize: 13, color: _sub),
  );
}

// ══════════════════════════════════════════
// 내역 뷰 (차량 탭 + 승인된 목록)
// ══════════════════════════════════════════
class _HistoryView extends StatelessWidget {
  final List<Map<String, dynamic>> vehicles;
  final List<Map<String, dynamic>> logs;
  final String? selectedVehicleId;
  final void Function(String?) onSelectVehicle;
  final bool isAdmin;
  final void Function(Map<String, dynamic>) onDelete;

  static const _orange = Color(0xFFFF8C42);
  static const _text   = Color(0xFF1A1D2E);
  static const _sub    = Color(0xFF8A93B0);
  static const _bg     = Color(0xFFF4F6FB);

  const _HistoryView({
    required this.vehicles, required this.logs,
    required this.selectedVehicleId, required this.onSelectVehicle,
    required this.isAdmin, required this.onDelete,
  });

  List<Map<String, dynamic>> get _approvedLogs =>
      logs.where((l) => l['status'] == 'APPROVED').toList();

  List<Map<String, dynamic>> get _currentLogs => selectedVehicleId == null
      ? _approvedLogs
      : _approvedLogs.where((l) => l['vehicle_id'] == selectedVehicleId).toList();

  double get _totalLiters => _currentLogs.fold(
      0.0, (s, l) => s + ((l['liters'] as num?)?.toDouble() ?? 0));

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _vehicleTabs(),
      if (selectedVehicleId != null) _summaryCard(),
      Expanded(child: _logList(context)),
    ]);
  }

  Widget _vehicleTabs() => Container(
    color: Colors.white,
    child: Column(children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(children: [
          _tab(null, '전체', null),
          const SizedBox(width: 8),
          ...vehicles.map((v) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _tab(v['id'] as String,
                v['name'] as String? ?? '-',
                v['plate_number'] as String?),
          )),
        ]),
      ),
      Container(height: 1, color: const Color(0xFFF0F2F8)),
    ]),
  );

  Widget _tab(String? id, String name, String? plate) {
    final sel = selectedVehicleId == id;
    return GestureDetector(
      onTap: () => onSelectVehicle(id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
            color: sel ? _orange : Colors.grey.withOpacity(0.07),
            borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.local_shipping_rounded, size: 13,
              color: sel ? Colors.white : _sub),
          const SizedBox(width: 5),
          Text(name, style: TextStyle(fontSize: 12,
              fontWeight: FontWeight.w800,
              color: sel ? Colors.white : _text)),
          if (plate != null && plate.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(plate, style: TextStyle(fontSize: 10,
                color: sel ? Colors.white.withOpacity(0.8) : _sub)),
          ],
        ]),
      ),
    );
  }

  Widget _summaryCard() {
    final v     = vehicles.firstWhere((v) => v['id'] == selectedVehicleId,
        orElse: () => {});
    final name  = v['name']         as String? ?? '';
    final plate = v['plate_number'] as String? ?? '';
    final now   = DateTime.now();
    final ym    = '${now.year}-${now.month.toString().padLeft(2,'0')}';
    final monthL = _currentLogs
        .where((l) => (l['fueled_at'] as String? ?? '').startsWith(ym))
        .fold(0.0, (s, l) => s + ((l['liters'] as num?)?.toDouble() ?? 0));

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [_orange, _orange.withOpacity(0.75)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: _orange.withOpacity(0.25),
            blurRadius: 12, offset: const Offset(0, 5))],
      ),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.local_gas_station_rounded,
                color: Colors.white, size: 24)),
        const SizedBox(width: 14),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(name, style: const TextStyle(fontSize: 15,
                fontWeight: FontWeight.w900, color: Colors.white)),
            if (plate.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6)),
                child: Text(plate, style: const TextStyle(fontSize: 10,
                    fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ],
          ]),
          const SizedBox(height: 4),
          Text('총 ${_totalLiters.toStringAsFixed(1)}L · ${_currentLogs.length}건',
              style: TextStyle(fontSize: 12,
                  color: Colors.white.withOpacity(0.85))),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('이번달', style: TextStyle(fontSize: 10,
              color: Colors.white.withOpacity(0.7))),
          const SizedBox(height: 2),
          Text('${monthL.toStringAsFixed(1)}L',
              style: const TextStyle(fontSize: 20,
                  fontWeight: FontWeight.w900, color: Colors.white)),
        ]),
      ]),
    );
  }

  Widget _logList(BuildContext context) {
    final filtered = _currentLogs;
    if (filtered.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.local_gas_station_rounded, size: 52, color: Colors.grey[300]),
        const SizedBox(height: 12),
        const Text('승인된 주유 내역이 없습니다',
            style: TextStyle(color: _sub, fontSize: 14)),
      ]));
    }
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final l in filtered) {
      final m = (l['fueled_at'] as String? ?? '').substring(0, 7);
      grouped.putIfAbsent(m, () => []).add(l);
    }
    final months = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
      itemCount: months.length,
      itemBuilder: (_, mi) {
        final month = months[mi];
        final items = grouped[month]!;
        final total = items.fold(0.0,
            (s, l) => s + ((l['liters'] as num?)?.toDouble() ?? 0));
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 4, 2, 10),
            child: Row(children: [
              Text(month.replaceAll('-', '년 ') + '월',
                  style: const TextStyle(fontSize: 14,
                      fontWeight: FontWeight.w900, color: _text)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: _orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: Text('합계 ${total.toStringAsFixed(1)}L',
                    style: const TextStyle(fontSize: 12,
                        fontWeight: FontWeight.w800, color: _orange)),
              ),
            ]),
          ),
          Container(
            decoration: BoxDecoration(color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
                    blurRadius: 8, offset: const Offset(0, 3))]),
            child: Column(children: items.asMap().entries.map((e) {
              final isLast = e.key == items.length - 1;
              return _tile(context, e.value, isLast);
            }).toList()),
          ),
          const SizedBox(height: 16),
        ]);
      },
    );
  }

  Widget _tile(BuildContext context, Map<String, dynamic> log, bool isLast) {
    final vName  = (log['vehicles'] as Map?)?['name']         as String? ?? '-';
    final vPlate = (log['vehicles'] as Map?)?['plate_number'] as String? ?? '';
    final date   = log['fueled_at']       as String? ?? '';
    final liters = (log['liters'] as num?)?.toDouble() ?? 0;
    final regName= log['registered_name'] as String? ?? '';
    final memo   = log['memo']            as String? ?? '';

    return GestureDetector(
      onLongPress: isAdmin ? () => onDelete(log) : null,
      child: Container(
        decoration: BoxDecoration(
            border: !isLast ? Border(bottom: BorderSide(
                color: Colors.grey.withOpacity(0.08))) : null,
            borderRadius: isLast
                ? const BorderRadius.vertical(bottom: Radius.circular(16))
                : null),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(children: [
          Container(width: 50, height: 50,
              decoration: BoxDecoration(color: _orange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(date.length >= 7 ? date.substring(5, 7) : '--',
                    style: const TextStyle(fontSize: 11, color: _sub,
                        fontWeight: FontWeight.w600)),
                Text(date.length >= 10 ? date.substring(8, 10) : '--',
                    style: const TextStyle(fontSize: 18,
                        fontWeight: FontWeight.w900, color: _orange)),
              ])),
          const SizedBox(width: 12),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (selectedVehicleId == null)
              Row(children: [
                Text(vName, style: const TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w800, color: _text)),
                if (vPlate.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  _chip(vPlate, _orange),
                ],
              ]),
            const SizedBox(height: 3),
            Row(children: [
              if (regName.isNotEmpty) _chip(regName, Colors.blue),
              if (memo.isNotEmpty) ...[
                const SizedBox(width: 6),
                Expanded(child: Text(memo,
                    style: const TextStyle(fontSize: 11, color: _sub),
                    overflow: TextOverflow.ellipsis)),
              ],
            ]),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(liters.toStringAsFixed(1),
                style: const TextStyle(fontSize: 22,
                    fontWeight: FontWeight.w900, color: _orange)),
            const Text('리터', style: TextStyle(fontSize: 10,
                color: _sub, fontWeight: FontWeight.w600)),
          ]),
        ]),
      ),
    );
  }

  Widget _chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6)),
    child: Text(label, style: TextStyle(fontSize: 10, color: color,
        fontWeight: FontWeight.w700)),
  );
}

// ══════════════════════════════════════════
// 신청 관리 뷰 (관리자 전용)
// ══════════════════════════════════════════
class _PendingView extends StatelessWidget {
  final List<Map<String, dynamic>> logs;
  final void Function(String) onApprove;
  final void Function(String) onReject;

  static const _orange = Color(0xFFFF8C42);
  static const _green  = Color(0xFF00C896);
  static const _red    = Color(0xFFFF4D64);
  static const _text   = Color(0xFF1A1D2E);
  static const _sub    = Color(0xFF8A93B0);
  static const _bg     = Color(0xFFF4F6FB);

  const _PendingView({
    required this.logs, required this.onApprove, required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.check_circle_outline_rounded, size: 56, color: Colors.grey[300]),
        const SizedBox(height: 12),
        const Text('대기 중인 신청이 없습니다',
            style: TextStyle(color: _sub, fontSize: 14)),
      ]));
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      itemCount: logs.length,
      itemBuilder: (_, i) => _pendingCard(logs[i]),
    );
  }

  Widget _pendingCard(Map<String, dynamic> log) {
    final id     = log['id']              as String;
    final vName  = (log['vehicles'] as Map?)?['name']         as String? ?? '-';
    final vPlate = (log['vehicles'] as Map?)?['plate_number'] as String? ?? '';
    final date   = log['fueled_at']       as String? ?? '';
    final liters = (log['liters'] as num?)?.toDouble() ?? 0;
    final regName= log['registered_name'] as String? ?? '';
    final memo   = log['memo']            as String? ?? '';
    final created = log['created_at']     as String? ?? '';

    String timeAgo = '';
    try {
      final dt = DateTime.parse(created).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) timeAgo = '${diff.inMinutes}분 전';
      else if (diff.inHours < 24) timeAgo = '${diff.inHours}시간 전';
      else timeAgo = '${diff.inDays}일 전';
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _orange.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
            blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        // 헤더
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
              color: _orange.withOpacity(0.04),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18))),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: _orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.local_gas_station_rounded,
                  color: _orange, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(vName, style: const TextStyle(fontSize: 15,
                    fontWeight: FontWeight.w900, color: _text)),
                if (vPlate.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                        color: _orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text(vPlate, style: const TextStyle(fontSize: 10,
                        fontWeight: FontWeight.w700, color: _orange)),
                  ),
                ],
              ]),
              const SizedBox(height: 3),
              Row(children: [
                Text(date, style: const TextStyle(
                    fontSize: 11, color: _sub)),
                const SizedBox(width: 6),
                if (regName.isNotEmpty)
                  Text('· $regName', style: const TextStyle(
                      fontSize: 11, color: _sub)),
                const Spacer(),
                Text(timeAgo, style: TextStyle(
                    fontSize: 10, color: Colors.grey[400])),
              ]),
            ])),
            // 리터 크게
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(liters.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 26,
                      fontWeight: FontWeight.w900, color: _orange)),
              const Text('리터', style: TextStyle(fontSize: 10,
                  color: _sub, fontWeight: FontWeight.w600)),
            ]),
          ]),
        ),
        // 메모
        if (memo.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(children: [
              const Icon(Icons.note_rounded, size: 13, color: _sub),
              const SizedBox(width: 6),
              Expanded(child: Text(memo, style: const TextStyle(
                  fontSize: 12, color: _sub))),
            ]),
          ),
        // 승인/반려 버튼
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Expanded(child: GestureDetector(
              onTap: () => onReject(id),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                    color: _red.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _red.withOpacity(0.2))),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  Icon(Icons.close_rounded, color: _red, size: 16),
                  SizedBox(width: 6),
                  Text('반려', style: TextStyle(color: _red,
                      fontWeight: FontWeight.w800, fontSize: 14)),
                ]),
              ),
            )),
            const SizedBox(width: 10),
            Expanded(flex: 2, child: GestureDetector(
              onTap: () => onApprove(id),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                    color: _green,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: _green.withOpacity(0.3),
                        blurRadius: 8, offset: const Offset(0, 3))]),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  Icon(Icons.check_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 6),
                  Text('승인', style: TextStyle(color: Colors.white,
                      fontWeight: FontWeight.w900, fontSize: 14)),
                ]),
              ),
            )),
          ]),
        ),
      ]),
    );
  }
}