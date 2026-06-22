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

  _Vehicle({
    required this.id,
    required this.name,
    required this.plateNumber,
    this.vehicleType = 'OFFICE',
    this.currentLog,
  });
}

// ══════════════════════════════════════════
// VehicleScreen
// ══════════════════════════════════════════

class VehicleScreen extends StatefulWidget {
  final Map<String, dynamic> userProfile;
  final bool isAdmin;
  const VehicleScreen({
    Key? key,
    required this.userProfile,
    required this.isAdmin,
  }) : super(key: key);

  @override
  State<VehicleScreen> createState() => _VehicleScreenState();
}

class _VehicleScreenState extends State<VehicleScreen>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  late TabController _tabCtrl;

  bool _isLoading = true;
  List<_Vehicle> _vehicles = [];

  static const _primary  = Color(0xFF2E6BFF);
  static const _teal     = Color(0xFF00BFA5);
  static const _tealDark = Color(0xFF00897B);
  static const _bg       = Color(0xFFF0F2F7);

  String get _dept =>
      widget.userProfile['dept_category'] as String? ?? '';

  bool get _onlyDelivery => _dept == 'DELIVERY';
  bool get _showBoth =>
      widget.isAdmin || ['PRODUCTION', 'SALES', 'MANAGEMENT'].contains(_dept);
  bool get _hasAccess => widget.isAdmin || _onlyDelivery || _showBoth;
  int  get _tabCount  => _showBoth ? 2 : 1;

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
        drivingMap[log['vehicle_id'] as String] =
            log as Map<String, dynamic>;
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
      tabs = [const Tab(text: '-')];
      tabViews = [const SizedBox.shrink()];
    }

    return Scaffold(
      backgroundColor: _bg,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          // ── 그라디언트 SliverAppBar
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor: _tealDark,
            foregroundColor: Colors.white,
            title: const Text(
              '차량 일지',
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                  color: Colors.white),
            ),
            actions: [
              if (widget.isAdmin)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  child: IconButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                VehicleStatsScreen(vehicles: _vehicles))),
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.bar_chart_rounded,
                          color: Colors.white, size: 18),
                    ),
                    tooltip: '주행 통계',
                  ),
                ),
              Container(
                margin: const EdgeInsets.only(right: 12),
                child: IconButton(
                  onPressed: _loadData,
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.refresh_rounded,
                        color: Colors.white, size: 18),
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF004D40), _tealDark, _teal],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(children: [
                  Positioned(
                    right: -40, top: -40,
                    child: Container(
                      width: 180, height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.07),
                      ),
                    ),
                  ),
                  Positioned(
                    left: -20, bottom: -30,
                    child: Container(
                      width: 130, height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.05),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 80, 20, 54),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.directions_car_rounded,
                            color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        const Text('차량 운행 일지',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w900)),
                        Text(
                          '${_vehicles.length}대 등록 · '
                          '${_vehicles.where((v) => v.currentLog != null).length}대 운행 중',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.72),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ]),
                    ]),
                  ),
                ]),
              ),
            ),
            bottom: _hasAccess
                ? TabBar(
                    controller: _tabCtrl,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white.withOpacity(0.6),
                    indicatorColor: Colors.white,
                    indicatorWeight: 3,
                    dividerColor: Colors.white.withOpacity(0.15),
                    labelStyle: const TextStyle(fontWeight: FontWeight.w800),
                    tabs: tabs,
                  )
                : null,
          ),
        ],
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: _teal))
            : !_hasAccess
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4))
                            ],
                          ),
                          child: Icon(Icons.lock_outline_rounded,
                              size: 40, color: Colors.grey[300]),
                        ),
                        const SizedBox(height: 16),
                        Text('접근 권한이 없습니다.',
                            style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 15,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  )
                : TabBarView(
                    controller: _tabCtrl,
                    children: tabViews,
                  ),
      ),
    );
  }

  Widget _vehicleListTab(List<_Vehicle> vehicles) {
    final driving   = vehicles.where((v) => v.currentLog != null).length;
    final available = vehicles.length - driving;

    return RefreshIndicator(
      color: _teal,
      onRefresh: _loadData,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        children: [
          // 요약 카드
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF004D40), _tealDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: _tealDark.withOpacity(0.30),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Stack(children: [
              Positioned(
                right: -20, top: -20,
                child: Container(
                  width: 90, height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.07),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _summaryChip(Icons.check_circle_rounded,
                      Colors.greenAccent, '사용 가능', '$available대'),
                  Container(
                      width: 1, height: 36,
                      color: Colors.white.withOpacity(0.2)),
                  _summaryChip(Icons.drive_eta_rounded,
                      Colors.orangeAccent, '운행 중', '$driving대'),
                  Container(
                      width: 1, height: 36,
                      color: Colors.white.withOpacity(0.2)),
                  _summaryChip(Icons.garage_rounded,
                      Colors.white, '전체', '${vehicles.length}대'),
                ],
              ),
            ]),
          ),
          const SizedBox(height: 16),
          if (vehicles.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Column(children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 14,
                            offset: const Offset(0, 4))
                      ],
                    ),
                    child: Icon(Icons.directions_car_outlined,
                        size: 40, color: Colors.grey[300]),
                  ),
                  const SizedBox(height: 14),
                  Text('등록된 차량이 없습니다',
                      style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            )
          else
            ...vehicles.map((v) => _vehicleCard(v)),
        ],
      ),
    );
  }

  Widget _summaryChip(
      IconData icon, Color color, String label, String value) {
    return Column(children: [
      Icon(icon, color: color, size: 22),
      const SizedBox(height: 5),
      Text(value,
          style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: color)),
      Text(label,
          style: TextStyle(
              fontSize: 10,
              color: Colors.white.withOpacity(0.65),
              fontWeight: FontWeight.w600)),
    ]);
  }

  Widget _vehicleCard(_Vehicle v) {
    final isDriving   = v.currentLog != null;
    final myId        = supabase.auth.currentUser?.id;
    final isMyDriving = isDriving && v.currentLog!['user_id'] == myId;

    final statusColor = isDriving ? Colors.orange : Colors.green;
    final statusLabel = isDriving ? '운행 중' : '사용 가능';
    final statusIcon  = isDriving
        ? Icons.drive_eta_rounded
        : Icons.check_circle_rounded;

    final carIcon = _vehicleIcon(v.name);

    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
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
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: statusColor.withOpacity(isDriving ? 0.14 : 0.07),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(children: [
          Row(children: [
            // 그라디언트 차량 아이콘
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDriving
                      ? [Colors.orange.shade300, Colors.orange.shade600]
                      : [_teal, _tealDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: (isDriving ? Colors.orange : _teal)
                        .withOpacity(0.30),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(carIcon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(v.name,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1A1D2E))),
                const SizedBox(height: 3),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(v.plateNumber,
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.black.withOpacity(0.5),
                            fontWeight: FontWeight.w700)),
                  ),
                ]),
              ]),
            ),
            // 상태 뱃지
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDriving
                      ? [Colors.orange.shade300, Colors.orange.shade500]
                      : [Colors.green.shade300, Colors.green.shade500],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withOpacity(0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(statusIcon, color: Colors.white, size: 12),
                const SizedBox(width: 4),
                Text(statusLabel,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800)),
              ]),
            ),
          ]),

          // 운행 중 정보
          if (isDriving) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.orange.withOpacity(0.06),
                    Colors.orange.withOpacity(0.03),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Colors.orange.withOpacity(0.2)),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_rounded,
                      size: 14, color: Colors.orange),
                ),
                const SizedBox(width: 8),
                Text(v.currentLog!['full_name'] ?? '-',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.orange)),
                const SizedBox(width: 8),
                Container(
                    width: 1,
                    height: 12,
                    color: Colors.orange.withOpacity(0.3)),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded,
                    size: 14, color: Colors.orange),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${v.currentLog!['departure']} → '
                    '${v.currentLog!['destination']}',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.withOpacity(0.8),
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
            ),
          ],

          const SizedBox(height: 12),

          // ── 액션 버튼 ──
          //  • 운행 중이 아님       → "출발 기록"
          //  • 본인 운행 중         → "귀환 기록"
          //  • 다른 직원 운행 중    → "대신 도착 처리"  (누구나 누를 수 있음)
          if (!isDriving)
            _gradientActionBtn(
              label: '출발 기록',
              icon: Icons.play_arrow_rounded,
              colors: [Colors.green.shade400, Colors.green.shade600],
              shadowColor: Colors.green,
              onTap: () => _showDepartureSheet(v),
            )
          else if (isMyDriving)
            _gradientActionBtn(
              label: '귀환 기록',
              icon: Icons.flag_rounded,
              colors: [_teal, _tealDark],
              shadowColor: _teal,
              onTap: () => _showReturnSheet(v),
            )
          else
            _gradientActionBtn(
              label: '대신 도착 처리',
              icon: Icons.assignment_turned_in_rounded,
              colors: [Colors.deepOrange.shade400, Colors.deepOrange.shade700],
              shadowColor: Colors.deepOrange,
              onTap: () => _showReturnSheet(v),
            ),
        ]),
      ),
    );
  }

  Widget _gradientActionBtn({
    required String label,
    required IconData icon,
    required List<Color> colors,
    required Color shadowColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: shadowColor.withOpacity(0.30),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.22),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900)),
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
        onSubmit: (mileageAfter, destination) =>
            _submitReturn(v, mileageAfter, destination),
      ),
    );
  }

  Future<void> _submitReturn(
      _Vehicle v, int mileageAfter, String destination) async {
    try {
      final logId         = v.currentLog!['id'] as String;
      final mileageBefore = v.currentLog!['mileage_before'] as int;
      await supabase.from('vehicle_logs').update({
        'mileage_after': mileageAfter,
        'distance':      mileageAfter - mileageBefore,
        'return_time':   DateFormat('HH:mm').format(DateTime.now()),
        'status':        'DONE',
        'destination':   destination,   // ← 경유지 추가/경로 수정 반영
      }).eq('id', logId);
      await _loadData();
      _snack('귀환 기록 완료! 수고하셨습니다 ✅', color: _teal);
    } catch (e) {
      debugPrint('귀환 기록 실패: $e');
      _snack('오류가 발생했습니다.');
    }
  }

  IconData _vehicleIcon(String name) {
    if (name.contains('톤') ||
        name.contains('트럭') ||
        name.contains('봉고')) {
      return Icons.local_shipping_rounded;
    }
    if (name.contains('KONA') || name.contains('ELECTRIC')) {
      return Icons.electric_car_rounded;
    }
    return Icons.directions_car_rounded;
  }
}