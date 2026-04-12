import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'app_strings.dart';
import 'lang_context.dart';

class AttendanceScreen extends StatefulWidget {
  final Map<String, dynamic> userProfile;
  const AttendanceScreen({Key? key, required this.userProfile}) : super(key: key);

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final supabase = Supabase.instance.client;

  bool _isLoading    = true;
  bool _isSubmitting = false;
  Map<String, dynamic>? _todayAttendance;
  String? _gpsStatusMsg;

  static const _primary  = Color(0xFF2E6BFF);
  static const _lighter  = Color(0xFF6B9FFF);
  static const _success  = Color(0xFF00C853);
  static const _warning  = Color(0xFFFF9100);
  static const _bg       = Color(0xFFF4F6FB);
  static const _text     = Color(0xFF1A1D2E);
  static const _sub      = Color(0xFF8A93B0);

  static const double companyLat  = 34.886365;
  static const double companyLng  = 127.600158;
  static const double checkRadius = 800.0;

  @override
  void initState() {
    super.initState();
    _fetchAttendance();
  }

  Future<void> _fetchAttendance() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    try {
      final data = await supabase
          .from('attendance').select()
          .eq('user_id', user.id).eq('work_date', today)
          .maybeSingle();
      if (mounted) setState(() { _todayAttendance = data; _isLoading = false; });
    } catch (e) {
      debugPrint("출퇴근 로드 실패: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _setGpsMsg(String? msg) {
    if (mounted) setState(() => _gpsStatusMsg = msg);
  }

  Future<bool> _checkGpsLocation() async {
    _setGpsMsg(context.tr({'ko': '📡 위치 서비스 확인 중...', 'en': '📡 Checking location service...', 'vi': '📡 Dang kiem tra dich vu vi tri...', 'uz': '📡 Joylashuv xizmati tekshirilmoqda...', 'km': '📡 កំពុងពិនិត្យសេវា GPS...'}));
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnackBar(context.tr({'ko': 'GPS 서비스가 꺼져 있습니다. 설정에서 위치를 켜주세요.', 'en': 'GPS is off. Please enable location in settings.', 'vi': 'GPS tat. Vui long bat vi tri trong cai dat.', 'uz': 'GPS o\'chiq. Sozlamalarda joylashuvni yoqing.', 'km': 'GPS បិទ។ សូមបើក GPS ក្នុងការកំណត់។'}));
      _setGpsMsg(null);
      return false;
    }

    _setGpsMsg(context.tr({'ko': '🔐 위치 권한 확인 중...', 'en': '🔐 Checking location permission...', 'vi': '🔐 Dang kiem tra quyen vi tri...', 'uz': '🔐 Joylashuv ruxsati tekshirilmoqda...', 'km': '🔐 កំពុងពិនិត្យសិទ្ធិទីតាំង...'}));
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackBar(context.tr({'ko': '위치 권한이 거부되었습니다.\nChrome 주소창 자물쇠 → 위치 → 허용', 'en': 'Location denied.\nChrome address bar lock → Location → Allow', 'vi': 'Quyen vi tri bi tu choi.\nChrome → Khoa dia chi → Vi tri → Cho phep', 'uz': 'Ruxsat rad etildi.\nChrome → Qulf → Joylashuv → Ruxsat bering', 'km': 'សិទ្ធិបានបដិសេធ។\nChrome → សោ → ទីតាំង → អនុញ្ញាត'}));
        _setGpsMsg(null);
        return false;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      _setGpsMsg(null);
      await _showPermissionGuideDialog();
      return false;
    }

    _setGpsMsg(context.tr({'ko': '📍 현재 위치 확인 중... (최대 15초)', 'en': '📍 Getting location... (up to 15s)', 'vi': '📍 Dang lay vi tri... (toi da 15 giay)', 'uz': '📍 Joylashuv olinmoqda... (15 soniyagacha)', 'km': '📍 កំពុងទទួល GPS... (រហូតដល់ 15 វិនាទី)'}));

