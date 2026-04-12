import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'app_strings.dart';
import 'lang_context.dart';

enum LeaveType {
  annual  ('ANNUAL',   Icons.calendar_month_rounded,   Color(0xFF2E6BFF),  true),
  half    ('HALF',     Icons.wb_sunny_rounded,          Color(0xFFFF9500),  true),
  public  ('PUBLIC',   Icons.account_balance_rounded,   Color(0xFF7C5CDB),  false),
  event   ('EVENT',    Icons.favorite_rounded,          Color(0xFFFF4D64),  false),
  training('TRAINING', Icons.school_rounded,            Color(0xFF00897B),  false);

  final String code;
  final IconData icon;
  final Color color;
  final bool deductsLeave;

  const LeaveType(this.code, this.icon, this.color, this.deductsLeave);

  static LeaveType fromCode(String code) =>
      LeaveType.values.firstWhere((t) => t.code == code,
          orElse: () => LeaveType.annual);

  bool get isSingleDay => this == LeaveType.half;

  String label(BuildContext ctx) => switch (code) {
    'HALF'     => ctx.tr(AppStrings.leaveHalf),
    'PUBLIC'   => ctx.tr(AppStrings.leavePublic),
    'EVENT'    => ctx.tr(AppStrings.leaveSpecial),
    'TRAINING' => ctx.tr({'ko': '교육', 'en': 'Training', 'vi': 'Dao tao',
                           'uz': "Ta'lim", 'km': 'បណ្តុះបណ្តាល'}),
    _          => ctx.tr(AppStrings.leaveAnnual),
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

  double get _remaining  => widget.totalLeave - widget.usedLeave;

  double get _selectedDays {
    if (_rangeStart == null) return 0;
    if (_leaveType == LeaveType.half) return 0.5;
    return ((_rangeEnd ?? _rangeStart!).difference(_rangeStart!).inDays + 1).toDouble();
  }

  bool get _reasonRequired =>
      _leaveType == LeaveType.public ||
      _leaveType == LeaveType.event  ||
      _leaveType == LeaveType.training;

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

  Color _lighten(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
  }

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
    final color   = _leaveType.color;
    final lighter = _lighten(color, 0.18);
    final d       = _dayUnit(context);

    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: Color(0xFFF4F6FB),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [

          // ── 그라디언트 헤더
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [lighter, color],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Stack(children: [
              // 배경 장식 원
              Positioned(
                right: -30, top: -30,
                child: Container(width: 120, height: 120,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.08))),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                child: Column(children: [
                  // 드래그 핸들
                  Center(
                    child: Container(
                      width: 36, height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.45),
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  // 제목 + 잔여 뱃지
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.22),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.edit_calendar_rounded,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      context.tr(AppStrings.leaveRequest),
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                    const Spacer(),
                    // 잔여 연차 뱃지
                    if (_leaveType.deductsLeave)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _remaining <= 3
                              ? const Color(0xFFFF4D64).withOpacity(0.3)
                              : Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(_remaining <= 3 ? Icons.warning_amber_rounded : Icons.beach_access_rounded,
                              color: Colors.white, size: 13),
                          const SizedBox(width: 5),
                          Text(
                            "${context.tr({'ko': '잔여', 'en': 'Left', 'vi': 'Con', 'uz': 'Qolgan', 'km': 'នៅសល់'})} ${_fmt(_remaining)}$d",
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
                          ),
                        ]),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.shield_rounded, color: Colors.white, size: 13),
                          const SizedBox(width: 5),
                          Text(
                            context.tr({'ko': '연차 미차감', 'en': 'No deduction', 'vi': 'Khong tru', 'uz': 'Chegirmaydi', 'km': 'មិនកាត់'}),
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ]),
                      ),
                  ]),
                ]),
              ),
            ]),
          ),

          const SizedBox(height: 16),

          // ── 타입 선택 칩
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
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
              const SizedBox(height: 10),
              _typeChip(LeaveType.training, fullWidth: true),
            ]),
          ),

          const SizedBox(height: 14),

          // ── 달력 (흰 카드)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: color.withOpacity(0.08), blurRadius: 14, offset: const Offset(0, 4)),
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
                ],
              ),
              child: TableCalendar(
                locale: context.langCode == 'ko' ? 'ko_KR' : 'en_US',
                firstDay: DateTime.now(),
                lastDay: DateTime.now().add(const Duration(days: 365)),
                focusedDay: _focusedDay,
                rangeStartDay: _rangeStart,
                rangeEndDay: _leaveType.isSingleDay ? _rangeStart : _rangeEnd,
                rangeSelectionMode: _leaveType.isSingleDay
                    ? RangeSelectionMode.disabled
                    : RangeSelectionMode.enforced,
                selectedDayPredicate: _leaveType.isSingleDay
                    ? (day) => isSameDay(day, _rangeStart)
                    : null,
                calendarStyle: CalendarStyle(
                  selectedDecoration: BoxDecoration(
                      gradient: LinearGradient(colors: [_lighten(color, 0.15), color],
                          begin: Alignment.topLeft, end: Alignment.bottomRight),
                      shape: BoxShape.circle),
                  selectedTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                  rangeStartDecoration: BoxDecoration(
                      gradient: LinearGradient(colors: [_lighten(color, 0.15), color],
                          begin: Alignment.topLeft, end: Alignment.bottomRight),
                      shape: BoxShape.circle),
                  rangeEndDecoration: BoxDecoration(
                      gradient: LinearGradient(colors: [_lighten(color, 0.15), color],
                          begin: Alignment.topLeft, end: Alignment.bottomRight),
                      shape: BoxShape.circle),
                  rangeStartTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                  rangeEndTextStyle:   const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                  withinRangeDecoration: BoxDecoration(color: color.withOpacity(0.08)),
                  withinRangeTextStyle: TextStyle(color: color, fontWeight: FontWeight.w700),
                  todayDecoration: BoxDecoration(
                      color: color.withOpacity(0.15), shape: BoxShape.circle),
                  todayTextStyle: TextStyle(color: color, fontWeight: FontWeight.w900),
                  weekendTextStyle: const TextStyle(color: Color(0xFFFF4D64), fontWeight: FontWeight.w600),
                  defaultTextStyle: const TextStyle(fontWeight: FontWeight.w600, color: _text),
                  outsideTextStyle: TextStyle(color: _sub.withOpacity(0.35)),
                  cellMargin: const EdgeInsets.all(4),
                ),
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _text),
                  headerPadding: const EdgeInsets.symmetric(vertical: 12),
                  leftChevronIcon:  _chevron(Icons.chevron_left_rounded, color),
                  rightChevronIcon: _chevron(Icons.chevron_right_rounded, color),
                ),
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: TextStyle(color: _sub, fontSize: 12, fontWeight: FontWeight.w700),
                  weekendStyle: const TextStyle(color: Color(0xFFFF4D64), fontSize: 12, fontWeight: FontWeight.w700),
                ),
                onDaySelected: _leaveType.isSingleDay
                    ? (selected, focused) => setState(() {
                          _rangeStart = selected;
                          _rangeEnd   = null;
                          _focusedDay = focused;
                        })
                    : null,
                onRangeSelected: !_leaveType.isSingleDay
                    ? (start, end, focused) => setState(() {
                          _rangeStart = start;
                          _rangeEnd   = end;
                          _focusedDay = focused;
                        })
                    : null,
                onPageChanged: (d) => setState(() => _focusedDay = d),
              ),
            ),
          ),

          // ── 선택 요약
          if (_rangeStart != null) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _selectionSummary(),
            ),
          ],

          const SizedBox(height: 12),

          // ── 사유 입력
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _reasonRequired ? color.withOpacity(0.3) : Colors.transparent,
                  width: _reasonRequired ? 1.5 : 0,
                ),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: TextField(
                controller: _reasonCtrl,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _text),
                decoration: InputDecoration(
                  hintText: _reasonRequired
                      ? context.tr({'ko': '사유 입력 (필수)', 'en': 'Reason (required)', 'vi': 'Ly do (bat buoc)', 'uz': 'Sabab (majburiy)', 'km': 'មូលហេតុ (ចាំបាច់)'})
                      : context.tr({'ko': '사유 입력 (선택사항)', 'en': 'Reason (optional)', 'vi': 'Ly do (tuy chon)', 'uz': 'Sabab (ixtiyoriy)', 'km': 'មូលហេតុ (ស្រេចចិត្ត)'}),
                  hintStyle: TextStyle(color: _reasonRequired ? color.withOpacity(0.5) : _sub, fontSize: 13),
                  filled: true,
                  fillColor: Colors.transparent,
                  contentPadding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  border:         OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  enabledBorder:  OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  focusedBorder:  OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 12, right: 8),
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: _reasonRequired ? color.withOpacity(0.1) : Colors.grey.withOpacity(0.07),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.notes_rounded,
                          color: _reasonRequired ? color : _sub, size: 16),
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  suffixIcon: _reasonRequired
                      ? Padding(
                          padding: const EdgeInsets.only(right: 14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              context.tr({'ko': '필수', 'en': 'Required', 'vi': 'Bat buoc', 'uz': 'Majburiy', 'km': 'ចាំបាច់'}),
                              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800),
                            ),
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── 신청 버튼
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: _canSubmit
                ? _GradientSubmitBtn(
                    label: _buildBtnLabel(context),
                    color: color,
                    lighter: _lighten(color, 0.18),
                    isLoading: _isSubmitting,
                    onTap: _submit,
                  )
                : Container(
                    height: 54,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.black.withOpacity(0.08)),
                    ),
                    child: Center(
                      child: Text(
                        _buildBtnLabel(context),
                        style: TextStyle(
                          color: _sub,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
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
    if (_rangeStart == null) {
      return ctx.tr({'ko': '날짜를 선택해주세요', 'en': 'Select a date', 'vi': 'Chon ngay', 'uz': 'Sanani tanlang', 'km': 'ជ្រើសរើសកាលបរិច្ឆេទ'});
    }
    if (_reasonRequired && _reasonCtrl.text.trim().isEmpty) {
      return ctx.tr({'ko': '사유를 입력해주세요', 'en': 'Enter a reason', 'vi': 'Nhap ly do', 'uz': 'Sabab kiriting', 'km': 'បញ្ចូលមូលហេតុ'});
    }
    if (_leaveType.deductsLeave && _selectedDays > _remaining) {
      return ctx.tr({'ko': '잔여 연차 초과', 'en': 'Exceeds remaining leave', 'vi': 'Vuot qua so nghi con lai', 'uz': "Qolgan ta'tildan oshib ketdi", 'km': 'លើសពី휴가ដែលនៅសល់'});
    }
    if (_leaveType == LeaveType.half) {
      return ctx.tr({'ko': '반차 신청하기', 'en': 'Request Half Day', 'vi': 'Dang ky nua ngay', 'uz': "Yarim kun so'rash", 'km': 'ស្នើសុំ휴가ពាក់កណ្ដាល'});
    }
    final typeLbl = _leaveType.label(ctx);
    return ctx.tr({
      'ko': '${_fmt(_selectedDays)}$d $typeLbl 신청하기',
      'en': 'Request ${_fmt(_selectedDays)}$d $typeLbl',
      'vi': 'Dang ky ${_fmt(_selectedDays)}$d $typeLbl',
      'uz': '${_fmt(_selectedDays)}$d $typeLbl so\'rash',
      'km': 'ស្នើសុំ ${_fmt(_selectedDays)}$d $typeLbl',
    });
  }

  Widget _typeChip(LeaveType type, {bool fullWidth = false}) {
    final selected = _leaveType == type;
    final c        = type.color;
    final lighter  = _lighten(c, 0.18);

    return GestureDetector(
      onTap: () => _onTypeChanged(type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(colors: [lighter, c], begin: Alignment.topLeft, end: Alignment.bottomRight)
              : null,
          color: selected ? null : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: selected
              ? [BoxShadow(color: c.withOpacity(0.30), blurRadius: 10, offset: const Offset(0, 4))]
              : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          // 아이콘
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: selected ? Colors.white.withOpacity(0.22) : c.withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(type.icon, size: 14, color: selected ? Colors.white : c),
          ),
          const SizedBox(width: 7),
          Text(
            type.label(context),
            style: TextStyle(
              color: selected ? Colors.white : c,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          if (!type.deductsLeave) ...[
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: selected ? Colors.white.withOpacity(0.22) : c.withOpacity(0.08),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                context.tr({'ko': '연차무관', 'en': 'No deduct', 'vi': 'Khong tru', 'uz': 'Chegirmaydi', 'km': 'មិនកាត់'}),
                style: TextStyle(
                    color: selected ? Colors.white.withOpacity(0.85) : c.withOpacity(0.7),
                    fontSize: 9, fontWeight: FontWeight.w700),
              ),
            ),
          ],
          const SizedBox(width: 4),
          Icon(
            type.isSingleDay ? Icons.looks_one_rounded : Icons.date_range_rounded,
            size: 11,
            color: selected ? Colors.white.withOpacity(0.65) : _sub.withOpacity(0.4),
          ),
        ]),
      ),
    );
  }

  Widget _selectionSummary() {
    final fmt  = DateFormat('MM/dd');
    final end  = _leaveType.isSingleDay ? _rangeStart! : (_rangeEnd ?? _rangeStart!);
    final over = _leaveType.deductsLeave && _selectedDays > _remaining;
    final c    = over ? _red : _leaveType.color;
    final d    = _dayUnit(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(color: c.withOpacity(0.10), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: c.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            over ? Icons.warning_rounded : Icons.check_circle_rounded,
            color: c, size: 16,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            over
                ? context.tr({'ko': '잔여 연차 ${_fmt(_remaining)}$d 초과! 신청 불가', 'en': 'Exceeds ${_fmt(_remaining)}$d remaining!', 'vi': 'Vuot ${_fmt(_remaining)}$d con lai!', 'uz': '${_fmt(_remaining)}$d dan oshib ketdi!', 'km': 'លើស ${_fmt(_remaining)}$d ដែលនៅសល់!'})
                : "${fmt.format(_rangeStart!)} ~ ${fmt.format(end)}  ·  "
                  "${_leaveType == LeaveType.half
                      ? context.tr({'ko': '반차 (0.5일)', 'en': 'Half day (0.5d)', 'vi': 'Nua ngay (0.5n)', 'uz': 'Yarim kun', 'km': 'ពាក់កណ្ដាល (0.5d)'})
                      : '${_fmt(_selectedDays)}$d ${_leaveType.label(context)}'}",
            style: TextStyle(color: c, fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
      ]),
    );
  }

  Widget _chevron(IconData icon, Color color) => Container(
    padding: const EdgeInsets.all(7),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Icon(icon, color: color, size: 18),
  );

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _isSubmitting = true);
    final end = _leaveType.isSingleDay ? _rangeStart! : (_rangeEnd ?? _rangeStart!);
    await widget.onSubmit(_rangeStart!, end, _selectedDays, _reasonCtrl.text, _leaveType.code);
    if (mounted) Navigator.pop(context);
  }
}

