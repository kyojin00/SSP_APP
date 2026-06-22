// home_screen.dart — 메인 홈
// 분리된 파일 구조:
//   home_models.dart     ← _SubItem, _Category
//   home_banner.dart     ← _StatusBanner, _BannerTile
//   home_widgets.dart    ← _CategoryCard, _SheetMenuItem, _QuickBtn, _MealTypeBtn, _SectionHeader
//   home_sheets.dart     ← _showMealSheet, _showLangSheet, _showCategorySheet
//   home_categories.dart ← _buildCategories, _quickActions

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

import 'package:shared_preferences/shared_preferences.dart';
import '../auth/login_screen.dart';
import 'meal_check_screen.dart';
import 'notice_list_screen.dart';
import 'field_management_screen.dart';
import 'dorm_management_screen.dart';
import 'suggestion_screen.dart';
import 'attendance_screen.dart';
import 'leave_request_screen.dart';
import 'attendance_management_screen.dart';
import '../../utils/app_router.dart';
import '../../widgets/shimmer_loader.dart';
import 'meal_report_screen.dart';
import 'excel_export_screen.dart';
import 'employee_management_screen.dart';
import 'pwa_install_guide_screen.dart';
import 'lang_context.dart';
import 'app_language_provider.dart';
import 'app_strings.dart';
import 'meal_menu_screen.dart';
import '../../services/onesignal_linker.dart';
import 'trend_screen.dart';
import 'vehicle_screen.dart';
import 'uniform_request_screen.dart';
import 'user_activity_screen.dart';
import 'dorm_room_map_screen.dart';
import 'health_screen.dart';
import 'business_card_screen.dart';
import 'fuel_card_screen.dart';
import 'cleaning_screen.dart';

part 'home_models.dart';
part 'home_banner.dart';
part 'home_widgets.dart';
part 'home_sheets.dart';
part 'home_categories.dart';

