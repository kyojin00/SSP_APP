part of 'cleaning_screen.dart';

class _CleaningThisWeekTab extends StatefulWidget {
  final _CleaningScreenState state;
  const _CleaningThisWeekTab({required this.state});

  @override
  State<_CleaningThisWeekTab> createState() => _CleaningThisWeekTabState();
}

class _CleaningThisWeekTabState extends State<_CleaningThisWeekTab> {
  Map<String, bool> _expanded = {};

  @override
  void initState() {
    super.initState();
    _initExpanded();
  }

  @override
  void didUpdateWidget(_CleaningThisWeekTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 새 주차 추가 시 기본값 세팅
    final grouped = _grouped();
    for (final key in grouped.keys) {
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

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.state._isAdmin;
    final grouped = _grouped();

    return RefreshIndicator(
      onRefresh: widget.state._loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          if (grouped.isEmpty) ...[
            const SizedBox(height: 48),
            Icon(Icons.cleaning_services_rounded,
                size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              isAdmin
                  ? context.tr(AppStrings.cleaningNoScheduleAdmin)
                  : context.tr(AppStrings.cleaningNoSchedule),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
            if (isAdmin) ...[
              const SizedBox(height: 24),
              _GenerateButton(state: widget.state),
            ],
          ] else ...[
            for (final entry in grouped.entries)
              _WeekSection(
                weekStart: entry.key,
                schedules: entry.value,
                state: widget.state,
                isAdmin: isAdmin,
                isExpanded: _expanded[entry.key] ?? false,
                onToggle: () => setState(() {
                  _expanded[entry.key] =
                      !(_expanded[entry.key] ?? false);
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
// 주차 섹션 (접기/펼치기)
// ══════════════════════════════════════════
class _WeekSection extends StatelessWidget {
  final String weekStart;
  final List<Map<String, dynamic>> schedules;
  final _CleaningScreenState state;
  final bool isAdmin;
  final bool isExpanded;
  final VoidCallback onToggle;

  const _WeekSection({
    required this.weekStart,
    required this.schedules,
    required this.state,
    required this.isAdmin,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final monday = DateTime.parse(weekStart);
    final sunday = monday.add(const Duration(days: 6));
    final isThisWeek = weekStart == state._thisMonday;

    final floor2 = schedules.where((s) => s['floor'] == 2).toList();
    final floor3 = schedules.where((s) => s['floor'] == 3).toList();

    final total = schedules.length;
    final done =
        schedules.where((s) => state._records[s['id']] != null).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isThisWeek
              ? Colors.teal.withOpacity(0.4)
              : Colors.grey.withOpacity(0.15),
          width: isThisWeek ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(children: [
        // ── 헤더
        GestureDetector(
          onTap: onToggle,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isThisWeek
                  ? Colors.teal.withOpacity(0.06)
                  : Colors.transparent,
              borderRadius: isExpanded
                  ? const BorderRadius.vertical(top: Radius.circular(18))
                  : BorderRadius.circular(18),
            ),
            child: Row(children: [
              if (isThisWeek)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: Colors.teal,
                      borderRadius: BorderRadius.circular(6)),
                  child: const Text('이번 주',
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.w800)),
                ),
              Expanded(
                child: Text(
                  '${DateFormat('MM/dd (E)', 'ko').format(monday)}'
                  ' ~ '
                  '${DateFormat('MM/dd (E)', 'ko').format(sunday)}',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isThisWeek ? Colors.teal : Colors.black87),
                ),
              ),
              // 완료 현황
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: done == total
                        ? Colors.green.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6)),
                child: Text('$done / $total',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: done == total
                            ? Colors.green
                            : Colors.orange)),
              ),
              AnimatedRotation(
                turns: isExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(Icons.keyboard_arrow_down_rounded,
                    color: isThisWeek ? Colors.teal : Colors.grey,
                    size: 22),
              ),
            ]),
          ),
        ),

        // ── 콘텐츠
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity, height: 0),
          secondChild: Column(children: [
            Divider(
                height: 1,
                color: isThisWeek
                    ? Colors.teal.withOpacity(0.15)
                    : Colors.grey.withOpacity(0.15)),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(children: [
                if (floor2.isNotEmpty) ...[
                  _FloorLabel(floor: 2),
                  const SizedBox(height: 8),
                  for (final s in floor2)
                    _ScheduleCard(
                        schedule: s, state: state, isAdmin: isAdmin),
                ],
                if (floor3.isNotEmpty) ...[
                  if (floor2.isNotEmpty) const SizedBox(height: 8),
                  _FloorLabel(floor: 3),
                  const SizedBox(height: 8),
                  for (final s in floor3)
                    _ScheduleCard(
                        schedule: s, state: state, isAdmin: isAdmin),
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
    );
  }
}

// ── 층 레이블
class _FloorLabel extends StatelessWidget {
  final int floor;
  const _FloorLabel({required this.floor});

  @override
  Widget build(BuildContext context) {
    final color = floor == 2 ? Colors.blue : Colors.purple;
    return Row(children: [
      Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.layers_rounded, size: 13, color: color),
          const SizedBox(width: 4),
          Text('${floor}층',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: color)),
        ]),
      ),
      Expanded(
          child: Divider(
              indent: 8, color: color.withOpacity(0.15))),
    ]);
  }
}

