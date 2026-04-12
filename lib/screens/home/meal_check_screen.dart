import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_strings.dart';
import 'lang_context.dart';

class MealCheckScreen extends StatefulWidget {
  final Map<String, dynamic> userProfile;
  final String mealType;

  const MealCheckScreen({
    Key? key,
    required this.userProfile,
    required this.mealType,
  }) : super(key: key);

  @override
  State<MealCheckScreen> createState() => _MealCheckScreenState();
}

class _MealCheckScreenState extends State<MealCheckScreen> {
  final supabase = Supabase.instance.client;

  bool? _isEating;
  bool _isSubmitting   = false;
  bool _alreadySubmitted = false;
  bool _isLoading      = true;

  int    _guestCount      = 0;
  bool   _showGuestInput  = false;
  bool   _guestSubmitting = false;
  int    _existingGuests  = 0;
  String? _guestId;

  // ── 헬퍼
  String get _today {
    final now = DateTime.now();
    if (now.hour >= 18) {
      final tomorrow = now.add(const Duration(days: 1));
      return tomorrow.toIso8601String().split('T')[0];
    }
    return now.toIso8601String().split('T')[0];
  }

  DateTime get _deadline {
    final now  = DateTime.now();
    final base = now.hour >= 18
        ? DateTime(now.year, now.month, now.day + 1)
        : DateTime(now.year, now.month, now.day);
    return widget.mealType == 'DINNER'
        ? DateTime(base.year, base.month, base.day, 13, 30)
        : DateTime(base.year, base.month, base.day,  9,  0);
  }

  bool get _isLocked => DateTime.now().isAfter(_deadline);

  String _remainingLabel(BuildContext ctx) {
    if (_isLocked) return ctx.tr({'ko': '마감됨', 'en': 'Closed', 'vi': 'Het han', 'uz': 'Yopildi', 'km': 'បានបិទ'});
    final mins = _deadline.difference(DateTime.now()).inMinutes;
    if (mins < 60) return ctx.tr({'ko': '${mins}분 후 마감', 'en': 'Closes in ${mins}m', 'vi': 'Con ${mins} phut', 'uz': '${mins} daqiqa', 'km': 'បិទក្នុង ${mins}នាទី'});
    final hrs = _deadline.difference(DateTime.now()).inHours;
    return ctx.tr({'ko': '${hrs}시간 후 마감', 'en': 'Closes in ${hrs}h', 'vi': 'Con ${hrs} gio', 'uz': '${hrs} soat', 'km': 'បិទក្នុង ${hrs}ម៉ោង'});
  }

  String _mealLabel(BuildContext ctx) =>
      widget.mealType == 'DINNER' ? ctx.tr(AppStrings.dinnerShort) : ctx.tr(AppStrings.lunchShort);

  IconData get _mealIcon =>
      widget.mealType == 'DINNER' ? Icons.dinner_dining : Icons.lunch_dining;

  Color get _themeColor =>
      widget.mealType == 'DINNER' ? const Color(0xFF3949AB) : const Color(0xFFFF7A2F);

  Color get _themeLighter =>
      widget.mealType == 'DINNER' ? const Color(0xFF6573C3) : const Color(0xFFFFAA6B);

  // ── Lifecycle
  @override
  void initState() {
    super.initState();
    _fetchTodayStatus();
  }

