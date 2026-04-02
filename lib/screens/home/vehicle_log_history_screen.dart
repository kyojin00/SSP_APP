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
      final to = DateFormat('yyyy-MM-dd').format(
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
        _logs = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('일지 로드 실패: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _exportExcel() {
    try {
      final excel = xl.Excel.createExcel();
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
      final subHeaderStyle = xl.CellStyle(
        bold: true,
        backgroundColorHex: xl.ExcelColor.fromHexString('#F0F2F7'),
        horizontalAlign: xl.HorizontalAlign.Center,
      );
      final centerStyle = xl.CellStyle(
          horizontalAlign: xl.HorizontalAlign.Center);
      final numberStyle = xl.CellStyle(
          horizontalAlign: xl.HorizontalAlign.Right,
          numberFormat: xl.NumFormat.custom(formatCode: '#,##0'));

      // 제목
      sheet.merge(
          xl.CellIndex.indexByString('A1'),
          xl.CellIndex.indexByString('M1'));
      final titleCell = sheet.cell(xl.CellIndex.indexByString('A1'));
      titleCell.value = xl.TextCellValue(
          '${widget.vehicle.name} (${widget.vehicle.plateNumber}) - '
          '${DateFormat('yyyy년 MM월').format(_selectedMonth)} 차량일지');
      titleCell.cellStyle = xl.CellStyle(
        bold: true,
        fontSize: 14,
        horizontalAlign: xl.HorizontalAlign.Center,
      );
      sheet.setRowHeight(0, 28);

      // 컬럼 헤더 (출발시간·도착시간 추가)
      final headers = [
        'No', '날짜', '운전자', '부서',
        '출발지', '도착지', '사용목적',
        '출발시간', '도착시간',                          // ← 추가
        '출발계기판(km)', '도착계기판(km)', '주행거리(km)', '상태',
      ];
      for (var c = 0; c < headers.length; c++) {
        final cell = sheet.cell(
            xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 2));
        cell.value = xl.TextCellValue(headers[c]);
        cell.cellStyle = headerStyle;
      }
      sheet.setRowHeight(2, 22);

      // 데이터
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
          xl.IntCellValue(i + 1),                                      // No
          xl.TextCellValue(log['use_date'] ?? ''),                     // 날짜
          xl.TextCellValue(log['full_name'] ?? '-'),                   // 운전자
          xl.TextCellValue(_deptLabel(log['dept_category'] ?? '')),    // 부서
          xl.TextCellValue(log['departure'] ?? ''),                    // 출발지
          xl.TextCellValue(log['destination'] ?? ''),                  // 도착지
          xl.TextCellValue(log['purpose'] ?? ''),                      // 사용목적
          xl.TextCellValue(departTime),                                // 출발시간 ← 추가
          xl.TextCellValue(returnTime.isNotEmpty ? returnTime : '-'),  // 도착시간 ← 추가
          xl.IntCellValue(log['mileage_before'] ?? 0),                 // 출발계기판
          log['mileage_after'] != null
              ? xl.IntCellValue(log['mileage_after'] as int)
              : xl.TextCellValue('-'),                                 // 도착계기판
          distance != null
              ? xl.IntCellValue(distance)
              : xl.TextCellValue('-'),                                 // 주행거리
          xl.TextCellValue(isDone ? '완료' : '운행중'),                 // 상태
        ];

        for (var c = 0; c < rowData.length; c++) {
          final cell = sheet.cell(
              xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row));
          cell.value = rowData[c];
          // 숫자 컬럼 (출발계기판:9, 도착계기판:10, 주행거리:11)
          if ([9, 10, 11].contains(c) && rowData[c] is xl.IntCellValue) {
            cell.cellStyle = numberStyle;
          } else if (c == 0 || c == 7 || c == 8) {
            // No, 출발시간, 도착시간 → 가운데 정렬
            cell.cellStyle = centerStyle;
          }
          if (i % 2 == 1) {
            cell.cellStyle = xl.CellStyle(
              backgroundColorHex: xl.ExcelColor.fromHexString('#F8F9FC'),
              horizontalAlign: c == 0 || c == 7 || c == 8
                  ? xl.HorizontalAlign.Center
                  : [9, 10, 11].contains(c)
                      ? xl.HorizontalAlign.Right
                      : xl.HorizontalAlign.Left,
            );
          }
        }
      }

      // 합계 행
      final sumRow = _logs.length + 3;
      sheet.merge(
        xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: sumRow),
        xl.CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: sumRow),
      );
      final sumLabelCell = sheet.cell(
          xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: sumRow));
      sumLabelCell.value =
          xl.TextCellValue('총 ${_logs.length}건 운행');
      sumLabelCell.cellStyle = subHeaderStyle;

      final sumCell = sheet.cell(
          xl.CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: sumRow));
      sumCell.value = xl.IntCellValue(totalDistance);
      sumCell.cellStyle = xl.CellStyle(
        bold: true,
        backgroundColorHex: xl.ExcelColor.fromHexString('#F0F2F7'),
        horizontalAlign: xl.HorizontalAlign.Right,
        numberFormat: xl.NumFormat.custom(formatCode: '#,##0'),
      );

      final sumUnitCell = sheet.cell(
          xl.CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: sumRow));
      sumUnitCell.value = xl.TextCellValue('km');
      sumUnitCell.cellStyle = subHeaderStyle;

      // 컬럼 너비 (출발시간·도착시간 컬럼 추가)
      final colWidths = [
        6.0,  // No
        12.0, // 날짜
        10.0, // 운전자
        12.0, // 부서
        14.0, // 출발지
        14.0, // 도착지
        18.0, // 사용목적
        10.0, // 출발시간 ← 추가
        10.0, // 도착시간 ← 추가
        16.0, // 출발계기판
        16.0, // 도착계기판
        14.0, // 주행거리
        8.0,  // 상태
      ];
      for (var c = 0; c < colWidths.length; c++) {
        sheet.setColumnWidth(c, colWidths[c]);
      }

      // 다운로드
      final bytes = excel.encode()!;
      final blob  = html.Blob(
          [Uint8List.fromList(bytes)],
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url    = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download',
            '차량일지_${widget.vehicle.name}_'
            '${DateFormat('yyyyMM').format(_selectedMonth)}.xlsx')
        ..click();
      html.Url.revokeObjectUrl(url);

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('엑셀 다운로드 완료 ✅',
            style: TextStyle(fontWeight: FontWeight.w700)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      ));
    } catch (e) {
      debugPrint('엑셀 export 실패: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('다운로드 실패: $e',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.redAccent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      ));
    }
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

  void _prevMonth() {
    setState(() => _selectedMonth =
        DateTime(_selectedMonth.year, _selectedMonth.month - 1));
    _loadLogs();
  }

  void _nextMonth() {
    final now = DateTime.now();
    if (_selectedMonth.year == now.year &&
        _selectedMonth.month == now.month) return;
    setState(() => _selectedMonth =
        DateTime(_selectedMonth.year, _selectedMonth.month + 1));
    _loadLogs();
  }

  @override
  Widget build(BuildContext context) {
    final totalDistance = _logs
        .where((l) => l['distance'] != null)
        .fold<int>(0, (sum, l) => sum + (l['distance'] as int));

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F7),
      appBar: AppBar(
        title: Text(widget.vehicle.name,
            style: const TextStyle(
                fontWeight: FontWeight.w900, fontSize: 17)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1D2E),
        elevation: 0,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _logs.isEmpty ? null : _exportExcel,
            icon: const Icon(Icons.download_rounded),
            tooltip: '엑셀 다운로드',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child:
              Container(height: 1, color: const Color(0xFFF0F2F8)),
        ),
      ),
      body: Column(children: [
        // 월 선택 + 통계
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(
                onPressed: _prevMonth,
                icon: const Icon(Icons.chevron_left_rounded),
                padding: EdgeInsets.zero,
              ),
              Text(DateFormat('yyyy년 MM월').format(_selectedMonth),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w900)),
              IconButton(
                onPressed: _nextMonth,
                icon: const Icon(Icons.chevron_right_rounded),
                padding: EdgeInsets.zero,
              ),
            ]),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
              _statChip('운행 건수', '${_logs.length}건', Colors.orange),
              _statChip('총 주행거리', '${totalDistance}km',
                  const Color(0xFF2E6BFF)),
            ]),
          ]),
        ),
        // 목록
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(
                  color: Color(0xFF2E6BFF)))
              : _logs.isEmpty
                  ? Center(
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                        Icon(Icons.article_outlined,
                            size: 48,
                            color: Colors.grey.withOpacity(0.4)),
                        const SizedBox(height: 12),
                        Text('이번 달 운행 기록이 없습니다',
                            style: TextStyle(
                                color: Colors.black.withOpacity(0.35),
                                fontWeight: FontWeight.w600)),
                      ]))
                  : RefreshIndicator(
                      color: const Color(0xFF2E6BFF),
                      onRefresh: _loadLogs,
                      child: ListView.builder(
                        padding:
                            const EdgeInsets.fromLTRB(16, 16, 16, 40),
                        itemCount: _logs.length,
                        itemBuilder: (_, i) => _logCard(_logs[i]),
                      ),
                    ),
        ),
      ]),
    );
  }

  Widget _statChip(String label, String value, Color color) {
    return Column(children: [
      Text(value,
          style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: color)),
      Text(label,
          style: TextStyle(
              fontSize: 11,
              color: Colors.black.withOpacity(0.4),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDriving
                ? Colors.orange.withOpacity(0.3)
                : Colors.transparent),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child:
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(date,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1D2E))),
            const SizedBox(height: 2),
            Row(children: [
              if (departTime.isNotEmpty) ...[
                const Icon(Icons.login_rounded,
                    size: 11, color: Colors.orange),
                const SizedBox(width: 3),
                Text(departTime,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.orange)),
              ],
              if (departTime.isNotEmpty && returnTime.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.arrow_forward_rounded,
                      size: 10, color: Colors.grey),
                ),
              if (returnTime.isNotEmpty) ...[
                const Icon(Icons.logout_rounded,
                    size: 11, color: Color(0xFF2E6BFF)),
                const SizedBox(width: 3),
                Text(returnTime,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2E6BFF))),
              ],
              if (isDriving && departTime.isNotEmpty) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4)),
                  child: const Text('운행 중',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.orange)),
                ),
              ],
            ]),
          ]),
          const Spacer(),
          if (isDriving)
            _badge('운행 중', Colors.orange)
          else if (distance != null)
            _badge('$distance km', const Color(0xFF2E6BFF)),
        ]),
        const SizedBox(height: 8),
        _iconRow(Icons.person_rounded, driver),
        const SizedBox(height: 3),
        _iconRow(Icons.arrow_forward_rounded, '$departure → $dest',
            ellipsis: true),
        const SizedBox(height: 3),
        _iconRow(Icons.description_rounded, purpose),
        const SizedBox(height: 8),
        Divider(height: 1, color: Colors.black.withOpacity(0.05)),
        const SizedBox(height: 8),
        Row(children: [
          _mileageChip('출발', '$before km', Colors.orange),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward_rounded,
              size: 14, color: Colors.grey),
          const SizedBox(width: 8),
          _mileageChip(
              '도착',
              after != null ? '$after km' : '미기록',
              after != null
                  ? const Color(0xFF2E6BFF)
                  : Colors.grey),
        ]),
      ]),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8)),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800)),
    );
  }

  Widget _iconRow(IconData icon, String text,
      {bool ellipsis = false}) {
    return Row(children: [
      Icon(icon, size: 13, color: Colors.grey),
      const SizedBox(width: 4),
      ellipsis
          ? Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 12, color: Colors.grey),
                  overflow: TextOverflow.ellipsis))
          : Text(text,
              style:
                  const TextStyle(fontSize: 12, color: Colors.grey)),
    ]);
  }

  Widget _mileageChip(String label, String value, Color color) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8)),
      child:
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(
                fontSize: 9,
                color: color.withOpacity(0.6),
                fontWeight: FontWeight.w700)),
        Text(value,
            style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w800)),
      ]),
    );
  }
}