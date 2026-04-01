part of 'home_screen.dart';

// ══════════════════════════════════════════
// 카테고리 빌더 + 퀵액션 (extension on _HomeScreenState)
// ══════════════════════════════════════════

extension HomeScreenCategories on _HomeScreenState {
  List<_Category> _buildCategories(
    BuildContext context,
    bool isAdmin,
    bool isManager,
    bool isNutrition,
    String myDept,
  ) {
    return [
      _Category(
        title: context.tr(AppStrings.catMeal),
        icon: Icons.restaurant_rounded,
        color: const Color(0xFFFF7A2F),
        desc: context.tr(AppStrings.catMealDesc),
        items: [
          _SubItem(Icons.restaurant_menu_rounded,
              context.tr(AppStrings.mealCheck), _showMealSheet),
          _SubItem(
            Icons.menu_book_rounded,
            context.tr(AppStrings.mealMenuWeekly),
            () => _push(MealMenuScreen(
                canUpload: isAdmin ||
                    (_userProfile!['dept_category'] ?? '') == 'NUTRITION')),
          ),
          if (isManager || isNutrition)
            _SubItem(Icons.bar_chart_rounded,
                context.tr(AppStrings.mealReport),
                () => _push(const MealReportScreen())),
        ],
      ),
      _Category(
        title: context.tr(AppStrings.catWork),
        icon: Icons.punch_clock_rounded,
        color: const Color(0xFF2E6BFF),
        desc: context.tr(AppStrings.catWorkDesc),
        badge: isManager && _pendingLeaveCount > 0 ? _pendingLeaveCount : null,
        items: [
          _SubItem(Icons.punch_clock_rounded,
              context.tr(AppStrings.attendance),
              () => _push(AttendanceScreen(userProfile: _userProfile!))),
          _SubItem(Icons.edit_calendar_rounded,
              context.tr(AppStrings.leaveRequest),
              () => _push(LeaveRequestScreen(userProfile: _userProfile!))),
          _SubItem(Icons.flight_takeoff_rounded,
              context.tr(AppStrings.leaveRealtime),
              () => _push(AttendanceManagementScreen(isManager: false))),
          if (isManager)
            _SubItem(Icons.how_to_reg_rounded,
                context.tr(AppStrings.attendanceMgmt),
                () => _push(AttendanceManagementScreen(isManager: true)),
                badge: _pendingLeaveCount > 0 ? _pendingLeaveCount : null),
        ],
      ),
      _Category(
        title: context.tr(AppStrings.catNotice),
        icon: Icons.campaign_rounded,
        color: const Color(0xFF7C5CDB),
        desc: context.tr(AppStrings.catNoticeDesc),
        items: [
          _SubItem(Icons.campaign_rounded, context.tr(AppStrings.notice),
              () => _push(NoticeListScreen(isAdmin: isAdmin, myDept: myDept))),
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
          _SubItem(Icons.grid_view_rounded, '호실 배치도',
              () => _push(const DormRoomMapScreen())),
          _SubItem(Icons.cleaning_services_rounded, '베란다 청소',  // ← 추가
              () => _push(CleaningScreen(userProfile: _userProfile!))),
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
            _SubItem(Icons.bar_chart_rounded,
                '사용자 활동 현황',
                () => _push(UserActivityScreen())),
            _SubItem(Icons.insights_rounded,
                context.tr(AppStrings.catTrend),
                () => _push(TrendScreen(isAdmin: isAdmin))),
          ],
        ),
      if (isAdmin || ['MANAGEMENT', 'DELIVERY', 'PRODUCTION', 'SALES']
          .contains(_userProfile!['dept_category']))
        _Category(
          title: context.tr(AppStrings.catVehicle),
          icon: Icons.directions_car_rounded,
          color: const Color(0xFF00BFA5),
          desc: context.tr(AppStrings.catVehicleDesc),
          badge: isAdmin && _pendingFuelCount > 0 ? _pendingFuelCount : null,
          items: [
            _SubItem(Icons.directions_car_rounded,
                context.tr(AppStrings.catVehicle),
                () => _push(VehicleScreen(
                    userProfile: _userProfile!, isAdmin: isAdmin))),
            _SubItem(Icons.local_gas_station_rounded,
                '주유 신청',
                () => _push(FuelCardScreen(isAdmin: isAdmin)),
                badge: isAdmin && _pendingFuelCount > 0
                    ? _pendingFuelCount : null),
          ],
        ),
      _Category(
        title: context.tr(AppStrings.catRequest),
        icon: Icons.assignment_rounded,
        color: const Color(0xFF43A047),
        desc: context.tr(AppStrings.catRequestDesc),
        badge: isAdmin && _pendingUniformCount > 0 ? _pendingUniformCount : null,
        items: [
          _SubItem(Icons.checkroom_rounded,
              context.tr(AppStrings.uniformTitle),
              () => _push(UniformRequestScreen(
                  userProfile: _userProfile!, isAdmin: isAdmin)),
              badge: isAdmin && _pendingUniformCount > 0
                  ? _pendingUniformCount : null),
          _SubItem(Icons.credit_card_rounded, '명함 지갑',
              () => _push(BusinessCardScreen())),
        ],
      ),
      if (isAdmin)
        _Category(
          title: '보건',
          icon: Icons.health_and_safety_rounded,
          color: const Color(0xFF00897B),
          desc: '근로자 건강상담 기록 · PDF 출력',
          items: [
            _SubItem(Icons.health_and_safety_rounded, '건강 리포트',
                () => _push(HealthScreen(isAdmin: isAdmin))),
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
            onTap: () => _push(AttendanceScreen(userProfile: _userProfile!)),
          ),
        ),
      ]),
    ]);
  }
}