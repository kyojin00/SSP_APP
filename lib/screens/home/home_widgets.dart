part of 'home_screen.dart';

// ══════════════════════════════════════════
// UI 위젯 컴포넌트
// ══════════════════════════════════════════

class _CategoryCard extends StatefulWidget {
  final _Category cat;
  final VoidCallback onTap;
  const _CategoryCard({required this.cat, required this.onTap});
  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cat = widget.cat;
    final color = cat.color;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: _pressed
                ? [BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 2))]
                : [BoxShadow(
                    color: Colors.black.withOpacity(0.07),
                    blurRadius: 14,
                    offset: const Offset(0, 6))],
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Stack(clipBehavior: Clip.none, children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14)),
                child: Icon(cat.icon, color: color, size: 24),
              ),
              if (cat.badge != null && cat.badge! > 0)
                Positioned(
                  right: -4, top: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 1.5)),
                    child: Text('${cat.badge}',
                        style: const TextStyle(fontSize: 9,
                            fontWeight: FontWeight.w900, color: Colors.white)),
                  ),
                ),
            ]),
            const SizedBox(height: 8),
            Text(cat.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1D2E))),
          ]),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────

class _SheetMenuItem extends StatefulWidget {
  final _SubItem sub;
  final Color color;
  const _SheetMenuItem({required this.sub, required this.color});
  @override
  State<_SheetMenuItem> createState() => _SheetMenuItemState();
}

class _SheetMenuItemState extends State<_SheetMenuItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.color;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) async {
        setState(() => _pressed = false);
        Navigator.pop(context);
        await Future.delayed(const Duration(milliseconds: 300));
        widget.sub.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: _pressed ? c.withOpacity(0.1) : c.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: _pressed ? c.withOpacity(0.3) : c.withOpacity(0.12)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: c.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(widget.sub.icon, color: c, size: 20),
          ),
          const SizedBox(width: 14),
          Text(widget.sub.label,
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800, color: c)),
          const Spacer(),
          if (widget.sub.badge != null && widget.sub.badge! > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                  color: Colors.red, borderRadius: BorderRadius.circular(10)),
              child: Text('${widget.sub.badge}',
                  style: const TextStyle(fontSize: 11,
                      fontWeight: FontWeight.w900, color: Colors.white)),
            ),
            const SizedBox(width: 8),
          ],
          Icon(Icons.arrow_forward_ios_rounded,
              color: c.withOpacity(0.4), size: 14),
        ]),
      ),
    );
  }
}

// ──────────────────────────────────────────

class _QuickBtn extends StatefulWidget {
  final IconData icon;
  final String label;
  final String sub;
  final Color color;
  final VoidCallback onTap;
  const _QuickBtn({
    required this.icon,
    required this.label,
    required this.sub,
    required this.color,
    required this.onTap,
  });
  @override
  State<_QuickBtn> createState() => _QuickBtnState();
}

class _QuickBtnState extends State<_QuickBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.color;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                c,
                HSLColor.fromColor(c)
                    .withLightness(
                        (HSLColor.fromColor(c).lightness + 0.1).clamp(0.0, 0.9))
                    .toColor()
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: _pressed
                ? []
                : [BoxShadow(
                    color: c.withOpacity(0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 6))],
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
              child: Icon(widget.icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900)),
              Text(widget.sub,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────

class _MealTypeBtn extends StatelessWidget {
  final String label, time;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _MealTypeBtn({
    required this.label,
    required this.time,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: color.withOpacity(0.12), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 10),
          Text(label,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w900, fontSize: 14)),
          const SizedBox(height: 4),
          Text(time,
              style: TextStyle(
                  color: color.withOpacity(0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

// ──────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title, subtitle;
  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text(title,
          style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1A1D2E))),
      const SizedBox(width: 8),
      Padding(
        padding: const EdgeInsets.only(bottom: 1),
        child: Text(subtitle,
            style: TextStyle(
                fontSize: 12,
                color: Colors.black.withOpacity(0.38),
                fontWeight: FontWeight.w500)),
      ),
    ]);
  }
}