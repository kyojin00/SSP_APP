part of 'vehicle_screen.dart';

// ══════════════════════════════════════════
// 공통 디자인 토큰
// ══════════════════════════════════════════

class _DS {
  // Colors
  static const bg       = Color(0xFFF7F8FC);
  static const surface  = Colors.white;
  static const primary  = Color(0xFF2563EB);
  static const success  = Color(0xFF16A34A);
  static const warn     = Color(0xFFF59E0B);
  static const danger   = Color(0xFFEF4444);
  static const ink      = Color(0xFF0F172A);
  static const inkMid   = Color(0xFF64748B);
  static const inkFaint = Color(0xFFCBD5E1);

  // Radius
  static const r8  = BorderRadius.all(Radius.circular(8));
  static const r12 = BorderRadius.all(Radius.circular(12));
  static const r16 = BorderRadius.all(Radius.circular(16));
  static const r20 = BorderRadius.all(Radius.circular(20));
  static const r24 = BorderRadius.all(Radius.circular(24));

  // Shadow
  static List<BoxShadow> shadow({double blur = 20, double opacity = .06}) => [
    BoxShadow(
      color: const Color(0xFF0F172A).withOpacity(opacity),
      blurRadius: blur,
      offset: const Offset(0, 4),
    )
  ];
}

// ══════════════════════════════════════════
// OCR 서비스
// ══════════════════════════════════════════

class _OdometerOcr {
  static Future<int?> recognize(Uint8List imageBytes) async {
    try {
      final base64Image = base64Encode(imageBytes);

      String mediaType = 'image/jpeg';
      if (imageBytes.length >= 4) {
        if (imageBytes[0] == 0x89 && imageBytes[1] == 0x50) {
          mediaType = 'image/png';
        } else if (imageBytes[0] == 0xFF && imageBytes[1] == 0xD8) {
          mediaType = 'image/jpeg';
        }
      }

      final response = await http.post(
        Uri.parse('https://kvgyxjnozsngtpgleyvo.supabase.co/functions/v1/ocr_mileage'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization':
              'Bearer ${Supabase.instance.client.auth.currentSession?.accessToken ?? ''}',
        },
        body: jsonEncode({'imageBase64': base64Image, 'mediaType': mediaType}),
      );

      if (response.statusCode != 200) return null;

      final data    = jsonDecode(response.body);
      final rawText = data['text'] as String? ?? '';

      if (rawText.trim().toUpperCase() == 'UNKNOWN' || rawText.trim().isEmpty) return null;

      final onlyDigits = rawText.replaceAll(RegExp(r'[^0-9]'), '');
      return int.tryParse(onlyDigits);
    } catch (e) {
      debugPrint('[OCR] 실패: $e');
      return null;
    }
  }
}

// ══════════════════════════════════════════
// OCR 카메라 버튼
// ══════════════════════════════════════════

class _OcrCameraBtn extends StatefulWidget {
  final TextEditingController mileageCtrl;
  const _OcrCameraBtn({required this.mileageCtrl});

  @override
  State<_OcrCameraBtn> createState() => _OcrCameraBtnState();
}

