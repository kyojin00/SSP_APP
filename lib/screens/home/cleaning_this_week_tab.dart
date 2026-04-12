part of 'cleaning_screen.dart';

class _CleaningThisWeekTab extends StatefulWidget {
  final _CleaningScreenState state;
  const _CleaningThisWeekTab({required this.state});

  @override
  State<_CleaningThisWeekTab> createState() => _CleaningThisWeekTabState();
}

class _CleaningThisWeekTabState extends State<_CleaningThisWeekTab> {
  Map<String, bool> _expanded = {};

  static const _teal   = Color(0xFF00BCD4);
  static const _tealDk = Color(0xFF0097A7);

  @override
  void initState() {
    super.initState();
    _initExpanded();
  }

  @override
  void didUpdateWidget(_CleaningThisWeekTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    for (final key in _grouped().keys) {
      _expanded.putIfAbsent(key, () => key == widget.state._thisMonday);
    }
  }

  void _initExpanded() {
    _expanded = {};
    for (final key in _grouped().keys) {
      _expanded[key] = key == widget.state._thisMonday;
    }
  }

  Map<String, List<Map<String, dynamic>>> _grouped() {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final s in widget.state._schedules) {
      grouped.putIfAbsent(s['week_start'] as String, () => []).add(s);
    }
    return grouped;
  }

  Color _lighten(Color c, double a) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + a).clamp(0.0, 1.0)).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.state._isAdmin;
    final grouped = _grouped();

    return RefreshIndicator(
      onRefresh: widget.state._loadData,
      color: _teal,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 40),
        child: Column(children: [
          if (grouped.isEmpty) ...[
            const SizedBox(height: 60),
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white, shape: BoxShape.circle,
                boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 14, offset: const Offset(0, 4))],
              ),
              child: Icon(Icons.cleaning_services_rounded,
                  size: 40, color: Colors.grey[300]),
            ),
            const SizedBox(height: 16),
            Text(
              isAdmin
                  ? context.tr(AppStrings.cleaningNoScheduleAdmin)
                  : context.tr(AppStrings.cleaningNoSchedule),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[400], fontSize: 14,
                  fontWeight: FontWeight.w600),
            ),
            if (isAdmin) ...[
              const SizedBox(height: 24),
              _GenerateButton(state: widget.state),
            ],
          ] else ...[
            for (final entry in grouped.entries)
              _WeekSection(
                weekStart:  entry.key,
                schedules:  entry.value,
                state:      widget.state,
                isAdmin:    isAdmin,
                isExpanded: _expanded[entry.key] ?? false,
                onToggle:   () => setState(() {
                  _expanded[entry.key] = !(_expanded[entry.key] ?? false);
                }),
              ),
            if (isAdmin) ...[
              const SizedBox(height: 8),
              _GenerateButton(state: widget.state),
            ],
          ],
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════
// 주차 섹션
// ══════════════════════════════════════════
class _WeekSection extends StatelessWidget {
  final String weekStart;
  final List<Map<String, dynamic>> schedules;
  final _CleaningScreenState state;
  final bool isAdmin, isExpanded;
  final VoidCallback onToggle;

  const _WeekSection({
    required this.weekStart, required this.schedules,
    required this.state,     required this.isAdmin,
    required this.isExpanded, required this.onToggle,
  });

  static const _teal   = Color(0xFF00BCD4);
  static const _tealDk = Color(0xFF0097A7);
  static const _text   = Color(0xFF1A1D2E);
  static const _sub    = Color(0xFF8A93B0);

