part of 'cleaning_screen.dart';

class _CleaningRotationTab extends StatelessWidget {
  final _CleaningScreenState state;
  const _CleaningRotationTab({required this.state});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 48),
      child: Column(children: [
        _FloorRotation(floor: 2, state: state),
        const SizedBox(height: 16),
        _FloorRotation(floor: 3, state: state),
      ]),
    );
  }
}

class _FloorRotation extends StatelessWidget {
  final int floor;
  final _CleaningScreenState state;
  const _FloorRotation({required this.floor, required this.state});

  static const _text = Color(0xFF1A1D2E);
  static const _sub  = Color(0xFF8A93B0);
  static const _bg   = Color(0xFFF4F6FB);

  Color _lighten(Color c, double a) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + a).clamp(0.0, 1.0)).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final rotations = floor == 2 ? state._rotations2 : state._rotations3;
    final color     = floor == 2
        ? const Color(0xFF2E6BFF)
        : const Color(0xFF8E59FF);
    final lighter   = _lighten(color, 0.18);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.10), blurRadius: 14,
              offset: const Offset(0, 5)),
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(children: [
          // ── 그라디언트 헤더
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [lighter, color],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.22),
                    shape: BoxShape.circle),
                child: const Icon(Icons.layers_rounded,
                    color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$floor${context.tr(AppStrings.cleaningFloorRotation)} '
                  '(${rotations.length}${context.tr(AppStrings.cleaningRooms)})',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w900,
                      color: Colors.white),
                ),
              ),
              // 저장 버튼
              GestureDetector(
                onTap: () => state._saveRotationOrder(floor),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(10)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.save_rounded,
                        color: Colors.white, size: 14),
                    const SizedBox(width: 5),
                    Text(context.tr(AppStrings.cleaningSave),
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w800,
                            color: Colors.white)),
                  ]),
                ),
              ),
            ]),
          ),

          // ── 드래그 힌트
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            color: color.withOpacity(0.04),
            child: Row(children: [
              Icon(Icons.drag_indicator_rounded, size: 14,
                  color: color.withOpacity(0.5)),
              const SizedBox(width: 6),
              Text('드래그로 순서를 변경하세요',
                  style: TextStyle(fontSize: 11, color: _sub,
                      fontWeight: FontWeight.w600)),
            ]),
          ),

          // ── 로테이션 목록
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rotations.length,
            onReorder: (oldIndex, newIndex) {
              state.setState(() {
                if (newIndex > oldIndex) newIndex--;
                final list = floor == 2 ? state._rotations2 : state._rotations3;
                final item = list.removeAt(oldIndex);
                list.insert(newIndex, item);
              });
            },
            itemBuilder: (context, index) {
              final r        = rotations[index];
              final isMerged = r['is_merged'] == true;

              return Container(
                key: ValueKey(r['id']),
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: isMerged
                      ? Colors.orange.withOpacity(0.04)
                      : _bg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: isMerged
                          ? Colors.orange.withOpacity(0.25)
                          : color.withOpacity(0.12)),
                  boxShadow: [BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 4, offset: const Offset(0, 2))],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  child: Row(children: [
                    // 순번 뱃지
                    Container(
                      width: 30, height: 30,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                            colors: [lighter, color],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: [BoxShadow(
                            color: color.withOpacity(0.25),
                            blurRadius: 5, offset: const Offset(0, 2))],
                      ),
                      child: Center(child: Text('${index + 1}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Colors.white, fontSize: 12))),
                    ),
                    const SizedBox(width: 12),
                    // 호실 정보
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(r['room_label'] as String? ?? '',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 14,
                              color: _text)),
                      if (isMerged) ...[
                        const SizedBox(height: 2),
                        Row(children: [
                          const Icon(Icons.merge_rounded,
                              size: 11, color: Colors.orange),
                          const SizedBox(width: 3),
                          Text(context.tr(AppStrings.cleaningMerged),
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.orange,
                                  fontWeight: FontWeight.w700)),
                        ]),
                      ],
                    ])),
                    // 드래그 핸들
                    Icon(Icons.drag_handle_rounded,
                        color: color.withOpacity(0.4), size: 22),
                  ]),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}