class _OcrCameraBtnState extends State<_OcrCameraBtn>
    with SingleTickerProviderStateMixin {
  bool _scanning = false;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 95,
      maxWidth: 1920,
      maxHeight: 1080,
    );
    if (picked == null) return;

    setState(() => _scanning = true);
    final bytes  = await picked.readAsBytes();
    final result = await _OdometerOcr.recognize(bytes);

    if (!mounted) return;
    setState(() => _scanning = false);

    final messenger = ScaffoldMessenger.of(context);
    if (result != null) {
      widget.mileageCtrl.text = '$result';
      messenger.showSnackBar(_snackBar(
        '계기판 인식: $result km ✅',
        _DS.success,
        Icons.check_circle_rounded,
      ));
    } else {
      messenger.showSnackBar(_snackBar(
        '인식 실패 — 직접 입력해주세요',
        _DS.warn,
        Icons.warning_amber_rounded,
      ));
    }
  }

  SnackBar _snackBar(String msg, Color color, IconData icon) => SnackBar(
    content: Row(children: [
      Icon(icon, color: Colors.white, size: 18),
      const SizedBox(width: 8),
      Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
    ]),
    behavior: SnackBarBehavior.floating,
    backgroundColor: color,
    shape: const RoundedRectangleBorder(borderRadius: _DS.r12),
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    duration: const Duration(seconds: 2),
  );

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _scanning ? null : _scan,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          gradient: _scanning
              ? null
              : const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          color: _scanning ? _DS.inkFaint : null,
          borderRadius: _DS.r12,
          boxShadow: _scanning ? [] : _DS.shadow(blur: 12, opacity: .2),
        ),
        child: _scanning
            ? FadeTransition(
                opacity: _pulse,
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  ),
                  SizedBox(width: 7),
                  Text('인식 중…',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ]),
              )
            : const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.camera_alt_rounded, color: Colors.white, size: 15),
                SizedBox(width: 6),
                Text('촬영',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .2)),
              ]),
      ),
    );
  }
}

// ══════════════════════════════════════════
// 출발 기록 바텀시트
// ══════════════════════════════════════════

class _DepartureSheet extends StatefulWidget {
  final _Vehicle vehicle;
  final Map<String, dynamic> userProfile;
  final Future<void> Function(
      String departure, String destination, String purpose, int mileageBefore) onSubmit;

  const _DepartureSheet({
    required this.vehicle,
    required this.userProfile,
    required this.onSubmit,
  });

  @override
  State<_DepartureSheet> createState() => _DepartureSheetState();
}

class _DepartureSheetState extends State<_DepartureSheet> {
  final supabase = Supabase.instance.client;

  final _departureCtrl = TextEditingController(text: '회사');
  final _purposeCtrl   = TextEditingController();
  final _mileageCtrl   = TextEditingController();
  final List<TextEditingController> _destCtrls = [TextEditingController()];

  bool _isLoading      = false;
  bool _mileageLoading = true;
  bool _isFirstRun     = false;

  @override
  void initState() {
    super.initState();
    _loadLastMileage();
  }

  Future<void> _loadLastMileage() async {
    try {
      final data = await supabase
          .from('vehicle_logs')
          .select('mileage_after')
          .eq('vehicle_id', widget.vehicle.id)
          .eq('status', 'DONE')
          .not('mileage_after', 'is', null)
          .order('created_at', ascending: false)
          .limit(1);

      if (!mounted) return;

      if (data.isNotEmpty) {
        final lastMileage = data.first['mileage_after'] as int?;
        if (lastMileage != null) _mileageCtrl.text = '$lastMileage';
      } else {
        setState(() => _isFirstRun = true);
      }
    } catch (e) {
      debugPrint('최근 계기판 로드 실패: $e');
    } finally {
      if (mounted) setState(() => _mileageLoading = false);
    }
  }

  @override
  void dispose() {
    _departureCtrl.dispose();
    _purposeCtrl.dispose();
    _mileageCtrl.dispose();
    for (final c in _destCtrls) c.dispose();
    super.dispose();
  }

  void _addDest()     => setState(() => _destCtrls.add(TextEditingController()));
  void _removeDest(int i) {
    if (_destCtrls.length <= 1) return;
    _destCtrls[i].dispose();
    setState(() => _destCtrls.removeAt(i));
  }

  String get _destinationText =>
      _destCtrls.map((c) => c.text.trim()).where((s) => s.isNotEmpty).join(' → ');

