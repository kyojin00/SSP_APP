// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as xl;
// excel 패키지에서 Flutter와 충돌 없는 것들만 직접 사용
import 'package:excel/excel.dart' show Excel, Sheet, CellIndex, TextCellValue, IntCellValue, DoubleCellValue, CellStyle, ExcelColor, HorizontalAlign, VerticalAlign;

class ExcelExportScreen extends StatefulWidget {
  const ExcelExportScreen({Key? key}) : super(key: key);
  @override
  State<ExcelExportScreen> createState() => _ExcelExportScreenState();
}

class _ExcelExportScreenState extends State<ExcelExportScreen> {
  final supabase = Supabase.instance.client;

  static const _bg   = Color(0xFFF4F6FB);
  static const _text = Color(0xFF1A1D2E);
  static const _sub  = Color(0xFF8A93B0);

  final Map<String, bool> _loading = {
    'employees': false,
    'attendance': false,
    'meal': false,
    'leave': false,
    'dorm': false,
    'combined': false,
  };
  final Set<String> _running = {};

  // ── 기간 범위
  int _startYear  = DateTime.now().year;
  int _startMonth = DateTime.now().month;
  int _endYear    = DateTime.now().year;
  int _endMonth   = DateTime.now().month;

  bool _isDownloading = false;

