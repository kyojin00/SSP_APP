part of 'vehicle_screen.dart';

// ══════════════════════════════════════════
// OCR 서비스 (귀환 시 사용)
// ══════════════════════════════════════════

class _OdometerOcr {
  static Future<int?> recognize(Uint8List imageBytes) async {
    try {
      final base64Image = base64Encode(imageBytes);

      // 이미지 포맷 감지
      String mediaType = 'image/jpeg';
      if (imageBytes.length >= 4) {
        if (imageBytes[0] == 0x89 && imageBytes[1] == 0x50) {
          mediaType = 'image/png';
        } else if (imageBytes[0] == 0xFF && imageBytes[1] == 0xD8) {
          mediaType = 'image/jpeg';
        }
      }

      final response = await http.post(
        Uri.parse(
            'https://kvgyxjnozsngtpgleyvo.supabase.co/functions/v1/ocr_mileage'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization':
              'Bearer ${Supabase.instance.client.auth.currentSession?.accessToken ?? ''}',
        },
        body: jsonEncode({
          'imageBase64': base64Image,
          'mediaType': mediaType,
        }),
      );

      debugPrint('[OCR] status: ${response.statusCode}');
      debugPrint('[OCR] body: ${response.body}');

      if (response.statusCode != 200) return null;

      final data    = jsonDecode(response.body);
      final rawText = data['text'] as String? ?? '';

      if (rawText.trim().toUpperCase() == 'UNKNOWN' || rawText.trim().isEmpty) {
        return null;
      }

      final onlyDigits = rawText.replaceAll(RegExp(r'[^0-9]'), '');
      return int.tryParse(onlyDigits);
    } catch (e) {
      debugPrint('[OCR] 실패: $e');
      return null;
    }
  }
}

// ══════════════════════════════════════════
// 카메라 OCR 버튼 (귀환 시트용)
// ══════════════════════════════════════════

class _OcrCameraBtn extends StatefulWidget {
  final TextEditingController mileageCtrl;
  const _OcrCameraBtn({required this.mileageCtrl});

  @override
  State<_OcrCameraBtn> createState() => _OcrCameraBtnState();
}

class _OcrCameraBtnState extends State<_OcrCameraBtn> {
  bool _scanning = false;

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

