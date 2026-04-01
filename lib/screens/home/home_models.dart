part of 'home_screen.dart';

// ══════════════════════════════════════════
// 데이터 모델
// ══════════════════════════════════════════

class _SubItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int? badge;
  const _SubItem(this.icon, this.label, this.onTap, {this.badge});
}

class _Category {
  final String title;
  final IconData icon;
  final Color color;
  final String desc;
  final List<_SubItem> items;
  final int? badge;
  const _Category({
    required this.title,
    required this.icon,
    required this.color,
    required this.desc,
    required this.items,
    this.badge,
  });
}