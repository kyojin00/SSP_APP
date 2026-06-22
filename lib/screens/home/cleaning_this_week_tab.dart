part of 'cleaning_screen.dart';

// ══════════════════════════════════════════
// 이번 주 탭
// ══════════════════════════════════════════

class _CleaningThisWeekTab extends StatelessWidget {
  final _CleaningScreenState state;
  const _CleaningThisWeekTab({required this.state});

  @override
  Widget build(BuildContext context) {
    final isAdmin = state._isAdmin;
    final floor2  = state._schedules.where((s) => s['floor'] == 2).toList();
    final floor3  = state._schedules.where((s) => s['floor'] == 3).toList();

    return RefreshIndicator(
      onRefresh: state._loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _FloorWeekSection(floor: 2, schedules: floor2, state: state, isAdmin: isAdmin),
          const SizedBox(height: 16),
          _FloorWeekSection(floor: 3, schedules: floor3, state: state, isAdmin: isAdmin),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════
// 층별 섹션
// ══════════════════════════════════════════

class _FloorWeekSection extends StatelessWidget {
  final int   floor;
  final List<Map<String, dynamic>> schedules;
  final _CleaningScreenState state;
  final bool  isAdmin;

  const _FloorWeekSection({
    required this.floor,
    required this.schedules,
    required this.state,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
    final color      = floor == 2 ? Colors.blue : Colors.purple;
    final info       = state._getCycleInfo(floor);
    final hasAssign  = schedules.isNotEmpty;
    final remaining  = state._getRemainingRooms(floor);
    final canSelect  = isAdmin && !hasAssign && !info.isAutoMode && remaining.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── 헤더 + 사이클 진행바
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: Column(children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.layers_rounded, color: color, size: 16),
              ),
              const SizedBox(width: 10),
              Text('${floor}층',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: info.isAutoMode
                        ? Colors.green.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6)),
                child: Text(
                  info.isAutoMode
                      ? '사이클 ${info.cycleNumber} · 자동반복'
                      : '사이클 1 · 직접선택',
                  style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w800,
                      color: info.isAutoMode ? Colors.green : Colors.orange),
                ),
              ),
              const Spacer(),
              if (info.total > 0)
                Text('${info.progress}/${info.total}',
                    style: TextStyle(
                        fontSize: 12, color: color, fontWeight: FontWeight.w700)),
            ]),

            // 진행률 바 + 방 레이블
            if (info.total > 0) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: info.progress / info.total,
                  minHeight: 8,
                  backgroundColor: color.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
              const SizedBox(height: 6),
              // 방별 슬롯 표시
              Row(
                children: List.generate(info.total, (i) {
                  final history    = floor == 2 ? state._allHistory2 : state._allHistory3;
                  final cycleStart = (history.length ~/ info.total) * info.total;
                  final cycleItems = history.skip(cycleStart).toList();
                  final isDone     = i < cycleItems.length;
                  final label      = isDone
                      ? cycleItems[i]['room_label'].toString().split(' ').last
                      : '?';
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: isDone
                            ? color.withOpacity(0.12)
                            : Colors.grey.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Center(
                        child: Text(label,
                            style: TextStyle(
                                fontSize: 9, fontWeight: FontWeight.w700,
                                color: isDone ? color : Colors.grey[400]),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ]),
        ),

        // ── 이번 주 배정 내용
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(children: [
            if (info.total == 0)
              // 등록된 방 없음
              _StatusCard(
                icon: Icons.add_circle_outline_rounded,
                message: isAdmin
                    ? '순번 관리 탭에서 청소 방을 추가해 주세요.'
                    : '청소 방이 아직 등록되지 않았습니다.',
                color: Colors.grey,
              )
            else if (hasAssign)
              // ✅ 배정된 방 카드들 (2개)
              ...schedules.map((s) =>
                  _ScheduleCard(schedule: s, state: state, isAdmin: isAdmin))
            else if (canSelect)
              // 첫 사이클: 방 선택 버튼
              _SelectButton(floor: floor, color: color, state: state)
            else if (!hasAssign)
              // 대기 또는 자동배정 처리 중
              _StatusCard(
                icon: info.isAutoMode
                    ? Icons.autorenew_rounded
                    : Icons.hourglass_empty_rounded,
                message: info.isAutoMode
                    ? '자동 배정 처리 중...'
                    : isAdmin
                        ? '이번 사이클의 모든 방이 완료되었습니다.'
                        : '이번 주 청소 방이 아직 배정되지 않았습니다.',
                color: info.isAutoMode ? Colors.teal : Colors.grey,
              ),
          ]),
        ),
      ]),
    );
  }
}

// ── 방 선택 버튼
class _SelectButton extends StatelessWidget {
  final int   floor;
  final Color color;
  final _CleaningScreenState state;

  const _SelectButton({
    required this.floor,
    required this.color,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => state._showRoomSelector(floor),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.add_circle_outline_rounded, color: color, size: 20),
          const SizedBox(width: 8),
          Text('이번 주 청소 방 2개 선택',
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w800, fontSize: 14)),
        ]),
      ),
    );
  }
}