    if (result != null) {
      widget.mileageCtrl.text = '$result';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('계기판 인식: $result km ✅',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        duration: const Duration(seconds: 2),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('인식 실패. 직접 입력해주세요.',
            style: TextStyle(fontWeight: FontWeight.w700)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.orange,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _scanning ? null : _scan,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF2E6BFF),
          borderRadius: BorderRadius.circular(10),
        ),
        child: _scanning
            ? const SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.camera_alt_rounded, color: Colors.white, size: 15),
                SizedBox(width: 5),
                Text('촬영',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800)),
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

  final _departureCtrl   = TextEditingController(text: '회사');
  final _destinationCtrl = TextEditingController();
  final _purposeCtrl     = TextEditingController();
  final _mileageCtrl     = TextEditingController();

  bool _isLoading      = false;
  bool _mileageLoading = true;
  bool _isFirstRun     = false;

  @override
  void initState() {
    super.initState();
    _loadLastMileage();
  }

  // 이전 도착 계기판 자동 로드
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
        if (lastMileage != null) {
          _mileageCtrl.text = '$lastMileage';
        }
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
    _destinationCtrl.dispose();
    _purposeCtrl.dispose();
    _mileageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_departureCtrl.text.trim().isEmpty ||
        _destinationCtrl.text.trim().isEmpty ||
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
      _destinationCtrl.text.trim(),
      _purposeCtrl.text.trim(),
      mileage,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      padding: EdgeInsets.fromLTRB(22, 22, 22, 16 + bottom),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(28)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _handle(),
        Row(children: [
          _iconBox(Icons.play_arrow_rounded, Colors.green),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('출발 기록',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            Text(widget.vehicle.name,
                style: TextStyle(
                    fontSize: 12, color: Colors.black.withOpacity(0.4))),
          ]),
        ]),
        const SizedBox(height: 20),
        _field(_departureCtrl,   '출발지',   Icons.location_on_rounded, hint: '예: 회사'),
        const SizedBox(height: 12),
        _field(_destinationCtrl, '도착지',   Icons.flag_rounded,        hint: '예: 광양시청'),
        const SizedBox(height: 12),
        _field(_purposeCtrl,     '사용 목적', Icons.description_rounded,  hint: '예: 거래처 방문'),
        const SizedBox(height: 12),

        // ── 출발 전 계기판 (자동 입력) ──
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('출발 전 계기판 (km)',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1D2E))),
          const SizedBox(height: 6),
          Stack(children: [
            TextField(
              controller: _mileageCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                hintText: _isFirstRun ? '첫 운행 - 계기판 수치 입력' : '예: 12345',
                prefixIcon: const Icon(Icons.speed_rounded,
                    size: 18, color: Colors.black38),
                filled: true,
                fillColor: const Color(0xFFF4F6FB),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
              ),
            ),
            if (_mileageLoading)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Center(
                    child: SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFF2E6BFF)),
                    ),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 4),
          if (_mileageLoading)
            Text('이전 기록 불러오는 중...',
                style: TextStyle(
                    fontSize: 11,
                    color: const Color(0xFF2E6BFF).withOpacity(0.7)))
          else if (_isFirstRun)
            Text('첫 운행이에요. 현재 계기판 수치를 직접 입력해주세요.',
                style: TextStyle(
                    fontSize: 11, color: Colors.orange.withOpacity(0.8)))
          else
            Text('📋 이전 도착 계기판에서 자동 입력됐어요. 확인 후 수정 가능해요.',
                style: TextStyle(
                    fontSize: 11, color: Colors.black.withOpacity(0.35))),
        ]),

        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('출발 기록하기',
                style: TextStyle(color: Colors.white,
                    fontSize: 15, fontWeight: FontWeight.w800)),
          ),
        ),
      ]),
    );
  }

  Widget _handle() => Container(
      width: 36, height: 4,
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
          color: Colors.grey[300], borderRadius: BorderRadius.circular(2)));

  Widget _iconBox(IconData icon, Color color) => Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, color: color, size: 22));

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {String? hint}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w700,
          color: Color(0xFF1A1D2E))),
      const SizedBox(height: 6),
      TextField(
        controller: ctrl,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, size: 18, color: Colors.black38),
          filled: true,
          fillColor: const Color(0xFFF4F6FB),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 14),
        ),
      ),
    ]);
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

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      padding: EdgeInsets.fromLTRB(22, 22, 22, 16 + bottom),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(28)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2))),
        Row(children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
                color: const Color(0xFF2E6BFF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.flag_rounded,
                color: Color(0xFF2E6BFF), size: 22),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('귀환 기록',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            Text(widget.vehicle.name,
                style: TextStyle(
                    fontSize: 12, color: Colors.black.withOpacity(0.4))),
          ]),
        ]),
        const SizedBox(height: 20),

        // 출발 정보 요약
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: const Color(0xFFF4F6FB),
              borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            _infoRow('출발지 → 도착지',
                '${widget.log['departure']} → ${widget.log['destination']}'),
            const SizedBox(height: 6),
            _infoRow('목적', widget.log['purpose'] ?? '-'),
            const SizedBox(height: 6),
            _infoRow('출발 전 계기판', '$mileageBefore km'),
          ]),
        ),
        const SizedBox(height: 16),

        // ── 도착 후 계기판 (카메라 + 수동 입력) ──
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('도착 후 계기판 (km)',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1D2E))),
            const Spacer(),
            // 카메라 OCR 버튼
            _OcrCameraBtn(mileageCtrl: _mileageCtrl),
          ]),
          const SizedBox(height: 6),
          TextField(
            controller: _mileageCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              hintText: '예: ${mileageBefore + 10}',
              prefixIcon: const Icon(Icons.speed_rounded,
                  size: 18, color: Colors.black38),
              filled: true,
              fillColor: const Color(0xFFF4F6FB),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 14),
              // 주행거리 실시간 표시
              suffix: _distance != null
                  ? Text('주행 $_distance km',
                      style: const TextStyle(
                          color: Color(0xFF2E6BFF),
                          fontWeight: FontWeight.w800,
                          fontSize: 13))
                  : null,
            ),
          ),
          const SizedBox(height: 4),
          Text('📷 촬영 버튼으로 계기판을 찍거나 직접 입력하세요',
              style: TextStyle(
                  fontSize: 11, color: Colors.black.withOpacity(0.35))),
        ]),

        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E6BFF),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('귀환 기록하기',
                style: TextStyle(color: Colors.white,
                    fontSize: 15, fontWeight: FontWeight.w800)),
          ),
        ),
      ]),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(children: [
      Text(label, style: TextStyle(
          fontSize: 12, color: Colors.black.withOpacity(0.4),
          fontWeight: FontWeight.w600)),
      const SizedBox(width: 8),
      Expanded(child: Text(value,
          textAlign: TextAlign.end,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700))),
    ]);
  }
}