import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dorm_rules_screen.dart';
import 'dorm_admin_assign_screen.dart';
import 'dorm_employee_screen.dart';
import 'dorm_repair_screen.dart';
import 'demerit_list_screen.dart';
import 'lang_context.dart';
import 'app_strings.dart';

class DormManagementScreen extends StatefulWidget {
  final bool isAdmin;
  final Map<String, dynamic> userProfile;

  const DormManagementScreen({
    Key? key,
    required this.isAdmin,
    required this.userProfile,
  }) : super(key: key);

  @override
  State<DormManagementScreen> createState() => _DormManagementScreenState();
}

class _DormManagementScreenState extends State<DormManagementScreen> {
  final supabase = Supabase.instance.client;

  static const _bg      = Color(0xFFF4F6FB);
  static const _text    = Color(0xFF1A1D2E);
  static const _sub     = Color(0xFF8A93B0);
  static const _primary = Color(0xFF2E6BFF);

  // 테마 컬러 (청록 계열)
  static const _teal    = Color(0xFF00BCD4);
  static const _tealDk  = Color(0xFF0097A7);

  Color _lighten(Color c, double a) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + a).clamp(0.0, 1.0)).toColor();
  }

  Future<Map<String, int>> _getDormStats() async {
    try {
      final rooms = await supabase
          .from('dorm_rooms')
          .select('max_capacity, current_occupancy');
      int totalRooms       = rooms.length;
      int currentResidents = 0;
      int maxTotalCapacity = 0;
      for (var room in rooms) {
        currentResidents += (room['current_occupancy'] as int? ?? 0);
        maxTotalCapacity  += (room['max_capacity']      as int? ?? 0);
      }
      return {
        'totalRooms':       totalRooms,
        'currentResidents': currentResidents,
        'remainingSeats':   maxTotalCapacity - currentResidents,
        'maxCapacity':      maxTotalCapacity,
      };
    } catch (e) {
      return {
        'totalRooms': 0, 'currentResidents': 0,
        'remainingSeats': 0, 'maxCapacity': 0,
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    final name    = widget.userProfile['full_name'] ?? '';
    final isAdmin = widget.isAdmin;

    return Scaffold(
      backgroundColor: _bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── 그라디언트 SliverAppBar
          SliverAppBar(
            expandedHeight: 150,
            floating: false,
            pinned: true,
            backgroundColor: _tealDk,
            foregroundColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: Text(context.tr(AppStrings.dormHub),
                style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 17, color: Colors.white)),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF005A6A), _tealDk, _teal],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(children: [
                  // 배경 원 장식
                  Positioned(right: -40, top: -40, child: Container(
                    width: 180, height: 180,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.06)),
                  )),
                  Positioned(right: 50, bottom: -30, child: Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.04)),
                  )),
                  // 콘텐츠
                  Positioned(left: 20, bottom: 22, right: 80,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                      if (isAdmin)
                        Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.35)),
                          ),
                          child: const Text('ADMIN',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1)),
                        ),
                      Text(name.isNotEmpty ? '$name님,' : '',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 14, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 2),
                      Text(
                        isAdmin ? 'ADMIN' : context.tr(AppStrings.dormHub),
                        style: const TextStyle(
                            color: Colors.white, fontSize: 22,
                            fontWeight: FontWeight.w900, letterSpacing: -0.5),
                      ),
                    ]),
                  ),
                  Positioned(right: 20, bottom: 14,
                    child: Icon(Icons.apartment_rounded,
                        size: 60, color: Colors.white.withOpacity(0.10))),
                ]),
              ),
            ),
          ),

          // ── 바디
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 48),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                // 어드민: 실시간 통계
                if (isAdmin) ...[
                  _sectionTitle('📊 실시간 시설 현황'),
                  const SizedBox(height: 12),
                  _buildOccupancySummary(),
                  const SizedBox(height: 28),
                ],

                // 주요 서비스
                _sectionTitle('⚙️ 주요 서비스'),
                const SizedBox(height: 14),
                _buildMenuGrid(context),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── 섹션 타이틀
  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(title,
          style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w900, color: _text)),
    );
  }

  // ── 입실률 요약 카드 (어드민)
  Widget _buildOccupancySummary() {
    return FutureBuilder<Map<String, int>>(
      future: _getDormStats(),
      builder: (context, snapshot) {
        final stats = snapshot.data ?? {
          'totalRooms': 0, 'currentResidents': 0,
          'remainingSeats': 0, 'maxCapacity': 0,
        };
        final residents = stats['currentResidents']!;
        final max       = stats['maxCapacity']!;
        final rooms     = stats['totalRooms']!;
        final remaining = stats['remainingSeats']!;
        final rate      = max > 0 ? residents / max : 0.0;

        final rateColor = rate > 0.9
            ? Colors.redAccent
            : rate > 0.6 ? Colors.orange : Colors.greenAccent;

        return Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF005A6A), _tealDk, _teal],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(color: _tealDk.withOpacity(0.30),
                  blurRadius: 18, offset: const Offset(0, 7)),
              BoxShadow(color: Colors.black.withOpacity(0.06),
                  blurRadius: 8, offset: const Offset(0, 3)),
            ],
          ),
          child: Stack(children: [
            Positioned(right: -20, top: -20, child: Container(
                width: 100, height: 100,
                decoration: BoxDecoration(shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.06)))),
            Padding(
              padding: const EdgeInsets.all(20),
              child: snapshot.connectionState == ConnectionState.waiting
                  ? const Center(child: SizedBox(
                      width: 24, height: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white)))
                  : Column(children: [
                      // 통계 3칸
                      Row(mainAxisAlignment:
                          MainAxisAlignment.spaceAround, children: [
                        _statBox('전체 호실', '$rooms', '개'),
                        Container(width: 1, height: 40,
                            color: Colors.white.withOpacity(0.2)),
                        _statBox('거주 인원', '$residents',
                            context.tr(AppStrings.members)),
                        Container(width: 1, height: 40,
                            color: Colors.white.withOpacity(0.2)),
                        _statBox('잔여 공석', '$remaining', '석'),
                      ]),
                      const SizedBox(height: 16),
                      // 진행 바
                      Row(children: [
                        Text('입실률  ${(rate * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.65),
                                fontSize: 11, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        Text('$residents / $max${context.tr(AppStrings.members)}',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.65),
                                fontSize: 11, fontWeight: FontWeight.w600)),
                      ]),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: LinearProgressIndicator(
                          value: rate.clamp(0.0, 1.0),
                          minHeight: 7,
                          backgroundColor:
                              Colors.white.withOpacity(0.15),
                          valueColor:
                              AlwaysStoppedAnimation(rateColor),
                        ),
                      ),
                    ]),
            ),
          ]),
        );
      },
    );
  }

  Widget _statBox(String label, String value, String unit) {
    return Column(children: [
      RichText(
        text: TextSpan(children: [
          TextSpan(text: value,
              style: const TextStyle(
                  color: Colors.white, fontSize: 26,
                  fontWeight: FontWeight.w900)),
          TextSpan(text: ' $unit',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.6), fontSize: 12)),
        ]),
      ),
      const SizedBox(height: 4),
      Text(label,
          style: TextStyle(
              color: Colors.white.withOpacity(0.55),
              fontSize: 11, fontWeight: FontWeight.w600)),
    ]);
  }

  // ── 메뉴 그리드
  Widget _buildMenuGrid(BuildContext context) {
    final menus = [
      _MenuItem(
        icon:  Icons.vpn_key_rounded,
        label: widget.isAdmin
            ? context.tr(AppStrings.approvalAssign)
            : context.tr(AppStrings.myDormitory),
        color:    _primary,
        gradient: [_lighten(_primary, 0.18), _primary],
        onTap: () {
          if (widget.isAdmin) {
            Navigator.push(context, MaterialPageRoute(
                builder: (_) => const DormAdminAssignScreen()));
          } else {
            Navigator.push(context, MaterialPageRoute(
                builder: (_) =>
                    DormEmployeeScreen(userProfile: widget.userProfile)));
          }
        },
      ),
      _MenuItem(
        icon:     Icons.menu_book_rounded,
        label:    context.tr(AppStrings.dormRules),
        color:    const Color(0xFF8E59FF),
        gradient: [_lighten(const Color(0xFF8E59FF), 0.18),
            const Color(0xFF8E59FF)],
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const DormRulesScreen())),
      ),
      _MenuItem(
        icon:     Icons.build_circle_rounded,
        label:    context.tr(AppStrings.repairReport),
        color:    const Color(0xFFFF9500),
        gradient: [_lighten(const Color(0xFFFF9500), 0.15),
            const Color(0xFFFF9500)],
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => DormRepairScreen(
                userProfile: widget.userProfile, isAdmin: widget.isAdmin))),
      ),
      _MenuItem(
        icon:     Icons.analytics_rounded,
        label:    widget.isAdmin
            ? context.tr(AppStrings.demeritMgmt)
            : context.tr(AppStrings.myDemerit),
        color:    const Color(0xFFFF3B30),
        gradient: [_lighten(const Color(0xFFFF3B30), 0.18),
            const Color(0xFFFF3B30)],
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) =>
                DemeritListScreen(isAdmin: widget.isAdmin))),
      ),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: 1.05,
      children: menus.map(_buildMenuCard).toList(),
    );
  }

  Widget _buildMenuCard(_MenuItem item) {
    return GestureDetector(
      onTap: item.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
                color: item.color.withOpacity(0.12),
                blurRadius: 16, offset: const Offset(0, 6)),
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center, children: [
            // 그라디언트 원형 아이콘
            Container(
              width: 62, height: 62,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: item.gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: item.color.withOpacity(0.30),
                      blurRadius: 12, offset: const Offset(0, 5)),
                ],
              ),
              child: Icon(item.icon, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(item.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 13,
                      color: _text, letterSpacing: -0.3)),
            ),
            const SizedBox(height: 6),
            // 하단 컬러 밑줄 포인트
            Container(
              width: 24, height: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: item.gradient),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 10),
          ]),
        ),
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  final Color color;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.gradient,
    required this.onTap,
  });
}