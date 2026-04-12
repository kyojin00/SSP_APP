part of 'cleaning_screen.dart';

class _CleaningHistoryTab extends StatelessWidget {
  final _CleaningScreenState state;
  const _CleaningHistoryTab({required this.state});

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
    return FutureBuilder(
      future: state.supabase
          .from('cleaning_schedule')
          .select('*, cleaning_records(*)')
          .order('week_start', ascending: false)
          .limit(40),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: _teal));
        }
        final all = List<Map<String, dynamic>>.from(snapshot.data as List);
        if (all.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white, shape: BoxShape.circle,
                  boxShadow: [BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 14, offset: const Offset(0, 4))],
                ),
                child: Icon(Icons.history_rounded, size: 36,
                    color: Colors.grey[300]),
              ),
              const SizedBox(height: 14),
              Text(context.tr(AppStrings.cleaningNoHistory),
                  style: TextStyle(color: Colors.grey[400],
                      fontWeight: FontWeight.w600)),
            ]),
          );
        }

        // week_start 기준 그룹핑
        final grouped = <String, List<Map<String, dynamic>>>{};
        for (final s in all) {
          grouped.putIfAbsent(s['week_start'] as String, () => []).add(s);
        }

        // 전체 완료율
        final totalCount = all.length;
        final doneCount  = all.where((s) {
          final recs = s['cleaning_records'] as List?;
          return recs != null && recs.isNotEmpty;
        }).length;

        return ListView(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 48),
          children: [
            // ── 전체 통계 카드
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [_lighten(_tealDk, 0.15), _tealDk],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: _tealDk.withOpacity(0.28),
                      blurRadius: 14, offset: const Offset(0, 6)),
                  BoxShadow(color: Colors.black.withOpacity(0.05),
                      blurRadius: 6, offset: const Offset(0, 2)),
                ],
              ),
              child: Stack(children: [
                Positioned(right: -20, top: -20, child: Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.07)))),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle),
                      child: const Icon(Icons.history_rounded,
                          color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('청소 기록',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 11, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text('총 $totalCount건 · 완료 $doneCount건',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16,
                              fontWeight: FontWeight.w900)),
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                      Text('${totalCount > 0 ? (doneCount / totalCount * 100).toStringAsFixed(0) : 0}%',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 22,
                              fontWeight: FontWeight.w900)),
                      Text('완료율', style: TextStyle(
                          color: Colors.white.withOpacity(0.65), fontSize: 11)),
                    ]),
                  ]),
                ),
              ]),
            ),

            // ── 주차별 목록
            ...grouped.entries.map((entry) {
              final monday    = DateTime.parse(entry.key);
              final sunday    = monday.add(const Duration(days: 6));
              final weekDone  = entry.value.where((s) {
                final recs = s['cleaning_records'] as List?;
                return recs != null && recs.isNotEmpty;
              }).length;
              final weekTotal = entry.value.length;
              final allDone   = weekDone == weekTotal;

              return Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                // 주 헤더
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                            colors: [_lighten(_teal, 0.15), _teal],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: [BoxShadow(
                            color: _teal.withOpacity(0.25), blurRadius: 6,
                            offset: const Offset(0, 2))],
                      ),
                      child: const Icon(Icons.date_range_rounded,
                          color: Colors.white, size: 13),
                    ),
                    const SizedBox(width: 9),
                    Text(
                      '${DateFormat('MM/dd').format(monday)} ~ '
                      '${DateFormat('MM/dd').format(sunday)}',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w900,
                          color: _text),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: allDone
                              ? Colors.green.withOpacity(0.1)
                              : _teal.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text('$weekDone/$weekTotal',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w800,
                              color: allDone ? Colors.green : _teal)),
                    ),
                  ]),
                ),
                ...entry.value.map(
                    (s) => _HistoryTile(schedule: s, state: state)),
                const SizedBox(height: 18),
              ]);
            }),
          ],
        );
      },
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final Map<String, dynamic> schedule;
  final _CleaningScreenState state;
  const _HistoryTile({required this.schedule, required this.state});

  static const _text = Color(0xFF1A1D2E);
  static const _sub  = Color(0xFF8A93B0);

  Color _lighten(Color c, double a) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + a).clamp(0.0, 1.0)).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final floor    = schedule['floor'] as int;
    final recs     = schedule['cleaning_records'] as List?;
    final record   = (recs != null && recs.isNotEmpty) ? recs.first : null;
    final isDone   = record != null;
    final photoUrl = record?['photo_url'] as String?;
    final color    = floor == 2
        ? const Color(0xFF2E6BFF)
        : const Color(0xFF8E59FF);
    final lighter  = _lighten(color, 0.18);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: isDone
                  ? Colors.green.withOpacity(0.07)
                  : Colors.black.withOpacity(0.04),
              blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Row(children: [
          // 왼쪽 컬러 바
          Container(
            width: 4,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: isDone
                      ? [Colors.green.shade300, Colors.green.shade600]
                      : [lighter, color],
                  begin: Alignment.topCenter, end: Alignment.bottomCenter),
            ),
          ),
          const SizedBox(width: 12),

          // 아이콘
          Container(
            width: 36, height: 36,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: isDone
                      ? [Colors.green.shade300, Colors.green.shade600]
                      : [lighter, color],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(
                  color: (isDone ? Colors.green : color).withOpacity(0.25),
                  blurRadius: 5, offset: const Offset(0, 2))],
            ),
            child: Icon(
                isDone ? Icons.check_rounded : Icons.cleaning_services_rounded,
                color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),

          // 내용
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(schedule['room_label'] as String? ?? '',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800,
                        color: isDone ? Colors.green.shade700 : _text)),
                const SizedBox(height: 3),
                Row(children: [
                  // 층 뱃지
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(5)),
                    child: Text('$floor층',
                        style: TextStyle(fontSize: 9,
                            fontWeight: FontWeight.w800, color: color)),
                  ),
                  const SizedBox(width: 6),
                  if (schedule['assigned_date'] != null)
                    Text(
                      DateFormat('MM/dd (E)', 'ko').format(
                          DateTime.parse(schedule['assigned_date'] as String)),
                      style: const TextStyle(fontSize: 11, color: _sub),
                    ),
                ]),
              ]),
            ),
          ),

          // 우측: 상태 + 사진
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.end, children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: isDone
                          ? [Colors.green.shade300, Colors.green.shade600]
                          : [Colors.grey.shade300, Colors.grey.shade500],
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: [BoxShadow(
                      color: (isDone ? Colors.green : Colors.grey)
                          .withOpacity(0.2),
                      blurRadius: 4, offset: const Offset(0, 2))],
                ),
                child: Text(
                  isDone
                      ? context.tr(AppStrings.cleaningDone)
                      : context.tr(AppStrings.cleaningPending),
                  style: const TextStyle(
                      color: Colors.white, fontSize: 10,
                      fontWeight: FontWeight.w900),
                ),
              ),
              if (photoUrl != null) ...[
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => state._showPhotoDialog(photoUrl),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(photoUrl, width: 44, height: 44,
                        fit: BoxFit.cover),
                  ),
                ),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}