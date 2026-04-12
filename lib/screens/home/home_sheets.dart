part of 'home_screen.dart';

// ══════════════════════════════════════════
// 바텀시트 (extension on _HomeScreenState)
// ══════════════════════════════════════════

extension HomeScreenSheets on _HomeScreenState {
  void _showMealSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(28)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2)),
          ),
          Text(context.tr(AppStrings.mealCheckTitle),
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(context.tr(AppStrings.mealSelectHint),
              style: TextStyle(
                  fontSize: 13, color: Colors.black.withOpacity(0.45))),
          const SizedBox(height: 22),
          Row(children: [
            Expanded(
              child: _MealTypeBtn(
                label: context.tr(AppStrings.lunch),
                icon: Icons.light_mode_rounded,
                color: Colors.orange,
                time: "12:00",
                onTap: () {
                  Navigator.pop(context);
                  _push(MealCheckScreen(
                      userProfile: _userProfile!, mealType: 'LUNCH'));
                },
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _MealTypeBtn(
                label: context.tr(AppStrings.dinner),
                icon: Icons.dark_mode_rounded,
                color: Colors.indigo,
                time: "18:00",
                onTap: () {
                  Navigator.pop(context);
                  _push(MealCheckScreen(
                      userProfile: _userProfile!, mealType: 'DINNER'));
                },
              ),
            ),
          ]),
          const SizedBox(height: 4),
        ]),
      ),
    );
  }

  void _showLangSheet(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setS) {
          final langProvider = context.lang;
          return Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)),
              ),
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: const Color(0xFF2E6BFF).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.language_rounded,
                      color: Color(0xFF2E6BFF), size: 20),
                ),
                const SizedBox(width: 12),
                Text(context.tr(AppStrings.langSettings),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w900)),
              ]),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(context.tr(AppStrings.langSubtitle),
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.black.withOpacity(0.4))),
              ),
              const SizedBox(height: 18),
              ...kSupportedLangs.map((lang) {
                final isSelected = langProvider.lang == lang.code;
                return GestureDetector(
                  onTap: () async {
                    await langProvider.setLang(lang.code);
                    setS(() {});
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 15),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF2E6BFF).withOpacity(0.07)
                          : Colors.black.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF2E6BFF).withOpacity(0.4)
                            : Colors.black.withOpacity(0.07),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(children: [
                      Text(lang.flag,
                          style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 14),
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(lang.nativeLabel,
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: isSelected
                                        ? const Color(0xFF2E6BFF)
                                        : const Color(0xFF1A1D2E))),
                            if (lang.nativeLabel != lang.label)
                              Text(lang.label,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.black.withOpacity(0.4))),
                          ]),
                      const Spacer(),
                      if (isSelected)
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                              color: Color(0xFF2E6BFF),
                              shape: BoxShape.circle),
                          child: const Icon(Icons.check_rounded,
                              color: Colors.white, size: 14),
                        ),
                    ]),
                  ),
                );
              }).toList(),
              const SizedBox(height: 4),
            ]),
          );
        },
      ),
    );
  }

  void _showCategorySheet(BuildContext context, _Category cat) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.45,
        minChildSize: 0.25,
        maxChildSize: 0.85,
        expand: false,
        snap: true,
        snapSizes: const [0.45, 0.85],
        builder: (_, scrollController) => Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F6FB),
            borderRadius: BorderRadius.circular(28),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            // ── 그라디언트 헤더 ──
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_lighten(cat.color, 0.18), cat.color],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(children: [
                // 배경 장식 원
                Positioned(
                  top: -25, right: -25,
                  child: Container(
                    width: 110, height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.10),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -30, left: 40,
                  child: Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.06),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 드래그 핸들
                      Center(
                        child: Container(
                          width: 36, height: 4,
                          margin: const EdgeInsets.only(bottom: 18),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.45),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                        // 아이콘 컨테이너
                        Container(
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.22),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(cat.icon, color: Colors.white, size: 26),
                        ),
                        const SizedBox(width: 15),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cat.title,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              cat.desc,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.72),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ]),
                    ],
                  ),
                ),
              ]),
            ),

            // ── 메뉴 아이템 스크롤 영역 ──
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                children: cat.items
                    .map((sub) => _SheetMenuItem(sub: sub, color: cat.color))
                    .toList(),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}