  Future<void> _submit() async {
    if (_departureCtrl.text.trim().isEmpty ||
        _destinationText.isEmpty ||
        _purposeCtrl.text.trim().isEmpty ||
        _mileageCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('모든 항목을 입력해주세요')));
      return;
    }
    final mileage = int.tryParse(_mileageCtrl.text.trim());
    if (mileage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('계기판 수치를 숫자로 입력해주세요')));
      return;
    }
    setState(() => _isLoading = true);
    Navigator.pop(context);
    await widget.onSubmit(
      _departureCtrl.text.trim(),
      _destinationText,
      _purposeCtrl.text.trim(),
      mileage,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: _DS.r24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── 헤더 그라디언트 배너 ──
          _SheetHeader(
            icon: Icons.play_arrow_rounded,
            iconColor: _DS.success,
            iconBg: const Color(0xFFDCFCE7),
            title: '출발 기록',
            subtitle: widget.vehicle.name,
            accentColor: _DS.success,
          ),

          // ── 폼 본체 ──
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 24 + bottom),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionLabel('출발 정보'),
                  const SizedBox(height: 10),

                  // 출발지 + 목적지 카드
                  Container(
                    decoration: BoxDecoration(
                      color: _DS.bg,
                      borderRadius: _DS.r16,
                      border: Border.all(color: _DS.inkFaint.withOpacity(.5)),
                    ),
                    child: Column(children: [
                      _RouteField(
                        controller: _departureCtrl,
                        icon: Icons.my_location_rounded,
                        hint: '출발지 (예: 회사)',
                        iconColor: _DS.success,
                        isFirst: true,
                      ),
                      _RouteDivider(),
                      // 목적지 다중
                      ...List.generate(_destCtrls.length, (i) {
                        final isLast = i == _destCtrls.length - 1;
                        return Column(children: [
                          _RouteField(
                            controller: _destCtrls[i],
                            icon: isLast && _destCtrls.length > 1
                                ? Icons.flag_rounded
                                : Icons.place_rounded,
                            iconColor: isLast ? _DS.primary : _DS.inkMid,
                            hint: i == 0 ? '목적지 (예: 광양시청)' : '경유지 ${i + 1}',
                            trailing: _destCtrls.length > 1
                                ? _RemoveBtn(() => _removeDest(i))
                                : null,
                          ),
                          if (!isLast) _RouteDivider(isVia: true),
                        ]);
                      }),
                    ]),
                  ),

                  const SizedBox(height: 8),

                  // 경유지 추가 버튼
                  GestureDetector(
                    onTap: _addDest,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: _DS.primary.withOpacity(.25), width: 1.5),
                        borderRadius: _DS.r12,
                        color: _DS.primary.withOpacity(.04),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                                color: _DS.primary.withOpacity(.12),
                                borderRadius: _DS.r8),
                            child: const Icon(Icons.add_rounded,
                                size: 14, color: _DS.primary),
                          ),
                          const SizedBox(width: 8),
                          const Text('경유지 추가',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _DS.primary)),
                        ],
                      ),
                    ),
                  ),

                  // 경로 미리보기
                  if (_destCtrls.length > 1) ...[
                    const SizedBox(height: 10),
                    AnimatedBuilder(
                      animation: Listenable.merge(_destCtrls),
                      builder: (_, __) {
                        final preview = _destinationText;
                        if (preview.isEmpty) return const SizedBox.shrink();
                        return _RoutePreviewChip(preview);
                      },
                    ),
                  ],

                  const SizedBox(height: 20),
                  _SectionLabel('사용 목적'),
                  const SizedBox(height: 10),
                  _InputField(
                    controller: _purposeCtrl,
                    icon: Icons.description_outlined,
                    hint: '예: 거래처 방문',
                  ),

                  const SizedBox(height: 20),
                  Row(children: [
                    _SectionLabel('출발 전 계기판'),
                    const SizedBox(width: 6),
                    Text('km',
                        style: TextStyle(
                            fontSize: 12,
                            color: _DS.inkMid,
                            fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 10),
                  Stack(children: [
                    _InputField(
                      controller: _mileageCtrl,
                      icon: Icons.speed_rounded,
                      hint: _isFirstRun ? '첫 운행 — 현재 계기판 수치 입력' : '예: 12345',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                    if (_mileageLoading)
                      Positioned.fill(
                        child: _LoadingOverlay(),
                      ),
                  ]),
                  const SizedBox(height: 6),
                  _HintChip(
                    icon: _mileageLoading
                        ? Icons.sync_rounded
                        : _isFirstRun
                            ? Icons.info_outline_rounded
                            : Icons.check_circle_outline_rounded,
                    text: _mileageLoading
                        ? '이전 기록 불러오는 중…'
                        : _isFirstRun
                            ? '첫 운행이에요. 현재 계기판 수치를 직접 입력해주세요.'
                            : '이전 도착 계기판에서 자동 입력됐어요. 수정 가능합니다.',
                    color: _mileageLoading
                        ? _DS.primary
                        : _isFirstRun
                            ? _DS.warn
                            : _DS.success,
                  ),

                  const SizedBox(height: 24),
                  _SubmitButton(
                    label: '출발 기록하기',
                    icon: Icons.play_arrow_rounded,
                    color: _DS.success,
                    isLoading: _isLoading,
                    onTap: _submit,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════
// 귀환 기록 바텀시트
// ══════════════════════════════════════════

class _ReturnSheet extends StatefulWidget {
  final _Vehicle vehicle;
  final Map<String, dynamic> log;
  final Future<void> Function(int mileageAfter) onSubmit;

  const _ReturnSheet({
    required this.vehicle,
    required this.log,
    required this.onSubmit,
  });

  @override
  State<_ReturnSheet> createState() => _ReturnSheetState();
}

class _ReturnSheetState extends State<_ReturnSheet> {
  final _mileageCtrl = TextEditingController();
  bool _isLoading = false;
  int? _distance;

  @override
  void initState() {
    super.initState();
    _mileageCtrl.addListener(_calcDistance);
  }

  void _calcDistance() {
    final after  = int.tryParse(_mileageCtrl.text);
    final before = widget.log['mileage_before'] as int?;
    setState(() {
      _distance = (after != null && before != null && after >= before)
          ? after - before
          : null;
    });
  }

  @override
  void dispose() {
    _mileageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final mileage = int.tryParse(_mileageCtrl.text.trim());
    if (mileage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('계기판 수치를 입력해주세요')));
      return;
    }
    final before = widget.log['mileage_before'] as int? ?? 0;
    if (mileage < before) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('도착 후 계기판은 출발 전보다 커야 합니다')));
      return;
    }
    setState(() => _isLoading = true);
    Navigator.pop(context);
    await widget.onSubmit(mileage);
  }

  @override
  Widget build(BuildContext context) {
    final bottom        = MediaQuery.of(context).viewInsets.bottom;
    final mileageBefore = widget.log['mileage_before'] as int? ?? 0;
    final departure     = widget.log['departure']     as String? ?? '-';
    final destination   = widget.log['destination']   as String? ?? '-';
    final purpose       = widget.log['purpose']       as String? ?? '-';

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: _DS.r24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SheetHeader(
            icon: Icons.flag_rounded,
            iconColor: _DS.primary,
            iconBg: const Color(0xFFDBEAFE),
            title: '귀환 기록',
            subtitle: widget.vehicle.name,
            accentColor: _DS.primary,
          ),

          SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 24 + bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 운행 요약 카드 ──
                _TripSummaryCard(
                  departure: departure,
                  destination: destination,
                  purpose: purpose,
                  mileageBefore: mileageBefore,
                ),

                const SizedBox(height: 20),
                Row(children: [
                  _SectionLabel('도착 후 계기판'),
                  const SizedBox(width: 6),
                  Text('km',
                      style: TextStyle(
                          fontSize: 12,
                          color: _DS.inkMid,
                          fontWeight: FontWeight.w600)),
                  const Spacer(),
                  _OcrCameraBtn(mileageCtrl: _mileageCtrl),
                ]),
                const SizedBox(height: 10),

                // 계기판 입력 + 주행거리 뱃지
                Stack(
                  alignment: Alignment.centerRight,
                  children: [
                    _InputField(
                      controller: _mileageCtrl,
                      icon: Icons.speed_rounded,
                      hint: '예: ${mileageBefore + 10}',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      contentPadding: const EdgeInsets.fromLTRB(48, 14, 130, 14),
                    ),
                    if (_distance != null)
                      Positioned(
                        right: 12,
                        child: AnimatedScale(
                          scale: _distance != null ? 1 : 0,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.elasticOut,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                              ),
                              borderRadius: _DS.r8,
                              boxShadow: _DS.shadow(blur: 8, opacity: .2),
                            ),
                            child: Text(
                              '+$_distance km',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: .3),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 6),
                _HintChip(
                  icon: Icons.camera_alt_outlined,
                  text: '촬영 버튼으로 계기판을 찍거나 직접 입력하세요',
                  color: _DS.inkMid,
                ),

                const SizedBox(height: 24),
                _SubmitButton(
                  label: '귀환 기록하기',
                  icon: Icons.flag_rounded,
                  color: _DS.primary,
                  isLoading: _isLoading,
                  onTap: _submit,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════
// 공통 서브 위젯
// ══════════════════════════════════════════

/// 시트 헤더 (그라디언트 배너)
class _SheetHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final Color accentColor;

  const _SheetHeader({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(.04),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        border: Border(
          bottom: BorderSide(color: accentColor.withOpacity(.1), width: 1),
        ),
      ),
      child: Column(children: [
        // 핸들
        Container(
          width: 36, height: 4,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
              color: _DS.inkFaint, borderRadius: _DS.r8),
        ),
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: iconBg, borderRadius: _DS.r12),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: _DS.ink,
                    letterSpacing: -.3)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: const TextStyle(
                    fontSize: 12,
                    color: _DS.inkMid,
                    fontWeight: FontWeight.w600)),
          ]),
        ]),
      ]),
    );
  }
}