  Color _lighten(Color c, double a) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + a).clamp(0.0, 1.0)).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final monday     = DateTime.parse(weekStart);
    final sunday     = monday.add(const Duration(days: 6));
    final isThisWeek = weekStart == state._thisMonday;
    final floor2     = schedules.where((s) => s['floor'] == 2).toList();
    final floor3     = schedules.where((s) => s['floor'] == 3).toList();
    final total      = schedules.length;
    final done       = schedules.where((s) => state._records[s['id']] != null).length;
    final ratio      = total > 0 ? done / total : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: isThisWeek
                  ? _teal.withOpacity(0.12)
                  : Colors.black.withOpacity(0.04),
              blurRadius: 10, offset: const Offset(0, 4)),
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 5, offset: const Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(children: [
          // ── 그라디언트 헤더 (이번주) / 일반 헤더
          GestureDetector(
            onTap: onToggle,
            behavior: HitTestBehavior.opaque,
            child: isThisWeek
                ? Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: [_lighten(_tealDk, 0.15), _tealDk],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight),
                    ),
                    child: Column(children: [
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.22),
                              borderRadius: BorderRadius.circular(8)),
                          child: const Text('이번 주',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 11,
                                  fontWeight: FontWeight.w900)),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${DateFormat('MM/dd').format(monday)} ~ '
                          '${DateFormat('MM/dd').format(sunday)}',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w800,
                              color: Colors.white),
                        ),
                        const Spacer(),
                        Text('$done/$total',
                            style: TextStyle(
                                fontSize: 12, color: Colors.white.withOpacity(0.8),
                                fontWeight: FontWeight.w700)),
                        const SizedBox(width: 8),
                        AnimatedRotation(
                          turns: isExpanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: const Icon(Icons.keyboard_arrow_down_rounded,
                              color: Colors.white, size: 20),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      // 진행 바
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ratio, minHeight: 5,
                          backgroundColor: Colors.white.withOpacity(0.25),
                          valueColor: const AlwaysStoppedAnimation(Colors.white),
                        ),
                      ),
                    ]),
                  )
                : Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                            color: _teal.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(9)),
                        child: const Icon(Icons.calendar_month_rounded,
                            color: _teal, size: 14),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${DateFormat('MM/dd').format(monday)} ~ '
                        '${DateFormat('MM/dd').format(sunday)}',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w800,
                            color: _text),
                      ),
                      const Spacer(),
                      Text('$done/$total',
                          style: const TextStyle(
                              fontSize: 12, color: _sub,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(width: 6),
                      AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(Icons.keyboard_arrow_down_rounded,
                            color: _sub, size: 20),
                      ),
                    ]),
                  ),
          ),

          // ── 콘텐츠
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Column(children: [
              Divider(height: 1,
                  color: isThisWeek
                      ? _teal.withOpacity(0.15)
                      : Colors.grey.withOpacity(0.1)),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                child: Column(children: [
                  if (floor2.isNotEmpty) ...[
                    _FloorLabel(floor: 2),
                    const SizedBox(height: 8),
                    for (final s in floor2)
                      _ScheduleCard(schedule: s, state: state, isAdmin: isAdmin),
                  ],
                  if (floor3.isNotEmpty) ...[
                    if (floor2.isNotEmpty) const SizedBox(height: 10),
                    _FloorLabel(floor: 3),
                    const SizedBox(height: 8),
                    for (final s in floor3)
                      _ScheduleCard(schedule: s, state: state, isAdmin: isAdmin),
                  ],
                ]),
              ),
            ]),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════
// 층 레이블
// ══════════════════════════════════════════
class _FloorLabel extends StatelessWidget {
  final int floor;
  const _FloorLabel({required this.floor});

  Color _lighten(Color c, double a) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + a).clamp(0.0, 1.0)).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final color = floor == 2 ? const Color(0xFF2E6BFF) : const Color(0xFF8E59FF);
    return Row(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [_lighten(color, 0.18), color],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(9),
          boxShadow: [BoxShadow(
              color: color.withOpacity(0.25), blurRadius: 6,
              offset: const Offset(0, 2))],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.layers_rounded, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text('$floor층', style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white)),
        ]),
      ),
      Expanded(child: Divider(indent: 8, color: color.withOpacity(0.15))),
    ]);
  }
}

// ══════════════════════════════════════════
// 스케줄 카드
// ══════════════════════════════════════════
class _ScheduleCard extends StatelessWidget {
  final Map<String, dynamic> schedule;
  final _CleaningScreenState state;
  final bool isAdmin;

  const _ScheduleCard({
    required this.schedule, required this.state, required this.isAdmin,
  });

  static const _text = Color(0xFF1A1D2E);
  static const _sub  = Color(0xFF8A93B0);

