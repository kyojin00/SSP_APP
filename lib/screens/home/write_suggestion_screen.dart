import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WriteSuggestionScreen extends StatefulWidget {
  const WriteSuggestionScreen({Key? key}) : super(key: key);

  @override
  State<WriteSuggestionScreen> createState() => _WriteSuggestionScreenState();
}

class _WriteSuggestionScreenState extends State<WriteSuggestionScreen> {
  final _titleController   = TextEditingController();
  final _contentController = TextEditingController();

  String _category    = '인사/노무';
  bool   _isAnonymous = true;
  bool   _isSubmitting = false;

  static const _indigo    = Color(0xFF3D5AFE);
  static const _indigoDk  = Color(0xFF1A237E);
  static const _bg        = Color(0xFFF4F6FB);
  static const _text      = Color(0xFF1A1D2E);
  static const _sub       = Color(0xFF8A93B0);

  // 카테고리
  static const _categories = ['인사/노무', '생산현장', '안전보건', '시설환경', '기타'];

  Color _catColor(String cat) => switch (cat) {
    '인사/노무' => const Color(0xFF2E6BFF),
    '안전보건'  => const Color(0xFFFF8C42),
    '생산현장'  => const Color(0xFF00897B),
    '시설환경'  => const Color(0xFF7C5CDB),
    _          => _indigo,
  };

  IconData _catIcon(String cat) => switch (cat) {
    '인사/노무' => Icons.people_alt_rounded,
    '안전보건'  => Icons.health_and_safety_rounded,
    '생산현장'  => Icons.precision_manufacturing_rounded,
    '시설환경'  => Icons.business_rounded,
    _          => Icons.campaign_rounded,
  };

  Color _lighten(Color c, double a) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + a).clamp(0.0, 1.0)).toColor();
  }

  @override
  void initState() {
    super.initState();
    _titleController.addListener(() => setState(() {}));
    _contentController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _titleController.text.trim().isNotEmpty &&
      _contentController.text.trim().isNotEmpty;

  Future<void> _submit() async {
    if (!_canSubmit) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('제목과 내용을 모두 입력해주세요.',
              style: TextStyle(fontWeight: FontWeight.w700)),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      await Supabase.instance.client.from('suggestions').insert({
        'user_id':      user?.id,
        'category':     _category,
        'title':        _titleController.text.trim(),
        'content':      _contentController.text.trim(),
        'is_anonymous': _isAnonymous,
      });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('소중한 의견이 제출되었습니다. ✅',
              style: TextStyle(fontWeight: FontWeight.w700)),
          backgroundColor: _indigo,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('제출 실패: $e',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selColor  = _catColor(_category);
    final selLighter = _lighten(selColor, 0.18);

    return Scaffold(
      backgroundColor: _bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── 그라디언트 SliverAppBar
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor: _indigoDk,
            foregroundColor: Colors.white,
            title: const Text(
              '건의 / 신고 작성',
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                  color: Colors.white),
            ),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_indigoDk, selColor, selLighter],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(children: [
                  Positioned(
                    right: -40, top: -40,
                    child: Container(
                      width: 180, height: 180,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.07)),
                    ),
                  ),
                  Positioned(
                    left: -20, bottom: -30,
                    child: Container(
                      width: 120, height: 120,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.05)),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 80, 20, 0),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.20),
                            shape: BoxShape.circle),
                        child: const Icon(Icons.edit_note_rounded,
                            color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        const Text('익명 보장 · 안전한 제보',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 3),
                        Text(
                          '제출하신 내용은 담당자가 확인 후 처리됩니다.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.72),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ]),
                    ]),
                  ),
                ]),
              ),
            ),
          ),

          // ── 폼 본체
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 48),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ── 카테고리 선택
                _SectionHeader(
                    icon: Icons.category_rounded, label: '제보 분야'),
                const SizedBox(height: 12),
                _CategoryChips(
                  categories: _categories,
                  selected: _category,
                  catColor: _catColor,
                  catIcon: _catIcon,
                  lighten: _lighten,
                  onSelect: (c) => setState(() => _category = c),
                ),

                const SizedBox(height: 22),

                // ── 익명 설정
                _SectionHeader(
                    icon: Icons.shield_rounded, label: '익명 설정'),
                const SizedBox(height: 12),
                _AnonymousToggleCard(
                  value: _isAnonymous,
                  accentColor: selColor,
                  onChanged: (v) => setState(() => _isAnonymous = v),
                ),

                const SizedBox(height: 22),

                // ── 제목
                _SectionHeader(
                    icon: Icons.title_rounded,
                    label: '제목',
                    required: true,
                    count: _titleController.text.trim().length),
                const SizedBox(height: 12),
                _StyledTextField(
                  controller: _titleController,
                  hint: '제목을 입력하세요',
                  icon: Icons.short_text_rounded,
                  accentColor: selColor,
                  maxLines: 1,
                ),

                const SizedBox(height: 22),

                // ── 내용
                _SectionHeader(
                    icon: Icons.subject_rounded,
                    label: '상세 내용',
                    required: true,
                    count: _contentController.text.trim().length),
                const SizedBox(height: 12),
                _StyledTextField(
                  controller: _contentController,
                  hint:
                      '사안의 일시, 장소, 내용 등을 구체적으로 적어주시면\n빠른 처리에 도움이 됩니다.',
                  icon: Icons.notes_rounded,
                  accentColor: selColor,
                  maxLines: 8,
                ),

                const SizedBox(height: 28),

                // ── 제출 버튼
                _SubmitButton(
                  canSubmit: _canSubmit,
                  isSubmitting: _isSubmitting,
                  category: _category,
                  selColor: selColor,
                  lighter: selLighter,
                  onTap: _submit,
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════
// 섹션 헤더
// ══════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool required;
  final int? count;

  const _SectionHeader({
    required this.icon,
    required this.label,
    this.required = false,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 16, color: const Color(0xFF3D5AFE)),
      const SizedBox(width: 7),
      Text(label,
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1A1D2E))),
      if (required) ...[
        const SizedBox(width: 4),
        const Text('*',
            style: TextStyle(
                color: Color(0xFFFF4D64),
                fontSize: 14,
                fontWeight: FontWeight.w900)),
      ],
      const Spacer(),
      if (count != null && count! > 0)
        Text('$count자',
            style: TextStyle(
                fontSize: 11,
                color: Colors.black.withOpacity(0.32),
                fontWeight: FontWeight.w600)),
    ]);
  }
}