    Position? pos;
    try {
      pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium, timeLimit: const Duration(seconds: 15));
    } catch (_) {
      _setGpsMsg(context.tr({'ko': '📍 GPS 재시도 중...', 'en': '📍 Retrying GPS...', 'vi': '📍 Thu lai GPS...', 'uz': '📍 GPS qayta urinmoqda...', 'km': '📍 កំពុងសាកម្ដងទៀត...'}));
      try {
        pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low, timeLimit: const Duration(seconds: 10));
      } catch (e) {
        debugPrint("GPS 실패: $e");
        _showSnackBar(context.tr({'ko': 'GPS 신호를 받을 수 없습니다.\nChrome 설정 → 위치 → 허용 후 다시 시도해주세요.', 'en': 'Cannot get GPS signal.\nChrome settings → Location → Allow, then retry.', 'vi': 'Khong the nhan tin hieu GPS.\nCai dat Chrome → Vi tri → Cho phep roi thu lai.', 'uz': 'GPS signali yo\'q.\nChrome sozlamalari → Joylashuv → Ruxsat, keyin qayta urining.', 'km': 'មិនអាចទទួល GPS បាន។\nការកំណត់ Chrome → ទីតាំង → អនុញ្ញាត រួចព្យាយាមម្ដងទៀត។'}));
        _setGpsMsg(null);
        return false;
      }
    }
    _setGpsMsg(null);

    final dist = Geolocator.distanceBetween(pos.latitude, pos.longitude, companyLat, companyLng);
    if (dist <= checkRadius) return true;
    _showSnackBar(context.tr({'ko': '회사 반경 밖입니다. (현재 거리: ${dist.toInt()}m)', 'en': 'Outside company area. (${dist.toInt()}m away)', 'vi': 'Ngoai khu vuc cong ty. (Cach ${dist.toInt()}m)', 'uz': 'Kompaniya hududidan tashqarida. (${dist.toInt()}m)', 'km': 'នៅក្រៅតំបន់ក្រុមហ៊ុន។ (${dist.toInt()}m)'}));
    return false;
  }

  Future<void> _showPermissionGuideDialog() async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.location_off_rounded, color: Colors.redAccent),
          const SizedBox(width: 8),
          Text(context.tr({'ko': '위치 권한 필요', 'en': 'Location Permission Required', 'vi': 'Can quyen vi tri', 'uz': 'Joylashuv ruxsati kerak', 'km': 'ត្រូវការសិទ្ធិទីតាំង'}), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(context.tr({'ko': 'Chrome 브라우저에서 위치를 허용해주세요:', 'en': 'Allow location in Chrome browser:', 'vi': 'Cho phep vi tri trong trinh duyet Chrome:', 'uz': 'Chrome brauzerda joylashuvga ruxsat bering:', 'km': 'អនុញ្ញាតទីតាំងនៅក្នុង Chrome:'}), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _guideStep('1', context.tr({'ko': 'Chrome 주소창 왼쪽 자물쇠 🔒 탭', 'en': 'Tap the lock 🔒 in Chrome address bar', 'vi': 'Nhan o khoa 🔒 tren thanh dia chi Chrome', 'uz': 'Chrome manzil satridagi qulf 🔒 ni bosing', 'km': 'ចុចសោ 🔒 នៅ Chrome'})),
          _guideStep('2', context.tr({'ko': '사이트 설정 → 위치', 'en': 'Site settings → Location', 'vi': 'Cai dat trang web → Vi tri', 'uz': 'Sayt sozlamalari → Joylashuv', 'km': 'ការកំណត់គេហទំព័រ → ទីតាំង'})),
          _guideStep('3', context.tr({'ko': '"허용" 선택 후 다시 시도', 'en': 'Select "Allow" then retry', 'vi': 'Chon "Cho phep" roi thu lai', 'uz': '"Ruxsat" ni tanlang va qayta urining', 'km': 'ជ្រើស "អនុញ្ញាត" រួចព្យាយាមម្ដងទៀត'})),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr(AppStrings.confirm), style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _guideStep(String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 22, height: 22,
          decoration: const BoxDecoration(color: _primary, shape: BoxShape.circle),
          child: Center(child: Text(num, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900))),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13, height: 1.4))),
      ]),
    );
  }

  Future<void> _recordTime(bool isCheckIn) async {
    setState(() { _isSubmitting = true; _gpsStatusMsg = null; });
    final messengerState = ScaffoldMessenger.of(context);
    final inRange = await _checkGpsLocation();
    if (!inRange) {
      if (mounted) setState(() => _isSubmitting = false);
      return;
    }
    final user    = supabase.auth.currentUser;
    final now     = DateTime.now();
    final timeStr = DateFormat('HH:mm:ss').format(now);
    try {
      if (isCheckIn) {
        await supabase.from('attendance').insert({
          'user_id':       user!.id,
          'full_name':     widget.userProfile['full_name'],
          'dept_category': widget.userProfile['dept_category'],
          'work_date':     DateFormat('yyyy-MM-dd').format(now),
          'check_in':      timeStr,
        });
      } else {
        await supabase.from('attendance').update({'check_out': timeStr}).eq('id', _todayAttendance!['id']);
      }
      await _fetchAttendance();
      if (mounted) {
        _showSnackBar(context.tr(isCheckIn
          ? {'ko': '정상 출근되었습니다. ✅', 'en': 'Checked in successfully. ✅', 'vi': 'Da cham cong vao. ✅', 'uz': 'Muvaffaqiyatli kirish. ✅', 'km': 'បានចូលធ្វើការដោយជោគជ័យ។ ✅'}
          : {'ko': '정상 퇴근되었습니다. ✅', 'en': 'Checked out successfully. ✅', 'vi': 'Da cham cong ra. ✅', 'uz': 'Muvaffaqiyatli chiqish. ✅', 'km': 'បានចេញពីការងារដោយជោគជ័យ។ ✅'}));
      }
    } catch (e) {
      messengerState.showSnackBar(SnackBar(
        content: Text(context.tr({'ko': '기록 중 오류가 발생했습니다.', 'en': 'An error occurred while recording.', 'vi': 'Co loi xay ra khi ghi.', 'uz': 'Yozishda xato yuz berdi.', 'km': 'មានកំហុសកើតឡើងពេលកត់ត្រា។'}), style: const TextStyle(fontWeight: FontWeight.w700)),
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      duration: const Duration(seconds: 4),
    ));
  }

  // ══════════════════════════════════════════
  // Build
  // ══════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
          backgroundColor: _bg,
          body: Center(child: CircularProgressIndicator(color: _primary)));
    }

    final checkIn  = _todayAttendance?['check_in']  ?? '--:--';
    final checkOut = _todayAttendance?['check_out'] ?? '--:--';
    final hasCheckIn  = _todayAttendance != null;
    final hasCheckOut = _todayAttendance?['check_out'] != null;

    final langCode = context.langCode;
    final now      = DateTime.now();
    final dateStr  = langCode == 'ko'
        ? DateFormat('yyyy년 MM월 dd일 (E)', 'ko_KR').format(now)
        : DateFormat('EEE, MMM dd yyyy').format(now);
    final name = widget.userProfile['full_name'] ?? '';

    return Scaffold(
      backgroundColor: _bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── 그라디언트 헤더 (시계 포함)
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            title: Text(
              context.tr(AppStrings.attendance),
              style: const TextStyle(
                  fontWeight: FontWeight.w900, fontSize: 17, color: Colors.white),
            ),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1229A8), _primary, _lighter],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(children: [
                  // 배경 장식 원
                  Positioned(
                    right: -50, top: -50,
                    child: Container(width: 200, height: 200,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.07))),
                  ),
                  Positioned(
                    left: -30, bottom: -40,
                    child: Container(width: 150, height: 150,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.05))),
                  ),
                  // 본문
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 88, 22, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 날짜 + 이름
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withOpacity(0.25)),
                            ),
                            child: Text(dateStr,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                          const Spacer(),
                          Text('$name님',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.75),
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                        ]),
                        const SizedBox(height: 12),
                        // 실시간 시계
                        StreamBuilder(
                          stream: Stream.periodic(const Duration(seconds: 1)),
                          builder: (_, __) => Text(
                            DateFormat('HH:mm:ss').format(DateTime.now()),
                            style: const TextStyle(
                              fontSize: 50,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -2,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
          ),

          // ── 본문
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 48),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ── 출근/퇴근 시간 카드
                Row(children: [
                  Expanded(child: _TimeCard(
                    label: context.tr({'ko': '출근', 'en': 'Check In', 'vi': 'Vao', 'uz': 'Kirish', 'km': 'ចូល'}),
                    time: checkIn,
                    icon: Icons.login_rounded,
                    color: _success,
                    lighter: const Color(0xFF69F0AE),
                    isDone: hasCheckIn,
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _TimeCard(
                    label: context.tr({'ko': '퇴근', 'en': 'Check Out', 'vi': 'Ra', 'uz': 'Chiqish', 'km': 'ចេញ'}),
                    time: checkOut,
                    icon: Icons.logout_rounded,
                    color: _warning,
                    lighter: const Color(0xFFFFCC80),
                    isDone: hasCheckOut,
                  )),
                ]),

                const SizedBox(height: 16),

                // ── GPS 상태 메시지
                if (_gpsStatusMsg != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    decoration: BoxDecoration(
                      color: _primary.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _primary.withOpacity(0.2)),
                    ),
                    child: Row(children: [
                      const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: _primary)),
                      const SizedBox(width: 12),
                      Expanded(child: Text(_gpsStatusMsg!,
                          style: const TextStyle(fontSize: 13, color: _primary, fontWeight: FontWeight.w700))),
                    ]),
                  ),
                  const SizedBox(height: 12),
                ],

                // ── 출퇴근 버튼 (로딩 중)
                if (_isSubmitting && _gpsStatusMsg == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator(color: _primary)),
                  )
                else ...[
                  // 출근하기
                  _ActionBtn(
                    label: context.tr({'ko': '출근하기', 'en': 'Check In', 'vi': 'Cham vao', 'uz': 'Kirish', 'km': 'ចូលធ្វើការ'}),
                    icon: Icons.login_rounded,
                    color: _primary,
                    lighter: _lighter,
                    enabled: !hasCheckIn && !_isSubmitting,
                    doneLabel: hasCheckIn ? '출근 완료 ✓' : null,
                    onTap: () => _recordTime(true),
                  ),
                  const SizedBox(height: 12),
                  // 퇴근하기
                  _ActionBtn(
                    label: context.tr({'ko': '퇴근하기', 'en': 'Check Out', 'vi': 'Cham ra', 'uz': 'Chiqish', 'km': 'ចេញពីការងារ'}),
                    icon: Icons.logout_rounded,
                    color: _warning,
                    lighter: const Color(0xFFFFCC80),
                    enabled: hasCheckIn && !hasCheckOut && !_isSubmitting,
                    doneLabel: hasCheckOut ? '퇴근 완료 ✓' : null,
                    onTap: () => _recordTime(false),
                  ),
                ],

                const SizedBox(height: 16),

                // ── GPS 안내
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.amber.withOpacity(0.3)),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.info_outline_rounded, size: 15, color: Colors.amber),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(
                      context.tr({'ko': 'GPS가 안 될 경우: Chrome 주소창 🔒 → 위치 → 허용', 'en': 'GPS issue? Chrome 🔒 → Location → Allow', 'vi': 'GPS khong hoat dong? Chrome 🔒 → Vi tri → Cho phep', 'uz': 'GPS ishlamasa: Chrome 🔒 → Joylashuv → Ruxsat', 'km': 'GPS មិនដំណើរការ? Chrome 🔒 → ទីតាំង → អនុញ្ញាត'}),
                      style: const TextStyle(fontSize: 12, color: Colors.amber, fontWeight: FontWeight.w700, height: 1.4),
                    )),
                  ]),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════