  Color _lighten(Color c, double a) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + a).clamp(0.0, 1.0)).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final floor        = schedule['floor'] as int;
    final roomLabel    = schedule['room_label'] as String;
    final assignedDate = DateTime.parse(schedule['assigned_date']);
    final record       = state._records[schedule['id']];
    final isDone       = record != null;
    final photoUrl     = record?['photo_url'] as String?;
    final isWeekend    = assignedDate.weekday >= 6;
    final floorColor   = floor == 2
        ? const Color(0xFF2E6BFF)
        : const Color(0xFF8E59FF);
    final lighter = _lighten(floorColor, 0.18);

    return GestureDetector(
      onTap: () => state._showResidents(roomLabel),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: isDone
                    ? Colors.green.withOpacity(0.08)
                    : floorColor.withOpacity(0.07),
                blurRadius: 10, offset: const Offset(0, 3)),
            BoxShadow(color: Colors.black.withOpacity(0.04),
                blurRadius: 5, offset: const Offset(0, 2)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(children: [
            // 상단 컬러 바
            Container(
              height: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: isDone
                        ? [Colors.green.shade300, Colors.green.shade600]
                        : [lighter, floorColor]),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(children: [
                Row(children: [
                  // 호실 아이콘
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: isDone
                              ? [Colors.green.shade300, Colors.green.shade600]
                              : [lighter, floorColor],
                          begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(
                          color: (isDone ? Colors.green : floorColor).withOpacity(0.25),
                          blurRadius: 6, offset: const Offset(0, 2))],
                    ),
                    child: Icon(
                        isDone
                            ? Icons.check_rounded
                            : Icons.cleaning_services_rounded,
                        color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(roomLabel,
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w900,
                            color: isDone ? Colors.green.shade700 : _text)),
                  ),
                  // 상태 뱃지
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: isDone
                              ? [Colors.green.shade300, Colors.green.shade600]
                              : [Colors.orange.shade300, Colors.orange.shade600],
                          begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [BoxShadow(
                          color: (isDone ? Colors.green : Colors.orange)
                              .withOpacity(0.25),
                          blurRadius: 5, offset: const Offset(0, 2))],
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(
                          isDone
                              ? Icons.check_circle_rounded
                              : Icons.pending_rounded,
                          size: 11, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                          isDone
                              ? context.tr(AppStrings.cleaningDone)
                              : context.tr(AppStrings.cleaningPending),
                          style: const TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w900,
                              color: Colors.white)),
                    ]),
                  ),
                ]),

                const SizedBox(height: 10),
                // 날짜 + 액션
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: const Color(0xFFF4F6FB),
                        borderRadius: BorderRadius.circular(8)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.event_rounded, size: 11, color: _sub),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('MM/dd (E)', 'ko').format(assignedDate),
                        style: const TextStyle(fontSize: 11, color: _sub,
                            fontWeight: FontWeight.w600)),
                      if (isWeekend) ...[
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4)),
                          child: Text(context.tr(AppStrings.cleaningWeekend),
                              style: const TextStyle(
                                  fontSize: 9, color: Colors.red,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ]),
                  ),
                  const Spacer(),
                  // 어드민 액션
                  if (isAdmin) ...[
                    _actionBtn(
                      icon: Icons.edit_calendar_rounded, color: _sub,
                      onTap: () => state._changeDate(schedule),
                    ),
                    const SizedBox(width: 6),
                    _actionBtn(
                      icon: isDone
                          ? Icons.cancel_rounded
                          : Icons.check_circle_rounded,
                      color: isDone ? Colors.orange : Colors.green,
                      onTap: () => state._toggleComplete(schedule),
                    ),
                    const SizedBox(width: 6),
                    _actionBtn(
                      icon: Icons.photo_camera_rounded, color: const Color(0xFF2E6BFF),
                      onTap: () => state._uploadPhoto(schedule),
                    ),
                  ] else ...[
                    _actionBtn(
                      icon: isDone ? Icons.cancel_rounded : Icons.check_circle_rounded,
                      color: isDone ? Colors.orange : Colors.green,
                      onTap: () => state._toggleComplete(schedule),
                    ),
                    const SizedBox(width: 6),
                    _actionBtn(
                      icon: Icons.photo_camera_rounded, color: const Color(0xFF2E6BFF),
                      onTap: () => state._uploadPhoto(schedule),
                    ),
                  ],
                ]),

                // 사진 미리보기
                if (photoUrl != null) ...[
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => state._showPhotoDialog(photoUrl),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(photoUrl, height: 90,
                          width: double.infinity, fit: BoxFit.cover),
                    ),
                  ),
                ],
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _actionBtn({
    required IconData icon, required Color color, required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: color.withOpacity(0.2))),
        child: Icon(icon, color: color, size: 15),
      ),
    );
  }
}

// ══════════════════════════════════════════
// 스케줄 생성 버튼
// ══════════════════════════════════════════
class _GenerateButton extends StatelessWidget {
  final _CleaningScreenState state;
  const _GenerateButton({required this.state});

  static const _teal   = Color(0xFF00BCD4);
  static const _tealDk = Color(0xFF0097A7);

  Color _lighten(Color c, double a) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + a).clamp(0.0, 1.0)).toColor();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: state._isGenerating ? null : state._generateSchedule,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: state._isGenerating
                  ? [Colors.grey.shade300, Colors.grey.shade400]
                  : [_lighten(_tealDk, 0.12), _tealDk],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(14),
          boxShadow: state._isGenerating ? [] : [BoxShadow(
              color: _tealDk.withOpacity(0.30),
              blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          state._isGenerating
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.auto_awesome_rounded,
                  size: 18, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            state._isGenerating
                ? context.tr(AppStrings.cleaningGenerating)
                : context.tr(AppStrings.cleaningGenerate),
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w900,
                color: Colors.white),
          ),
        ]),
      ),
    );
  }
}