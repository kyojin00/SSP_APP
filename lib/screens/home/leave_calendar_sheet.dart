import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'app_strings.dart';
import 'lang_context.dart';

enum LeaveType {
  annual('ANNUAL',   Icons.calendar_month_rounded,  Color(0xFF2E6BFF),  true),
  half  ('HALF',     Icons.wb_sunny_rounded,         Color(0xFFFF9500),  true),
  public('PUBLIC',   Icons.account_balance_rounded,  Color(0xFF7C5CDB),  false),
  event ('EVENT',    Icons.favorite_rounded,         Color(0xFFFF4D64),  false);

  final String code;
  final IconData icon;
  final Color color;
  final bool deductsLeave;

  const LeaveType(this.code, this.icon, this.color, this.deductsLeave);

  static LeaveType fromCode(String code) =>
      LeaveType.values.firstWhere((t) => t.code == code, orElse: () => LeaveType.annual);

  // context 필요하므로 label은 메서드로
  String label(BuildContext ctx) => switch (code) {
    'HALF'   => ctx.tr(AppStrings.leaveHalf),
    'PUBLIC' => ctx.tr(AppStrings.leavePublic),
    'EVENT'  => ctx.tr(AppStrings.leaveSpecial),
    _        => ctx.tr(AppStrings.leaveAnnual),
  };
}

class LeaveCalendarSheet extends StatefulWidget {
  final double totalLeave;
  final double usedLeave;
  final Future<void> Function(DateTime, DateTime, double, String, String) onSubmit;

  const LeaveCalendarSheet({
    Key? key,
    required this.totalLeave,
    required this.usedLeave,
    required this.onSubmit,
  }) : super(key: key);

  @override
  State<LeaveCalendarSheet> createState() => _LeaveCalendarSheetState();
}

class _LeaveCalendarSheetState extends State<LeaveCalendarSheet> {
  static const _text    = Color(0xFF1A1D2E);
  static const _sub     = Color(0xFF8A93B0);
  static const _red     = Color(0xFFFF4D64);
  static const _primary = Color(0xFF2E6BFF);
  static const _bg      = Color(0xFFF4F6FB);

  DateTime  _focusedDay   = DateTime.now();
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  LeaveType _leaveType    = LeaveType.annual;
  final     _reasonCtrl   = TextEditingController();
  bool      _isSubmitting = false;

  double get _remaining => widget.totalLeave - widget.usedLeave;

  bool get _isSingleDay =>
      _leaveType == LeaveType.half ||
      _leaveType == LeaveType.public ||
      _leaveType == LeaveType.event;

  double get _selectedDays {
    if (_rangeStart == null) return 0;
    if (_leaveType == LeaveType.half) return 0.5;
    return ((_rangeEnd ?? _rangeStart!).difference(_rangeStart!).inDays + 1).toDouble();
  }

  bool get _reasonRequired =>
      _leaveType == LeaveType.public || _leaveType == LeaveType.event;

  bool get _canSubmit {
    if (_rangeStart == null || _selectedDays <= 0) return false;
    if (_reasonRequired && _reasonCtrl.text.trim().isEmpty) return false;
    if (_leaveType.deductsLeave && _selectedDays > _remaining) return false;
    return true;
  }