/// 섹션 레이블
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: _DS.ink,
        letterSpacing: -.1),
  );
}

/// 경로 입력 필드 (카드 안에서 사용)
class _RouteField extends StatelessWidget {
  final TextEditingController controller;
  final IconData icon;
  final Color iconColor;
  final String hint;
  final bool isFirst;
  final Widget? trailing;

  const _RouteField({
    required this.controller,
    required this.icon,
    required this.iconColor,
    required this.hint,
    this.isFirst = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Padding(
        padding: const EdgeInsets.only(left: 14),
        child: Icon(icon, color: iconColor, size: 18),
      ),
      Expanded(
        child: TextField(
          controller: controller,
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _DS.ink),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
                color: _DS.inkFaint,
                fontSize: 14,
                fontWeight: FontWeight.w500),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 14),
          ),
        ),
      ),
      if (trailing != null)
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: trailing!,
        ),
    ]);
  }
}

/// 경로 구분선
class _RouteDivider extends StatelessWidget {
  final bool isVia;
  const _RouteDivider({this.isVia = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 23),
      child: Row(children: [
        SizedBox(
          height: 18,
          child: VerticalDivider(
              width: 1, thickness: 1.5,
              color: isVia ? _DS.warn.withOpacity(.4) : _DS.inkFaint),
        ),
        if (isVia) ...[
          const SizedBox(width: 8),
          Text('경유',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: _DS.warn.withOpacity(.7))),
        ],
      ]),
    );
  }
}

