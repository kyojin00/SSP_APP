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

  static const _bg      = Color(0xFFEBF2FF);
  static const _text    = Color(0xFF1A1D2E);
  static const _primary = Color(0xFF2E6BFF);

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
      return {'totalRooms': 0, 'currentResidents': 0, 'remainingSeats': 0, 'maxCapacity': 0};
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
          // ─── SliverAppBar ───
          SliverAppBar(
            expandedHeight: 160,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF1E4AD9),
            foregroundColor: Colors.white,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1E4AD9), Color(0xFF2E6BFF), Color(0xFF4FB2FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(children: [
                  Positioned(
                    right: -30, top: -20,
                    child: Container(
                      width: 180, height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.04),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 40, bottom: -40,
                    child: Container(
                      width: 120, height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.06),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20, bottom: 24,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isAdmin)
                          Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _primary.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: _primary.withOpacity(0.5)),
                            ),
                            child: const Text("ADMIN",
                                style: TextStyle(
                                    color: Colors.white, fontSize: 10,
                                    fontWeight: FontWeight.w900, letterSpacing: 1)),
                          ),
                        Text("$name${context.tr(AppStrings.dormHub).contains('님') ? '님,' : ','}",
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 15,
                                fontWeight: FontWeight.w500)),
                        const SizedBox(height: 2),
                        Text(
                          isAdmin ? "ADMIN" : context.tr(AppStrings.dormHub),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 24,
                              fontWeight: FontWeight.w900, letterSpacing: -0.5),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 20, bottom: 20,
                    child: Icon(Icons.apartment_rounded,
                        size: 64, color: Colors.white.withOpacity(0.1)),
                  ),
                ]),
              ),
            ),
            title: Text(context.tr(AppStrings.dormHub),
                style: const TextStyle(
                    fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white)),
          ),

          // ─── 바디 ───
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isAdmin) ...[
                    _sectionHeader("📊 실시간 시설 현황"),
                    const SizedBox(height: 12),
                    _buildOccupancySummary(),
                    const SizedBox(height: 28),
                  ],
                  _sectionHeader("⚙️ 주요 서비스"),
                  const SizedBox(height: 14),
                  _buildMenuGrid(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOccupancySummary() {
    return FutureBuilder<Map<String, int>>(
      future: _getDormStats(),
      builder: (context, snapshot) {
        final stats = snapshot.data ??
            {'totalRooms': 0, 'currentResidents': 0, 'remainingSeats': 0, 'maxCapacity': 0};
        final residents = stats['currentResidents']!;
        final max       = stats['maxCapacity']!;
        final rate      = max > 0 ? residents / max : 0.0;

        return Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E293B), Color(0xFF334155)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(
                color: const Color(0xFF1E293B).withOpacity(0.3),
                blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: Column(children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statItem(context, "전체 호실", "${stats['totalRooms']}", "개"),
                Container(width: 1, height: 40, color: Colors.white.withOpacity(0.15)),
                _statItem(context, "거주 인원", "$residents", context.tr(AppStrings.members)),
                Container(width: 1, height: 40, color: Colors.white.withOpacity(0.15)),
                _statItem(context, "잔여 공석", "${stats['remainingSeats']}", "석"),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("입실률  ${(rate * 100).toStringAsFixed(0)}%",
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 11, fontWeight: FontWeight.w600)),
                Text("$residents / $max${context.tr(AppStrings.members)}",
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: rate.clamp(0.0, 1.0),
                minHeight: 5,
                backgroundColor: Colors.white.withOpacity(0.1),
                valueColor: const AlwaysStoppedAnimation(Colors.white),
              ),
            ),
          ]),
        );
      },
    );
  }

  Widget _statItem(BuildContext context, String label, String value, String unit) {
    return Column(children: [
      RichText(
        text: TextSpan(children: [
          TextSpan(text: value,
              style: const TextStyle(
                  color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
          TextSpan(text: " $unit",
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
        ]),
      ),
      const SizedBox(height: 5),
      Text(label,
          style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 12, fontWeight: FontWeight.w600)),
    ]);
  }

  Widget _buildMenuGrid(BuildContext context) {
    final menus = [
      _MenuItem(
        icon: Icons.vpn_key_rounded,
        label: widget.isAdmin
            ? context.tr(AppStrings.approvalAssign)
            : context.tr(AppStrings.myDormitory),
        color: _primary,
        onTap: () {
          if (widget.isAdmin) {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const DormAdminAssignScreen()));
          } else {
            Navigator.push(context,
                MaterialPageRoute(
                    builder: (_) => DormEmployeeScreen(userProfile: widget.userProfile)));
          }
        },
      ),
      _MenuItem(
        icon: Icons.menu_book_rounded,
        label: context.tr(AppStrings.dormRules),
        color: const Color(0xFF8E59FF),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const DormRulesScreen())),
      ),
      _MenuItem(
        icon: Icons.build_circle_rounded,
        label: context.tr(AppStrings.repairReport),
        color: const Color(0xFFFF9500),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(
                builder: (_) => DormRepairScreen(
                    userProfile: widget.userProfile, isAdmin: widget.isAdmin))),
      ),
      _MenuItem(
        icon: Icons.analytics_rounded,
        label: widget.isAdmin
            ? context.tr(AppStrings.demeritMgmt)
            : context.tr(AppStrings.myDemerit),
        color: const Color(0xFFFF3B30),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(
                builder: (_) => DemeritListScreen(isAdmin: widget.isAdmin))),
      ),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: 1.05,
      children: menus.map((m) => _buildMenuCard(m)).toList(),
    );
  }

  Widget _buildMenuCard(_MenuItem item) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(24),
        splashColor: item.color.withOpacity(0.08),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 16, offset: const Offset(0, 6))],
            border: Border.all(color: Colors.black.withOpacity(0.03)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 58, height: 58,
                decoration: BoxDecoration(
                  color: item.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(item.icon, color: item.color, size: 28),
              ),
              const SizedBox(height: 13),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(item.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 13,
                        color: _text, letterSpacing: -0.3)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(title,
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w900,
              color: _text, letterSpacing: -0.3)),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _MenuItem({
    required this.icon, required this.label,
    required this.color, required this.onTap,
  });
}