  static const _deptMap = {
    'MANAGEMENT': '관리부',
    'PRODUCTION': '생산관리부',
    'SALES':      '영업부',
    'RND':        '연구소',
    'STEEL':      '스틸생산부',
    'BOX':        '박스생산부',
    'DELIVERY':   '포장납품부',
    'SSG':        '에스에스지',
    'CLEANING':   '환경미화',
    'NUTRITION':  '영양사',
  };
  String _dept(String? d) => _deptMap[d ?? ''] ?? (d ?? '-');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text("엑셀 내보내기",
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: _text,
        elevation: 0,
        surfaceTintColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFF0F2F8)),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 48),
        children: [
          _rangePicker(),
          const SizedBox(height: 20),
          _card(
            keyName: 'employees',
            color: const Color(0xFF2E6BFF),
            icon: Icons.people_rounded,
            title: "직원 목록",
            desc: "전체 직원 · 부서 · 연차 · 국적",
            onTap: _exportEmployees,
          ),
          _card(
            keyName: 'attendance',
            color: Colors.green,
            icon: Icons.punch_clock_rounded,
            title: "근태 기록",
            desc: "$_rangeLabel · 개인별 출근율 + 일별",
            onTap: _exportAttendance,
          ),
          _card(
            keyName: 'meal',
            color: Colors.deepOrange,
            icon: Icons.restaurant_rounded,
            title: "식수 현황",
            desc: "$_rangeLabel · 일요일 제외 · 개인별 집계",
            onTap: _exportMeal,
          ),
          _card(
            keyName: 'leave',
            color: const Color(0xFF00BCD4),
            icon: Icons.edit_calendar_rounded,
            title: "휴가 신청 내역",
            desc: "$_rangeLabel · 연차/반차/공가/경조사",
            onTap: _exportLeave,
          ),
          _card(
            keyName: 'dorm',
            color: Colors.purple,
            icon: Icons.hotel_rounded,
            title: "기숙사 현황",
            desc: "전체 입주자 · 호실 배정 현황",
            onTap: _exportDorm,
          ),
          const SizedBox(height: 8),
          _card(
            keyName: 'combined',
            color: const Color(0xFFD81B60),
            icon: Icons.layers_rounded,
            title: "통합 기록 (식수 + 근태 + 휴가)",
            desc: "$_rangeLabel · 한 파일에 모두 포함",
            onTap: _exportCombined,
            highlight: true,
          ),
        ],
      ),
    );
  }

  // ── 기간 범위 선택 위젯
  Widget _rangePicker() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: const [
            Icon(Icons.date_range_rounded, size: 16, color: Color(0xFF2E6BFF)),
            SizedBox(width: 8),
            Text("기간 선택",
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: _text)),
          ]),
          const SizedBox(height: 12),
          _pickerRow(
            label: '시작',
            year: _startYear,
            month: _startMonth,
            onYear: (v) => setState(() {
              _startYear = v!;
              _fixRange();
            }),
            onMonth: (v) => setState(() {
              _startMonth = v!;
              _fixRange();
            }),
          ),
          const SizedBox(height: 8),
          _pickerRow(
            label: '종료',
            year: _endYear,
            month: _endMonth,
            onYear: (v) => setState(() {
              _endYear = v!;
              _fixRange();
            }),
            onMonth: (v) => setState(() {
              _endMonth = v!;
              _fixRange();
            }),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF3FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded, size: 13, color: Color(0xFF2E6BFF)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '$_monthsCount개월 · 평일 ${_weekdaysInRange}일 · 식당운영 ${_mealServingDaysInRange}일',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF2E6BFF)),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _pickerRow({
    required String label,
    required int year,
    required int month,
    required void Function(int?) onYear,
    required void Function(int?) onMonth,
  }) {
    return Row(children: [
      Container(
        width: 40,
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F2F8),
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _text)),
      ),
      const Spacer(),
      _drop<int>(
        value: year,
        items: List.generate(4, (i) => DateTime.now().year - i),
        label: (v) => '$v년',
        onChanged: onYear,
      ),
      const SizedBox(width: 8),
      _drop<int>(
        value: month,
        items: List.generate(12, (i) => i + 1),
        label: (v) => '$v월',
        onChanged: onMonth,
      ),
    ]);
  }

  void _fixRange() {
    final start = _startYear * 100 + _startMonth;
    final end   = _endYear   * 100 + _endMonth;
    if (start > end) {
      _endYear  = _startYear;
      _endMonth = _startMonth;
    }
  }

  Widget _card({
    required String keyName,
    required Color color,
    required IconData icon,
    required String title,
    required String desc,
    required Future<void> Function() onTap,
    bool highlight = false,
  }) {
    final busy = _loading[keyName] ?? false;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        gradient: highlight
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color.withOpacity(0.06), color.withOpacity(0.02)],
              )
            : null,
        color: highlight ? null : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: highlight ? Border.all(color: color.withOpacity(0.25), width: 1.2) : null,
        boxShadow: [
          BoxShadow(
            color: highlight ? color.withOpacity(0.12) : Colors.black.withOpacity(0.04),
            blurRadius: highlight ? 12 : 8,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 22)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: _text)),
          const SizedBox(height: 3),
          Text(desc, style: const TextStyle(fontSize: 12, color: _sub)),
        ])),
        const SizedBox(width: 8),
        busy
            ? const SizedBox(width: 24, height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5))
            : ElevatedButton.icon(
                onPressed: (busy || _isDownloading)
                    ? null
                    : () => _runOnce(keyName, onTap),
                icon: const Icon(Icons.download_rounded, size: 14),
                label: const Text("다운로드",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
      ]),
    );
  }

  Widget _drop<T>({
    required T value, required List<T> items,
    required String Function(T) label, required void Function(T?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE0E5F0))),
      child: DropdownButton<T>(
        value: value, underline: const SizedBox(), isDense: true,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _text),
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(label(e)))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  void _busy(String key, bool v) {
    if (mounted) setState(() => _loading[key] = v);
  }

  Future<void> _runOnce(String key, Future<void> Function() job) async {
    if (_running.contains(key)) return;
    _running.add(key);
    try { await job(); } finally { _running.remove(key); }
  }

  void _err(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
      backgroundColor: Colors.redAccent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ));
  }

  // 페이지네이션 (Supabase 1000행 limit 우회)
  Future<List<Map<String, dynamic>>> _fetchAllInRange({
    required String table,
    required String columns,
    required String dateColumn,
  }) async {
    const pageSize = 1000;
    final all = <Map<String, dynamic>>[];
    int from = 0;
    while (true) {
      final res = await supabase
          .from(table)
          .select(columns)
          .gte(dateColumn, _rangeFrom)
          .lte(dateColumn, _rangeTo)
          .order(dateColumn, ascending: true)
          .range(from, from + pageSize - 1);
      final list = List<Map<String, dynamic>>.from(res as List);
      all.addAll(list);
      if (list.length < pageSize) break;
      from += pageSize;
    }
    return all;
  }

  void _headers(Sheet s, List<String> hs, {String hexColor = 'FF2E6BFF'}) {
    for (var i = 0; i < hs.length; i++) {
      final cell = s.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(hs[i]);
      cell.cellStyle = CellStyle(
        bold: true,
        fontSize: 11,
        fontColorHex: ExcelColor.fromHexString('FFFFFFFF'),
        backgroundColorHex: ExcelColor.fromHexString(hexColor),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        leftBorder:   xl.Border(borderStyle: xl.BorderStyle.Thin,
            borderColorHex: ExcelColor.fromHexString('FFCFD8DC')),
        rightBorder:  xl.Border(borderStyle: xl.BorderStyle.Thin,
            borderColorHex: ExcelColor.fromHexString('FFCFD8DC')),
        bottomBorder: xl.Border(borderStyle: xl.BorderStyle.Medium,
            borderColorHex: ExcelColor.fromHexString('FF000000')),
        topBorder:    xl.Border(borderStyle: xl.BorderStyle.Thin,
            borderColorHex: ExcelColor.fromHexString('FFCFD8DC')),
      );
    }
  }

  void _row(Sheet s, int r, List<dynamic> vals) {
    final isEven = r % 2 == 0;
    final bgHex  = isEven ? 'FFF5F7FF' : 'FFFFFFFF';
    for (var i = 0; i < vals.length; i++) {
      final cell = s.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: r));
      final v = vals[i];
      cell.value = v is int
          ? IntCellValue(v)
          : v is double
              ? DoubleCellValue(v)
              : TextCellValue(v?.toString() ?? '-');
      cell.cellStyle = CellStyle(
        fontSize: 10,
        backgroundColorHex: ExcelColor.fromHexString(bgHex),
        horizontalAlign: v is num ? HorizontalAlign.Center : HorizontalAlign.Left,
        verticalAlign: VerticalAlign.Center,
        leftBorder:   xl.Border(borderStyle: xl.BorderStyle.Thin,
            borderColorHex: ExcelColor.fromHexString('FFE0E5F0')),
        rightBorder:  xl.Border(borderStyle: xl.BorderStyle.Thin,
            borderColorHex: ExcelColor.fromHexString('FFE0E5F0')),
        bottomBorder: xl.Border(borderStyle: xl.BorderStyle.Thin,
            borderColorHex: ExcelColor.fromHexString('FFE0E5F0')),
        topBorder:    xl.Border(borderStyle: xl.BorderStyle.Thin,
            borderColorHex: ExcelColor.fromHexString('FFE0E5F0')),
      );
    }
  }

  void _rowHeights(Sheet s, int rowCount,
      {double header = 22, double data = 18}) {
    s.setRowHeight(0, header);
    for (var i = 1; i <= rowCount; i++) s.setRowHeight(i, data);
  }

  void _widths(Sheet s, List<double> ws) {
    for (var i = 0; i < ws.length; i++) s.setColumnWidth(i, ws[i]);
  }

  void _download(Excel excel, String name) {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);
    String? url;
    try {
      final bytes = excel.encode();
      if (bytes == null) throw Exception('저장 실패');
      final blob = html.Blob([bytes],
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', name)
        ..style.display = 'none';
      html.document.body!.append(anchor);
      anchor.click();
      anchor.remove();
    } catch (e) {
      _err('파일 다운로드 중 오류가 발생했습니다.');
    } finally {
      if (url != null) html.Url.revokeObjectUrl(url);
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _isDownloading = false);
      });
    }
  }

  // ── 기간 헬퍼
  String _two(int n) => n.toString().padLeft(2, '0');

  String get _rangeFrom => '$_startYear-${_two(_startMonth)}-01';
  String get _rangeTo {
    final last = DateUtils.getDaysInMonth(_endYear, _endMonth);
    return '$_endYear-${_two(_endMonth)}-${_two(last)}';
  }

  String get _rangeYm {
    final s = '$_startYear${_two(_startMonth)}';
    final e = '$_endYear${_two(_endMonth)}';
    return s == e ? s : '${s}_$e';
  }

  String get _rangeLabel {
    if (_startYear == _endYear && _startMonth == _endMonth) {
      return '$_startYear년 $_startMonth월';
    }
    if (_startYear == _endYear) {
      return '$_startYear년 $_startMonth월 ~ $_endMonth월';
    }
    return '$_startYear년 $_startMonth월 ~ $_endYear년 $_endMonth월';
  }

  int get _monthsCount =>
      (_endYear - _startYear) * 12 + (_endMonth - _startMonth) + 1;

  int get _totalDaysInRange {
    final start = DateTime(_startYear, _startMonth, 1);
    final endLast = DateUtils.getDaysInMonth(_endYear, _endMonth);
    final end = DateTime(_endYear, _endMonth, endLast);
    return end.difference(start).inDays + 1;
  }

  // 평일(월~금) 수
  int get _weekdaysInRange {
    int days = 0;
    var current = DateTime(_startYear, _startMonth, 1);
    final endLast = DateUtils.getDaysInMonth(_endYear, _endMonth);
    final end = DateTime(_endYear, _endMonth, endLast);
    while (!current.isAfter(end)) {
      if (current.weekday != DateTime.saturday &&
          current.weekday != DateTime.sunday) {
        days++;
      }
      current = current.add(const Duration(days: 1));
    }
    return days;
  }

  // ── 식당 운영일 (일요일 제외)
  int get _mealServingDaysInRange {
    int days = 0;
    var current = DateTime(_startYear, _startMonth, 1);
    final endLast = DateUtils.getDaysInMonth(_endYear, _endMonth);
    final end = DateTime(_endYear, _endMonth, endLast);
    while (!current.isAfter(end)) {
      if (current.weekday != DateTime.sunday) days++;
      current = current.add(const Duration(days: 1));
    }
    return days;
  }

  // 날짜 문자열이 일요일인지 검사
  bool _isSundayDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return false;
    try {
      final d = DateTime.parse(dateStr);
      return d.weekday == DateTime.sunday;
    } catch (_) {
      return false;
    }
  }

  String get _todayStamp => DateFormat('yyyyMMdd').format(DateTime.now());

  // ╔════════════════════════════════════════════
  // ║ 1. 직원 목록
  // ╚════════════════════════════════════════════
  Future<void> _exportEmployees() async {
    if (_loading['employees'] == true) return;
    _busy('employees', true);
    try {
      final rows = await supabase
          .from('profiles')
          .select('full_name, dept_category, position, role, total_leave, used_leave, nationality, email')
          .order('dept_category', ascending: true)
          .order('full_name', ascending: true);

      final excel = Excel.createExcel();
      final s = excel['직원목록'];
      excel.delete('Sheet1');

      _writeEmployees(s, List<Map<String, dynamic>>.from(rows));
      _download(excel, '직원목록_$_todayStamp.xlsx');
    } catch (e) {
      _err('직원 목록 실패: $e');
    } finally {
      _busy('employees', false);
    }
  }

  // ╔════════════════════════════════════════════
  // ║ 2. 근태 기록
  // ╚════════════════════════════════════════════
  Future<void> _exportAttendance() async {
    if (_loading['attendance'] == true) return;
    _busy('attendance', true);
    try {
      final results = await Future.wait([
        supabase.from('profiles')
            .select('id, full_name, dept_category')
            .order('full_name', ascending: true),
        _fetchAllInRange(
          table: 'attendance',
          columns: 'user_id, full_name, dept_category, work_date, check_in, check_out',
          dateColumn: 'work_date',
        ),
      ]);

      final profiles   = List<Map<String, dynamic>>.from(results[0] as List);
      final attendance = results[1] as List<Map<String, dynamic>>;

      final excel = Excel.createExcel();
      final s1 = excel['개인별 집계'];
      excel.delete('Sheet1');
      _writeAttendanceSummary(s1, profiles, attendance);

      final s2 = excel['일별 원본'];
      _writeAttendance(s2, attendance);

      _download(excel, '근태기록_${_rangeYm}_$_todayStamp.xlsx');
    } catch (e) {
      _err('근태 기록 실패: $e');
    } finally {
      _busy('attendance', false);
    }
  }

  // ╔════════════════════════════════════════════
  // ║ 3. 식수 현황
  // ╚════════════════════════════════════════════
  Future<void> _exportMeal() async {
    if (_loading['meal'] == true) return;
    _busy('meal', true);
    try {
      final results = await Future.wait([
        supabase.from('profiles')
            .select('id, full_name, dept_category')
            .order('full_name', ascending: true),
        _fetchAllInRange(
          table: 'meal_requests',
          columns: 'user_id, full_name, dept_category, meal_date, meal_type, is_eating',
          dateColumn: 'meal_date',
        ),
      ]);

      final profiles = List<Map<String, dynamic>>.from(results[0] as List);
      final meals    = results[1] as List<Map<String, dynamic>>;

      final excel = Excel.createExcel();
      final s1 = excel['개인별 집계'];
      excel.delete('Sheet1');
      _writeMealSummary(s1, profiles, meals);

      final s2 = excel['일별 원본'];
      _writeMealDaily(s2, meals);

      _download(excel, '식수현황_${_rangeYm}_$_todayStamp.xlsx');
    } catch (e) {
      _err('식수 현황 실패: $e');
    } finally {
      _busy('meal', false);
    }
  }

  // ╔════════════════════════════════════════════
  // ║ 4. 휴가 신청
  // ╚════════════════════════════════════════════
  Future<void> _exportLeave() async {
    if (_loading['leave'] == true) return;
    _busy('leave', true);
    try {
      final rows = await _fetchAllInRange(
        table: 'leave_requests',
        columns: 'full_name, dept_category, start_date, end_date, leave_days, leave_type, reason, status',
        dateColumn: 'start_date',
      );

      final excel = Excel.createExcel();
      final s = excel['휴가내역'];
      excel.delete('Sheet1');

      _writeLeave(s, rows);
      _download(excel, '휴가내역_${_rangeYm}_$_todayStamp.xlsx');
    } catch (e) {
      _err('휴가 내역 실패: $e');
    } finally {
      _busy('leave', false);
    }
  }

  // ╔════════════════════════════════════════════
  // ║ 5. 기숙사 현황
  // ╚════════════════════════════════════════════
  Future<void> _exportDorm() async {
    if (_loading['dorm'] == true) return;
    _busy('dorm', true);
    try {
      final results = await Future.wait([
        supabase.from('dorm_residents').select('*').order('room_id', ascending: true),
        supabase.from('dorm_rooms').select('*').order('room_number', ascending: true),
        supabase.from('profiles').select('id, dept_category, nationality').order('id'),
      ]);

      final residents = List<Map<String, dynamic>>.from(results[0] as List);
      final rooms     = List<Map<String, dynamic>>.from(results[1] as List);
      final profiles  = List<Map<String, dynamic>>.from(results[2] as List);
      final roomMap   = {for (final r in rooms) (r['id'] as String): r};

      String pickDate(Map<String, dynamic> r) {
        final v = r['created_at'] ?? r['move_in_date'] ?? r['move_in_at']
            ?? r['check_in_date'] ?? r['inserted_at'] ?? r['entry_date'];
        if (v == null) return '-';
        final s = v.toString();
        return s.length >= 10 ? s.substring(0, 10) : s;
      }

      final excel = Excel.createExcel();
      final s1 = excel['입주자 현황'];
      excel.delete('Sheet1');

      _headers(s1, ['호실', '이름', '부서', '국적', '입주일'], hexColor: 'FF4A148C');
      _widths(s1, [14, 12, 14, 12, 14]);

      for (var i = 0; i < residents.length; i++) {
        final r    = residents[i];
        final room = roomMap[r['room_id']];
        final prof = profiles.firstWhere(
            (p) => p['id'] == r['user_id'], orElse: () => {});
        _row(s1, i + 1, [
          room?['room_number'] ?? '-',
          r['resident_name'] ?? '-',
          _dept(prof['dept_category'] as String?),
          prof['nationality'] ?? '-',
          pickDate(r),
        ]);
      }

      final s2 = excel['호실 현황'];
      _headers(s2, ['호실', '정원', '현재인원', '빈자리'], hexColor: 'FF6A1B9A');
      _widths(s2, [14, 10, 10, 8]);

      for (var i = 0; i < rooms.length; i++) {
        final room    = rooms[i];
        final current = residents.where((r) => r['room_id'] == room['id']).length;
        final capRaw  = room['max_capacity'] ?? room['capacity'] ?? room['cap'];
        final cap     = (capRaw is num) ? capRaw.toInt() : 0;
        _row(s2, i + 1, [room['room_number'] ?? '-', cap, current, cap - current]);
      }

      _rowHeights(s1, residents.length);
      _rowHeights(s2, rooms.length);
      _download(excel, '기숙사현황_$_todayStamp.xlsx');
    } catch (e) {
      _err('기숙사 현황 실패: $e');
    } finally {
      _busy('dorm', false);
    }
  }

  // ╔════════════════════════════════════════════
  // ║ 6. 통합 기록
  // ╚════════════════════════════════════════════
  Future<void> _exportCombined() async {
    if (_loading['combined'] == true) return;
    _busy('combined', true);
    try {
      final results = await Future.wait([
        _fetchAllInRange(
          table: 'attendance',
          columns: 'user_id, full_name, dept_category, work_date, check_in, check_out',
          dateColumn: 'work_date',
        ),
        supabase.from('profiles')
            .select('id, full_name, dept_category')
            .order('full_name', ascending: true),
        _fetchAllInRange(
          table: 'meal_requests',
          columns: 'user_id, full_name, dept_category, meal_date, meal_type, is_eating',
          dateColumn: 'meal_date',
        ),
        _fetchAllInRange(
          table: 'leave_requests',
          columns: 'full_name, dept_category, start_date, end_date, leave_days, leave_type, reason, status',
          dateColumn: 'start_date',
        ),
      ]);

      final attendance = results[0] as List<Map<String, dynamic>>;
      final profiles   = List<Map<String, dynamic>>.from(results[1] as List);
      final meals      = results[2] as List<Map<String, dynamic>>;
      final leaves     = results[3] as List<Map<String, dynamic>>;

      final excel = Excel.createExcel();

      final sCover = excel['요약'];
      excel.delete('Sheet1');
      _writeCover(sCover, attendance.length, meals.length, leaves.length, profiles.length);

      final sAttSum = excel['근태-개인별'];
      _writeAttendanceSummary(sAttSum, profiles, attendance);

      final sAtt = excel['근태-일별'];
      _writeAttendance(sAtt, attendance);

      final sMealSum = excel['식수-개인별'];
      _writeMealSummary(sMealSum, profiles, meals);

      final sMealDaily = excel['식수-일별'];
      _writeMealDaily(sMealDaily, meals);

      final sLeave = excel['휴가내역'];
      _writeLeave(sLeave, leaves);

      _download(excel, '통합기록_${_rangeYm}_$_todayStamp.xlsx');
    } catch (e) {
      _err('통합 기록 실패: $e');
    } finally {
      _busy('combined', false);
    }
  }

  // ╔════════════════════════════════════════════
  // ║ 시트 작성 공용 함수들
  // ╚════════════════════════════════════════════

  void _writeEmployees(Sheet s, List<Map<String, dynamic>> rows) {
    _headers(s, ['이름', '부서', '직책', '권한', '국적', '이메일',
        '전체연차(일)', '사용연차(일)', '잔여연차(일)'], hexColor: 'FF1565C0');
    _widths(s, [13, 14, 10, 9, 12, 24, 13, 13, 13]);

    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      final total = (r['total_leave'] as num?)?.toDouble() ?? 0;
      final used  = (r['used_leave']  as num?)?.toDouble() ?? 0;
      _row(s, i + 1, [
        r['full_name']    ?? '-',
        _dept(r['dept_category'] as String?),
        r['position']     ?? '-',
        r['role'] == 'ADMIN' ? '관리자' : '직원',
        r['nationality']  ?? '-',
        r['email']        ?? '-',
        total,
        used,
        total - used,
      ]);
    }
    _rowHeights(s, rows.length);
  }

  // 근태 개인별 (출근율 포함)
  void _writeAttendanceSummary(
      Sheet s,
      List<Map<String, dynamic>> profiles,
      List<Map<String, dynamic>> attendance) {
    _headers(s,
        ['이름', '부서', '출근일수', '퇴근완료', '미퇴근', '평일수', '출근율(평일)'],
        hexColor: 'FF1B5E20');
    _widths(s, [13, 14, 11, 11, 10, 10, 13]);

    final weekdays = _weekdaysInRange;

    for (var i = 0; i < profiles.length; i++) {
      final p = profiles[i];
      final my = attendance.where((r) {
        if (r['user_id'] != null && p['id'] != null) {
          return r['user_id'] == p['id'];
        }
        return r['full_name'] == p['full_name'];
      }).toList();

      final workDates      = <String>{};
      final completedDates = <String>{};
      for (final r in my) {
        final d = r['work_date']?.toString();
        if (d == null || d.isEmpty) continue;
        workDates.add(d);
        final co = r['check_out']?.toString();
        if (co != null && co.isNotEmpty && co != 'null') {
          completedDates.add(d);
        }
      }

      final workDays      = workDates.length;
      final completedDays = completedDates.length;
      final noCheckOut    = workDays - completedDays;
      final rate = weekdays > 0
          ? '${(workDays / weekdays * 100).toStringAsFixed(1)}%'
          : '-';

      _row(s, i + 1, [
        p['full_name'] ?? '-',
        _dept(p['dept_category'] as String?),
        workDays,
        completedDays,
        noCheckOut,
        weekdays,
        rate,
      ]);
    }
    _rowHeights(s, profiles.length);
  }

  void _writeAttendance(Sheet s, List<Map<String, dynamic>> rows) {
    _headers(s, ['이름', '부서', '날짜', '출근', '퇴근'], hexColor: 'FF2E7D32');
    _widths(s, [13, 13, 14, 10, 10]);

    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      _row(s, i + 1, [
        r['full_name']    ?? '-',
        _dept(r['dept_category'] as String?),
        r['work_date']    ?? '-',
        r['check_in']     ?? '-',
        r['check_out']    ?? '-',
      ]);
    }
    _rowHeights(s, rows.length);
  }

  // ── 식수 개인별 (일요일 제외)
  void _writeMealSummary(
      Sheet s,
      List<Map<String, dynamic>> profiles,
      List<Map<String, dynamic>> meals) {
    _headers(s, ['이름', '부서', '점심(식사)', '점심(불참)',
        '저녁(식사)', '저녁(불참)', '미응답', '참여율'], hexColor: 'FFE65100');
    _widths(s, [12, 14, 12, 12, 12, 12, 10, 11]);

    // 일요일 제외한 식당 운영일 × 2 (점심/저녁)
    final totalSlots = _mealServingDaysInRange * 2;

    for (var i = 0; i < profiles.length; i++) {
      final p = profiles[i];
      // 일요일 응답 제외 + 사용자 매칭
      final my = meals.where((r) {
        if (_isSundayDate(r['meal_date']?.toString())) return false;
        if (r['user_id'] != null && p['id'] != null) {
          return r['user_id'] == p['id'];
        }
        return r['full_name'] == p['full_name'];
      }).toList();

      final le = my.where((r) => r['meal_type'] == 'LUNCH'  && r['is_eating'] == true).length;
      final ln = my.where((r) => r['meal_type'] == 'LUNCH'  && r['is_eating'] == false).length;
      final de = my.where((r) => r['meal_type'] == 'DINNER' && r['is_eating'] == true).length;
      final dn = my.where((r) => r['meal_type'] == 'DINNER' && r['is_eating'] == false).length;
      final responded = le + ln + de + dn;
      final rate = totalSlots > 0
          ? '${(responded / totalSlots * 100).toStringAsFixed(1)}%' : '-';

      _row(s, i + 1, [
        p['full_name'],
        _dept(p['dept_category'] as String?),
        le, ln, de, dn, totalSlots - responded, rate,
      ]);
    }
    _rowHeights(s, profiles.length);
  }

  void _writeMealDaily(Sheet s, List<Map<String, dynamic>> meals) {
    _headers(s, ['날짜', '요일', '이름', '부서', '구분', '식사여부'], hexColor: 'FFBF360C');
    _widths(s, [13, 7, 12, 14, 8, 10]);

    const dayNames = ['월','화','수','목','금','토','일'];

    for (var i = 0; i < meals.length; i++) {
      final r = meals[i];
      final dateStr = r['meal_date']?.toString();
      String dayLabel = '-';
      if (dateStr != null && dateStr.isNotEmpty) {
        try {
          final d = DateTime.parse(dateStr);
          dayLabel = dayNames[d.weekday - 1];
        } catch (_) {}
      }

      _row(s, i + 1, [
        dateStr           ?? '-',
        dayLabel,
        r['full_name']    ?? '-',
        _dept(r['dept_category'] as String?),
        r['meal_type'] == 'LUNCH' ? '점심' : '저녁',
        r['is_eating'] == true ? '식사' : '불참',
      ]);
    }
    _rowHeights(s, meals.length);
  }

  void _writeLeave(Sheet s, List<Map<String, dynamic>> rows) {
    _headers(s, ['이름', '부서', '시작일', '종료일', '일수', '구분', '사유', '상태'],
        hexColor: 'FF006064');
    _widths(s, [12, 14, 14, 14, 8, 10, 24, 9]);

    String typeLabel(t) => switch (t) {
          'HALF'     => '반차',
          'PUBLIC'   => '공가',
          'EVENT'    => '경조사',
          'SICK'     => '병가',
          'TRAINING' => '교육',
          _          => '연차',
        };
    String stLabel(st) => switch (st) {
          'APPROVED' => '승인',
          'REJECTED' => '반려',
          _          => '대기',
        };

    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      _row(s, i + 1, [
        r['full_name']  ?? '-',
        _dept(r['dept_category'] as String?),
        r['start_date'] ?? '-',
        r['end_date']   ?? '-',
        (r['leave_days'] as num?)?.toDouble() ?? 0.0,
        typeLabel(r['leave_type'] ?? ''),
        r['reason']     ?? '-',
        stLabel(r['status'] ?? ''),
      ]);
    }
    _rowHeights(s, rows.length);
  }

  void _writeCover(Sheet s, int attCount, int mealCount, int leaveCount, int profileCount) {
    _widths(s, [22, 30]);

    final t = s.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
    t.value = TextCellValue('통합 기록 요약');
    t.cellStyle = CellStyle(
      bold: true,
      fontSize: 16,
      fontColorHex: ExcelColor.fromHexString('FFFFFFFF'),
      backgroundColorHex: ExcelColor.fromHexString('FFD81B60'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
    final t2 = s.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0));
    t2.value = TextCellValue('');
    t2.cellStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('FFD81B60'),
    );
    s.setRowHeight(0, 32);

    final items = <List<String>>[
      ['기간',          _rangeLabel],
      ['시작일',        _rangeFrom],
      ['종료일',        _rangeTo],
      ['총 개월수',     '$_monthsCount개월'],
      ['총 일수',       '$_totalDaysInRange일'],
      ['평일 수',       '$_weekdaysInRange일 (월~금)'],
      ['식당 운영일',   '$_mealServingDaysInRange일 (일요일 제외)'],
      ['생성일',        DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())],
      ['',              ''],
      ['직원 수',       '$profileCount명'],
      ['근태 기록 수',  '$attCount건'],
      ['식수 응답 수',  '$mealCount건'],
      ['휴가 신청 수',  '$leaveCount건'],
      ['',              ''],
      ['시트 안내',     '아래 시트에 상세 데이터'],
      ['  · 근태-개인별', '출근일수, 출근율(평일 기준)'],
      ['  · 근태-일별',   '날짜별 출퇴근 원본'],
      ['  · 식수-개인별', '개인별 참여 집계 (일요일 제외)'],
      ['  · 식수-일별',   '날짜별 식사 응답 원본'],
      ['  · 휴가내역',    '기간 내 휴가 신청 내역'],
    ];

    for (var i = 0; i < items.length; i++) {
      final row = i + 1;
      final isEmpty = items[i][0].isEmpty;
      final isSection = items[i][0] == '시트 안내';

      for (var col = 0; col < 2; col++) {
        final cell = s.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
        cell.value = TextCellValue(items[i][col]);
        cell.cellStyle = CellStyle(
          fontSize: isSection ? 11 : 10,
          bold: col == 0 || isSection,
          fontColorHex: ExcelColor.fromHexString(isSection ? 'FFD81B60' : 'FF1A1D2E'),
          backgroundColorHex: ExcelColor.fromHexString(
              isEmpty ? 'FFFFFFFF' : (col == 0 ? 'FFFCE4EC' : 'FFFFFFFF')),
          horizontalAlign: HorizontalAlign.Left,
          verticalAlign: VerticalAlign.Center,
          leftBorder: isEmpty ? null : xl.Border(borderStyle: xl.BorderStyle.Thin,
              borderColorHex: ExcelColor.fromHexString('FFE0E5F0')),
          rightBorder: isEmpty ? null : xl.Border(borderStyle: xl.BorderStyle.Thin,
              borderColorHex: ExcelColor.fromHexString('FFE0E5F0')),
          bottomBorder: isEmpty ? null : xl.Border(borderStyle: xl.BorderStyle.Thin,
              borderColorHex: ExcelColor.fromHexString('FFE0E5F0')),
          topBorder: isEmpty ? null : xl.Border(borderStyle: xl.BorderStyle.Thin,
              borderColorHex: ExcelColor.fromHexString('FFE0E5F0')),
        );
      }
      s.setRowHeight(row, isEmpty ? 8 : 20);
    }
  }
}