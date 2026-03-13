import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_strings.dart';
import 'lang_context.dart';

class MealCheckScreen extends StatefulWidget {
  final Map<String, dynamic> userProfile;
  final String mealType; // 'LUNCH' | 'DINNER'

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

  // ── 18시 이후면 다음날 기준으로 체크
  String get _today {
    final now = DateTime.now();
    if (now.hour >= 18) {
      final tomorrow = now.add(const Duration(days: 1));
      return tomorrow.toIso8601String().split('T')[0];
    }
    return now.toIso8601String().split('T')[0];
  }

  // ── 마감 시간: 점심 10:00 / 저녁 15:00
  DateTime get _deadline {
    final now = DateTime.now();
    // 18시 이후면 다음날 기준
    final base = now.hour >= 18
        ? DateTime(now.year, now.month, now.day + 1)
        : DateTime(now.year, now.month, now.day);
    if (widget.mealType == 'DINNER') {
      return DateTime(base.year, base.month, base.day, 15, 0);
    } else {
      return DateTime(base.year, base.month, base.day, 10, 0);
    }
  }

  // 마감 후면 잠금
  bool get _isLocked => DateTime.now().isAfter(_deadline);

  // 마감까지 남은 시간 텍스트
  String _remainingLabel(BuildContext ctx) {
    if (_isLocked) {
      return ctx.tr({'ko': '마감됨', 'en': 'Closed', 'vi': 'Het han', 'uz': 'Yopildi', 'km': 'បានបិទ'});
    }
    final mins = _deadline.difference(DateTime.now()).inMinutes;
    if (mins < 60) {
      return ctx.tr({'ko': '${mins}분 후 마감', 'en': 'Closes in ${mins}m', 'vi': 'Con ${mins} phut', 'uz': '${mins} daqiqa', 'km': 'បិទក្នុង ${mins}នាទី'});
    }
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
      final data = await supabase
          .from('meal_requests')
          .select('is_eating')
          .eq('user_id', user.id)
          .eq('meal_date', _today)
          .eq('meal_type', widget.mealType)
          .maybeSingle();
      if (!mounted) return;
      if (data != null) {
        setState(() {
          _alreadySubmitted = true;
          _isEating = data['is_eating'] as bool?;
        });
      }
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
        await supabase
            .from('meal_requests')
            .update({'is_eating': eating})
            .eq('user_id', user.id)
            .eq('meal_date', _today)
            .eq('meal_type', widget.mealType);
      } else {
        await supabase.from('meal_requests').insert({
          'user_id': user.id,
          'full_name': widget.userProfile['full_name'],
          'dept_category': widget.userProfile['dept_category'],
          'meal_date': _today,
          'meal_type': widget.mealType,
          'is_eating': eating,
        });
      }