// 출근/퇴근 시간 카드
// ══════════════════════════════════════════

class _TimeCard extends StatelessWidget {
  final String label, time;
  final IconData icon;
  final Color color, lighter;
  final bool isDone;

  const _TimeCard({
    required this.label,
    required this.time,
    required this.icon,
    required this.color,
    required this.lighter,
    required this.isDone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDone ? color.withOpacity(0.18) : Colors.black.withOpacity(0.05),
            blurRadius: 14, offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(children: [
        // 그라디언트 원형 아이콘
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isDone
                ? LinearGradient(colors: [lighter, color], begin: Alignment.topLeft, end: Alignment.bottomRight)
                : null,
            color: isDone ? null : Colors.grey.withOpacity(0.08),
          ),
          child: Icon(icon,
              color: isDone ? Colors.white : Colors.grey[400], size: 20),
        ),
        const SizedBox(height: 10),
        Text(label, style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700,
            color: isDone ? color : const Color(0xFF8A93B0))),
        const SizedBox(height: 5),
        Text(time, style: TextStyle(
            fontSize: 22, fontWeight: FontWeight.w900,
            color: isDone ? const Color(0xFF1A1D2E) : const Color(0xFFCDD3E0),
            letterSpacing: -0.5)),
      ]),
    );
  }
}