  String _fmt(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toString();

  String _dayUnit(BuildContext ctx) =>
      ctx.tr({'ko': '일', 'en': 'd', 'vi': 'n', 'uz': 'k', 'km': 'ថ្ងៃ'});

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  void _onTypeChanged(LeaveType type) {
    setState(() {
      _leaveType  = type;
      _rangeStart = null;
      _rangeEnd   = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = _leaveType.color;

    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),

          // 헤더
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.edit_calendar_rounded, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Text(context.tr(AppStrings.leaveRequest),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _text)),
              const Spacer(),
              if (_leaveType.deductsLeave)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _remaining <= 3 ? _red.withOpacity(0.08) : _primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "${context.tr({'ko':'잔여','en':'Left','vi':'Con','uz':'Qolgan','km':'នៅសល់'})} ${_fmt(_remaining)}${_dayUnit(context)}",
                    style: TextStyle(
                        color: _remaining <= 3 ? _red : _primary,
                        fontSize: 13, fontWeight: FontWeight.w800)),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.info_outline_rounded, size: 13, color: color),
                    const SizedBox(width: 4),
                    Text(
                      context.tr({'ko':'연차 미차감','en':'No deduction','vi':'Khong tru phep','uz':'Chegirmaydi','km':'មិនកាត់'}),
                      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800)),
                  ]),
                ),
            ]),
          ),
          const SizedBox(height: 16),

          // 타입 선택 2x2
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(children: [
              Row(children: [
                Expanded(child: _typeChip(LeaveType.annual)),
                const SizedBox(width: 10),
                Expanded(child: _typeChip(LeaveType.half)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _typeChip(LeaveType.public)),
                const SizedBox(width: 10),
                Expanded(child: _typeChip(LeaveType.event)),
              ]),
            ]),
          ),
          const SizedBox(height: 8),

          // 달력 (locale은 언어코드 기반)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: TableCalendar(
              locale: context.langCode == 'ko' ? 'ko_KR' : 'en_US',
              firstDay: DateTime.now(),
              lastDay: DateTime.now().add(const Duration(days: 365)),
              focusedDay: _focusedDay,
              rangeStartDay: _rangeStart,
              rangeEndDay: _isSingleDay ? _rangeStart : _rangeEnd,
              rangeSelectionMode: _isSingleDay
                  ? RangeSelectionMode.disabled
                  : RangeSelectionMode.enforced,
              selectedDayPredicate: _isSingleDay
                  ? (day) => isSameDay(day, _rangeStart)
                  : null,
              calendarStyle: CalendarStyle(
                selectedDecoration: BoxDecoration(color: color, shape: BoxShape.circle),
                selectedTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                rangeStartDecoration: BoxDecoration(color: color, shape: BoxShape.circle),
                rangeEndDecoration: BoxDecoration(color: color, shape: BoxShape.circle),
                rangeStartTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                rangeEndTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                withinRangeDecoration: BoxDecoration(color: color.withOpacity(0.1)),
                withinRangeTextStyle: TextStyle(color: color),
                todayDecoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
                todayTextStyle: TextStyle(color: color, fontWeight: FontWeight.w800),
                weekendTextStyle: const TextStyle(color: Color(0xFFFF4D64)),
                defaultTextStyle: const TextStyle(fontWeight: FontWeight.w600, color: _text),
                outsideTextStyle: TextStyle(color: _sub.withOpacity(0.4)),
                cellMargin: const EdgeInsets.all(4),
              ),
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _text),
                leftChevronIcon:  _chevron(Icons.chevron_left_rounded),
                rightChevronIcon: _chevron(Icons.chevron_right_rounded),
              ),
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: TextStyle(color: _sub, fontSize: 12, fontWeight: FontWeight.w700),
                weekendStyle: const TextStyle(color: Color(0xFFFF4D64), fontSize: 12, fontWeight: FontWeight.w700),
              ),
              onDaySelected: _isSingleDay
                  ? (selected, focused) => setState(() {
                        _rangeStart = selected;
                        _rangeEnd   = null;
                        _focusedDay = focused;
                      })
                  : null,
              onRangeSelected: !_isSingleDay
                  ? (start, end, focused) => setState(() {
                        _rangeStart = start;
                        _rangeEnd   = end;
                        _focusedDay = focused;
                      })
                  : null,
              onPageChanged: (d) => setState(() => _focusedDay = d),
            ),
          ),

          if (_rangeStart != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: _selectionSummary(),
            ),
          const SizedBox(height: 12),

          // 사유 입력
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _reasonCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: _reasonRequired
                    ? context.tr({'ko':'사유 입력 (필수)','en':'Reason (required)','vi':'Ly do (bat buoc)','uz':'Sabab (majburiy)','km':'មូលហេតុ (ចាំបាច់)'})
                    : context.tr({'ko':'사유 입력 (선택사항)','en':'Reason (optional)','vi':'Ly do (tuy chon)','uz':'Sabab (ixtiyoriy)','km':'មូលហេតុ (ស្រេចចិត្ត)'}),
                hintStyle: TextStyle(
                    color: _reasonRequired ? color.withOpacity(0.5) : _sub, fontSize: 13),
                filled: true, fillColor: _bg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: _reasonRequired ? BorderSide(color: color.withOpacity(0.3)) : BorderSide.none),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: _reasonRequired ? BorderSide(color: color.withOpacity(0.25)) : BorderSide.none),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: color, width: 1.5)),
                prefixIcon: Icon(Icons.notes_rounded, color: _reasonRequired ? color : _sub, size: 18),
                suffixIcon: _reasonRequired
                    ? Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Text(
                          context.tr({'ko':'필수','en':'Required','vi':'Bat buoc','uz':'Majburiy','km':'ចាំបាច់'}),
                          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)))
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 신청 버튼
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: SizedBox(
              width: double.infinity, height: 54,
              child: ElevatedButton(
                onPressed: (_canSubmit && !_isSubmitting) ? _submit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  disabledBackgroundColor: _bg, elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isSubmitting
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(
                        _buildBtnLabel(context),
                        style: TextStyle(
                            color: _canSubmit ? Colors.white : _sub,
                            fontSize: 15, fontWeight: FontWeight.w800),
                      ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  String _buildBtnLabel(BuildContext ctx) {
    final d = _dayUnit(ctx);
    if (_rangeStart == null) return ctx.tr({'ko':'날짜를 선택해주세요','en':'Select a date','vi':'Chon ngay','uz':'Sanani tanlang','km':'ជ្រើសរើសកាលបរិច្ឆេទ'});
    if (_reasonRequired && _reasonCtrl.text.trim().isEmpty)
      return ctx.tr({'ko':'사유를 입력해주세요','en':'Enter a reason','vi':'Nhap ly do','uz':'Sabab kiriting','km':'បញ្ចូលមូលហេតុ'});
    if (_leaveType.deductsLeave && _selectedDays > _remaining)
      return ctx.tr({'ko':'잔여 연차 초과','en':'Exceeds remaining leave','vi':'Vuot qua so nghi con lai','uz':'Qolgan ta\'tildan oshib ketdi','km':'លើសពី휴가ដែលនៅសល់'});
    final typeLbl = _leaveType.label(ctx);
    if (_leaveType == LeaveType.half) return ctx.tr({'ko':'반차 신청하기','en':'Request Half Day','vi':'Dang ky nua ngay','uz':'Yarim kun so\'rash','km':'ស្នើសុំ휴가ពាក់កណ្ដាល'});
    return ctx.tr({
      'ko': '${_fmt(_selectedDays)}$d $typeLbl 신청하기',
      'en': 'Request ${_fmt(_selectedDays)}$d $typeLbl',
      'vi': 'Dang ky ${_fmt(_selectedDays)}$d $typeLbl',
      'uz': '${_fmt(_selectedDays)}$d $typeLbl so\'rash',
      'km': 'ស្នើសុំ ${_fmt(_selectedDays)}$d $typeLbl',
    });
  }

  Widget _typeChip(LeaveType type) {
    final selected = _leaveType == type;
    final color    = type.color;
    return GestureDetector(
      onTap: () => _onTypeChanged(type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.08) : _bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? color.withOpacity(0.4) : Colors.transparent),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(type.icon, size: 15, color: selected ? color : _sub),
            const SizedBox(width: 5),
            Text(type.label(context),
                style: TextStyle(
                    color: selected ? color : _sub,
                    fontWeight: FontWeight.w800, fontSize: 14)),
          ]),
          if (!type.deductsLeave)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                context.tr({'ko':'연차 미차감','en':'No deduction','vi':'Khong tru phep','uz':'Chegirmaydi','km':'មិនកាត់'}),
                style: TextStyle(
                    color: selected ? color.withOpacity(0.6) : _sub.withOpacity(0.5),
                    fontSize: 10, fontWeight: FontWeight.w600)),
            ),
        ]),
      ),
    );
  }

  Widget _selectionSummary() {
    final fmt  = DateFormat('MM/dd');
    final end  = _isSingleDay ? _rangeStart! : (_rangeEnd ?? _rangeStart!);
    final over = _leaveType.deductsLeave && _selectedDays > _remaining;
    final color = over ? _red : _leaveType.color;
    final d = _dayUnit(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(children: [
        Icon(over ? Icons.warning_rounded : Icons.check_circle_rounded, color: color, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(
          over
              ? context.tr({'ko':'잔여 연차 ${_fmt(_remaining)}$d 초과! 신청 불가','en':'Exceeds ${_fmt(_remaining)}$d remaining!','vi':'Vuot ${_fmt(_remaining)}$d con lai!','uz':'${_fmt(_remaining)}$d dan oshib ketdi!','km':'លើស ${_fmt(_remaining)}$d ដែលនៅសល់!'})
              : "${fmt.format(_rangeStart!)} ~ ${fmt.format(end)}  ·  "
                "${_leaveType == LeaveType.half
                    ? context.tr({'ko':'반차 (0.5일)','en':'Half day (0.5d)','vi':'Nua ngay (0.5n)','uz':'Yarim kun','km':'ពាក់កណ្ដាល (0.5d)'})
                    : '${_fmt(_selectedDays)}$d ${_leaveType.label(context)}'}",
          style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700),
        )),
      ]),
    );
  }

  Widget _chevron(IconData icon) => Container(
    padding: const EdgeInsets.all(6),
    decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(8)),
    child: Icon(icon, color: _text, size: 18),
  );

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _isSubmitting = true);
    final end = _isSingleDay ? _rangeStart! : (_rangeEnd ?? _rangeStart!);
    await widget.onSubmit(
        _rangeStart!, end, _selectedDays, _reasonCtrl.text, _leaveType.code);
    if (mounted) Navigator.pop(context);
  }
}