/// 삭제 버튼
class _RemoveBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _RemoveBtn(this.onTap);

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
          color: _DS.danger.withOpacity(.08),
          borderRadius: _DS.r8),
      child: const Icon(Icons.close_rounded,
          size: 15, color: _DS.danger),
    ),
  );
}

/// 경로 미리보기 칩
class _RoutePreviewChip extends StatelessWidget {
  final String text;
  const _RoutePreviewChip(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _DS.success.withOpacity(.06),
        borderRadius: _DS.r12,
        border: Border.all(color: _DS.success.withOpacity(.2)),
      ),
      child: Row(children: [
        Icon(Icons.route_rounded, size: 15, color: _DS.success.withOpacity(.8)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _DS.success.withOpacity(.9))),
        ),
      ]),
    );
  }
}

/// 일반 입력 필드
class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final IconData icon;
  final String hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final EdgeInsets? contentPadding;

  const _InputField({
    required this.controller,
    required this.icon,
    required this.hint,
    this.keyboardType,
    this.inputFormatters,
    this.contentPadding,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: _DS.ink),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
            color: _DS.inkFaint,
            fontSize: 14,
            fontWeight: FontWeight.w500),
        prefixIcon: Icon(icon, size: 18, color: _DS.inkMid),
        filled: true,
        fillColor: _DS.bg,
        border: OutlineInputBorder(
            borderRadius: _DS.r12,
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: _DS.r12,
            borderSide: BorderSide(
                color: _DS.inkFaint.withOpacity(.6), width: 1)),
        focusedBorder: OutlineInputBorder(
            borderRadius: _DS.r12,
            borderSide: const BorderSide(color: _DS.primary, width: 1.5)),
        contentPadding: contentPadding ??
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}

