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
    final cat     = widget.cat;
    final color   = cat.color;
    final lighter = _lighten(color, 0.18);

    return GestureDetector(
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapUp:     (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: ()  => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.90 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── 아이콘 박스 (iOS 스타일 그라디언트)
            Expanded(
              child: Stack(clipBehavior: Clip.none, children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [lighter, color],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: _pressed
                        ? []
                        : [
                            BoxShadow(
                              color: color.withOpacity(0.38),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                  ),
                  child: Stack(children: [
                    // 내부 하이라이트 원
                    Positioned(
                      top: -12, right: -12,
                      child: Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.12),
                        ),
                      ),
                    ),
                    Center(
                      child: Icon(cat.icon, color: Colors.white, size: 26),
                    ),
                  ]),
                ),
                // 뱃지
                if (cat.badge != null && cat.badge! > 0)
                  Positioned(
                    right: -4, top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Colors.white, width: 1.5),
                      ),
                      child: Text('${cat.badge}',
                          style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: Colors.white)),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 7),
            // ── 카테고리 이름
            Text(
              cat.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1D2E),
                height: 1.25,
              ),
            ),
          ],
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
    final c       = widget.color;
    final lighter = _lighten(c, 0.18);

    return GestureDetector(
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapUp:     (_) async {
        setState(() => _pressed = false);
        Navigator.pop(context);
        await Future.delayed(const Duration(milliseconds: 280));
        widget.sub.onTap();
      },
      onTapCancel: ()  => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _pressed ? Colors.white.withOpacity(0.85) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: _pressed
                ? []
                : [
                    BoxShadow(
                      color: c.withOpacity(0.10),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(children: [
            // 그라디언트 아이콘
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [lighter, c],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(widget.sub.icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                widget.sub.label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1D2E),
                ),
              ),
            ),
            if (widget.sub.badge != null && widget.sub.badge! > 0) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10)),
                child: Text('${widget.sub.badge}',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Colors.white)),
              ),
              const SizedBox(width: 8),
            ],
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: c.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.arrow_forward_ios_rounded,
                  color: c, size: 12),
            ),
          ]),
        ),
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
    final c       = widget.color;
    final lighter = _lighten(c, 0.18);

    return GestureDetector(
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapUp:     (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: ()  => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [lighter, c],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: _pressed
                ? []
                : [
                    BoxShadow(
                      color: c.withOpacity(0.42),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 배경 하이라이트 원
              Positioned(
                top: -25, right: -20,
                child: Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.10),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 흰 원형 아이콘
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.22),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(widget.icon, color: Colors.white, size: 22),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    widget.sub,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.72),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────

class _MealTypeBtn extends StatefulWidget {
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
  State<_MealTypeBtn> createState() => _MealTypeBtnState();
}

class _MealTypeBtnState extends State<_MealTypeBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c       = widget.color;
    final lighter = _lighten(c, 0.18);
    return GestureDetector(
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapUp:     (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: ()  => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [lighter, c],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: _pressed
                ? []
                : [
                    BoxShadow(
                      color: c.withOpacity(0.38),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned(
              top: -20, right: -10,
              child: Container(
                width: 70, height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.10),
                ),
              ),
            ),
            Column(children: [
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.22),
                  shape: BoxShape.circle,
                ),
                child: Icon(widget.icon, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 10),
              Text(widget.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  )),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(widget.time,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    )),
              ),
            ]),
          ]),
        ),
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
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      // 왼쪽 컬러 액센트 바
      Container(
        width: 4,
        height: 20,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2E6BFF), Color(0xFF7C5CDB)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        title,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w900,
          color: Color(0xFF1A1D2E),
        ),
      ),
      const SizedBox(width: 8),
      Padding(
        padding: const EdgeInsets.only(bottom: 1),
        child: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: Colors.black.withOpacity(0.38),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ]);
  }
}