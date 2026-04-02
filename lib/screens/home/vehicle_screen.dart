// vehicle_screen.dart — 차량 일지 메인
// 분리된 파일 구조:
//   vehicle_sheets.dart          ← 출발/귀환 바텀시트
//   vehicle_log_history_screen.dart ← 월별 일지 내역
//   vehicle_stats_screen.dart    ← 주행 통계

import 'dart:convert';
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:excel/excel.dart' as xl;
part 'vehicle_sheets.dart';
part 'vehicle_log_history_screen.dart';
part 'vehicle_stats_screen.dart';

// ══════════════════════════════════════════
// 모델
// ══════════════════════════════════════════

class _Vehicle {
  final String id;
  final String name;
  final String plateNumber;
  final String vehicleType; // 'DELIVERY' | 'OFFICE'
  Map<String, dynamic>? currentLog;

  _Vehicle({required this.id, required this.name,
      required this.plateNumber, this.vehicleType = 'OFFICE', this.currentLog});
}

// ══════════════════════════════════════════
// VehicleScreen
// ══════════════════════════════════════════

class VehicleScreen extends StatefulWidget {
  final Map<String, dynamic> userProfile;
  final bool isAdmin;
  const VehicleScreen({Key? key, required this.userProfile, required this.isAdmin})
      : super(key: key);

  @override
  State<VehicleScreen> createState() => _VehicleScreenState();
}