  Future<void> _fetchTodayStatus() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      final results = await Future.wait([
        supabase.from('meal_requests').select('is_eating')
            .eq('user_id', user.id).eq('meal_date', _today)
            .eq('meal_type', widget.mealType).maybeSingle(),
        supabase.from('meal_guests').select('id, guest_count')
            .eq('registered_by', user.id).eq('meal_date', _today)
            .eq('meal_type', widget.mealType).maybeSingle(),
      ]);
      if (!mounted) return;
      final mealData  = results[0] as Map<String, dynamic>?;
      final guestData = results[1] as Map<String, dynamic>?;
      setState(() {
        if (mealData != null) {
          _alreadySubmitted = true;
          _isEating = mealData['is_eating'] as bool?;
          if (_isEating == true) _showGuestInput = true;
        }
        if (guestData != null) {
          _existingGuests = (guestData['guest_count'] as int?) ?? 0;
          _guestCount     = _existingGuests;
          _guestId        = guestData['id'] as String?;
        }
      });
    } catch (e) {
      debugPrint("식수 데이터 로드 에러: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitMealRequest(bool eating) async {
    if (_isLocked) return;
    if (_alreadySubmitted && _isEating == eating) return;
    setState(() => _isSubmitting = true);
    final user = supabase.auth.currentUser;
    try {
      if (user == null) throw Exception("로그인 정보 없음");
      final wasChange = _alreadySubmitted;
      if (_alreadySubmitted) {
        await supabase.from('meal_requests').update({'is_eating': eating})
            .eq('user_id', user.id).eq('meal_date', _today)
            .eq('meal_type', widget.mealType);
      } else {
        await supabase.from('meal_requests').insert({
          'user_id':       user.id,
          'full_name':     widget.userProfile['full_name'],
          'dept_category': widget.userProfile['dept_category'],
          'meal_date':     _today,
          'meal_type':     widget.mealType,
          'is_eating':     eating,
        });
      }
      if (!mounted) return;
      final label = _mealLabel(context);
      setState(() {
        _alreadySubmitted = true;
        _isEating         = eating;
        _showGuestInput   = eating;
        if (!eating) _removeGuest();
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          eating
              ? (wasChange ? '$label 식사로 변경됐어요 ✅' : '$label 식사 신청됐어요 🍽️')
              : (wasChange ? '$label 미신청으로 변경됐어요' : '$label 미신청으로 등록됐어요'),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: eating ? _themeColor : Colors.blueGrey,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ));
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar("오류 발생: $e");
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _saveGuest() async {
    if (_guestSubmitting) return;
    setState(() => _guestSubmitting = true);
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      if (_guestCount == 0) {
        await _removeGuest();
      } else if (_guestId != null) {
        await supabase.from('meal_guests')
            .update({'guest_count': _guestCount}).eq('id', _guestId!);
        setState(() => _existingGuests = _guestCount);
      } else {
        final res = await supabase.from('meal_guests').insert({
          'registered_by': user.id,
          'meal_date':     _today,
          'meal_type':     widget.mealType,
          'guest_count':   _guestCount,
        }).select().single();
        setState(() {
          _guestId        = res['id'] as String?;
          _existingGuests = _guestCount;
        });
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_guestCount > 0
            ? '손님 $_guestCount명 등록됐어요 👥'
            : '손님 정보가 삭제됐어요'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ));
    } catch (e) {
      debugPrint('손님 저장 실패: $e');
    } finally {
      if (mounted) setState(() => _guestSubmitting = false);
    }
  }

  Future<void> _removeGuest() async {
    if (_guestId == null) return;
    try {
      await supabase.from('meal_guests').delete().eq('id', _guestId!);
      setState(() {
        _guestId        = null;
        _guestCount     = 0;
        _existingGuests = 0;
      });
    } catch (e) {
      debugPrint('손님 삭제 실패: $e');
    }
  }

  void _showErrorSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.redAccent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ));
  }

  // ══════════════════════════════════════════
  // Build
  // ══════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF4F6FB),
        body: Center(
          child: CircularProgressIndicator(color: _themeColor),
        ),
      );
    }

    final label  = _mealLabel(context);
    final locked = _isLocked;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── 그라디언트 헤더
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor: _themeColor,
            foregroundColor: Colors.white,
            title: Text(
              '$label 식수 체크',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 17,
                color: Colors.white,
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_themeLighter, _themeColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(children: [
                  // 배경 장식 원
                  Positioned(
                    right: -40, top: -40,
                    child: Container(
                      width: 200, height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.08),
                      ),
                    ),
                  ),
                  Positioned(
                    left: -20, bottom: -30,
                    child: Container(
                      width: 140, height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.06),
                      ),
                    ),
                  ),
                  // 본문
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 90, 22, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // 아이콘 원
                        Container(
                          width: 64, height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.22),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.4),
                                width: 2),
                          ),
                          child: Icon(_mealIcon,
                              color: Colors.white, size: 30),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _alreadySubmitted
                                    ? (_isEating == true ? '✅ 식사 신청 완료' : '⛔ 미신청 완료')
                                    : '오늘 $label 어떻게 하시겠어요?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 8),
                              // 마감 뱃지
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: locked
                                      ? Colors.red.withOpacity(0.3)
                                      : Colors.white.withOpacity(0.22),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: Colors.white.withOpacity(0.35)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      locked
                                          ? Icons.lock_rounded
                                          : Icons.timer_rounded,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      locked
                                          ? (widget.mealType == 'LUNCH'
                                              ? '점심 마감 (09:00 이후)'
                                              : '저녁 마감 (13:30 이후)')
                                          : _remainingLabel(context),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
          ),

          // ── 본문
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 48),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ── 선택 카드 2개
                Row(children: [
                  Expanded(
                    child: _ChoiceCard(
                      title:      '먹어요',
                      subtitle:   '식사 신청',
                      icon:       Icons.restaurant_rounded,
                      color:      _themeColor,
                      lighter:    _themeLighter,
                      isSelected: _isEating == true,
                      disabled:   locked,
                      onTap:      () => _submitMealRequest(true),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _ChoiceCard(
                      title:      '안 먹어요',
                      subtitle:   '미신청',
                      icon:       Icons.no_meals_rounded,
                      color:      const Color(0xFF607D8B),
                      lighter:    const Color(0xFF8FA8B4),
                      isSelected: _isEating == false,
                      disabled:   locked,
                      onTap:      () => _submitMealRequest(false),
                    ),
                  ),
                ]),

                // ── 손님 추가 (먹어요 + 마감 전)
                if (_showGuestInput && !locked) ...[
                  const SizedBox(height: 16),
                  _buildGuestSection(),
                ],

                // ── 마감 후 손님 표시
                if (_showGuestInput && locked && _existingGuests > 0) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: _themeColor.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: _themeColor.withOpacity(0.2)),
                    ),
                    child: Row(children: [
                      Icon(Icons.people_rounded,
                          size: 18, color: _themeColor),
                      const SizedBox(width: 8),
                      Text('손님 $_existingGuests명 등록됨',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _themeColor)),
                    ]),
                  ),
                ],

                // ── 변경 가능 안내
                if (!locked && _alreadySubmitted) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: Colors.blue.withOpacity(0.18)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.swap_horiz_rounded,
                          size: 16, color: Colors.blue),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          '다른 항목을 누르면 변경됩니다.',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ]),
                  ),
                ],

                // ── 마감 + 미신청 안내
                if (locked && !_alreadySubmitted) ...[
                  const SizedBox(height: 20),
                  Text(
                    '마감 시간이 지나 신청할 수 없습니다.',
                    style: TextStyle(
                        color: Colors.black38,
                        fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],

                // ── 마감 후 변경 안내
                if (locked && _alreadySubmitted) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      '※ 변경이 필요한 경우 관리자에게 문의하세요.',
                      style: TextStyle(
                          fontSize: 12, color: Colors.black45),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],

                // ── 홈으로 버튼
                if (_alreadySubmitted || locked) ...[
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        backgroundColor:
                            Colors.black.withOpacity(0.05),
                      ),
                      child: const Text('홈으로 돌아가기',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Colors.black54)),
                    ),
                  ),
                ],

                if (_isSubmitting) ...[
                  const SizedBox(height: 24),
                  Center(
                    child: CircularProgressIndicator(
                        color: _themeColor),
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── 손님 섹션
  Widget _buildGuestSection() {
    final changed = _guestCount != _existingGuests;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: _themeColor.withOpacity(0.10),
              blurRadius: 14,
              offset: const Offset(0, 4)),
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_themeLighter, _themeColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.people_rounded,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          const Text('손님 동행',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1A1D2E))),
          const Spacer(),
          if (_existingGuests > 0)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Text('$_existingGuests명 등록됨',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.green)),
            ),
        ]),
        const SizedBox(height: 5),
        Text('함께 식사하는 손님이 있으면 인원을 추가해주세요',
            style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _countBtn(Icons.remove_rounded,
              _guestCount > 0
                  ? () => setState(() => _guestCount--)
                  : null),
          const SizedBox(width: 24),
          Column(children: [
            Text('$_guestCount',
                style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: _themeColor)),
            const Text('명',
                style: TextStyle(
                    fontSize: 12, color: Color(0xFF8A93B0))),
          ]),
          const SizedBox(width: 24),
          _countBtn(Icons.add_rounded,
              () => setState(() => _guestCount++),
              active: true),
        ]),
        if (changed) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _guestSubmitting ? null : _saveGuest,
              style: ElevatedButton.styleFrom(
                backgroundColor: _themeColor,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _guestSubmitting
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Text(
                      _guestCount == 0
                          ? '손님 정보 삭제'
                          : '손님 ${_guestCount}명 저장',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14)),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _countBtn(IconData icon, VoidCallback? onTap,
      {bool active = false}) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46, height: 46,
        decoration: BoxDecoration(
          color: disabled
              ? Colors.grey.withOpacity(0.08)
              : active
                  ? _themeColor.withOpacity(0.12)
                  : Colors.grey.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon,
            size: 20,
            color: disabled
                ? Colors.grey[300]
                : active ? _themeColor : Colors.grey[600]),
      ),
    );
  }
}

