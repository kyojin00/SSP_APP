part of 'vehicle_screen.dart';

// ══════════════════════════════════════════
// 주행 통계 화면
// ══════════════════════════════════════════

class VehicleStatsScreen extends StatefulWidget {
  final List<_Vehicle> vehicles;
  const VehicleStatsScreen({Key? key, required this.vehicles}) : super(key: key);

  @override
  State<VehicleStatsScreen> createState() => _VehicleStatsScreenState();
}

class _VehicleStatsScreenState extends State<VehicleStatsScreen>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  late TabController _tabCtrl;

  bool _isLoading = true;
  List<Map<String, dynamic>> _vehicleStats = [];
  List<Map<String, dynamic>> _driverStats  = [];
  int _totalTrips = 0;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadStats();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final logs = await supabase
          .from('vehicle_logs')
          .select()
          .eq('status', 'DONE')
          .not('distance', 'is', null)
          .order('use_date', ascending: false);

      final allLogs = List<Map<String, dynamic>>.from(logs);

      // ── 차량별: 마지막 계기판 + 누적 운행 거리 + 횟수
      final vehicleMap = <String, Map<String, dynamic>>{};
      for (final v in widget.vehicles) {
        vehicleMap[v.id] = {
          'name':         v.name,
          'plate':        v.plateNumber,
          'distance':     0,    // 누적 주행거리
          'trips':        0,
          'last_mileage': null, // 마지막 계기판
        };
      }
      // 날짜 내림차순으로 정렬됐으므로 첫 번째가 최신
      for (final log in allLogs) {
        final vid = log['vehicle_id'] as String? ?? '';
        if (!vehicleMap.containsKey(vid)) continue;

        final dist = log['distance'] as int? ?? 0;
        vehicleMap[vid]!['distance'] =
            (vehicleMap[vid]!['distance'] as int) + dist;
        vehicleMap[vid]!['trips'] =
            (vehicleMap[vid]!['trips'] as int) + 1;

        // 마지막 계기판 (첫 번째로 만나는 = 가장 최근 로그)
        if (vehicleMap[vid]!['last_mileage'] == null) {
          final after = log['mileage_after'] as int?;
          if (after != null) vehicleMap[vid]!['last_mileage'] = after;
        }
      }
      final vehicleStats = vehicleMap.values.toList()
        ..sort((a, b) =>
            (b['distance'] as int).compareTo(a['distance'] as int));

      // ── 운전자별
      final driverMap = <String, Map<String, dynamic>>{};
      for (final log in allLogs) {
        final name = log['full_name']     as String? ?? '-';
        final dept = log['dept_category'] as String? ?? '';
        driverMap.putIfAbsent(name, () => {
          'name': name, 'dept': dept, 'distance': 0, 'trips': 0,
        });
        driverMap[name]!['distance'] =
            (driverMap[name]!['distance'] as int) + (log['distance'] as int? ?? 0);
        driverMap[name]!['trips'] =
            (driverMap[name]!['trips'] as int) + 1;
      }
      final driverStats = driverMap.values.toList()
        ..sort((a, b) =>
            (b['distance'] as int).compareTo(a['distance'] as int));

      if (!mounted) return;
      setState(() {
        _vehicleStats = vehicleStats;
        _driverStats  = driverStats;
        _totalTrips   = allLogs.length;
        _isLoading    = false;
      });
    } catch (e) {
      debugPrint('통계 로드 실패: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F7),
      appBar: AppBar(
        title: const Text('주행 통계',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1D2E),
        elevation: 0,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadStats,
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: const Color(0xFF2E6BFF),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF2E6BFF),
          indicatorWeight: 3,
          dividerColor: Colors.transparent,
          tabs: const [
            Tab(text: '차량별'),
            Tab(text: '운전자별'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(
              color: Color(0xFF2E6BFF)))
          : Column(children: [
              // 총 운행 횟수만
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(children: [
                  const Icon(Icons.directions_car_rounded,
                      color: Colors.orange, size: 18),
                  const SizedBox(width: 8),
                  Text('총 운행',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: Colors.black.withOpacity(0.5))),
                  const SizedBox(width: 8),
                  Text('$_totalTrips회',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w900,
                          color: Colors.orange)),
                  const Spacer(),
                  Text('차량 ${widget.vehicles.length}대',
                      style: TextStyle(
                          fontSize: 12, color: Colors.black.withOpacity(0.35))),
                ]),
              ),
              Container(height: 1, color: const Color(0xFFF0F2F8)),
              Expanded(
                child: TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _vehicleTab(),
                    _driverTab(),
                  ],
                ),
              ),
            ]),
    );
  }

  // ── 차량별 탭 ──
  Widget _vehicleTab() {
    final maxDist = _vehicleStats.isEmpty ? 1
        : (_vehicleStats.first['distance'] as int).clamp(1, 999999);
    return RefreshIndicator(
      onRefresh: _loadStats,
      color: const Color(0xFF2E6BFF),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: _vehicleStats.map((s) {
          final lastMileage = s['last_mileage'] as int?;
          return _vehicleCard(
            name:         s['name']     as String,
            plate:        s['plate']    as String,
            distance:     s['distance'] as int,
            trips:        s['trips']    as int,
            ratio:        (s['distance'] as int) / maxDist,
            lastMileage:  lastMileage,
          );
        }).toList(),
      ),
    );
  }

  // ── 운전자별 탭 ──
  Widget _driverTab() {
    final maxDist = _driverStats.isEmpty ? 1
        : (_driverStats.first['distance'] as int).clamp(1, 999999);
    const colors = [
      Colors.orange, Color(0xFF2E6BFF), Color(0xFF7C5CDB),
      Colors.green, Colors.red,
    ];
    return RefreshIndicator(
      onRefresh: _loadStats,
      color: const Color(0xFF2E6BFF),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: _driverStats.asMap().entries.map((e) => _statCard(
          title:    e.value['name']     as String,
          subtitle: _deptLabel(e.value['dept'] as String),
          distance: e.value['distance'] as int,
          trips:    e.value['trips']    as int,
          ratio:    (e.value['distance'] as int) / maxDist,
          color:    colors[e.key % colors.length],
          icon:     Icons.person_rounded,
          rank:     e.key + 1,
        )).toList(),
      ),
    );
  }

  // ── 차량 카드 (마지막 계기판 포함) ──
  Widget _vehicleCard({
    required String name,
    required String plate,
    required int distance,
    required int trips,
    required double ratio,
    required int? lastMileage,
  }) {
    const color = Color(0xFF2E6BFF);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
                color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.directions_car_rounded,
                color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(name, style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w900,
                  color: Color(0xFF1A1D2E))),
              Text(plate, style: TextStyle(
                  fontSize: 11, color: Colors.black.withOpacity(0.4))),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('$distance km', style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w900, color: color)),
            Text('$trips회', style: TextStyle(
                fontSize: 11, color: Colors.black.withOpacity(0.4))),
          ]),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: color.withOpacity(0.08),
            valueColor: const AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        // 마지막 계기판
        if (lastMileage != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F6FB),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              Icon(Icons.speed_rounded, size: 14,
                  color: Colors.black.withOpacity(0.4)),
              const SizedBox(width: 6),
              Text('현재 계기판',
                  style: TextStyle(
                      fontSize: 11, color: Colors.black.withOpacity(0.4),
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(
                '${NumberFormat('#,###').format(lastMileage)} km',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1D2E)),
              ),
            ]),
          ),
        ],
      ]),
    );
  }

  // ── 운전자 카드 ──
  Widget _statCard({
    required String title,
    required String subtitle,
    required int distance,
    required int trips,
    required double ratio,
    required Color color,
    required IconData icon,
    int? rank,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (rank != null && rank <= 3)
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: [Colors.amber, Colors.grey.shade400,
                    Colors.brown.shade300][rank - 1].withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Center(child: Text('$rank',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w900,
                      color: [Colors.amber, Colors.grey.shade600,
                          Colors.brown][rank - 1]))),
            )
          else
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 18),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(title, style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w900,
                  color: Color(0xFF1A1D2E))),
              Text(subtitle, style: TextStyle(
                  fontSize: 11, color: Colors.black.withOpacity(0.4))),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('$distance km', style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w900, color: color)),
            Text('$trips회', style: TextStyle(
                fontSize: 11, color: Colors.black.withOpacity(0.4))),
          ]),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: color.withOpacity(0.08),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ]),
    );
  }

  String _deptLabel(String dept) {
    const m = {
      'MANAGEMENT': '관리부', 'PRODUCTION': '생산관리부',
      'SALES': '영업부', 'RND': '연구소', 'STEEL': '스틸생산부',
      'BOX': '박스생산부', 'DELIVERY': '포장납품부',
      'SSG': '에스에스지', 'CLEANING': '환경미화', 'NUTRITION': '영양사',
    };
    return m[dept] ?? dept;
  }
}