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
  bool _isLoading = true;
  bool _booted = false;
  bool _langListenerAdded = false;

  DateTime? _lastBackPress;

  late final AnimationController _cardCtrl;
  late final List<Animation<double>> _cardAnims;
  static const int _maxCards = 6;

  int _unreadNoticeCount = 0;
  bool _lunchChecked   = false;
  bool _dinnerChecked  = false;
  bool _attendanceChecked = false;
  bool _bannerLoading  = true;
  int _pendingFuelCount    = 0;
  int _pendingLeaveCount   = 0;
  int _pendingUniformCount = 0;

  @override
  bool get wantKeepAlive => true;

  void _onLangChanged() {
    if (mounted) setState(() {});
  }

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
        _isLoading = false;
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
      final futures = [
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
            .eq('step1_status', 'PENDING'));
      }
      if (isAdmin) {
        futures.add(supabase.from('uniform_requests')
            .select('id').eq('status', 'PENDING'));
      }
      final results = await Future.wait(futures);
      final allNotices  = results[0] as List;
      final readNotices = results[1] as List;
      final todayMeals  = results[2] as List;
      final todayAttend = results[3] as List;
      final readIds = readNotices.map((r) => r['notice_id'] as String).toSet();
      final unreadCount = allNotices
          .where((n) => !readIds.contains(n['id'] as String)).length;
      final lunchChecked  = todayMeals.any((r) => r['meal_type'] == 'LUNCH');
      final dinnerChecked = todayMeals.any((r) => r['meal_type'] == 'DINNER');
      final attendChecked = todayAttend.isNotEmpty;
      final pendingFuel    = isAdmin && results.length > 4
          ? (results[4] as List).length : 0;
      final leaveIdx       = isAdmin ? 5 : 4;
      final pendingLeave   = isManager && results.length > leaveIdx
          ? (results[leaveIdx] as List).length : 0;
      final uniformIdx     = leaveIdx + (isManager ? 1 : 0);
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
      if (showSnack && mounted)
        _snack(context.tr(AppStrings.notifReconnectDone));
    } catch (e) {
      debugPrint('[OneSignal] reconnect error: $e');
      if (showSnack && mounted)
        _snack(context.tr(AppStrings.notifReconnectFail));
    }
  }

  Future<void> _logout() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
        'SALES': '영업부',
        'RND': '연구소',
        'STEEL': '스틸생산부',
        'BOX': '박스생산부',
        'DELIVERY': '포장납품부',
        'SSG': '에스에스지',
        'CLEANING': '환경미화',
        'NUTRITION': '영양사',
        'ADMIN': '관리자',
      };
      return m[c] ?? c;
    }
    return switch (c) {
      'MANAGEMENT' => ctx.tr(AppStrings.deptManagement),
      'PRODUCTION' => ctx.tr(AppStrings.deptProduction),
      'SALES' => ctx.tr(AppStrings.deptSales),
      'RND' => ctx.tr(AppStrings.deptRnd),
      'STEEL' => ctx.tr(AppStrings.deptSteel),
      'BOX' => ctx.tr(AppStrings.deptBox),
      'DELIVERY' => ctx.tr(AppStrings.deptDelivery),
      'SSG' => ctx.tr(AppStrings.deptSsg),
      'CLEANING' => ctx.tr(AppStrings.deptCleaning),
      'NUTRITION' => ctx.tr(AppStrings.deptNutrition),
      _ => c,
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
        final now = DateTime.now();
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
    final isAdmin = _userProfile!['role'] == 'ADMIN';
    final position = _userProfile!['position'] as String? ?? '';
    const mgr = ['과장', '차장', '부장', '이사', '본부장', '대표이사'];
    final isManager = isAdmin || mgr.contains(position);
    final isNutrition = (_userProfile!['dept_category'] ?? '') == 'NUTRITION';
    final name = _userProfile!['full_name'] ?? '';
    final dept = _deptLabel(_userProfile!['dept_category'] ?? '', context);
    final categories =
        _buildCategories(context, isAdmin, isManager, isNutrition, dept);

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
                    unreadNoticeCount:  _unreadNoticeCount,
                    lunchChecked:       _lunchChecked,
                    dinnerChecked:      _dinnerChecked,
                    attendanceChecked:  _attendanceChecked,
                    onNoticeTap: () =>
                        _push(NoticeListScreen(isAdmin: isAdmin, myDept: dept)),
                    onMealTap:        _showMealSheet,
                    onAttendanceTap:  () => _push(AttendanceScreen(
                        userProfile: _userProfile!)),
                  ),
                if (!_bannerLoading) const SizedBox(height: 20),
                _quickActions(isAdmin),
                const SizedBox(height: 24),
                _SectionHeader(
                  title: context.tr(AppStrings.menu),
                  subtitle: context.tr(AppStrings.menuSubtitle),
                ),
                const SizedBox(height: 14),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.9,
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
                        cat: categories[i],
                        onTap: () =>
                            _showCategorySheet(context, categories[i]),
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

  Widget _sliverAppBar(BuildContext context, String name, String dept,
      String position, bool isAdmin) {
    return SliverAppBar(
      expandedHeight: 195,
      floating: false,
      pinned: true,
      stretch: true,
      stretchTriggerOffset: 80,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: const Color(0xFF1E4AD9),
      title: Text(context.tr(AppStrings.appName),
          style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: Colors.white.withOpacity(0.92))),
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
                Color(0xFF1A3EC7),
                Color(0xFF2E6BFF),
                Color(0xFF4FB8FF)
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(children: [
            Positioned(
              right: -40,
              top: -40,
              child: CircleAvatar(
                  radius: 110,
                  backgroundColor: Colors.white.withOpacity(0.05)),
            ),
            Positioned(
              left: -20,
              bottom: -30,
              child: CircleAvatar(
                  radius: 80,
                  backgroundColor: Colors.white.withOpacity(0.04)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 75, 20, 0),
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1.5),
                      ),
                      child: const Icon(Icons.person_rounded,
                          color: Colors.white, size: 36),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(children: [
                            Text(name,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 21,
                                    fontWeight: FontWeight.w900)),
                            const SizedBox(width: 8),
                            if (isAdmin)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                    color: Colors.orangeAccent,
                                    borderRadius:
                                        BorderRadius.circular(6)),
                                child: const Text("ADMIN",
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900)),
                              ),
                          ]),
                          const SizedBox(height: 5),
                          Text("$dept  ·  $position",
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 11, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.calendar_today_rounded,
                                      color: Colors.white70, size: 12),
                                  const SizedBox(width: 6),
                                  Text(
                                    DateFormat('yyyy.MM.dd (E)', 'ko_KR')
                                        .format(DateTime.now()),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ]),
                          ),
                        ],
                      ),
                    ),
                  ]),
            ),
          ]),
        ),
      ),
    );
  }
}