/// 로딩 오버레이
class _LoadingOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
        color: Colors.white.withOpacity(.75),
        borderRadius: _DS.r12),
    child: const Center(
      child: SizedBox(
          width: 16, height: 16,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: _DS.primary)),
    ),
  );
}

/// 힌트 칩
class _HintChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _HintChip({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 13, color: color.withOpacity(.7)),
    const SizedBox(width: 5),
    Expanded(
      child: Text(text,
          style: TextStyle(
              fontSize: 11,
              color: color.withOpacity(.8),
              fontWeight: FontWeight.w600)),
    ),
  ]);
}

/// 운행 요약 카드 (귀환 시트용)
class _TripSummaryCard extends StatelessWidget {
  final String departure;
  final String destination;
  final String purpose;
  final int mileageBefore;

  const _TripSummaryCard({
    required this.departure,
    required this.destination,
    required this.purpose,
    required this.mileageBefore,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _DS.bg,
        borderRadius: _DS.r16,
        border: Border.all(color: _DS.inkFaint.withOpacity(.5)),
      ),
      child: Column(children: [
        // 경로 시각화
        Row(children: [
          _dot(_DS.success),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(height: 1.5, color: _DS.inkFaint.withOpacity(.6)),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: _DS.r8,
                    border: Border.all(color: _DS.inkFaint.withOpacity(.6)),
                  ),
                  child: Text(purpose,
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _DS.inkMid)),
                ),
              ],
            ),
          ),
          _dot(_DS.primary),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: Text(departure,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _DS.ink)),
          ),
          Expanded(
            child: Text(destination,
                textAlign: TextAlign.end,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _DS.ink)),
          ),
        ]),
        const SizedBox(height: 12),
        Container(
          height: 1,
          color: _DS.inkFaint.withOpacity(.4),
        ),
        const SizedBox(height: 12),
        Row(children: [
          const Icon(Icons.speed_rounded, size: 14, color: _DS.inkMid),
          const SizedBox(width: 6),
          const Text('출발 전 계기판',
              style: TextStyle(
                  fontSize: 12,
                  color: _DS.inkMid,
                  fontWeight: FontWeight.w600)),
          const Spacer(),
          Text('$mileageBefore km',
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: _DS.ink)),
        ]),
      ]),
    );
  }

  Widget _dot(Color color) => Container(
    width: 10, height: 10,
    decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(
            color: color.withOpacity(.4),
            blurRadius: 6, spreadRadius: 1)]),
  );
}

/// 제출 버튼
class _SubmitButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isLoading;
  final VoidCallback onTap;

  const _SubmitButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: isLoading
              ? null
              : LinearGradient(
                  colors: [color, Color.lerp(color, Colors.black, .12)!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          color: isLoading ? _DS.inkFaint : null,
          borderRadius: _DS.r16,
          boxShadow: isLoading ? [] : _DS.shadow(blur: 16, opacity: .2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
            else ...[
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.2)),
            ],
          ],
        ),
      ),
    );
  }
}