part of 'home_screen.dart';

// ══════════════════════════════════════════
// 상태 배너 위젯
// ══════════════════════════════════════════

class _StatusBanner extends StatelessWidget {
  final int unreadNoticeCount;
  final bool lunchChecked;
  final bool dinnerChecked;
  final bool attendanceChecked;
  final bool isNutrition;       // ← 영양사 여부
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
    // 영양사는 배너 전체 숨김
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
      if (tiles.isNotEmpty) tiles.add(const SizedBox(height: 8));
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
      if (tiles.isNotEmpty) tiles.add(const SizedBox(height: 8));
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

class _BannerTile extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color.withOpacity(0.9))),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration:
                BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
            child: Text(actionLabel,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800)),
          ),
        ]),
      ),
    );
  }
}