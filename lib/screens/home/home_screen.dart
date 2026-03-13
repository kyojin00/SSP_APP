// home_screen.dart — 메인 홈 (공지 미읽음 + 식수 미체크 배너 추가)

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

import '../auth/login_screen.dart';
import 'meal_stats_screen.dart';
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

// ══════════════════════════════════════════
// 데이터 모델
// ══════════════════════════════════════════

class _SubItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SubItem(this.icon, this.label, this.onTap);
}

class _Category {
  final String title;
  final IconData icon;
  final Color color;
  final String desc;
  final List<_SubItem> items;
  const _Category({
    required this.title,
    required this.icon,
    required this.color,
    required this.desc,
    required this.items,
  });
}

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

  // ✅ 언어 리스너 안전 관리
  bool _langListenerAdded = false;

  DateTime? _lastBackPress;

  late final AnimationController _cardCtrl;
  late final List<Animation<double>> _cardAnims;
  static const int _maxCards = 6;

  // ✅ 알림 배너 상태
  int _unreadNoticeCount = 0;
  bool _lunchChecked = false;
  bool _dinnerChecked = false;
  bool _bannerLoading = true;

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

      // 프로필 로드 후 배너 데이터 로드
      await _loadBannerData();
    } catch (e) {
      debugPrint("프로필 로드: $e");
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  // ✅ 공지 미읽음 + 식수 미체크 데이터 로드
  Future<void> _loadBannerData() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    try {
      // 전체 공지 id 목록 + 내가 읽은 공지 id 목록을 동시에 조회
      final results = await Future.wait([
        supabase.from('notices').select('id'),
        supabase
            .from('notice_reads')
            .select('notice_id')
            .eq('user_id', user.id),
        // 오늘 식수 체크 여부
        supabase
            .from('meal_requests')
            .select('meal_type')
            .eq('user_id', user.id)
            .eq('meal_date', today),
      ]);

      final allNotices = results[0] as List;
      final readNotices = results[1] as List;
      final todayMeals = results[2] as List;

      final readIds = readNotices.map((r) => r['notice_id'] as String).toSet();
      final unreadCount = allNotices
          .where((n) => !readIds.contains(n['id'] as String))
          .length;

      final lunchChecked =
          todayMeals.any((r) => r['meal_type'] == 'LUNCH');
      final dinnerChecked =
          todayMeals.any((r) => r['meal_type'] == 'DINNER');

      if (!mounted) return;
      setState(() {
        _unreadNoticeCount = unreadCount;
        _lunchChecked = lunchChecked;
        _dinnerChecked = dinnerChecked;
        _bannerLoading = false;
      });
    } catch (e) {
      debugPrint("배너 데이터 로드 실패: $e");
      if (!mounted) return;
      setState(() => _bannerLoading = false);
    }
  }

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

  Future<void> _logout() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
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
        );
      },
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

  void _push(Widget screen) => Navigator.push(context, AppRouter.slide(screen));

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
        'ADMIN': '관리자'
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
    const mgr = ['주임', '대리', '과장', '차장', '부장', '이사', '본부장', '대표이사'];
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
                // ✅ 알림 배너
                if (!_bannerLoading)
                  _StatusBanner(
                    unreadNoticeCount: _unreadNoticeCount,
                    lunchChecked: _lunchChecked,
                    dinnerChecked: _dinnerChecked,
                    onNoticeTap: () => _push(NoticeListScreen(
                        isAdmin: isAdmin, myDept: dept)),
                    onMealTap: _showMealSheet,
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

  List<_Category> _buildCategories(BuildContext context, bool isAdmin,
      bool isManager, bool isNutrition, String myDept) {
    final cats = <_Category>[
      _Category(
        title: context.tr(AppStrings.catMeal),
        icon: Icons.restaurant_rounded,
        color: const Color(0xFFFF7A2F),
        desc: context.tr(AppStrings.catMealDesc),
        items: [
          _SubItem(Icons.restaurant_menu_rounded,
              context.tr(AppStrings.mealCheck), _showMealSheet),

          // ✅ 이번주 식단표 추가
          _SubItem(Icons.menu_book_rounded, '이번주 식단표',
              () => _push(MealMenuScreen(
                  canUpload: isAdmin ||
                      (_userProfile!['dept_category'] ?? '') == 'NUTRITION'))),

          if (isManager || isNutrition)
            _SubItem(Icons.bar_chart_rounded,
                context.tr(AppStrings.mealReport),
                () => _push(const MealReportScreen())),
          if (isManager)
            _SubItem(Icons.analytics_rounded,
                context.tr(AppStrings.mealStats),
                () => _push(MealStatsScreen(userProfile: _userProfile!))),
        ],
      ),
      _Category(
        title: context.tr(AppStrings.catWork),
        icon: Icons.punch_clock_rounded,
        color: const Color(0xFF2E6BFF),
        desc: context.tr(AppStrings.catWorkDesc),
        items: [
          _SubItem(Icons.punch_clock_rounded,
              context.tr(AppStrings.attendance),
              () => _push(AttendanceScreen(userProfile: _userProfile!))),
          _SubItem(Icons.edit_calendar_rounded,
              context.tr(AppStrings.leaveRequest),
              () => _push(LeaveRequestScreen(userProfile: _userProfile!))),
          if (isManager)
            _SubItem(Icons.how_to_reg_rounded,
                context.tr(AppStrings.attendanceMgmt),
                () => _push(AttendanceManagementScreen())),
        ],
      ),
      _Category(
        title: context.tr(AppStrings.catNotice),
        icon: Icons.campaign_rounded,
        color: const Color(0xFF7C5CDB),
        desc: context.tr(AppStrings.catNoticeDesc),
        items: [
          _SubItem(Icons.campaign_rounded, context.tr(AppStrings.notice),
              () => _push(
                  NoticeListScreen(isAdmin: isAdmin, myDept: myDept))),
          _SubItem(Icons.record_voice_over_rounded,
              context.tr(AppStrings.suggestion),
              () => _push(SuggestionScreen(isAdmin: isAdmin))),
        ],
      ),
      _Category(
        title: context.tr(AppStrings.catField),
        icon: Icons.engineering_rounded,
        color: const Color(0xFFFF8C42),
        desc: context.tr(AppStrings.catFieldDesc),
        items: [
          _SubItem(Icons.engineering_rounded,
              context.tr(AppStrings.fieldMgmt),
              () => _push(FieldManagementScreen(isAdmin: isAdmin))),
        ],
      ),
      _Category(
        title: context.tr(AppStrings.catDorm),
        icon: Icons.hotel_rounded,
        color: const Color(0xFF00BCD4),
        desc: context.tr(AppStrings.catDormDesc),
        items: [
          _SubItem(Icons.hotel_rounded, context.tr(AppStrings.dormitory),
              () => _push(DormManagementScreen(
                  isAdmin: isAdmin, userProfile: _userProfile!))),
        ],
      ),
      if (isAdmin)
        _Category(
          title: context.tr(AppStrings.catAdmin),
          icon: Icons.admin_panel_settings_rounded,
          color: const Color(0xFFE91E8C),
          desc: context.tr(AppStrings.catAdminDesc),
          items: [
            _SubItem(Icons.manage_accounts_rounded,
                context.tr(AppStrings.employeeMgmt),
                () => _push(const EmployeeManagementScreen())),
            _SubItem(Icons.file_download_rounded,
                context.tr(AppStrings.excelExport),
                () => _push(const ExcelExportScreen())),
          ],
        ),
      _Category(
        title: context.tr(AppStrings.catEtc),
        icon: Icons.more_horiz_rounded,
        color: const Color(0xFF607D8B),
        desc: context.tr(AppStrings.catEtcDesc),
        items: [
          _SubItem(Icons.language_rounded,
              context.tr(AppStrings.langSettings),
              () => _showLangSheet(context)),
          _SubItem(Icons.notifications_active_rounded,
              context.tr(AppStrings.notifReconnect),
              () => _reconnectOneSignal()),
          _SubItem(Icons.menu_book_rounded, context.tr(AppStrings.manual),
              () => _snack(context.tr(AppStrings.preparing))),
          _SubItem(Icons.install_mobile_rounded,
              context.tr(AppStrings.appInstall),
              () => _push(const PwaInstallGuideScreen())),
        ],
      ),
      
    ];

    return cats;
  }

  Widget _quickActions(bool isAdmin) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SectionHeader(
        title: context.tr(AppStrings.quickAction),
        subtitle: context.tr(AppStrings.quickSubtitle),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
          child: _QuickBtn(
            icon: Icons.restaurant_menu_rounded,
            label: context.tr(AppStrings.mealCheck),
            sub: context.tr(AppStrings.mealCheckSub),
            color: const Color(0xFFFF7A2F),
            onTap: _showMealSheet,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickBtn(
            icon: Icons.punch_clock_rounded,
            label: context.tr(AppStrings.attendance),
            sub: context.tr(AppStrings.attendanceSub),
            color: const Color(0xFF2E6BFF),
            onTap: () =>
                _push(AttendanceScreen(userProfile: _userProfile!)),
          ),
        ),
      ]),
    ]);
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
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                      color: const Color(0xFF2E6BFF).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.language_rounded,
                      color: Color(0xFF2E6BFF), size: 22),
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
              const SizedBox(height: 20),
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
                                      color:
                                          Colors.black.withOpacity(0.4))),
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

  void _showMealSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
        padding: const EdgeInsets.all(22),
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
          Text(context.tr(AppStrings.mealCheckTitle),
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(context.tr(AppStrings.mealSelectHint),
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.black.withOpacity(0.45))),
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

  void _showCategorySheet(BuildContext context, _Category cat) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2)),
          ),
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cat.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(cat.icon, color: cat.color, size: 24),
            ),
            const SizedBox(width: 14),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(cat.title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w900)),
              Text(cat.desc,
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.black.withOpacity(0.4))),
            ]),
          ]),
          const SizedBox(height: 20),
          Divider(height: 1, color: Colors.black.withOpacity(0.06)),
          const SizedBox(height: 16),
          ...cat.items.map((sub) =>
              _SheetMenuItem(sub: sub, color: cat.color)),
          const SizedBox(height: 4),
        ]),
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
                backgroundColor: Colors.white.withOpacity(0.05),
              ),
            ),
            Positioned(
              left: -20,
              bottom: -30,
              child: CircleAvatar(
                radius: 80,
                backgroundColor: Colors.white.withOpacity(0.04),
              ),
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
                            child:
                                Row(mainAxisSize: MainAxisSize.min, children: [
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

// ══════════════════════════════════════════
// ✅ 상태 배너 위젯
// ══════════════════════════════════════════

class _StatusBanner extends StatelessWidget {
  final int unreadNoticeCount;
  final bool lunchChecked;
  final bool dinnerChecked;
  final VoidCallback onNoticeTap;
  final VoidCallback onMealTap;

  const _StatusBanner({
    required this.unreadNoticeCount,
    required this.lunchChecked,
    required this.dinnerChecked,
    required this.onNoticeTap,
    required this.onMealTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasUnreadNotice = unreadNoticeCount > 0;
    final mealUnchecked = !lunchChecked || !dinnerChecked;

    // 둘 다 이상 없으면 배너 숨김
    if (!hasUnreadNotice && !mealUnchecked) return const SizedBox.shrink();

    return Column(
      children: [
        // 공지 미읽음 배너
        if (hasUnreadNotice)
          _BannerTile(
            icon: Icons.campaign_rounded,
            color: const Color(0xFF7C5CDB),
            label: context.tr(AppStrings.bannerUnreadNotice).replaceAll('{n}', '$unreadNoticeCount'),
            actionLabel: context.tr(AppStrings.bannerGoCheck),
            onTap: onNoticeTap,
          ),
        if (hasUnreadNotice && mealUnchecked) const SizedBox(height: 8),
        // 식수 미체크 배너
        if (mealUnchecked)
          _BannerTile(
            icon: Icons.restaurant_menu_rounded,
            color: const Color(0xFFFF7A2F),
            label: _mealLabel(context, lunchChecked, dinnerChecked),
            actionLabel: context.tr(AppStrings.bannerMealCheck),
            onTap: onMealTap,
          ),
      ],
    );
  }

  String _mealLabel(BuildContext context, bool lunch, bool dinner) {
    if (!lunch && !dinner) return context.tr(AppStrings.bannerMealBoth);
    if (!lunch) return context.tr(AppStrings.bannerMealLunch);
    return context.tr(AppStrings.bannerMealDinner);
  }
}

class _BannerTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String actionLabel;
  final VoidCallback onTap;

  const _BannerTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.actionLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color.withOpacity(0.9),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              actionLabel,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════
// 카테고리 카드 / UI 컴포넌트
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
                ? [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 4,
                        offset: const Offset(0, 2))
                  ]
                : [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.07),
                        blurRadius: 14,
                        offset: const Offset(0, 6))
                  ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(cat.icon, color: color, size: 24),
              ),
              const SizedBox(height: 8),
              Text(
                cat.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1D2E),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
              color:
                  _pressed ? c.withOpacity(0.3) : c.withOpacity(0.12)),
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
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: c)),
          const Spacer(),
          Icon(Icons.arrow_forward_ios_rounded,
              color: c.withOpacity(0.4), size: 14),
        ]),
      ),
    );
  }
}

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
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                c,
                HSLColor.fromColor(c)
                    .withLightness(
                        (HSLColor.fromColor(c).lightness + 0.1)
                            .clamp(0.0, 0.9))
                    .toColor()
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: _pressed
                ? []
                : [
                    BoxShadow(
                      color: c.withOpacity(0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    )
                  ],
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle),
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
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 14)),
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