// ══════════════════════════════════════════
// HomeScreen
// ══════════════════════════════════════════

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final supabase = Supabase.instance.client;

  Map<String, dynamic>? _userProfile;
  bool _isLoading  = true;
  bool _booted     = false;
  bool _langListenerAdded = false;

  DateTime? _lastBackPress;

  late final AnimationController _cardCtrl;
  late final List<Animation<double>> _cardAnims;
  static const int _maxCards = 6;

  int  _unreadNoticeCount  = 0;
  bool _lunchChecked       = false;
  bool _dinnerChecked      = false;
  bool _attendanceChecked  = false;
  bool _bannerLoading      = true;
  int  _pendingFuelCount    = 0;
  int  _pendingLeaveCount   = 0;
  int  _pendingUniformCount = 0;
  List<String> _quickActionIds = ['meal_check', 'attendance'];

  @override
  bool get wantKeepAlive => true;

  void _onLangChanged() {
    if (mounted) setState(() {});
  }

  // ──────────────────────────────────────────
  // Lifecycle
  // ──────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _cardCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _cardAnims = List.generate(_maxCards, (i) {
      final s = (i * 0.12).clamp(0.0, 0.6);
      final e = (s + 0.5).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _cardCtrl,
        curve: Interval(s, e, curve: Curves.easeOutBack),
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_langListenerAdded) {
      context.lang.addListener(_onLangChanged);
      _langListenerAdded = true;
    }
    if (_booted) return;
    _booted = true;
    _loadUserProfile();
    _reconnectOneSignal(showSnack: false);
    _loadQuickActionPrefs();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final isAdmin = _userProfile?['role'] == 'ADMIN';
      OneSignalLinker.registerClickHandler(context, isAdmin: isAdmin);
    });
  }

  @override
  void dispose() {
    if (_langListenerAdded) {
      context.lang.removeListener(_onLangChanged);
    }
    _cardCtrl.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────
  // 데이터 로딩
  // ──────────────────────────────────────────

  Future<void> _loadUserProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      return;
    }
    try {
      final data = await supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();
      if (!mounted) return;
      setState(() {
        _userProfile = data;
        _isLoading   = false;
      });
      if (_cardCtrl.status == AnimationStatus.dismissed) _cardCtrl.forward();
      await _loadBannerData();
    } catch (e) {
      debugPrint("프로필 로드: $e");
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadBannerData() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    final today    = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final isAdmin  = _userProfile?['role'] == 'ADMIN';
    final position = _userProfile?['position'] as String? ?? '';
    const mgrRanks = ['과장', '차장', '부장', '이사', '본부장', '대표이사'];
    final isManager = isAdmin || mgrRanks.contains(position);
    try {
      final futures = <Future>[
        supabase.from('notices').select('id'),
        supabase.from('notice_reads').select('notice_id').eq('user_id', user.id),
        supabase.from('meal_requests').select('meal_type')
            .eq('user_id', user.id).eq('meal_date', today),
        supabase.from('attendance').select('id')
            .eq('user_id', user.id).eq('work_date', today),
      ];
      if (isAdmin) {
        futures.add(supabase.from('fuel_logs')
            .select('id').eq('status', 'PENDING'));
      }
      if (isManager) {
        futures.add(supabase.from('leave_requests')
            .select('id')
            .eq('status', 'PENDING')       // ← 추가
            .eq('step1_status', 'PENDING'));
      }
      if (isAdmin) {
        futures.add(supabase.from('uniform_requests')
            .select('id').eq('status', 'PENDING'));
      }

      final results     = await Future.wait(futures);
      final allNotices  = results[0] as List;
      final readNotices = results[1] as List;
      final todayMeals  = results[2] as List;
      final todayAttend = results[3] as List;
      final readIds     = readNotices.map((r) => r['notice_id'] as String).toSet();
      final unreadCount = allNotices
          .where((n) => !readIds.contains(n['id'] as String)).length;
      final lunchChecked  = todayMeals.any((r) => r['meal_type'] == 'LUNCH');
      final dinnerChecked = todayMeals.any((r) => r['meal_type'] == 'DINNER');
      final attendChecked = todayAttend.isNotEmpty;
      final pendingFuel   = isAdmin && results.length > 4
          ? (results[4] as List).length : 0;
      final leaveIdx      = isAdmin ? 5 : 4;
      final pendingLeave  = isManager && results.length > leaveIdx
          ? (results[leaveIdx] as List).length : 0;
      final uniformIdx    = leaveIdx + (isManager ? 1 : 0);
      final pendingUniform = isAdmin && results.length > uniformIdx
          ? (results[uniformIdx] as List).length : 0;

      if (!mounted) return;
      setState(() {
        _unreadNoticeCount   = unreadCount;
        _lunchChecked        = lunchChecked;
        _dinnerChecked       = dinnerChecked;
        _attendanceChecked   = attendChecked;
        _pendingFuelCount    = pendingFuel;
        _pendingLeaveCount   = pendingLeave;
        _pendingUniformCount = pendingUniform;
        _bannerLoading       = false;
      });
    } catch (e) {
      debugPrint("배너 데이터 로드 실패: $e");
      if (!mounted) return;
      setState(() => _bannerLoading = false);
    }
  }

  // ──────────────────────────────────────────
  // 액션 / 유틸
  // ──────────────────────────────────────────

  Future<void> _reconnectOneSignal({bool showSnack = true}) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      if (showSnack && mounted) _snack(context.tr(AppStrings.profileError));
      return;
    }
    try {
      final id = await OneSignalLinker.linkAndGetId(user.id);
      if (id == null) {
        if (showSnack && mounted) _snack(context.tr(AppStrings.notifWebOnly));
        return;
      }
      debugPrint('[OneSignal] reconnected onesignalId=$id');
      if (showSnack && mounted) _snack(context.tr(AppStrings.notifReconnectDone));
    } catch (e) {
      debugPrint('[OneSignal] reconnect error: $e');
      if (showSnack && mounted) _snack(context.tr(AppStrings.notifReconnectFail));
    }
  }

  // ── 퀵액션 환경설정 ──
  Future<void> _loadQuickActionPrefs() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList('quick_actions_${user.id}');
      if (saved != null && mounted) setState(() => _quickActionIds = saved);
    } catch (e) {
      debugPrint('퀵액션 로드 실패: $e');
    }
  }

  Future<void> saveQuickActionPrefs(List<String> ids) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('quick_actions_${user.id}', ids);
      if (mounted) setState(() => _quickActionIds = ids);
    } catch (e) {
      debugPrint('퀵액션 저장 실패: $e');
    }
  }

  Future<void> _logout() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(context.tr(AppStrings.logout),
            style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Text(context.tr(AppStrings.logoutConfirm),
            style: const TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr(AppStrings.no2),
                style: const TextStyle(
                    fontWeight: FontWeight.w700, color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E6BFF),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr(AppStrings.yes),
                style: const TextStyle(
                    fontWeight: FontWeight.w900, color: Colors.white)),
          ),
        ],
      ),
    );
    if (result == true) {
      try {
        await supabase.auth.signOut();
        if (!mounted) return;
        Navigator.pushReplacement(context, AppRouter.fade(LoginScreen()));
      } catch (_) {
        if (mounted) _snack(context.tr(AppStrings.logoutFailed));
      }
    }
  }

  void _push(Widget screen) =>
      Navigator.push(context, AppRouter.slide(screen))
          .then((_) => _loadBannerData());

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
      backgroundColor: const Color(0xFF1A1D2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
    ));
  }

  void _onUserActivity() => _lastBackPress = null;

  String _deptLabel(String c, [BuildContext? ctx]) {
    if (ctx == null) {
      const m = {
        'MANAGEMENT': '관리부',
        'PRODUCTION': '생산관리부',
        'SALES':      '영업부',
        'RND':        '연구소',
        'STEEL':      '스틸생산부',
        'BOX':        '박스생산부',
        'DELIVERY':   '포장납품부',
        'SSG':        '에스에스지',
        'CLEANING':   '환경미화',
        'NUTRITION':  '영양사',
        'ADMIN':      '관리자',
      };
      return m[c] ?? c;
    }
    return switch (c) {
      'MANAGEMENT' => ctx.tr(AppStrings.deptManagement),
      'PRODUCTION' => ctx.tr(AppStrings.deptProduction),
      'SALES'      => ctx.tr(AppStrings.deptSales),
      'RND'        => ctx.tr(AppStrings.deptRnd),
      'STEEL'      => ctx.tr(AppStrings.deptSteel),
      'BOX'        => ctx.tr(AppStrings.deptBox),
      'DELIVERY'   => ctx.tr(AppStrings.deptDelivery),
      'SSG'        => ctx.tr(AppStrings.deptSsg),
      'CLEANING'   => ctx.tr(AppStrings.deptCleaning),
      'NUTRITION'  => ctx.tr(AppStrings.deptNutrition),
      _            => c,
    };
  }

  // ──────────────────────────────────────────
  // Build
  // ──────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isLoading) return const HomeMenuSkeleton();
    if (_userProfile == null) {
      return Scaffold(
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(context.tr(AppStrings.profileError)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadUserProfile,
              child: Text(context.tr(AppStrings.retryBtn)),
            ),
          ]),
        ),
      );
    }

    final body = _buildBody(context);
    if (Theme.of(context).platform != TargetPlatform.android) return body;

    return WillPopScope(
      onWillPop: () async {
        if (Navigator.of(context).canPop()) return true;
        final now   = DateTime.now();
        final first = _lastBackPress == null ||
            now.difference(_lastBackPress!) > const Duration(seconds: 2);
        if (first) {
          _lastBackPress = now;
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(SnackBar(
              content: Text(context.tr(AppStrings.exitHint),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
              backgroundColor: const Color(0xFF1A1D2E),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            ));
          return false;
        }
        return true;
      },
      child: GestureDetector(
        onTap: _onUserActivity,
        onPanUpdate: (_) => _onUserActivity(),
        child: NotificationListener<ScrollNotification>(
          onNotification: (_) {
            _onUserActivity();
            return false;
          },
          child: body,
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final isAdmin    = _userProfile!['role'] == 'ADMIN';
    final position   = _userProfile!['position'] as String? ?? '';
    const mgr        = ['과장', '차장', '부장', '이사', '본부장', '대표이사'];
    final isManager  = isAdmin || mgr.contains(position);
    final isNutrition = (_userProfile!['dept_category'] ?? '') == 'NUTRITION';
    final name       = _userProfile!['full_name'] ?? '';
    final dept       = _deptLabel(_userProfile!['dept_category'] ?? '', context);
    final categories = _buildCategories(context, isAdmin, isManager, isNutrition, dept);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F7),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          _sliverAppBar(context, name, dept, position, isAdmin),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 48),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (!_bannerLoading)
                  _StatusBanner(
                    unreadNoticeCount: _unreadNoticeCount,
                    lunchChecked:      _lunchChecked,
                    dinnerChecked:     _dinnerChecked,
                    attendanceChecked: _attendanceChecked,
                    isNutrition:       isNutrition,
                    onNoticeTap: () =>
                        _push(NoticeListScreen(isAdmin: isAdmin, myDept: dept)),
                    onMealTap:        _showMealSheet,
                    onAttendanceTap:  () =>
                        _push(AttendanceScreen(userProfile: _userProfile!)),
                  ),
                if (!_bannerLoading) const SizedBox(height: 20),
                _quickActions(
                    isAdmin, isNutrition,
                    _userProfile!['dept_category'] as String? ?? ''),
                const SizedBox(height: 24),
                _SectionHeader(
                  title:    context.tr(AppStrings.menu),
                  subtitle: context.tr(AppStrings.menuSubtitle),
                ),
                const SizedBox(height: 14),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount:  4,
                    mainAxisSpacing:  16,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.78,
                  ),
                  itemCount: categories.length,
                  itemBuilder: (_, i) {
                    final idx = i.clamp(0, _maxCards - 1);
                    return AnimatedBuilder(
                      animation: _cardAnims[idx],
                      builder: (_, child) => FadeTransition(
                        opacity: _cardAnims[idx],
                        child: ScaleTransition(
                            scale: _cardAnims[idx], child: child),
                      ),
                      child: _CategoryCard(
                        cat:   categories[i],
                        onTap: () => _showCategorySheet(context, categories[i]),
                      ),
                    );
                  },
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────
  // SliverAppBar — 개선된 헤더
  // ──────────────────────────────────────────

  Widget _sliverAppBar(BuildContext context, String name, String dept,
      String position, bool isAdmin) {
    // 시간대별 인사
    final hour = DateTime.now().hour;
    final String greeting;
    final String greetingEmoji;
    if (hour < 12) {
      greeting      = '좋은 아침이에요';
      greetingEmoji = '🌅';
    } else if (hour < 18) {
      greeting      = '좋은 오후예요';
      greetingEmoji = '☀️';
    } else {
      greeting      = '좋은 저녁이에요';
      greetingEmoji = '🌙';
    }

    // 오늘 날짜
    final now      = DateTime.now();
    final weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final weekday  = weekdays[now.weekday - 1];
    final dateStr  = '${now.month}월 ${now.day}일 $weekday요일';

    // 아바타 이니셜
    final initial = name.isNotEmpty ? name[0] : '?';

    return SliverAppBar(
      expandedHeight: 210,
      floating: false,
      pinned: true,
      stretch: true,
      stretchTriggerOffset: 80,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: const Color(0xFF1E4AD9),
      title: Text(
        context.tr(AppStrings.appName),
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 18,
          color: Colors.white.withOpacity(0.92),
        ),
      ),
      actions: [
        GestureDetector(
          onTap: _logout,
          child: Container(
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.power_settings_new_rounded,
                color: Colors.white70, size: 22),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF1229A8),
                Color(0xFF1E4AD9),
                Color(0xFF3A7FFF),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(children: [
            // ── 배경 장식 원들
            Positioned(
              right: -50, top: -50,
              child: Container(
                width: 220, height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.06),
                ),
              ),
            ),
            Positioned(
              left: -30, bottom: -50,
              child: Container(
                width: 160, height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.04),
                ),
              ),
            ),
            Positioned(
              right: 60, bottom: 20,
              child: Container(
                width: 60, height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),

            // ── 본문
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 78, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 인사 뱃지 + 날짜
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.25)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(greetingEmoji,
                            style: const TextStyle(fontSize: 13)),
                        const SizedBox(width: 5),
                        Text(
                          greeting,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      dateStr,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.65),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 아바타
                      Container(
                        width: 58, height: 58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6B9FFF), Color(0xFF4078FF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.4),
                              width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            initial,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      // 이름 + 뱃지
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$name님',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                _headerBadge(
                                    dept, Colors.white.withOpacity(0.2)),
                                if (position.isNotEmpty)
                                  _headerBadge(position,
                                      Colors.white.withOpacity(0.15)),
                                if (isAdmin)
                                  _headerBadge('ADMIN',
                                      const Color(0xFFFF7A2F).withOpacity(0.7)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  /// 헤더 뱃지
  Widget _headerBadge(String label, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}