// ══════════════════════════════════════════
// 출근하기 / 퇴근하기 버튼
// ══════════════════════════════════════════

class _ActionBtn extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color, lighter;
  final bool enabled;
  final String? doneLabel;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.lighter,
    required this.enabled,
    this.doneLabel,
    required this.onTap,
  });

  @override
  State<_ActionBtn> createState() => _ActionBtnState();
}

class _ActionBtnState extends State<_ActionBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDone = widget.doneLabel != null;

    return GestureDetector(
      onTapDown:   widget.enabled ? (_) => setState(() => _pressed = true)  : null,
      onTapUp:     widget.enabled ? (_) { setState(() => _pressed = false); widget.onTap(); } : null,
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 62,
          decoration: BoxDecoration(
            gradient: widget.enabled
                ? LinearGradient(
                    colors: [widget.lighter, widget.color],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: widget.enabled ? null : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: widget.enabled
                ? null
                : Border.all(color: Colors.grey.withOpacity(0.15)),
            boxShadow: widget.enabled && !_pressed
                ? [BoxShadow(
                    color: widget.color.withOpacity(0.35),
                    blurRadius: 14, offset: const Offset(0, 6))]
                : [],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: widget.enabled
                    ? Colors.white.withOpacity(0.22)
                    : isDone
                        ? widget.color.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isDone ? Icons.check_circle_rounded : widget.icon,
                color: widget.enabled
                    ? Colors.white
                    : isDone ? widget.color : Colors.grey[400],
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              isDone ? widget.doneLabel! : widget.label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: widget.enabled
                    ? Colors.white
                    : isDone ? widget.color : Colors.grey[400],
              ),
            ),
          ]),
        ),
      ),
    );
  } 
}