// ══════════════════════════════════════════
// 카테고리 칩
// ══════════════════════════════════════════

class _CategoryChips extends StatelessWidget {
  final List<String> categories;
  final String selected;
  final Color Function(String) catColor;
  final IconData Function(String) catIcon;
  final Color Function(Color, double) lighten;
  final ValueChanged<String> onSelect;

  const _CategoryChips({
    required this.categories,
    required this.selected,
    required this.catColor,
    required this.catIcon,
    required this.lighten,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: categories.map((cat) {
        final sel     = cat == selected;
        final color   = catColor(cat);
        final icon    = catIcon(cat);
        final lighter = lighten(color, 0.18);

        return GestureDetector(
          onTap: () => onSelect(cat),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              gradient: sel
                  ? LinearGradient(
                      colors: [lighter, color],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: sel ? null : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: sel
                  ? [
                      BoxShadow(
                          color: color.withOpacity(0.30),
                          blurRadius: 10,
                          offset: const Offset(0, 4))
                    ]
                  : [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 6,
                          offset: const Offset(0, 2))
                    ],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: sel
                      ? Colors.white.withOpacity(0.22)
                      : color.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon,
                    color: sel ? Colors.white : color, size: 13),
              ),
              const SizedBox(width: 7),
              Text(cat,
                  style: TextStyle(
                      color: sel ? Colors.white : color,
                      fontSize: 13,
                      fontWeight: FontWeight.w800)),
            ]),
          ),
        );
      }).toList(),
    );
  }
}

// ══════════════════════════════════════════
// 익명 토글 카드
// ══════════════════════════════════════════

class _AnonymousToggleCard extends StatelessWidget {
  final bool value;
  final Color accentColor;
  final ValueChanged<bool> onChanged;

