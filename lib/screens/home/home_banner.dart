part of 'home_screen.dart';

// ══════════════════════════════════════════
// 상태 배너 위젯
// ══════════════════════════════════════════

class _StatusBanner extends StatelessWidget {
  final int unreadNoticeCount;
  final bool lunchChecked;
  final bool dinnerChecked;
  final bool attendanceChecked;
  final bool isNutrition;
  final VoidCallback onNoticeTap;
  final VoidCallback onMealTap;
  final VoidCallback onAttendanceTap;

  const _StatusBanner({
    required this.unreadNoticeCount,
    required this.lunchChecked,
    required this.dinnerChecked,
    required this.attendanceChecked,
    required this.onNoticeTap,
    required this.onMealTap,
    required this.onAttendanceTap,
    this.isNutrition = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isNutrition) return const SizedBox.shrink();

    final hasUnreadNotice = unreadNoticeCount > 0;
    final mealUnchecked   = !lunchChecked || !dinnerChecked;
    final noAttendance    = !attendanceChecked;

    if (!hasUnreadNotice && !mealUnchecked && !noAttendance) {
      return const SizedBox.shrink();
    }

    final tiles = <Widget>[];

    if (noAttendance)
      tiles.add(_BannerTile(
        icon:        Icons.fingerprint_rounded,
        color:       const Color(0xFF00BFA5),
        label:       context.tr(AppStrings.bannerAttendance),
        actionLabel: context.tr(AppStrings.bannerAttendanceCheck),
        onTap:       onAttendanceTap,
      ));

    if (hasUnreadNotice) {
      if (tiles.isNotEmpty) tiles.add(const SizedBox(height: 10));
      tiles.add(_BannerTile(
        icon:        Icons.campaign_rounded,
        color:       const Color(0xFF7C5CDB),
        label:       context
            .tr(AppStrings.bannerUnreadNotice)
            .replaceAll('{n}', '$unreadNoticeCount'),
        actionLabel: context.tr(AppStrings.bannerGoCheck),
        onTap:       onNoticeTap,
      ));
    }

    if (mealUnchecked) {
      if (tiles.isNotEmpty) tiles.add(const SizedBox(height: 10));
      tiles.add(_BannerTile(
        icon:        Icons.restaurant_menu_rounded,
        color:       const Color(0xFFFF7A2F),
        label:       _mealLabel(context, lunchChecked, dinnerChecked),
        actionLabel: context.tr(AppStrings.bannerMealCheck),
        onTap:       onMealTap,
      ));
    }

    return Column(children: tiles);
  }

  String _mealLabel(BuildContext context, bool lunch, bool dinner) {
    if (!lunch && !dinner) return context.tr(AppStrings.bannerMealBoth);
    if (!lunch) return context.tr(AppStrings.bannerMealLunch);
    return context.tr(AppStrings.bannerMealDinner);
  }
}

// ──────────────────────────────────────────

class _BannerTile extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String actionLabel;
  final VoidCallback onTap;

  const _BannerTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.actionLabel,
    required this.onTap,
  });

  @override
  State<_BannerTile> createState() => _BannerTileState();
}

class _BannerTileState extends State<_BannerTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.color;
    return GestureDetector(
      onTapDown:    (_) => setState(() => _pressed = true),
      onTapUp:      (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel:  ()  => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: c.withOpacity(_pressed ? 0.08 : 0.18),
                blurRadius: _pressed ? 8 : 20,
                offset: const Offset(0, 5),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(children: [
            // 그라디언트 아이콘 컨테이너
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [c, _lighten(c, 0.12)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: c.withOpacity(0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(widget.icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1D2E),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // 액션 버튼
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [c, _lighten(c, 0.08)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: c.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                widget.actionLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// 헬퍼: 색상을 밝게
Color _lighten(Color c, double amount) {
  final hsl = HSLColor.fromColor(c);
  return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
}