// ══════════════════════════════════════════
// 신청 버튼
// ══════════════════════════════════════════
class _GradientSubmitBtn extends StatefulWidget {
  final String label;
  final Color color, lighter;
  final bool isLoading;
  final VoidCallback onTap;

  const _GradientSubmitBtn({
    required this.label,
    required this.color,
    required this.lighter,
    required this.isLoading,
    required this.onTap,
  });

  @override
  State<_GradientSubmitBtn> createState() => _GradientSubmitBtnState();
}

class _GradientSubmitBtnState extends State<_GradientSubmitBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   widget.isLoading ? null : (_) => setState(() => _pressed = true),
      onTapUp:     widget.isLoading ? null : (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          height: 54,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [widget.lighter, widget.color],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: _pressed
                ? []
                : [BoxShadow(
                    color: widget.color.withOpacity(0.38),
                    blurRadius: 14, offset: const Offset(0, 6))],
          ),
          child: Stack(children: [
            Positioned(
              top: -15, right: -10,
              child: Container(width: 60, height: 60,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.08))),
            ),
            Center(
              child: widget.isLoading
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.22),
                            shape: BoxShape.circle),
                        child: const Icon(Icons.send_rounded, color: Colors.white, size: 16),
                      ),
                      const SizedBox(width: 10),
                      Text(widget.label,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 15,
                              fontWeight: FontWeight.w900)),
                    ]),
            ),
          ]),
        ),
      ),
    );
  }
}