  const _AnonymousToggleCard({
    required this.value,
    required this.accentColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: value
                ? accentColor.withOpacity(0.3)
                : Colors.black.withOpacity(0.07),
            width: value ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: value
                  ? accentColor.withOpacity(0.10)
                  : Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(children: [
          // 아이콘
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 46, height: 46,
            decoration: BoxDecoration(
              gradient: value
                  ? LinearGradient(
                      colors: [
                        accentColor.withOpacity(0.8),
                        accentColor
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: value ? null : const Color(0xFFF4F6FB),
              shape: BoxShape.circle,
              boxShadow: value
                  ? [
                      BoxShadow(
                          color: accentColor.withOpacity(0.28),
                          blurRadius: 10,
                          offset: const Offset(0, 4))
                    ]
                  : [],
            ),
            child: Icon(
              value ? Icons.shield_rounded : Icons.shield_outlined,
              color: value ? Colors.white : const Color(0xFF8A93B0),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          // 텍스트
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(
                value ? '익명으로 제출' : '실명으로 제출',
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: value ? accentColor : const Color(0xFF1A1D2E)),
              ),
              const SizedBox(height: 3),
              Text(
                value
                    ? '작성자 정보가 비공개 처리됩니다.'
                    : '내 이름이 제보자로 표시됩니다.',
                style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8A93B0),
                    fontWeight: FontWeight.w500),
              ),
            ]),
          ),
          // 토글 스위치
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 50, height: 28,
            decoration: BoxDecoration(
              gradient: value
                  ? LinearGradient(
                      colors: [accentColor, accentColor.withOpacity(0.8)],
                    )
                  : null,
              color: value ? null : const Color(0xFFE2E4ED),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Stack(children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                left: value ? 24 : 2,
                top: 2,
                child: Container(
                  width: 24, height: 24,
                  decoration: const BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════
// 스타일 텍스트필드
// ══════════════════════════════════════════

class _StyledTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final Color accentColor;
  final int maxLines;

  const _StyledTextField({
    required this.controller,
    required this.hint,
    required this.icon,
    required this.accentColor,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8, offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1D2E),
            height: 1.6),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
              color: Colors.black.withOpacity(0.28),
              fontSize: 14,
              fontWeight: FontWeight.w400,
              height: 1.6),
          prefixIcon: Padding(
            padding: EdgeInsets.only(
                left: 14, right: 10,
                top: maxLines == 1 ? 0 : 14),
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accentColor, size: 16),
            ),
          ),
          prefixIconConstraints: BoxConstraints(
            minWidth: maxLines == 1 ? 52 : 52,
            minHeight: maxLines == 1 ? 52 : 52,
          ),
          alignLabelWithHint: true,
          filled: true,
          fillColor: Colors.transparent,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                  color: Colors.black.withOpacity(0.07))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: accentColor, width: 1.5)),
          contentPadding: EdgeInsets.fromLTRB(
              0, maxLines == 1 ? 16 : 16, 16,
              maxLines == 1 ? 16 : 16),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════
// 제출 버튼
// ══════════════════════════════════════════

class _SubmitButton extends StatefulWidget {
  final bool canSubmit, isSubmitting;
  final String category;
  final Color selColor, lighter;
  final VoidCallback onTap;

  const _SubmitButton({
    required this.canSubmit,
    required this.isSubmitting,
    required this.category,
    required this.selColor,
    required this.lighter,
    required this.onTap,
  });

  @override
  State<_SubmitButton> createState() => _SubmitButtonState();
}

class _SubmitButtonState extends State<_SubmitButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.canSubmit && !widget.isSubmitting
          ? (_) => setState(() => _pressed = true)
          : null,
      onTapUp: widget.canSubmit && !widget.isSubmitting
          ? (_) {
              setState(() => _pressed = false);
              widget.onTap();
            }
          : null,
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 56,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: widget.canSubmit && !widget.isSubmitting
                ? LinearGradient(
                    colors: [widget.lighter, widget.selColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: widget.canSubmit && !widget.isSubmitting
                ? null
                : const Color(0xFFE2E4ED),
            borderRadius: BorderRadius.circular(18),
            boxShadow: widget.canSubmit && !widget.isSubmitting && !_pressed
                ? [
                    BoxShadow(
                      color: widget.selColor.withOpacity(0.38),
                      blurRadius: 16,
                      offset: const Offset(0, 7),
                    ),
                  ]
                : [],
          ),
          child: Stack(children: [
            if (widget.canSubmit && !widget.isSubmitting)
              Positioned(
                top: -10, right: -8,
                child: Container(
                  width: 60, height: 60,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.08)),
                ),
              ),
            Center(
              child: widget.isSubmitting
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: widget.canSubmit
                              ? Colors.white.withOpacity(0.22)
                              : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.send_rounded,
                          color: widget.canSubmit
                              ? Colors.white
                              : const Color(0xFF8A93B0),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '제출하기',
                        style: TextStyle(
                            color: widget.canSubmit
                                ? Colors.white
                                : const Color(0xFF8A93B0),
                            fontSize: 16,
                            fontWeight: FontWeight.w900),
                      ),
                    ]),
            ),
          ]),
        ),
      ),
    );
  }
}