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

  // ── 주행 시간 계산 (HH:mm → "1시간 20분")
  int? _toMinutes(String s) {
    final p = s.split(':');
    if (p.length != 2) return null;
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  String? _drivingDuration(String depart, String ret) {
    if (depart.isEmpty || ret.isEmpty) return null;
    final d = _toMinutes(depart);
    final r = _toMinutes(ret);
    if (d == null || r == null) return null;
    var diff = r - d;
    if (diff < 0) diff += 24 * 60; // 자정 넘김 처리
    if (diff == 0) return null;
    final h = diff ~/ 60;
    final m = diff % 60;
    return h > 0 ? '${h}시간 ${m}분' : '${m}분';
  }

  // ══════════════════════════════════════════
  // 수정 / 삭제
  // ══════════════════════════════════════════

  void _showEditSheet(Map<String, dynamic> log) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LogEditSheet(
        log: log,
        vehicleName: widget.vehicle.name,
        onSubmit: (updates) =>
            _submitEdit(log['id'] as String, updates),
      ),
    );
  }

  Future<void> _submitEdit(
      String logId, Map<String, dynamic> updates) async {
    try {
      await supabase
          .from('vehicle_logs')
          .update(updates)
          .eq('id', logId);
      await _loadLogs();
      widget.onRefresh();
      if (!mounted) return;
      _toast('수정 완료 ✓', _teal);
    } catch (e) {
      debugPrint('수정 실패: $e');
      if (mounted) _toast('수정에 실패했습니다.', Colors.redAccent);
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> log) async {
    final dep = log['departure']   as String? ?? '-';
    final dst = log['destination'] as String? ?? '-';
    final dt  = log['use_date']    as String? ?? '-';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.delete_outline_rounded,
              color: Colors.redAccent, size: 22),
          SizedBox(width: 8),
          Text('운행 기록 삭제',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w900)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('이 기록을 삭제하시겠습니까?',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.04),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dt,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A1D2E))),
                  const SizedBox(height: 3),
                  Text('$dep → $dst',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.black.withOpacity(0.6),
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text('삭제하면 복구할 수 없습니다.',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w700)),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
                foregroundColor: Colors.grey,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8)),
            child: const Text('취소',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
            ),
            child: const Text('삭제',
                style: TextStyle(
                    fontWeight: FontWeight.w900, fontSize: 13)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await supabase
          .from('vehicle_logs')
          .delete()
          .eq('id', log['id'] as String);
      await _loadLogs();
      widget.onRefresh();
      if (!mounted) return;
      _toast('삭제 완료 ✓', _tealDark);
    } catch (e) {
      debugPrint('삭제 실패: $e');
      if (mounted) _toast('삭제에 실패했습니다.', Colors.redAccent);
    }
  }

  void _toast(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(fontWeight: FontWeight.w700)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      duration: const Duration(seconds: 2),
    ));
  }

  // ══════════════════════════════════════════
  // Excel export (기존 그대로)
  // ══════════════════════════════════════════

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
          xl.CellIndex.indexByString('N1'));
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
        '출발시간', '도착시간', '주행시간',
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
        final driveTime  = _drivingDuration(departTime, returnTime);
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
          xl.TextCellValue(driveTime ?? '-'),
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
          if ([10, 11, 12].contains(c) &&
              rowData[c] is xl.IntCellValue) {
            cell.cellStyle = numberStyle;
          } else if (c == 0 || c == 7 || c == 8 || c == 9) {
            cell.cellStyle = centerStyle;
          }
          if (i % 2 == 1) {
            cell.cellStyle = xl.CellStyle(
              backgroundColorHex:
                  xl.ExcelColor.fromHexString('#F8F9FC'),
              horizontalAlign: c == 0 || c == 7 || c == 8 || c == 9
                  ? xl.HorizontalAlign.Center
                  : [10, 11, 12].contains(c)
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
    final drivingTime = _drivingDuration(departTime, returnTime);

    // ── 본인 로그 여부 ──
    final myId    = supabase.auth.currentUser?.id;
    final isMyLog = myId != null && log['user_id'] == myId;

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
          // ── 상단: 날짜 + 운전자 + 상태 + 더보기 메뉴
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
                Row(children: [
                  Flexible(
                    child: Text(driver,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1A1D2E))),
                  ),
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
                  if (isMyLog) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: _primary.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Text('내 기록',
                          style: TextStyle(
                              fontSize: 9,
                              color: _primary,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -.1)),
                    ),
                  ],
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
                  if (drivingTime != null) ...[
                    const SizedBox(width: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.timer_outlined,
                            size: 10, color: Colors.black.withOpacity(0.45)),
                        const SizedBox(width: 3),
                        Text(drivingTime,
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.black.withOpacity(0.55))),
                      ]),
                    ),
                  ],
                ]),
              ]),
            ),
            // 주행거리 뱃지 / 운행 중
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

            // ── 본인 기록일 때만 더보기 메뉴 ──
            if (isMyLog) ...[
              const SizedBox(width: 4),
              SizedBox(
                width: 32, height: 32,
                child: PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  tooltip: '메뉴',
                  icon: Icon(Icons.more_vert_rounded,
                      size: 18, color: Colors.grey[500]),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 8,
                  onSelected: (value) {
                    if (value == 'edit')   _showEditSheet(log);
                    if (value == 'delete') _confirmDelete(log);
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem<String>(
                      value: 'edit',
                      height: 40,
                      child: Row(children: const [
                        Icon(Icons.edit_rounded,
                            size: 16, color: _primary),
                        SizedBox(width: 10),
                        Text('수정',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                      ]),
                    ),
                    PopupMenuItem<String>(
                      value: 'delete',
                      height: 40,
                      child: Row(children: const [
                        Icon(Icons.delete_outline_rounded,
                            size: 16, color: Colors.redAccent),
                        SizedBox(width: 10),
                        Text('삭제',
                            style: TextStyle(
                                fontSize: 13,
                                color: Colors.redAccent,
                                fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ],
                ),
              ),
            ],
          ]),

          const SizedBox(height: 10),
          Container(height: 1, color: Colors.black.withOpacity(0.05)),
          const SizedBox(height: 10),

          // ── 경로 + 목적
          Row(children: [
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

          // 계기판
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

// ══════════════════════════════════════════
// 운행 기록 수정 바텀시트
// ══════════════════════════════════════════

class _LogEditSheet extends StatefulWidget {
  final Map<String, dynamic> log;
  final String vehicleName;
  final Future<void> Function(Map<String, dynamic> updates) onSubmit;

  const _LogEditSheet({
    required this.log,
    required this.vehicleName,
    required this.onSubmit,
  });

  @override
  State<_LogEditSheet> createState() => _LogEditSheetState();
}

class _LogEditSheetState extends State<_LogEditSheet> {
  late final TextEditingController _departureCtrl;
  late final List<TextEditingController> _destCtrls;
  late final TextEditingController _purposeCtrl;
  late final TextEditingController _mileageBeforeCtrl;
  late final TextEditingController _mileageAfterCtrl;

  TimeOfDay? _departTime;
  TimeOfDay? _returnTime;

  bool _isLoading = false;
  bool get _isDone => widget.log['status'] == 'DONE';

  @override
  void initState() {
    super.initState();
    final log = widget.log;

    _departureCtrl     = TextEditingController(
        text: log['departure']      as String? ?? '');
    _purposeCtrl       = TextEditingController(
        text: log['purpose']        as String? ?? '');
    _mileageBeforeCtrl = TextEditingController(
        text: '${log['mileage_before'] ?? ''}');
    _mileageAfterCtrl  = TextEditingController(
        text: log['mileage_after']?.toString() ?? '');

    final destination = log['destination'] as String? ?? '';
    final destParts   = destination
        .split('→')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    _destCtrls = destParts.isEmpty
        ? [TextEditingController()]
        : destParts.map((d) => TextEditingController(text: d)).toList();

    _departTime = _parseTime(log['depart_time'] as String?);
    _returnTime = _parseTime(log['return_time'] as String?);
  }

  TimeOfDay? _parseTime(String? s) {
    if (s == null || s.isEmpty) return null;
    final parts = s.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  String _formatTime(TimeOfDay? t) {
    if (t == null) return '';
    return '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}';
  }

  String get _destinationText => _destCtrls
      .map((c) => c.text.trim())
      .where((s) => s.isNotEmpty)
      .join(' → ');

  void _addDest() =>
      setState(() => _destCtrls.add(TextEditingController()));

  void _removeDest(int i) {
    if (_destCtrls.length <= 1) return;
    _destCtrls[i].dispose();
    setState(() => _destCtrls.removeAt(i));
  }

  Future<void> _pickTime(bool isReturn) async {
    final initial = isReturn ? _returnTime : _departTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        if (isReturn) {
          _returnTime = picked;
        } else {
          _departTime = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (_departureCtrl.text.trim().isEmpty || _destinationText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('출발지와 도착지를 입력해주세요')));
      return;
    }
    final mileageBefore = int.tryParse(_mileageBeforeCtrl.text.trim());
    if (mileageBefore == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('출발 계기판을 숫자로 입력해주세요')));
      return;
    }
    int? mileageAfter;
    int? distance;
    if (_isDone) {
      mileageAfter = int.tryParse(_mileageAfterCtrl.text.trim());
      if (mileageAfter == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('도착 계기판을 숫자로 입력해주세요')));
        return;
      }
      if (mileageAfter < mileageBefore) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('도착 계기판은 출발보다 커야 합니다')));
        return;
      }
      distance = mileageAfter - mileageBefore;
    }

    final updates = <String, dynamic>{
      'departure':      _departureCtrl.text.trim(),
      'destination':    _destinationText,
      'purpose':        _purposeCtrl.text.trim(),
      'mileage_before': mileageBefore,
      'depart_time':    _formatTime(_departTime),
    };
    if (_isDone) {
      updates['mileage_after'] = mileageAfter;
      updates['distance']      = distance;
      updates['return_time']   = _formatTime(_returnTime);
    }

    setState(() => _isLoading = true);
    Navigator.pop(context);
    await widget.onSubmit(updates);
  }

  @override
  void dispose() {
    _departureCtrl.dispose();
    _purposeCtrl.dispose();
    _mileageBeforeCtrl.dispose();
    _mileageAfterCtrl.dispose();
    for (final c in _destCtrls) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: _DS.r24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SheetHeader(
            icon: Icons.edit_note_rounded,
            iconColor: _DS.primary,
            iconBg: const Color(0xFFDBEAFE),
            title: '운행 기록 수정',
            subtitle: widget.vehicleName,
            accentColor: _DS.primary,
          ),

          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottom),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 운행 중 안내
                  if (!_isDone) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.08),
                        borderRadius: _DS.r12,
                        border: Border.all(
                            color: Colors.orange.withOpacity(0.25)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.directions_car_rounded,
                            size: 14, color: Colors.orange),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text(
                            '운행 중인 기록은 출발 정보만 수정됩니다',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 16),
                  ],

                  _SectionLabel('경로'),
                  const SizedBox(height: 10),
                  _RouteEditCard(
                    departureCtrl: _departureCtrl,
                    destCtrls: _destCtrls,
                    onAddDest: _addDest,
                    onRemoveDest: _removeDest,
                  ),

                  const SizedBox(height: 20),
                  _SectionLabel('사용 목적'),
                  const SizedBox(height: 10),
                  _InputField(
                    controller: _purposeCtrl,
                    icon: Icons.description_outlined,
                    hint: '예: 거래처 방문',
                  ),

                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionLabel('출발 시간'),
                            const SizedBox(height: 10),
                            _TimePickerField(
                              time: _departTime,
                              onTap: () => _pickTime(false),
                            ),
                          ],
                        ),
                      ),
                      if (_isDone) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SectionLabel('도착 시간'),
                              const SizedBox(height: 10),
                              _TimePickerField(
                                time: _returnTime,
                                onTap: () => _pickTime(true),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionLabel('출발 계기판 (km)'),
                            const SizedBox(height: 10),
                            _InputField(
                              controller: _mileageBeforeCtrl,
                              icon: Icons.speed_rounded,
                              hint: '12345',
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (_isDone) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SectionLabel('도착 계기판 (km)'),
                              const SizedBox(height: 10),
                              _InputField(
                                controller: _mileageAfterCtrl,
                                icon: Icons.speed_rounded,
                                hint: '12380',
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 24),
                  _SubmitButton(
                    label: '저장하기',
                    icon: Icons.check_rounded,
                    color: _DS.primary,
                    isLoading: _isLoading,
                    onTap: _submit,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════
// 시간 선택 필드
// ══════════════════════════════════════════

class _TimePickerField extends StatelessWidget {
  final TimeOfDay? time;
  final VoidCallback onTap;

  const _TimePickerField({required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final label = time == null
        ? '시간 선택'
        : '${time!.hour.toString().padLeft(2, '0')}:'
          '${time!.minute.toString().padLeft(2, '0')}';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: _DS.bg,
          borderRadius: _DS.r12,
          border: Border.all(color: _DS.inkFaint.withOpacity(.6)),
        ),
        child: Row(children: [
          Icon(Icons.access_time_rounded, size: 18, color: _DS.inkMid),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: time == null ? _DS.inkFaint : _DS.ink,
            ),
          ),
        ]),
      ),
    );
  }
}