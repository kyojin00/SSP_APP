// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' hide Border;

class ExcelExportScreen extends StatefulWidget {
  const ExcelExportScreen({Key? key}) : super(key: key);
  @override
  State<ExcelExportScreen> createState() => _ExcelExportScreenState();
}

class _ExcelExportScreenState extends State<ExcelExportScreen> {
  final supabase = Supabase.instance.client;

  static const _bg = Color(0xFFF4F6FB);
  static const _text = Color(0xFF1A1D2E);
  static const _sub = Color(0xFF8A93B0);

  final Map<String, bool> _loading = {
    'employees': false,
    'attendance': false,
    'meal': false,
    'leave': false,
    'dorm': false,
  };

  final Set<String> _running = {};

  int _year = DateTime.now().year;
  int _month = DateTime.now().month;

  bool _isDownloading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text(
          "엑셀 내보내기",
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
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
          _monthPicker(),
          const SizedBox(height: 20),
          _card(
            keyName: 'employees',
            color: const Color(0xFF2E6BFF),
            icon: Icons.people_rounded,
            title: "직원 목록",
            desc: "전체 직원 · 부서 · 연차 현황",
            onTap: _exportEmployees,
          ),
          _card(
            keyName: 'attendance',
            color: Colors.green,
            icon: Icons.punch_clock_rounded,
            title: "근태 기록",
            desc: "$_year년 $_month월 · 출퇴근 · 근무시간",
            onTap: _exportAttendance,
          ),
          _card(
            keyName: 'meal',
            color: Colors.deepOrange,
            icon: Icons.restaurant_rounded,
            title: "식수 현황",
            desc: "$_year년 $_month월 · 점심/저녁 · 개인별 집계",
            onTap: _exportMeal,
          ),
          _card(
            keyName: 'leave',
            color: const Color(0xFF00BCD4),
            icon: Icons.edit_calendar_rounded,
            title: "휴가 신청 내역",
            desc: "$_year년 $_month월 · 연차/반차/공가/경조사",
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
        ],
      ),
    );
  }

  Widget _monthPicker() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF2E6BFF)),
          const SizedBox(width: 8),
          const Text(
            "기준 월",
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: _text),
          ),
          const Spacer(),
          _drop<int>(
            value: _year,
            items: List.generate(3, (i) => DateTime.now().year - i),
            label: (v) => '$v년',
            onChanged: (v) => setState(() => _year = v!),
          ),
          const SizedBox(width: 8),
          _drop<int>(
            value: _month,
            items: List.generate(12, (i) => i + 1),
            label: (v) => '$v월',
            onChanged: (v) => setState(() => _month = v!),
          ),
        ],
      ),
    );
  }

  Widget _card({
    required String keyName,
    required Color color,
    required IconData icon,
    required String title,
    required String desc,
    required Future<void> Function() onTap,
  }) {
    final busy = _loading[keyName] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: _text)),
                const SizedBox(height: 3),
                Text(desc, style: const TextStyle(fontSize: 12, color: _sub)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          busy
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5))
              : ElevatedButton.icon(
                  onPressed: (busy || _isDownloading)
                      ? null
                      : () => _runOnce(keyName, () async {
                            await onTap();
                          }),
                  icon: const Icon(Icons.download_rounded, size: 14),
                  label: const Text("다운로드", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _drop<T>({
    required T value,
    required List<T> items,
    required String Function(T) label,
    required void Function(T?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E5F0)),
      ),
      child: DropdownButton<T>(
        value: value,
        underline: const SizedBox(),
        isDense: true,
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
    try {
      await job();
    } finally {
      _running.remove(key);
    }
  }

  void _err(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
  }

  void _headers(Sheet s, List<String> hs) {
    for (var i = 0; i < hs.length; i++) {
      s.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).value = TextCellValue(hs[i]);
    }
  }

  void _row(Sheet s, int r, List<dynamic> vals) {
    for (var i = 0; i < vals.length; i++) {
      final cell = s.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: r));
      final v = vals[i];
      cell.value = v is int
          ? IntCellValue(v)
          : v is double
              ? DoubleCellValue(v)
              : TextCellValue(v?.toString() ?? '-');
    }
  }

  void _widths(Sheet s, List<double> ws) {
    for (var i = 0; i < ws.length; i++) {
      s.setColumnWidth(i, ws[i]);
    }
  }

  // ✅ 핵심 수정 부분: excel.save() 대신 excel.encode() 사용
  void _download(Excel excel, String name) {
    if (_isDownloading) return;
    
    setState(() => _isDownloading = true);

    String? url;
    try {
      // ✅ 중요: .save()는 웹에서 자동 다운로드를 유발하므로 .encode()를 사용합니다.
      final bytes = excel.encode(); 
      if (bytes == null) throw Exception('저장 실패');

      final blob = html.Blob(
        [bytes],
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
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

  String get _ym => '$_year${_month.toString().padLeft(2, '0')}';
  String get _monthFrom => '$_year-${_month.toString().padLeft(2, '0')}-01';
  String get _monthTo {
    final last = DateUtils.getDaysInMonth(_year, _month);
    return '$_year-${_month.toString().padLeft(2, '0')}-${last.toString().padLeft(2, '0')}';
  }

  // 1. 직원 목록
  Future<void> _exportEmployees() async {
    if (_loading['employees'] == true) return;
    _busy('employees', true);
    try {
      final rows = await supabase
          .from('profiles')
          .select('full_name, dept_category, role, total_leave, used_leave')
          .order('full_name', ascending: true);

      final excel = Excel.createExcel();
      final s = excel['직원목록'];
      excel.delete('Sheet1');

      _headers(s, ['이름', '부서', '권한', '전체연차(일)', '사용연차(일)', '잔여연차(일)']);
      _widths(s, [13, 14, 9, 13, 13, 13]);

      for (var i = 0; i < rows.length; i++) {
        final r = rows[i] as Map<String, dynamic>;
        final total = (r['total_leave'] as num?)?.toDouble() ?? 0;
        final used = (r['used_leave'] as num?)?.toDouble() ?? 0;

        _row(s, i + 1, [
          r['full_name'] ?? '-',
          r['dept_category'] ?? '-',
          r['role'] == 'ADMIN' ? '관리자' : '직원',
          total,
          used,
          total - used,
        ]);
      }

      _download(excel, '직원목록_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx');
    } catch (e) {
      _err('직원 목록 실패: $e');
    } finally {
      _busy('employees', false);
    }
  }

  // 2. 근태 기록
  Future<void> _exportAttendance() async {
    if (_loading['attendance'] == true) return;
    _busy('attendance', true);
    try {
      final rows = await supabase
          .from('attendance')
          .select('full_name, dept_category, work_date, check_in, check_out')
          .gte('work_date', _monthFrom)
          .lte('work_date', _monthTo)
          .order('work_date', ascending: true);

      final excel = Excel.createExcel();
      final s = excel['근태기록'];
      excel.delete('Sheet1');

      _headers(s, ['이름', '부서', '날짜', '출근', '퇴근']);
      _widths(s, [13, 13, 14, 10, 10]);

      for (var i = 0; i < rows.length; i++) {
        final r = rows[i] as Map<String, dynamic>;
        _row(s, i + 1, [
          r['full_name'] ?? '-',
          r['dept_category'] ?? '-',
          r['work_date'] ?? '-',
          r['check_in'] ?? '-',
          r['check_out'] ?? '-',
        ]);
      }

      _download(excel, '근태기록_${_ym}_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx');
    } catch (e) {
      _err('근태 기록 실패: $e');
    } finally {
      _busy('attendance', false);
    }
  }

  // 3. 식수 현황
  Future<void> _exportMeal() async {
    if (_loading['meal'] == true) return;
    _busy('meal', true);
    try {
      final results = await Future.wait([
        supabase.from('profiles').select('id, full_name, dept_category').order('full_name', ascending: true),
        supabase
            .from('meal_requests')
            .select('user_id, full_name, dept_category, meal_date, meal_type, is_eating')
            .gte('meal_date', _monthFrom)
            .lte('meal_date', _monthTo)
            .order('meal_date', ascending: true),
      ]);

      final profiles = List<Map<String, dynamic>>.from(results[0] as List);
      final meals = List<Map<String, dynamic>>.from(results[1] as List);
      final lastDay = DateUtils.getDaysInMonth(_year, _month);

      final excel = Excel.createExcel();
      final s1 = excel['개인별 집계'];
      excel.delete('Sheet1');
      _headers(s1, ['이름', '부서', '점심(식사)', '점심(불참)', '저녁(식사)', '저녁(불참)', '미응답', '참여율']);
      _widths(s1, [12, 12, 12, 12, 12, 12, 10, 10]);

      for (var i = 0; i < profiles.length; i++) {
        final p = profiles[i];
        final my = meals.where((r) => r['user_id'] == p['id']).toList();
        final le = my.where((r) => r['meal_type'] == 'LUNCH' && r['is_eating'] == true).length;
        final ln = my.where((r) => r['meal_type'] == 'LUNCH' && r['is_eating'] == false).length;
        final de = my.where((r) => r['meal_type'] == 'DINNER' && r['is_eating'] == true).length;
        final dn = my.where((r) => r['meal_type'] == 'DINNER' && r['is_eating'] == false).length;

        final total = lastDay * 2;
        final responded = le + ln + de + dn;
        final rate = total > 0 ? '${(responded / total * 100).toStringAsFixed(1)}%' : '-';

        _row(s1, i + 1, [p['full_name'], p['dept_category'], le, ln, de, dn, total - responded, rate]);
      }

      final s2 = excel['일별 원본'];
      _headers(s2, ['날짜', '이름', '부서', '구분', '식사여부']);
      _widths(s2, [14, 12, 12, 8, 10]);

      for (var i = 0; i < meals.length; i++) {
        final r = meals[i];
        _row(s2, i + 1, [
          r['meal_date'] ?? '-',
          r['full_name'] ?? '-',
          r['dept_category'] ?? '-',
          r['meal_type'] == 'LUNCH' ? '점심' : '저녁',
          r['is_eating'] == true ? '식사' : '불참',
        ]);
      }

      _download(excel, '식수현황_${_ym}_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx');
    } catch (e) {
      _err('식수 현황 실패: $e');
    } finally {
      _busy('meal', false);
    }
  }

  // 4. 휴가 신청
  Future<void> _exportLeave() async {
    if (_loading['leave'] == true) return;
    _busy('leave', true);
    try {
      final rows = await supabase
          .from('leave_requests')
          .select('full_name, start_date, end_date, leave_days, leave_type, reason, status')
          .gte('start_date', _monthFrom)
          .lte('start_date', _monthTo)
          .order('start_date', ascending: true);

      final excel = Excel.createExcel();
      final s = excel['휴가내역'];
      excel.delete('Sheet1');

      _headers(s, ['이름', '시작일', '종료일', '일수', '구분', '사유', '상태']);
      _widths(s, [12, 14, 14, 8, 10, 24, 9]);

      String typeLabel(t) => switch (t) {
            'HALF' => '반차',
            'PUBLIC' => '공가',
            'EVENT' => '경조사',
            _ => '연차',
          };

      String stLabel(s) => switch (s) {
            'APPROVED' => '승인',
            'REJECTED' => '반려',
            _ => '대기',
          };

      for (var i = 0; i < rows.length; i++) {
        final r = rows[i] as Map<String, dynamic>;
        _row(s, i + 1, [
          r['full_name'] ?? '-',
          r['start_date'] ?? '-',
          r['end_date'] ?? '-',
          (r['leave_days'] as num?)?.toDouble() ?? 0.0,
          typeLabel(r['leave_type'] ?? ''),
          r['reason'] ?? '-',
          stLabel(r['status'] ?? ''),
        ]);
      }

      _download(excel, '휴가내역_${_ym}_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx');
    } catch (e) {
      _err('휴가 내역 실패: $e');
    } finally {
      _busy('leave', false);
    }
  }

  // 5. 기숙사 현황
  Future<void> _exportDorm() async {
    if (_loading['dorm'] == true) return;
    _busy('dorm', true);
    try {
      final results = await Future.wait([
        supabase.from('dorm_residents').select('*').order('room_id', ascending: true),
        supabase.from('dorm_rooms').select('*').order('room_number', ascending: true),
        supabase.from('profiles').select('id, dept_category').order('id', ascending: true),
      ]);

      final residents = List<Map<String, dynamic>>.from(results[0] as List);
      final rooms = List<Map<String, dynamic>>.from(results[1] as List);
      final profiles = List<Map<String, dynamic>>.from(results[2] as List);
      final roomMap = {for (final r in rooms) (r['id'] as String): r};

      String pickDate(Map<String, dynamic> r) {
        final v = r['created_at'] ?? r['move_in_date'] ?? r['move_in_at'] ?? r['check_in_date'] ?? r['inserted_at'] ?? r['date'] ?? r['createdAt'];
        if (v == null) return '-';
        final s = v.toString();
        return s.length >= 10 ? s.substring(0, 10) : s;
      }

      final excel = Excel.createExcel();
      final s1 = excel['입주자 현황'];
      excel.delete('Sheet1');
      _headers(s1, ['호실', '이름', '부서', '입주일']);
      _widths(s1, [9, 12, 14, 14]);

      for (var i = 0; i < residents.length; i++) {
        final r = residents[i];
        final room = roomMap[r['room_id']];
        final dept = profiles.firstWhere((p) => p['id'] == r['user_id'], orElse: () => {})['dept_category'] ?? '-';
        _row(s1, i + 1, ['${room?['room_number'] ?? '-'}호', r['resident_name'] ?? '-', dept, pickDate(r)]);
      }

      final s2 = excel['호실 현황'];
      _headers(s2, ['호실', '정원', '현재인원', '빈자리']);
      _widths(s2, [9, 10, 10, 8]);

      for (var i = 0; i < rooms.length; i++) {
        final room = rooms[i];
        final current = residents.where((r) => r['room_id'] == room['id']).length;
        final capRaw = room['max_capacity'] ?? room['capacity'] ?? room['cap'];
        final cap = (capRaw is num) ? capRaw.toInt() : 0;
        _row(s2, i + 1, ['${room['room_number'] ?? '-'}호', cap, current, cap - current]);
      }

      _download(excel, '기숙사현황_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx');
    } catch (e) {
      _err('기숙사 현황 실패: $e');
    } finally {
      _busy('dorm', false);
    }
  }
}