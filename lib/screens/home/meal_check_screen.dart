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
  bool _isSubmitting = false;
  bool _alreadySubmitted = false;
  bool _isLoading = true;

  // 손님 관련
  int  _guestCount       = 0;
  bool _showGuestInput   = false;
  bool _guestSubmitting  = false;
  int  _existingGuests   = 0; // 이미 등록된 손님 수
  String? _guestId;           // 기존 meal_guests row id

  String get _today {
    final now = DateTime.now();
    if (now.hour >= 18) {
      final tomorrow = now.add(const Duration(days: 1));
      return tomorrow.toIso8601String().split('T')[0];
    }
    return now.toIso8601String().split('T')[0];
  }

  DateTime get _deadline {
    final now = DateTime.now();
    final base = now.hour >= 18
        ? DateTime(now.year, now.month, now.day + 1)
        : DateTime(now.year, now.month, now.day);
    return widget.mealType == 'DINNER'
        ? DateTime(base.year, base.month, base.day, 13, 30) // ← 13:30
        : DateTime(base.year, base.month, base.day,  9,  0); // ← 09:00
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
      widget.mealType == 'DINNER' ? Colors.indigo : Colors.orange;

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
          // 먹어요면 손님 입력 영역 표시
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
          'user_id':      user.id,
          'full_name':    widget.userProfile['full_name'],
          'dept_category':widget.userProfile['dept_category'],
          'meal_date':    _today,
          'meal_type':    widget.mealType,
          'is_eating':    eating,
        });
      }

      if (!mounted) return;
      final label = _mealLabel(context);
      setState(() {
        _alreadySubmitted = true;
        _isEating         = eating;
        _showGuestInput   = eating; // 먹어요일 때만 손님 입력 표시
        if (!eating) {
          // 불참으로 변경 시 기존 손님 삭제
          _removeGuest();
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(eating
            ? (wasChange ? '오늘 $label 식사로 변경되었습니다. 🍚' : '오늘 $label 식사가 신청되었습니다. 🍚')
            : (wasChange ? '오늘 $label 미식사로 변경되었습니다. 🚫' : '오늘 $label 미식사로 접수되었습니다. 🚫')),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ));

      // 먹어요가 아니면 바로 닫기
      if (!eating) {
        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) Navigator.pop(context);
      }
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        if (!mounted) return;
        setState(() => _alreadySubmitted = true);
        _showErrorSnackBar('이미 오늘 ${_mealLabel(context)} 체크를 완료했습니다.');
        Navigator.pop(context);
      }
    } catch (e) {
      _showErrorSnackBar('저장에 실패했습니다. 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // 손님 저장/수정
  Future<void> _saveGuest() async {
    if (_isLocked || _guestCount == _existingGuests) return;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() => _guestSubmitting = true);
    try {
      if (_guestCount == 0) {
        await _removeGuest();
      } else if (_guestId != null) {
        // 수정
        await supabase.from('meal_guests')
            .update({'guest_count': _guestCount}).eq('id', _guestId!);
      } else {
        // 신규
        final res = await supabase.from('meal_guests').insert({
          'registered_by': user.id,
          'dept_category': widget.userProfile['dept_category'],
          'meal_date':     _today,
          'meal_type':     widget.mealType,
          'guest_count':   _guestCount,
        }).select().single();
        _guestId = res['id'] as String?;
      }
      setState(() => _existingGuests = _guestCount);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_guestCount > 0
              ? '손님 $_guestCount명 등록됐어요 👥'
              : '손님 정보가 삭제됐어요'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ));
      }
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
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.redAccent));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(
        body: Center(child: CircularProgressIndicator()));

    final label  = _mealLabel(context);
    final locked = _isLocked;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: Text('$label 식수 체크',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true, elevation: 0,
        backgroundColor: Colors.white, foregroundColor: Colors.black,
      ),
      body: Column(children: [
        // ── 상단 헤더
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(30))),
          child: Column(children: [
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                  color: locked
                      ? Colors.red.withOpacity(0.07)
                      : Colors.green.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: locked
                          ? Colors.red.withOpacity(0.3)
                          : Colors.green.withOpacity(0.3))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(locked ? Icons.lock_rounded : Icons.timer_rounded,
                    size: 13, color: locked ? Colors.red : Colors.green),
                const SizedBox(width: 5),
                Text(
                  locked
                      ? (widget.mealType == 'LUNCH'
                          ? '점심 마감 (09:00 이후)' : '저녁 마감 (13:30 이후)') // ← 수정
                      : _remainingLabel(context),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                      color: locked ? Colors.red : Colors.green),
                ),
              ]),
            ),
            Icon(_mealIcon, size: 56,
                color: locked ? Colors.grey[400] : _themeColor),
            const SizedBox(height: 14),
            Text("$_today ($label)",
                style: const TextStyle(fontSize: 15, color: Colors.grey,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              locked && !_alreadySubmitted
                  ? '마감 시간이 지나 신청할 수 없습니다.'
                  : locked && _alreadySubmitted
                      ? '식수 체크 완료 (마감)'
                      : !_alreadySubmitted
                          ? '오늘 $label 식사를 하시겠습니까?'
                          : '변경 가능합니다 (마감 전)',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: (locked && !_alreadySubmitted) ? Colors.grey : Colors.black87),
            ),
          ]),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              // ── 먹어요 / 안먹어요
              Row(children: [
                Expanded(child: _buildChoiceCard(
                  title: '먹어요', subtitle: '식사 신청',
                  icon: Icons.restaurant, color: Colors.orange,
                  isSelected: _isEating == true, disabled: locked,
                  onTap: () => _submitMealRequest(true),
                )),
                const SizedBox(width: 16),
                Expanded(child: _buildChoiceCard(
                  title: '안 먹어요', subtitle: '미신청',
                  icon: Icons.no_meals, color: Colors.blueGrey,
                  isSelected: _isEating == false, disabled: locked,
                  onTap: () => _submitMealRequest(false),
                )),
              ]),

              // ── 손님 추가 (먹어요 선택 + 마감 전)
              if (_showGuestInput && !locked) ...[
                const SizedBox(height: 20),
                _buildGuestSection(),
              ],

              // ── 기존 손님 표시 (마감 후)
              if (_showGuestInput && locked && _existingGuests > 0) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: Colors.orange.withOpacity(0.2))),
                  child: Row(children: [
                    const Icon(Icons.people_rounded,
                        size: 18, color: Colors.orange),
                    const SizedBox(width: 8),
                    Text('손님 $_existingGuests명 등록됨',
                        style: const TextStyle(fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.orange)),
                  ]),
                ),
              ],

              const SizedBox(height: 20),

              if (!locked && _alreadySubmitted)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.blue.withOpacity(0.2))),
                  child: Row(children: [
                    const Icon(Icons.swap_horiz_rounded,
                        size: 16, color: Colors.blue),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('다른 항목을 누르면 변경됩니다.',
                        style: TextStyle(fontSize: 12,
                            color: Colors.blue,
                            fontWeight: FontWeight.w600))),
                  ]),
                ),

              if (locked && _alreadySubmitted) ...[
                const SizedBox(height: 8),
                const Text('※ 변경이 필요한 경우 관리자에게 문의하세요.',
                    style: TextStyle(color: Colors.black38, fontSize: 13),
                    textAlign: TextAlign.center),
              ],

              if (_alreadySubmitted || locked) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('홈으로 돌아가기',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],

              if (_isSubmitting)
                const Padding(padding: EdgeInsets.only(top: 24),
                    child: CircularProgressIndicator()),
            ]),
          ),
        ),
      ]),
    );
  }

  // ── 손님 추가 섹션
  Widget _buildGuestSection() {
    final changed = _guestCount != _existingGuests;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 헤더
        Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.people_rounded,
                color: Colors.orange, size: 18),
          ),
          const SizedBox(width: 10),
          const Text('손님 동행', style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w900,
              color: Color(0xFF1A1D2E))),
          const Spacer(),
          if (_existingGuests > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Text('$_existingGuests명 등록됨',
                  style: const TextStyle(fontSize: 11,
                      fontWeight: FontWeight.w700, color: Colors.green)),
            ),
        ]),
        const SizedBox(height: 6),
        Text('함께 식사하는 손님이 있으면 인원을 추가해주세요',
            style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        const SizedBox(height: 16),

        // 인원 조절
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _countBtn(Icons.remove_rounded,
              _guestCount > 0
                  ? () => setState(() => _guestCount--)
                  : null),
          const SizedBox(width: 24),
          Column(children: [
            Text('$_guestCount',
                style: const TextStyle(fontSize: 36,
                    fontWeight: FontWeight.w900, color: Colors.orange)),
            const Text('명', style: TextStyle(fontSize: 12,
                color: Color(0xFF8A93B0))),
          ]),
          const SizedBox(width: 24),
          _countBtn(Icons.add_rounded,
              () => setState(() => _guestCount++),
              active: true),
        ]),

        // 변경사항 있을 때 저장 버튼
        if (changed) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _guestSubmitting ? null : _saveGuest,
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              child: _guestSubmitting
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Text(
                      _guestCount == 0
                          ? '손님 정보 삭제'
                          : '손님 ${_guestCount}명 저장',
                      style: const TextStyle(color: Colors.white,
                          fontWeight: FontWeight.w800, fontSize: 14)),
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
        width: 44, height: 44,
        decoration: BoxDecoration(
            color: disabled
                ? Colors.grey.withOpacity(0.08)
                : active
                    ? Colors.orange.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, size: 20,
            color: disabled
                ? Colors.grey[300]
                : active ? Colors.orange : Colors.grey[600]),
      ),
    );
  }

  Widget _buildChoiceCard({
    required String title, required String subtitle,
    required IconData icon, required Color color,
    required bool isSelected, required bool disabled,
    required VoidCallback onTap,
  }) {
    final isDimmed = disabled && !isSelected;
    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 180,
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: isSelected ? color : Colors.black.withOpacity(0.05),
              width: 2),
          boxShadow: [
            if (isSelected)
              BoxShadow(color: color.withOpacity(0.3),
                  blurRadius: 15, offset: const Offset(0, 8)),
          ],
        ),
        child: Opacity(
          opacity: isDimmed ? 0.25 : 1.0,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withOpacity(0.2)
                      : color.withOpacity(0.1),
                  shape: BoxShape.circle),
              child: Icon(icon, size: 40,
                  color: isSelected ? Colors.white : color),
            ),
            const SizedBox(height: 16),
            Text(title, style: TextStyle(fontSize: 18,
                fontWeight: FontWeight.w900,
                color: isSelected ? Colors.white : Colors.black87)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(fontSize: 12,
                color: isSelected
                    ? Colors.white.withOpacity(0.8) : Colors.black38)),
            if (disabled && isSelected) ...[
              const SizedBox(height: 8),
              Icon(Icons.lock_rounded, size: 14,
                  color: Colors.white.withOpacity(0.7)),
            ],
          ]),
        ),
      ),
    );
  }
}