      if (!mounted) return;
      final label = _mealLabel(context);
      setState(() {
        _alreadySubmitted = true;
        _isEating = eating;
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(eating
            ? context.tr({
                'ko': wasChange ? '오늘 $label 식사로 변경되었습니다. 🍚' : '오늘 $label 식사가 신청되었습니다. 🍚',
                'en': wasChange ? '$label changed to eating. 🍚' : '$label meal registered. 🍚',
                'vi': wasChange ? 'Da doi thanh an bua $label. 🍚' : 'Da dang ky bua $label. 🍚',
                'uz': wasChange ? '$label ovqat oʻzgartirildi. 🍚' : '$label ovqat roʻyxatdan oʻtdi. 🍚',
                'km': wasChange ? 'បានផ្លាស់ប្ដូរទៅញ៉ាំ $label 🍚' : 'បានចុះឈ្មោះ $label 🍚',
              })
            : context.tr({
                'ko': wasChange ? '오늘 $label 미식사로 변경되었습니다. 🚫' : '오늘 $label 미식사로 접수되었습니다. 🚫',
                'en': wasChange ? '$label changed to skip. 🚫' : '$label skipped. 🚫',
                'vi': wasChange ? 'Da doi thanh bo bua $label. 🚫' : 'Da bo qua bua $label. 🚫',
                'uz': wasChange ? '$label oʻtkazib yuborishga oʻzgartirildi. 🚫' : '$label ovqat oʻtkazib yuborildi. 🚫',
                'km': wasChange ? 'បានផ្លាស់ប្ដូរទៅមិនញ៉ាំ $label 🚫' : 'បានបញ្ជាក់ថាមិនញ៉ាំ $label 🚫',
              })),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ));

      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) Navigator.pop(context);
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        if (!mounted) return;
        setState(() => _alreadySubmitted = true);
        _showErrorSnackBar(context.tr({
          'ko': '이미 오늘 ${_mealLabel(context)} 체크를 완료했습니다.',
          'en': 'Already checked for ${_mealLabel(context)}.',
          'vi': 'Da kiem tra bua ${_mealLabel(context)} hom nay.',
          'uz': 'Bugun ${_mealLabel(context)} allaqachon belgilangan.',
          'km': 'បានពិនិត្យ${_mealLabel(context)}ហើយ។',
        }));
        Navigator.pop(context);
      }
    } catch (e) {
      _showErrorSnackBar(context.tr({
        'ko': '저장에 실패했습니다. 다시 시도해주세요.',
        'en': 'Failed to save. Please try again.',
        'vi': 'Luu that bai. Vui long thu lai.',
        'uz': 'Saqlash muvaffaqiyatsiz. Qayta urining.',
        'km': 'បរាជ័យក្នុងការរក្សាទុក។ សូមព្យាយាមម្តងទៀត។',
      }));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showErrorSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final label = _mealLabel(context);
    final locked = _isLocked;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: Text(
          context.tr({
            'ko': '$label 식수 체크',
            'en': '$label Check',
            'vi': 'Kiem tra bua $label',
            'uz': '$label tekshiruvi',
            'km': 'ពិនិត្យ$label',
          }),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
            ),
            child: Column(children: [
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: locked ? Colors.red.withOpacity(0.07) : Colors.green.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: locked ? Colors.red.withOpacity(0.3) : Colors.green.withOpacity(0.3),
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    locked ? Icons.lock_rounded : Icons.timer_rounded,
                    size: 13,
                    color: locked ? Colors.red : Colors.green,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    locked
                        ? context.tr({
                            'ko': widget.mealType == 'LUNCH' ? '점심 마감 (10:00 이후)' : '저녁 마감 (15:00 이후)',
                            'en': widget.mealType == 'LUNCH' ? 'Lunch closed (after 10:00)' : 'Dinner closed (after 15:00)',
                            'vi': widget.mealType == 'LUNCH' ? 'Het han bua trua (sau 10:00)' : 'Het han bua toi (sau 15:00)',
                            'uz': widget.mealType == 'LUNCH' ? 'Tushlik yopildi (10:00 dan keyin)' : 'Kechki yopildi (15:00 dan keyin)',
                            'km': widget.mealType == 'LUNCH' ? 'ថ្ងៃត្រង់បានបិទ (បន្ទាប់ពី 10:00)' : 'ល្ងាចបានបិទ (បន្ទាប់ពី 15:00)',
                          })
                        : _remainingLabel(context),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: locked ? Colors.red : Colors.green,
                    ),
                  ),
                ]),
              ),
              Icon(_mealIcon, size: 56, color: locked ? Colors.grey[400] : _themeColor),
              const SizedBox(height: 14),
              Text(
                "$_today ($label)",
                style: const TextStyle(fontSize: 15, color: Colors.grey, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                locked && !_alreadySubmitted
                    ? context.tr({
                        'ko': '마감 시간이 지나 신청할 수 없습니다.',
                        'en': 'Deadline has passed.',
                        'vi': 'Da qua han dang ky.',
                        'uz': 'Muddati oʻtdi.',
                        'km': 'ផុតកំណត់ហើយ។',
                      })
                    : locked && _alreadySubmitted
                        ? context.tr({
                            'ko': '식수 체크 완료 (마감)',
                            'en': 'Meal check complete (locked)',
                            'vi': 'Kiem tra hoan thanh (da dong)',
                            'uz': 'Tekshiruv tugadi (yopildi)',
                            'km': 'ការពិនិត្យបានបញ្ចប់ (បិទ)',
                          })
                        : !_alreadySubmitted
                            ? context.tr({
                                'ko': '오늘 $label 식사를 하시겠습니까?',
                                'en': 'Will you have $label today?',
                                'vi': 'Ban co an bua $label hom nay khong?',
                                'uz': 'Bugun $label ovqatlanasizmi?',
                                'km': 'តើអ្នកញ៉ាំ${label}ថ្ងៃនេះទេ?',
                              })
                            : context.tr({
                                'ko': '변경 가능합니다 (마감 전)',
                                'en': 'You can still change your selection',
                                'vi': 'Ban co the thay doi',
                                'uz': 'Hali oʻzgartirish mumkin',
                                'km': 'នៅអាចផ្លាស់ប្ដូរបាន',
                              }),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: (locked && !_alreadySubmitted) ? Colors.grey : Colors.black87,
                ),
              ),
            ]),
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(children: [
                    Expanded(
                      child: _buildChoiceCard(
                        title: context.tr({'ko': '먹어요', 'en': 'Yes', 'vi': 'Co', 'uz': 'Ha', 'km': 'ញ៉ាំ'}),
                        subtitle: context.tr({'ko': '식사 신청', 'en': 'Meal request', 'vi': 'Dang ky an', 'uz': 'Ovqat', 'km': 'ចុះឈ្មោះ'}),
                        icon: Icons.restaurant,
                        color: Colors.orange,
                        isSelected: _isEating == true,
                        disabled: locked,
                        onTap: () => _submitMealRequest(true),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildChoiceCard(
                        title: context.tr({'ko': '안 먹어요', 'en': 'No', 'vi': 'Khong', 'uz': "Yo'q", 'km': 'មិនញ៉ាំ'}),
                        subtitle: context.tr({'ko': '미신청', 'en': 'Skip', 'vi': 'Bo qua', 'uz': "O'tkazib", 'km': 'លើកលែង'}),
                        icon: Icons.no_meals,
                        color: Colors.blueGrey,
                        isSelected: _isEating == false,
                        disabled: locked,
                        onTap: () => _submitMealRequest(false),
                      ),
                    ),
                  ]),

                  const SizedBox(height: 20),

                  if (!locked && _alreadySubmitted)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.withOpacity(0.2)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.swap_horiz_rounded, size: 16, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            context.tr({
                              'ko': '다른 항목을 누르면 변경됩니다.',
                              'en': 'Tap the other option to change.',
                              'vi': 'Nhan vao lua chon khac de thay doi.',
                              'uz': "Oʻzgartirish uchun boshqasini bosing.",
                              'km': 'ចុចជម្រើសផ្សេងដើម្បីផ្លាស់ប្ដូរ។',
                            }),
                            style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ]),
                    ),

                  if (locked && _alreadySubmitted) ...[
                    const SizedBox(height: 8),
                    Text(
                      context.tr({
                        'ko': '※ 변경이 필요한 경우 관리자에게 문의하세요.',
                        'en': '※ Contact admin to change your meal selection.',
                        'vi': '※ Lien he quan tri vien neu can thay doi.',
                        'uz': "※ Oʻzgartirish uchun administratorga murojaat qiling.",
                        'km': '※ ទំនាក់ទំនងអ្នកគ្រប់គ្រងដើម្បីផ្លាស់ប្ដូរ។',
                      }),
                      style: const TextStyle(color: Colors.black38, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ],

                  if (_alreadySubmitted || locked) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        context.tr({
                          'ko': '홈으로 돌아가기',
                          'en': 'Back to Home',
                          'vi': 'Ve trang chu',
                          'uz': 'Bosh sahifaga qaytish',
                          'km': 'ត្រឡប់ទៅផ្ទះ',
                        }),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],

                  if (_isSubmitting)
                    const Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: CircularProgressIndicator(),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required bool disabled,
    required VoidCallback onTap,
  }) {
    final bool isDimmed = disabled && !isSelected;

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
            width: 2,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(color: color.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8)),
          ],
        ),
        child: Opacity(
          opacity: isDimmed ? 0.25 : 1.0,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withOpacity(0.2) : color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 40, color: isSelected ? Colors.white : color),
              ),
              const SizedBox(height: 16),
              Text(title,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900,
                      color: isSelected ? Colors.white : Colors.black87)),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: TextStyle(fontSize: 12,
                      color: isSelected ? Colors.white.withOpacity(0.8) : Colors.black38)),
              if (disabled && isSelected) ...[
                const SizedBox(height: 8),
                Icon(Icons.lock_rounded, size: 14, color: Colors.white.withOpacity(0.7)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}