// ══════════════════════════════════════════
// 선택 카드 위젯
// ══════════════════════════════════════════

class _ChoiceCard extends StatefulWidget {
  final String title, subtitle;
  final IconData icon;
  final Color color, lighter;
  final bool isSelected, disabled;
  final VoidCallback onTap;

  const _ChoiceCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.lighter,
    required this.isSelected,
    required this.disabled,
    required this.onTap,
  });

  @override
  State<_ChoiceCard> createState() => _ChoiceCardState();
}

class _ChoiceCardState extends State<_ChoiceCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDimmed   = widget.disabled && !widget.isSelected;
    final isSelected = widget.isSelected;
    final c          = widget.color;
    final lighter    = widget.lighter;

    return GestureDetector(
      onTapDown:   widget.disabled ? null : (_) => setState(() => _pressed = true),
      onTapUp:     widget.disabled ? null : (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: 170,
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [lighter, c],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : LinearGradient(
                    colors: [
                      c.withOpacity(isDimmed ? 0.04 : 0.09),
                      c.withOpacity(isDimmed ? 0.02 : 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected
                  ? Colors.transparent
                  : c.withOpacity(isDimmed ? 0.1 : 0.22),
              width: isSelected ? 0 : 1.5,
            ),
            boxShadow: isSelected && !_pressed
                ? [
                    BoxShadow(
                      color: c.withOpacity(0.40),
                      blurRadius: 18,
                      offset: const Offset(0, 7),
                    ),
                  ]
                : [],
          ),
          child: Opacity(
            opacity: isDimmed ? 0.45 : 1.0,
            child: Stack(clipBehavior: Clip.none, children: [
              // 배경 하이라이트
              if (isSelected)
                Positioned(
                  top: -20, right: -20,
                  child: Container(
                    width: 90, height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.10),
                    ),
                  ),
                ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 아이콘
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withOpacity(0.22)
                            : c.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.icon,
                        color: isSelected ? Colors.white : c,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 제목
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: isSelected ? Colors.white : c,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // 서브타이틀
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Colors.white.withOpacity(0.75)
                            : c.withOpacity(0.55),
                      ),
                    ),
                    // 선택 완료 체크
                    if (isSelected) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.22),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_rounded,
                                color: Colors.white, size: 13),
                            SizedBox(width: 4),
                            Text('선택됨',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}