// ── 상태 카드
class _StatusCard extends StatelessWidget {
  final IconData icon;
  final String   message;
  final Color    color;
  const _StatusCard({required this.icon, required this.message, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withOpacity(0.12)),
      ),
      child: Column(children: [
        Icon(icon, color: color.withOpacity(0.5), size: 36),
        const SizedBox(height: 8),
        Text(message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500], fontSize: 13)),
      ]),
    );
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
    required this.schedule,
    required this.state,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
    final floor        = schedule['floor'] as int;
    final roomLabel    = schedule['room_label'] as String;
    final assignedDate = DateTime.parse(schedule['assigned_date']);
    final record       = state._records[schedule['id']];
    final isDone       = record != null;
    final photoUrl     = record?['photo_url'] as String?;
    final isWeekend    = assignedDate.weekday >= 6;
    final floorColor   = floor == 2 ? Colors.blue : Colors.purple;
    final hasPhotoUnconfirmed = photoUrl != null && !isDone;
    final names        = state._residentNames[roomLabel] ?? [];

    return GestureDetector(
      onTap: () => state._showResidents(roomLabel),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isDone
              ? Colors.green.withOpacity(0.03)
              : hasPhotoUnconfirmed
                  ? Colors.teal.withOpacity(0.03)
                  : Colors.grey.withOpacity(0.02),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isDone
                  ? Colors.green.withOpacity(0.2)
                  : hasPhotoUnconfirmed
                      ? Colors.teal.withOpacity(0.3)
                      : floorColor.withOpacity(0.15)),
        ),
        child: Column(children: [
          // 헤더
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: floorColor.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 방 이름 (작게)
                    Text(roomLabel,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: floorColor.withOpacity(0.7))),
                    const SizedBox(height: 4),
                    // 거주자 이름 (크게)
                    if (names.isNotEmpty)
                      Text(
                        names.join('  ·  '),
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: floorColor,
                            height: 1.2),
                      )
                    else
                      Text('거주자 정보 없음',
                          style: TextStyle(fontSize: 13, color: Colors.grey[400])),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: isDone
                        ? Colors.green.withOpacity(0.1)
                        : hasPhotoUnconfirmed
                            ? Colors.teal.withOpacity(0.1)
                            : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                      isDone
                          ? Icons.check_circle_rounded
                          : hasPhotoUnconfirmed
                              ? Icons.photo_rounded
                              : Icons.pending_rounded,
                      size: 12,
                      color: isDone
                          ? Colors.green
                          : hasPhotoUnconfirmed ? Colors.teal : Colors.orange),
                  const SizedBox(width: 4),
                  Text(
                      isDone
                          ? context.tr(AppStrings.cleaningDone)
                          : hasPhotoUnconfirmed
                              ? context.tr(AppStrings.cleaningPhotoWaiting)
                              : context.tr(AppStrings.cleaningPending),
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700,
                          color: isDone
                              ? Colors.green
                              : hasPhotoUnconfirmed ? Colors.teal : Colors.orange)),
                ]),
              ),
            ]),
          ),

          // 날짜 + 버튼
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(children: [
              Row(children: [
                Icon(Icons.event_rounded, size: 14, color: Colors.grey[400]),
                const SizedBox(width: 6),
                Text(
                  '${context.tr(AppStrings.cleaningDate)}: '
                  '${DateFormat('MM/dd (E)', 'ko').format(assignedDate)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600],
                      fontWeight: FontWeight.w600),
                ),
                if (isWeekend) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4)),
                    child: Text(context.tr(AppStrings.cleaningWeekend),
                        style: const TextStyle(fontSize: 9, color: Colors.red,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
                if (isAdmin) ...[
                  const Spacer(),
                  GestureDetector(
                    onTap: () => state._changeDate(schedule),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6)),
                      child: Text(context.tr(AppStrings.cleaningChangeDate),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ]),

              // 사진 미리보기
              if (photoUrl != null) ...[
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => state._showPhotoDialog(photoUrl),
                  child: Stack(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(photoUrl, height: 140,
                          width: double.infinity, fit: BoxFit.cover),
                    ),
                    Positioned(right: 8, bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.zoom_in_rounded,
                            color: Colors.white, size: 16),
                      ),
                    ),
                  ]),
                ),
              ],

              const SizedBox(height: 10),

              // 버튼: 사용자=사진 업로드 / 관리자=완료 확인
              if (!isAdmin)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => state._uploadPhoto(schedule),
                    icon: Icon(photoUrl != null
                        ? Icons.photo_camera_rounded : Icons.add_a_photo_rounded,
                        size: 14, color: Colors.teal),
                    label: Text(
                        photoUrl != null
                            ? context.tr(AppStrings.cleaningPhotoReupload)
                            : context.tr(AppStrings.cleaningPhotoUpload),
                        style: const TextStyle(fontSize: 12, color: Colors.teal,
                            fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      side: const BorderSide(color: Colors.teal),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => state._toggleComplete(schedule),
                    icon: Icon(isDone ? Icons.cancel_outlined : Icons.check_circle_outline,
                        size: 14, color: isDone ? Colors.red : Colors.green),
                    label: Text(
                        isDone
                            ? context.tr(AppStrings.cleaningUndone)
                            : context.tr(AppStrings.cleaningCheck),
                        style: TextStyle(fontSize: 12,
                            color: isDone ? Colors.red : Colors.green,
                            fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      side: BorderSide(color: isDone ? Colors.red : Colors.green),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}