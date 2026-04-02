part of 'home_screen.dart';

// ══════════════════════════════════════════
// 퀵액션 정의 모델
// ══════════════════════════════════════════

class _QuickActionDef {
  final String   id;
  final IconData icon;
  final Color    color;
  final String Function(BuildContext) labelFn;
  final String Function(BuildContext) subFn;
  final VoidCallback onTap;

  const _QuickActionDef({
    required this.id,
    required this.icon,
    required this.color,
    required this.labelFn,
    required this.subFn,
    required this.onTap,
  });
}

// ══════════════════════════════════════════
// 카테고리 빌더 + 퀵액션 (extension on _HomeScreenState)
// ══════════════════════════════════════════

extension HomeScreenCategories on _HomeScreenState {

  // ── 이 유저가 사용 가능한 퀵액션 전체 목록 ──
  List<_QuickActionDef> _availableQuickActions(
      bool isAdmin, bool isNutrition, String myDept) {
    final position = _userProfile!['position'] as String? ?? '';
    const mgrRanks = ['과장', '차장', '부장', '이사', '본부장', '대표이사'];
    final isManager = isAdmin || mgrRanks.contains(position);

    return [
      if (!isNutrition)
        _QuickActionDef(
          id:      'meal_check',
          icon:    Icons.restaurant_menu_rounded,
          color:   const Color(0xFFFF7A2F),
          labelFn: (ctx) => ctx.tr(AppStrings.mealCheck),
          subFn:   (ctx) => ctx.tr(AppStrings.mealCheckSub),
          onTap:   _showMealSheet,
        ),
      if (!isNutrition)
        _QuickActionDef(
          id:      'attendance',
          icon:    Icons.punch_clock_rounded,
          color:   const Color(0xFF2E6BFF),
          labelFn: (ctx) => ctx.tr(AppStrings.attendance),
          subFn:   (ctx) => ctx.tr(AppStrings.attendanceSub),
          onTap:   () => _push(AttendanceScreen(userProfile: _userProfile!)),
        ),
      if (isAdmin ||
          ['MANAGEMENT', 'DELIVERY', 'PRODUCTION', 'SALES'].contains(myDept))
        _QuickActionDef(
          id:      'vehicle',
          icon:    Icons.directions_car_rounded,
          color:   const Color(0xFF00BFA5),
          labelFn: (_) => '차량 일지',
          subFn:   (_) => '운행 기록',
          onTap:   () => _push(VehicleScreen(
              userProfile: _userProfile!, isAdmin: isAdmin)),
        ),
      _QuickActionDef(
        id:      'notice',
        icon:    Icons.campaign_rounded,
        color:   const Color(0xFF7C5CDB),
        labelFn: (ctx) => ctx.tr(AppStrings.notice),
        subFn:   (_) => '공지 확인',
        onTap:   () => _push(NoticeListScreen(
            isAdmin: isAdmin, myDept: myDept)),
      ),
      if (!isNutrition)
        _QuickActionDef(
          id:      'leave',
          icon:    Icons.edit_calendar_rounded,
          color:   const Color(0xFF43A047),
          labelFn: (ctx) => ctx.tr(AppStrings.leaveRequest),
          subFn:   (_) => '휴가 신청',
          onTap:   () => _push(LeaveRequestScreen(userProfile: _userProfile!)),
        ),
      if (isManager || isNutrition)
        _QuickActionDef(
          id:      'meal_report',
          icon:    Icons.bar_chart_rounded,
          color:   const Color(0xFFFF9800),
          labelFn: (_) => '식수 리포트',
          subFn:   (_) => '오늘 식수 현황',
          onTap:   () => _push(const MealReportScreen()),
        ),
      if (!isNutrition)
        _QuickActionDef(
          id:      'meal_menu',
          icon:    Icons.menu_book_rounded,
          color:   const Color(0xFF00897B),
          labelFn: (ctx) => ctx.tr(AppStrings.mealMenuWeekly),
          subFn:   (_) => '주간 식단',
          onTap:   () => _push(MealMenuScreen(
              canUpload: isAdmin || myDept == 'NUTRITION')),
        ),
      _QuickActionDef(
        id:      'suggestion',
        icon:    Icons.record_voice_over_rounded,
        color:   const Color(0xFF607D8B),
        labelFn: (ctx) => ctx.tr(AppStrings.suggestion),
        subFn:   (_) => '건의하기',
        onTap:   () => _push(SuggestionScreen(isAdmin: isAdmin)),
      ),
    ];
  }

