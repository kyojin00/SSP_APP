part of 'vehicle_screen.dart';

// ══════════════════════════════════════════
// 차량 일지 내역 화면
// ══════════════════════════════════════════

class VehicleLogHistoryScreen extends StatefulWidget {
  final _Vehicle vehicle;
  final Map<String, dynamic> userProfile;
  final bool isAdmin;
  final VoidCallback onRefresh;

  const VehicleLogHistoryScreen({
    Key? key,
    required this.vehicle,
    required this.userProfile,
    required this.isAdmin,
    required this.onRefresh,
  }) : super(key: key);

  @override
  State<VehicleLogHistoryScreen> createState() =>
      _VehicleLogHistoryScreenState();
}

class _VehicleLogHistoryScreenState
    extends State<VehicleLogHistoryScreen> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _logs = [];
  DateTime _selectedMonth = DateTime.now();

  static const _teal     = Color(0xFF00BFA5);
  static const _tealDark = Color(0xFF00897B);
  static const _primary  = Color(0xFF2E6BFF);

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    try {
      final from = DateFormat('yyyy-MM-dd').format(
          DateTime(_selectedMonth.year, _selectedMonth.month, 1));
      final to   = DateFormat('yyyy-MM-dd').format(
          DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0));

      final data = await supabase
          .from('vehicle_logs')
          .select()
          .eq('vehicle_id', widget.vehicle.id)
          .gte('use_date', from)
          .lte('use_date', to)
          .order('created_at', ascending: false);

      if (!mounted) return;
      setState(() {
        _logs      = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('일지 로드 실패: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _prevMonth() {
    setState(() {
      _selectedMonth =
          DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    });
    _loadLogs();
  }

  void _nextMonth() {
    final now = DateTime.now();
    if (_selectedMonth.year == now.year &&
        _selectedMonth.month == now.month) return;
    setState(() {
      _selectedMonth =
          DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    });
    _loadLogs();
  }

  String _deptLabel(String? dept) {
    const m = {
      'MANAGEMENT': '관리부', 'PRODUCTION': '생산관리부',
      'SALES':      '영업부', 'RND':        '연구소',
      'STEEL':      '스틸생산부', 'BOX':    '박스생산부',
      'DELIVERY':   '포장납품부', 'SSG':    '에스에스지',
      'CLEANING':   '환경미화',  'NUTRITION': '영양사',
    };
    return m[dept ?? ''] ?? (dept ?? '-');
  }

  // ── Excel export (기존 로직 그대로 유지)
  void _exportExcel() {
    try {
      final excel    = xl.Excel.createExcel();
      final sheetName =
          '${widget.vehicle.name}_${DateFormat('yyyy년MM월').format(_selectedMonth)}';
      final sheet = excel[sheetName];
      excel.delete('Sheet1');

      final headerStyle = xl.CellStyle(
        bold: true,
        backgroundColorHex: xl.ExcelColor.fromHexString('#2E6BFF'),
        fontColorHex: xl.ExcelColor.fromHexString('#FFFFFF'),
        horizontalAlign: xl.HorizontalAlign.Center,
        verticalAlign: xl.VerticalAlign.Center,
      );
      final centerStyle =
          xl.CellStyle(horizontalAlign: xl.HorizontalAlign.Center);
      final numberStyle = xl.CellStyle(
          horizontalAlign: xl.HorizontalAlign.Right,
          numberFormat: xl.NumFormat.custom(formatCode: '#,##0'));

      sheet.merge(xl.CellIndex.indexByString('A1'),
          xl.CellIndex.indexByString('M1'));
      final titleCell = sheet.cell(xl.CellIndex.indexByString('A1'));
      titleCell.value = xl.TextCellValue(
          '${widget.vehicle.name} (${widget.vehicle.plateNumber}) - '
          '${DateFormat('yyyy년 MM월').format(_selectedMonth)} 차량일지');
      titleCell.cellStyle = xl.CellStyle(
        bold: true, fontSize: 14,
        horizontalAlign: xl.HorizontalAlign.Center,
      );
      sheet.setRowHeight(0, 28);

      final headers = [
        'No', '날짜', '운전자', '부서',
        '출발지', '도착지', '사용목적',
        '출발시간', '도착시간',
        '출발계기판(km)', '도착계기판(km)', '주행거리(km)', '상태',
      ];
      for (var c = 0; c < headers.length; c++) {
        final cell = sheet.cell(
            xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 2));
        cell.value = xl.TextCellValue(headers[c]);
        cell.cellStyle = headerStyle;
      }
      sheet.setRowHeight(2, 22);

      int totalDistance = 0;
      for (var i = 0; i < _logs.length; i++) {
        final log        = _logs[i];
        final row        = i + 3;
        final isDone     = log['status'] == 'DONE';
        final distance   = log['distance'] as int?;
        final departTime = log['depart_time'] as String? ?? '';
        final returnTime = log['return_time'] as String? ?? '';
        if (distance != null) totalDistance += distance;

        final rowData = [
          xl.IntCellValue(i + 1),
          xl.TextCellValue(log['use_date'] ?? ''),
          xl.TextCellValue(log['full_name'] ?? '-'),
          xl.TextCellValue(_deptLabel(log['dept_category'] as String?)),
          xl.TextCellValue(log['departure'] ?? ''),
          xl.TextCellValue(log['destination'] ?? ''),
          xl.TextCellValue(log['purpose'] ?? ''),
          xl.TextCellValue(departTime),
          xl.TextCellValue(returnTime.isNotEmpty ? returnTime : '-'),
          xl.IntCellValue(log['mileage_before'] ?? 0),
          log['mileage_after'] != null
              ? xl.IntCellValue(log['mileage_after'] as int)
              : xl.TextCellValue('-'),
          distance != null
              ? xl.IntCellValue(distance)
              : xl.TextCellValue('-'),
          xl.TextCellValue(isDone ? '완료' : '운행중'),
        ];

        for (var c = 0; c < rowData.length; c++) {
          final cell = sheet.cell(
              xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row));
          cell.value = rowData[c];
          if ([9, 10, 11].contains(c) &&
              rowData[c] is xl.IntCellValue) {
            cell.cellStyle = numberStyle;
          } else if (c == 0 || c == 7 || c == 8) {
            cell.cellStyle = centerStyle;
          }
          if (i % 2 == 1) {
            cell.cellStyle = xl.CellStyle(
              backgroundColorHex:
                  xl.ExcelColor.fromHexString('#F8F9FC'),
              horizontalAlign: c == 0 || c == 7 || c == 8
                  ? xl.HorizontalAlign.Center
                  : [9, 10, 11].contains(c)
                      ? xl.HorizontalAlign.Right
                      : xl.HorizontalAlign.Left,
            );
          }
        }
      }

      final bytes = excel.encode();
      if (bytes == null) return;
      final blob = html.Blob([bytes],
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url    = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute(
            'download',
            '${widget.vehicle.name}_'
            '${DateFormat('yyyy년MM월').format(_selectedMonth)}_차량일지.xlsx')
        ..style.display = 'none';
      html.document.body!.append(anchor);
      anchor.click();
      anchor.remove();
      html.Url.revokeObjectUrl(url);
    } catch (e) {
      debugPrint('Excel 내보내기 실패: $e');
    }
  }

  // ══════════════════════════════════════════
  // Build
  // ══════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final totalDistance = _logs.fold<int>(
        0, (sum, l) => sum + ((l['distance'] as int?) ?? 0));

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── 그라디언트 SliverAppBar
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor: _tealDark,
            foregroundColor: Colors.white,
            title: Text(
              widget.vehicle.name,
              style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                  color: Colors.white),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 12),
                child: IconButton(
                  onPressed: _logs.isEmpty ? null : _exportExcel,
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.download_rounded,
                        color: Colors.white, size: 18),
                  ),
                  tooltip: '엑셀 다운로드',
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
                      width: 170, height: 170,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.07),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 80, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 차량 번호판
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.3)),
                          ),
                          child: Text(
                            widget.vehicle.plateNumber,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // 통계 3개
                        Row(children: [
                          _headerStat('운행 건수',
                              '${_logs.length}건', Colors.white),
                          Container(
                              width: 1,
                              height: 30,
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              color: Colors.white.withOpacity(0.25)),
                          _headerStat('총 주행거리',
                              '${totalDistance}km',
                              const Color(0xFF69F0AE)),
                        ]),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
          ),

          // ── 월 선택 바
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                GestureDetector(
                  onTap: _prevMonth,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _teal.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.chevron_left_rounded,
                        color: _tealDark, size: 22),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  DateFormat('yyyy년 MM월').format(_selectedMonth),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w900),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: _nextMonth,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _teal.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.chevron_right_rounded,
                        color: _tealDark, size: 22),
                  ),
                ),
              ]),
            ),
          ),

          // ── 로그 목록
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(
                  child: CircularProgressIndicator(color: _teal)),
            )
          else if (_logs.isEmpty)
            SliverFillRemaining(
              child: Center(
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
                            blurRadius: 14,
                            offset: const Offset(0, 4))
                      ],
                    ),
                    child: Icon(Icons.article_outlined,
                        size: 40, color: Colors.grey[300]),
                  ),
                  const SizedBox(height: 14),
                  Text('이번 달 운행 기록이 없습니다',
                      style: TextStyle(
                          color: Colors.black.withOpacity(0.35),
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                ]),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _logCard(_logs[i]),
                  childCount: _logs.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _headerStat(String label, String value, Color color) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value,
          style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w900, color: color)),
      Text(label,
          style: TextStyle(
              fontSize: 11,
              color: Colors.white.withOpacity(0.65),
              fontWeight: FontWeight.w600)),
    ]);
  }

  Widget _logCard(Map<String, dynamic> log) {
    final isDriving  = log['status'] == 'DRIVING';
    final date       = log['use_date']       as String? ?? '';
    final driver     = log['full_name']      as String? ?? '-';
    final departure  = log['departure']      as String? ?? '';
    final dest       = log['destination']    as String? ?? '';
    final purpose    = log['purpose']        as String? ?? '';
    final before     = log['mileage_before'] as int?    ?? 0;
    final after      = log['mileage_after']  as int?;
    final distance   = log['distance']       as int?;
    final departTime = log['depart_time']    as String? ?? '';
    final returnTime = log['return_time']    as String? ?? '';

    // 날짜 파싱
    String dateLabel = date;
    String weekday   = '';
    try {
      final d = DateTime.parse(date);
      dateLabel = DateFormat('MM/dd').format(d);
      weekday   = ['월', '화', '수', '목', '금', '토', '일'][d.weekday - 1];
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isDriving ? Colors.orange : _teal).withOpacity(0.10),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── 상단: 날짜 + 운전자 + 상태
          Row(children: [
            // 날짜 박스
            Container(
              width: 52,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDriving
                      ? [Colors.orange.shade300, Colors.orange.shade500]
                      : [_teal, _tealDark],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(children: [
                Text(dateLabel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Colors.white)),
                Text(weekday,
                    style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withOpacity(0.8),
                        fontWeight: FontWeight.w700)),
              ]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                // 운전자
                Row(children: [
                  Text(driver,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1A1D2E))),
                  const SizedBox(width: 6),
                  if (isDriving)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('운행 중',
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.orange,
                              fontWeight: FontWeight.w800)),
                    ),
                ]),
                const SizedBox(height: 3),
                // 시간
                Row(children: [
                  if (departTime.isNotEmpty) ...[
                    Icon(Icons.login_rounded,
                        size: 11, color: Colors.orange.shade400),
                    const SizedBox(width: 3),
                    Text(departTime,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.orange.shade400)),
                  ],
                  if (departTime.isNotEmpty && returnTime.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Icon(Icons.arrow_forward_rounded,
                          size: 10, color: Colors.grey[400]),
                    ),
                  if (returnTime.isNotEmpty) ...[
                    Icon(Icons.logout_rounded,
                        size: 11, color: _teal),
                    const SizedBox(width: 3),
                    Text(returnTime,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _teal)),
                  ],
                ]),
              ]),
            ),
            // 주행거리 뱃지
            if (distance != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_teal, _tealDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: _teal.withOpacity(0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Text('+$distance km',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900)),
              )
            else if (isDriving)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.orange.withOpacity(0.25)),
                ),
                child: const Text('운행 중',
                    style: TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                        fontWeight: FontWeight.w800)),
              ),
          ]),

          const SizedBox(height: 10),
          Container(height: 1, color: Colors.black.withOpacity(0.05)),
          const SizedBox(height: 10),

          // ── 경로 + 목적
          Row(children: [
            // 출발 → 도착
            Expanded(
              child: Row(children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade300, Colors.green.shade500],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.green.withOpacity(0.3),
                          blurRadius: 4,
                          spreadRadius: 1),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '$departure → $dest',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1D2E),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
            ),
            const SizedBox(width: 8),
            // 목적
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                purpose,
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.black.withOpacity(0.55),
                    fontWeight: FontWeight.w600),
              ),
            ),
          ]),

          // ── 계기판
          if (before > 0) ...[
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.speed_rounded,
                  size: 12, color: Colors.black.withOpacity(0.3)),
              const SizedBox(width: 5),
              Text(
                after != null
                    ? '$before km → $after km'
                    : '$before km → -',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.black.withOpacity(0.4),
                    fontWeight: FontWeight.w600),
              ),
            ]),
          ],
        ]),
      ),
    );
  }
}