class _VehicleScreenState extends State<VehicleScreen>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  late TabController _tabCtrl;

  bool _isLoading = true;
  List<_Vehicle> _vehicles = [];

  static const _primary = Color(0xFF2E6BFF);
  static const _bg      = Color(0xFFF0F2F7);

  // ── 부서별 접근 권한
  String get _dept =>
      widget.userProfile['dept_category'] as String? ?? '';

  /// 납품차량(트럭)만 볼 수 있는 부서
  bool get _onlyDelivery => _dept == 'DELIVERY';

  /// 납품차량 + 사무차량 둘 다 볼 수 있는 부서
  bool get _showBoth =>
      widget.isAdmin || ['PRODUCTION', 'SALES', 'MANAGEMENT'].contains(_dept);

  /// 접근 가능 여부
  bool get _hasAccess => widget.isAdmin || _onlyDelivery || _showBoth;

  int get _tabCount {
    if (_showBoth) return 2;
    return 1;
  }

  List<_Vehicle> get _deliveryVehicles =>
      _vehicles.where((v) => v.vehicleType == 'DELIVERY').toList();
  List<_Vehicle> get _officeVehicles =>
      _vehicles.where((v) => v.vehicleType == 'OFFICE').toList();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabCount, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final vehicles = await supabase
          .from('vehicles')
          .select()
          .eq('is_active', true)
          .order('name');

      final drivingLogs = await supabase
          .from('vehicle_logs')
          .select()
          .eq('status', 'DRIVING');

      final drivingMap = <String, Map<String, dynamic>>{};
      for (final log in drivingLogs) {
        drivingMap[log['vehicle_id'] as String] = log as Map<String, dynamic>;
      }

      if (!mounted) return;
      setState(() {
        _vehicles = (vehicles as List).map((v) => _Vehicle(
          id:          v['id']           as String,
          name:        v['name']         as String,
          plateNumber: v['plate_number'] as String,
          vehicleType: v['vehicle_type'] as String? ?? 'OFFICE',
          currentLog:  drivingMap[v['id'] as String],
        )).toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('차량 로드 실패: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _snack(String msg, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
      behavior: SnackBarBehavior.floating,
      backgroundColor: color ?? const Color(0xFF1A1D2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final delivery = _deliveryVehicles;
    final office   = _officeVehicles;

    late final List<Tab> tabs;
    late final List<Widget> tabViews;

    if (_showBoth) {
      tabs = [
        Tab(text: '납품차량 (${delivery.length})'),
        Tab(text: '사무차량 (${office.length})'),
      ];
      tabViews = [
        _vehicleListTab(delivery),
        _vehicleListTab(office),
      ];
    } else if (_onlyDelivery) {
      tabs = [Tab(text: '납품차량 (${delivery.length})')];
      tabViews = [_vehicleListTab(delivery)];
    } else {
      // 접근 불가 — 빈 탭 (body에서 처리)
      tabs = [const Tab(text: '-')];
      tabViews = [const SizedBox.shrink()];
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('차량 일지',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1D2E),
        elevation: 0,
        surfaceTintColor: Colors.white,
        bottom: _hasAccess
            ? TabBar(
                controller: _tabCtrl,
                labelColor: _primary,
                unselectedLabelColor: Colors.grey,
                indicatorColor: _primary,
                indicatorWeight: 3,
                dividerColor: Colors.transparent,
                tabs: tabs,
              )
            : null,
        actions: [
          if (widget.isAdmin)
            IconButton(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) =>
                      VehicleStatsScreen(vehicles: _vehicles))),
              icon: const Icon(Icons.bar_chart_rounded),
              tooltip: '주행 통계',
            ),
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : !_hasAccess
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline_rounded,
                          size: 52, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text('접근 권한이 없습니다.',
                          style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabCtrl,
                  children: tabViews,
                ),
    );
  }

  Widget _vehicleListTab(List<_Vehicle> vehicles) {
    final driving   = vehicles.where((v) => v.currentLog != null).length;
    final available = vehicles.length - driving;

    return RefreshIndicator(
      color: _primary,
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        children: [
          Row(children: [
            Expanded(child: _summaryChip(
                Icons.check_circle_rounded, Colors.green, '사용 가능', '$available대')),
            const SizedBox(width: 10),
            Expanded(child: _summaryChip(
                Icons.drive_eta_rounded, Colors.orange, '운행 중', '$driving대')),
            const SizedBox(width: 10),
            Expanded(child: _summaryChip(
                Icons.garage_rounded, _primary, '전체', '${vehicles.length}대')),
          ]),
          const SizedBox(height: 20),
          if (vehicles.isEmpty)
            Center(child: Padding(
              padding: const EdgeInsets.only(top: 60),
              child: Column(children: [
                Icon(Icons.directions_car_outlined,
                    size: 52, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text('등록된 차량이 없습니다',
                    style: TextStyle(color: Colors.grey[400], fontSize: 14)),
              ]),
            ))
          else
            ...vehicles.map((v) => _vehicleCard(v)),
        ],
      ),
    );
  }

  Widget _summaryChip(IconData icon, Color color, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w900, color: color)),
        Text(label, style: TextStyle(
            fontSize: 10, color: Colors.black.withOpacity(0.4),
            fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _vehicleCard(_Vehicle v) {
    final isDriving   = v.currentLog != null;
    final myId        = supabase.auth.currentUser?.id;
    final isMyDriving = isDriving && v.currentLog!['user_id'] == myId;

    final statusColor = isDriving ? Colors.orange : Colors.green;
    final statusLabel = isDriving ? '운행 중' : '사용 가능';
    final statusIcon  = isDriving
        ? Icons.drive_eta_rounded : Icons.check_circle_rounded;

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => VehicleLogHistoryScreen(
            vehicle:     v,
            userProfile: widget.userProfile,
            isAdmin:     widget.isAdmin,
            onRefresh:   _loadData,
          ))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isDriving
                  ? Colors.orange.withOpacity(0.3)
                  : Colors.transparent),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(children: [
          Row(children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14)),
              child: Icon(_vehicleIcon(v.name), color: statusColor, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(v.name, style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w900,
                    color: Color(0xFF1A1D2E))),
                const SizedBox(height: 2),
                Text(v.plateNumber, style: TextStyle(
                    fontSize: 12, color: Colors.black.withOpacity(0.4),
                    fontWeight: FontWeight.w600)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(statusIcon, color: statusColor, size: 12),
                const SizedBox(width: 4),
                Text(statusLabel, style: TextStyle(
                    color: statusColor, fontSize: 12,
                    fontWeight: FontWeight.w800)),
              ]),
            ),
          ]),

          if (isDriving) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                const Icon(Icons.person_rounded, size: 14, color: Colors.orange),
                const SizedBox(width: 6),
                Text(v.currentLog!['full_name'] ?? '-',
                    style: const TextStyle(fontSize: 13,
                        fontWeight: FontWeight.w700, color: Colors.orange)),
                const SizedBox(width: 8),
                Container(width: 1, height: 12,
                    color: Colors.orange.withOpacity(0.3)),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded,
                    size: 14, color: Colors.orange),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${v.currentLog!['departure']} → ${v.currentLog!['destination']}',
                    style: TextStyle(fontSize: 12,
                        color: Colors.orange.withOpacity(0.8),
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
            ),
          ],

          const SizedBox(height: 12),
          if (!isDriving)
            _actionBtn('출발 기록', Icons.play_arrow_rounded, Colors.green,
                () => _showDepartureSheet(v))
          else if (isMyDriving)
            _actionBtn('귀환 기록', Icons.flag_rounded, _primary,
                () => _showReturnSheet(v))
          else
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(12)),
              child: const Center(
                child: Text('다른 직원이 사용 중',
                    style: TextStyle(fontSize: 13, color: Colors.grey,
                        fontWeight: FontWeight.w600)),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _actionBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(
              color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }

  void _showDepartureSheet(_Vehicle v) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DepartureSheet(
        vehicle:     v,
        userProfile: widget.userProfile,
        onSubmit: (dep, dest, purpose, mileage) =>
            _submitDeparture(v, dep, dest, purpose, mileage),
      ),
    );
  }

  Future<void> _submitDeparture(_Vehicle v, String dep, String dest,
      String purpose, int mileageBefore) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      await supabase.from('vehicle_logs').insert({
        'vehicle_id':     v.id,
        'user_id':        user.id,
        'full_name':      widget.userProfile['full_name'] ?? '',
        'dept_category':  widget.userProfile['dept_category'] ?? '',
        'use_date':       DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'depart_time':    DateFormat('HH:mm').format(DateTime.now()),
        'departure':      dep,
        'destination':    dest,
        'purpose':        purpose,
        'mileage_before': mileageBefore,
        'status':         'DRIVING',
      });
      await _loadData();
      _snack('출발 기록 완료! 안전 운전하세요 🚗', color: Colors.green);
    } catch (e) {
      debugPrint('출발 기록 실패: $e');
      _snack('오류가 발생했습니다.');
    }
  }

  void _showReturnSheet(_Vehicle v) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReturnSheet(
        vehicle:  v,
        log:      v.currentLog!,
        onSubmit: (mileageAfter) => _submitReturn(v, mileageAfter),
      ),
    );
  }

  Future<void> _submitReturn(_Vehicle v, int mileageAfter) async {
    try {
      final logId         = v.currentLog!['id'] as String;
      final mileageBefore = v.currentLog!['mileage_before'] as int;
      await supabase.from('vehicle_logs').update({
        'mileage_after': mileageAfter,
        'distance':      mileageAfter - mileageBefore,
        'return_time':   DateFormat('HH:mm').format(DateTime.now()),
        'status':        'DONE',
      }).eq('id', logId);
      await _loadData();
      _snack('귀환 기록 완료! 수고하셨습니다 ✅', color: _primary);
    } catch (e) {
      debugPrint('귀환 기록 실패: $e');
      _snack('오류가 발생했습니다.');
    }
  }

  IconData _vehicleIcon(String name) {
    if (name.contains('톤') || name.contains('트럭') || name.contains('봉고')) {
      return Icons.local_shipping_rounded;
    }
    if (name.contains('KONA') || name.contains('ELECTRIC')) {
      return Icons.electric_car_rounded;
    }
    return Icons.directions_car_rounded;
  }
}