  // ── 퀵액션 위젯 ──
  Widget _quickActions(bool isAdmin, bool isNutrition, String myDept) {
    final available    = _availableQuickActions(isAdmin, isNutrition, myDept);
    final availableIds = available.map((a) => a.id).toSet();

    // 저장된 ID 중 이 유저가 사용 가능한 것만 필터
    var selectedIds = _quickActionIds
        .where((id) => availableIds.contains(id))
        .toList();

    // 선택된 것이 없으면 기본값
    if (selectedIds.isEmpty) {
      selectedIds = ['meal_check', 'attendance']
          .where(availableIds.contains).toList();
    }

    final selectedActions = selectedIds
        .map((id) => available.firstWhere((a) => a.id == id,
            orElse: () => available.first))
        .toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // 헤더 + 편집 버튼
      Row(children: [
        _SectionHeader(
          title:    context.tr(AppStrings.quickAction),
          subtitle: context.tr(AppStrings.quickSubtitle),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () => _showQuickActionEditSheet(
              available, selectedIds, isAdmin, isNutrition, myDept),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF2E6BFF).withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.tune_rounded, size: 13, color: Color(0xFF2E6BFF)),
              SizedBox(width: 4),
              Text('편집',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2E6BFF))),
            ]),
          ),
        ),
      ]),
      const SizedBox(height: 12),

      // 2열 그리드 (최대 4개)
      ...List.generate((selectedActions.length / 2).ceil(), (row) {
        final start      = row * 2;
        final end        = (start + 2).clamp(0, selectedActions.length);
        final rowActions = selectedActions.sublist(start, end);
        final isLastRow  = row == (selectedActions.length / 2).ceil() - 1;
        return Padding(
          padding: EdgeInsets.only(bottom: isLastRow ? 0 : 12),
          child: Row(children: [
            for (int i = 0; i < rowActions.length; i++) ...[
              Expanded(
                child: _QuickBtn(
                  icon:  rowActions[i].icon,
                  label: rowActions[i].labelFn(context),
                  sub:   rowActions[i].subFn(context),
                  color: rowActions[i].color,
                  onTap: rowActions[i].onTap,
                ),
              ),
              if (i < rowActions.length - 1) const SizedBox(width: 12),
              // 홀수 개일 때 빈 자리
              if (rowActions.length == 1) const Expanded(child: SizedBox()),
            ],
          ]),
        );
      }),
    ]);
  }

  // ── 편집 시트 열기 ──
  void _showQuickActionEditSheet(
    List<_QuickActionDef> available,
    List<String> currentIds,
    bool isAdmin,
    bool isNutrition,
    String myDept,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _QuickActionEditSheet(
        available:  available,
        currentIds: List.from(currentIds),
        onSave:     saveQuickActionPrefs,
      ),
    );
  }

  // ── 카테고리 빌더 ──
  List<_Category> _buildCategories(
    BuildContext context,
    bool isAdmin,
    bool isManager,
    bool isNutrition,
    String myDept,
  ) {
    if (isNutrition) {
      return [
        _Category(
          title: context.tr(AppStrings.catNotice),
          icon:  Icons.campaign_rounded,
          color: const Color(0xFF7C5CDB),
          desc:  context.tr(AppStrings.catNoticeDesc),
          items: [
            _SubItem(Icons.campaign_rounded, context.tr(AppStrings.notice),
                () => _push(NoticeListScreen(isAdmin: isAdmin, myDept: myDept))),
            _SubItem(Icons.record_voice_over_rounded,
                context.tr(AppStrings.suggestion),
                () => _push(SuggestionScreen(isAdmin: isAdmin))),
          ],
        ),
        _Category(
          title: context.tr(AppStrings.catMeal),
          icon:  Icons.bar_chart_rounded,
          color: const Color(0xFFFF7A2F),
          desc:  context.tr(AppStrings.catMealDesc),
          items: [
            _SubItem(Icons.menu_book_rounded,
                context.tr(AppStrings.mealMenuWeekly),
                () => _push(MealMenuScreen(canUpload: true))),
            _SubItem(Icons.bar_chart_rounded,
                context.tr(AppStrings.mealReport),
                () => _push(const MealReportScreen())),
          ],
        ),
        _Category(
          title: context.tr(AppStrings.catEtc),
          icon:  Icons.more_horiz_rounded,
          color: const Color(0xFF607D8B),
          desc:  context.tr(AppStrings.catEtcDesc),
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

    return [
      _Category(
        title: context.tr(AppStrings.catMeal),
        icon:  Icons.restaurant_rounded,
        color: const Color(0xFFFF7A2F),
        desc:  context.tr(AppStrings.catMealDesc),
        items: [
          _SubItem(Icons.restaurant_menu_rounded,
              context.tr(AppStrings.mealCheck), _showMealSheet),
          _SubItem(Icons.menu_book_rounded,
              context.tr(AppStrings.mealMenuWeekly),
              () => _push(MealMenuScreen(
                  canUpload: isAdmin ||
                      (_userProfile!['dept_category'] ?? '') == 'NUTRITION'))),
          if (isManager || isNutrition)
            _SubItem(Icons.bar_chart_rounded,
                context.tr(AppStrings.mealReport),
                () => _push(const MealReportScreen())),
        ],
      ),
      _Category(
        title: context.tr(AppStrings.catWork),
        icon:  Icons.punch_clock_rounded,
        color: const Color(0xFF2E6BFF),
        desc:  context.tr(AppStrings.catWorkDesc),
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
        icon:  Icons.campaign_rounded,
        color: const Color(0xFF7C5CDB),
        desc:  context.tr(AppStrings.catNoticeDesc),
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
        icon:  Icons.engineering_rounded,
        color: const Color(0xFFFF8C42),
        desc:  context.tr(AppStrings.catFieldDesc),
        items: [
          _SubItem(Icons.engineering_rounded,
              context.tr(AppStrings.fieldMgmt),
              () => _push(FieldManagementScreen(isAdmin: isAdmin))),
        ],
      ),
      _Category(
        title: context.tr(AppStrings.catDorm),
        icon:  Icons.hotel_rounded,
        color: const Color(0xFF00BCD4),
        desc:  context.tr(AppStrings.catDormDesc),
        items: [
          _SubItem(Icons.hotel_rounded, context.tr(AppStrings.dormitory),
              () => _push(DormManagementScreen(
                  isAdmin: isAdmin, userProfile: _userProfile!))),
          _SubItem(Icons.grid_view_rounded, '호실 배치도',
              () => _push(const DormRoomMapScreen())),
          _SubItem(Icons.cleaning_services_rounded, '베란다 청소',
              () => _push(CleaningScreen(userProfile: _userProfile!))),
        ],
      ),
      if (isAdmin)
        _Category(
          title: context.tr(AppStrings.catAdmin),
          icon:  Icons.admin_panel_settings_rounded,
          color: const Color(0xFFE91E8C),
          desc:  context.tr(AppStrings.catAdminDesc),
          items: [
            _SubItem(Icons.manage_accounts_rounded,
                context.tr(AppStrings.employeeMgmt),
                () => _push(const EmployeeManagementScreen())),
            _SubItem(Icons.file_download_rounded,
                context.tr(AppStrings.excelExport),
                () => _push(const ExcelExportScreen())),
            _SubItem(Icons.bar_chart_rounded, '사용자 활동 현황',
                () => _push(UserActivityScreen())),
            _SubItem(Icons.insights_rounded,
                context.tr(AppStrings.catTrend),
                () => _push(TrendScreen(isAdmin: isAdmin))),
          ],
        ),
      if (isAdmin ||
          ['MANAGEMENT', 'DELIVERY', 'PRODUCTION', 'SALES']
              .contains(_userProfile!['dept_category']))
        _Category(
          title: context.tr(AppStrings.catVehicle),
          icon:  Icons.directions_car_rounded,
          color: const Color(0xFF00BFA5),
          desc:  context.tr(AppStrings.catVehicleDesc),
          badge: isAdmin && _pendingFuelCount > 0 ? _pendingFuelCount : null,
          items: [
            _SubItem(Icons.directions_car_rounded,
                context.tr(AppStrings.catVehicle),
                () => _push(VehicleScreen(
                    userProfile: _userProfile!, isAdmin: isAdmin))),
            _SubItem(Icons.local_gas_station_rounded, '주유 신청',
                () => _push(FuelCardScreen(isAdmin: isAdmin)),
                badge: isAdmin && _pendingFuelCount > 0
                    ? _pendingFuelCount : null),
          ],
        ),
      _Category(
        title: context.tr(AppStrings.catRequest),
        icon:  Icons.assignment_rounded,
        color: const Color(0xFF43A047),
        desc:  context.tr(AppStrings.catRequestDesc),
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
          icon:  Icons.health_and_safety_rounded,
          color: const Color(0xFF00897B),
          desc:  '근로자 건강상담 기록 · PDF 출력',
          items: [
            _SubItem(Icons.health_and_safety_rounded, '건강 리포트',
                () => _push(HealthScreen(isAdmin: isAdmin))),
          ],
        ),
      _Category(
        title: context.tr(AppStrings.catEtc),
        icon:  Icons.more_horiz_rounded,
        color: const Color(0xFF607D8B),
        desc:  context.tr(AppStrings.catEtcDesc),
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
}

// ══════════════════════════════════════════
// 퀵액션 편집 시트
// ══════════════════════════════════════════

class _QuickActionEditSheet extends StatefulWidget {
  final List<_QuickActionDef> available;
  final List<String> currentIds;
  final void Function(List<String>) onSave;

  const _QuickActionEditSheet({
    required this.available,
    required this.currentIds,
    required this.onSave,
  });

  @override
  State<_QuickActionEditSheet> createState() => _QuickActionEditSheetState();
}

class _QuickActionEditSheetState extends State<_QuickActionEditSheet> {
  late List<String> _selectedIds;

  static const _maxCount = 4;
  static const _primary  = Color(0xFF2E6BFF);
  static const _bg       = Color(0xFFF4F6FB);

  @override
  void initState() {
    super.initState();
    _selectedIds = List.from(widget.currentIds);
  }

  void _toggle(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        if (_selectedIds.length > 1) _selectedIds.remove(id);
      } else {
        if (_selectedIds.length < _maxCount) _selectedIds.add(id);
      }
    });
  }

  void _moveUp(int i) {
    if (i == 0) return;
    setState(() {
      final tmp          = _selectedIds[i - 1];
      _selectedIds[i - 1] = _selectedIds[i];
      _selectedIds[i]    = tmp;
    });
  }

  void _moveDown(int i) {
    if (i >= _selectedIds.length - 1) return;
    setState(() {
      final tmp          = _selectedIds[i + 1];
      _selectedIds[i + 1] = _selectedIds[i];
      _selectedIds[i]    = tmp;
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedDefs = _selectedIds
        .map((id) => widget.available.firstWhere((a) => a.id == id,
            orElse: () => widget.available.first))
        .toList();
    final unselected = widget.available
        .where((a) => !_selectedIds.contains(a.id))
        .toList();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28)),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // 핸들
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 16),
            decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2)),
          ),

          // 헤더
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: _primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.tune_rounded,
                    color: _primary, size: 18),
              ),
              const SizedBox(width: 12),
              const Text('빠른 실행 편집',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w900)),
              const Spacer(),
              Text('최대 $_maxCount개',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.black.withOpacity(0.35),
                      fontWeight: FontWeight.w600)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Text('탭해서 추가/제거 · 화살표로 순서 변경',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.black.withOpacity(0.38))),
          ),

          // ── 선택된 항목 ──
          if (selectedDefs.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(children: [
                Text('선택됨 (${_selectedIds.length}/$_maxCount)',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _primary)),
              ]),
            ),
            ...selectedDefs.asMap().entries.map((entry) {
              final i   = entry.key;
              final def = entry.value;
              return Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: def.color.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: def.color.withOpacity(0.25)),
                ),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                        color: def.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10)),
                    child: Icon(def.icon, color: def.color, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(def.labelFn(context),
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: def.color)),
                  ),
                  _arrowBtn(Icons.arrow_upward_rounded,
                      i > 0 ? () => _moveUp(i) : null),
                  const SizedBox(width: 4),
                  _arrowBtn(Icons.arrow_downward_rounded,
                      i < selectedDefs.length - 1
                          ? () => _moveDown(i) : null),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _toggle(def.id),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.remove_rounded,
                          size: 16, color: Colors.redAccent),
                    ),
                  ),
                ]),
              );
            }),
            const SizedBox(height: 4),
            Divider(indent: 16, endIndent: 16,
                color: Colors.black.withOpacity(0.06)),
          ],

          // ── 추가 가능한 항목 ──
          if (unselected.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(children: [
                Text('추가 가능',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.black.withOpacity(0.45))),
                if (_selectedIds.length >= _maxCount) ...[
                  const SizedBox(width: 8),
                  Text('(최대 $_maxCount개)',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.redAccent.withOpacity(0.7),
                          fontWeight: FontWeight.w600)),
                ],
              ]),
            ),
            ...unselected.map((def) {
              final canAdd = _selectedIds.length < _maxCount;
              return GestureDetector(
                onTap: canAdd ? () => _toggle(def.id) : null,
                child: Opacity(
                  opacity: canAdd ? 1.0 : 0.4,
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _bg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: Colors.black.withOpacity(0.06)),
                    ),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                            color: def.color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10)),
                        child: Icon(def.icon, color: def.color, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(def.labelFn(context),
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700)),
                      ),
                      Icon(Icons.add_rounded,
                          size: 18,
                          color: canAdd ? _primary : Colors.grey),
                    ]),
                  ),
                ),
              );
            }),
          ],

          const SizedBox(height: 12),

          // 저장 버튼
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: () {
                  widget.onSave(_selectedIds);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary, elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('저장하기',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900)),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Widget _arrowBtn(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap != null ? 1.0 : 0.25,
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(7)),
          child: Icon(icon, size: 15, color: Colors.black54),
        ),
      ),
    );
  }
}