// ── 스케줄 생성 버튼
class _GenerateButton extends StatelessWidget {
  final _CleaningScreenState state;
  const _GenerateButton({required this.state});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: state._isGenerating ? null : state._generateSchedule,
        icon: state._isGenerating
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.auto_awesome_rounded, size: 18),
        label: Text(state._isGenerating
            ? context.tr(AppStrings.cleaningGenerating)
            : context.tr(AppStrings.cleaningGenerate)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

// ── 스케줄 카드
class _ScheduleCard extends StatelessWidget {
  final Map<String, dynamic> schedule;
  final _CleaningScreenState state;
  final bool isAdmin;

  const _ScheduleCard({
    required this.schedule,
    required this.state,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
    final floor = schedule['floor'] as int;
    final roomLabel = schedule['room_label'] as String;
    final assignedDate = DateTime.parse(schedule['assigned_date']);
    final record = state._records[schedule['id']];
    final isDone = record != null;
    final photoUrl = record?['photo_url'] as String?;
    final isWeekend = assignedDate.weekday >= 6;
    final floorColor = floor == 2 ? Colors.blue : Colors.purple;

    return GestureDetector(
      onTap: () => state._showResidents(roomLabel),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isDone
              ? Colors.green.withOpacity(0.03)
              : Colors.grey.withOpacity(0.02),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isDone
                  ? Colors.green.withOpacity(0.2)
                  : floorColor.withOpacity(0.15)),
        ),
        child: Column(children: [
          // 헤더
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: floorColor.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14)),
            ),
            child: Row(children: [
              Expanded(
                child: Text(roomLabel,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: floorColor)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: isDone
                        ? Colors.green.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                      isDone
                          ? Icons.check_circle_rounded
                          : Icons.pending_rounded,
                      size: 12,
                      color: isDone ? Colors.green : Colors.orange),
                  const SizedBox(width: 4),
                  Text(
                      isDone
                          ? context.tr(AppStrings.cleaningDone)
                          : context.tr(AppStrings.cleaningPending),
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDone
                              ? Colors.green
                              : Colors.orange)),
                ]),
              ),
            ]),
          ),

          // 날짜 + 액션
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(children: [
              Row(children: [
                Icon(Icons.event_rounded,
                    size: 14, color: Colors.grey[400]),
                const SizedBox(width: 6),
                Text(
                  '${context.tr(AppStrings.cleaningDate)}: '
                  '${DateFormat('MM/dd (E)', 'ko').format(assignedDate)}',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w600),
                ),
                if (isWeekend) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4)),
                    child: Text(
                        context.tr(AppStrings.cleaningWeekend),
                        style: const TextStyle(
                            fontSize: 9,
                            color: Colors.red,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
                if (isAdmin) ...[
                  const Spacer(),
                  GestureDetector(
                    onTap: () => state._changeDate(schedule),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6)),
                      child: Text(
                          context.tr(AppStrings.cleaningChangeDate),
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ]),

              if (photoUrl != null) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(photoUrl,
                      height: 140,
                      width: double.infinity,
                      fit: BoxFit.cover),
                ),
              ],

              if (isAdmin) ...[
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          state._toggleComplete(schedule),
                      icon: Icon(
                          isDone
                              ? Icons.cancel_outlined
                              : Icons.check_circle_outline,
                          size: 14,
                          color:
                              isDone ? Colors.red : Colors.green),
                      label: Text(
                          isDone
                              ? context.tr(AppStrings.cleaningUndone)
                              : context.tr(AppStrings.cleaningCheck),
                          style: TextStyle(
                              fontSize: 12,
                              color:
                                  isDone ? Colors.red : Colors.green,
                              fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 8),
                        side: BorderSide(
                            color:
                                isDone ? Colors.red : Colors.green),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => state._uploadPhoto(schedule),
                      icon: const Icon(Icons.photo_camera_rounded,
                          size: 14, color: Colors.teal),
                      label: Text(
                          context.tr(AppStrings.cleaningPhotoUpload),
                          style: const TextStyle(
                              fontSize: 12,
                              color: Colors.teal,
                              fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 8),
                        side: const BorderSide(color: Colors.teal),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ]),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}