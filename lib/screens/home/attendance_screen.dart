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

  // GPS 상태 메시지 (사용자에게 진행 상황 표시)
  String? _gpsStatusMsg;

  static const _primary = Color(0xFF2E6BFF);
  static const _success = Color(0xFF00C853);
  static const _warning = Color(0xFFFF9100);
  static const _bg      = Color(0xFFF4F6FB);
  static const _text    = Color(0xFF1A1D2E);
  static const _sub     = Color(0xFF8A93B0);

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
          .from('attendance')
          .select()
          .eq('user_id', user.id)
          .eq('work_date', today)
          .maybeSingle();
      if (mounted) {
        setState(() { _todayAttendance = data; _isLoading = false; });
      }
    } catch (e) {
      debugPrint("출퇴근 로드 실패: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _setGpsMsg(String? msg) {
    if (mounted) setState(() => _gpsStatusMsg = msg);
  }

  Future<bool> _checkGpsLocation() async {
    // ① GPS 서비스 켜져 있는지 확인
    _setGpsMsg(context.tr({
      'ko': '📡 위치 서비스 확인 중...',
      'en': '📡 Checking location service...',
      'vi': '📡 Dang kiem tra dich vu vi tri...',
      'uz': '📡 Joylashuv xizmati tekshirilmoqda...',
      'km': '📡 កំពុងពិនិត្យសេវា GPS...',
    }));

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnackBar(context.tr({
        'ko': 'GPS 서비스가 꺼져 있습니다. 설정에서 위치를 켜주세요.',
        'en': 'GPS is off. Please enable location in settings.',
        'vi': 'GPS tat. Vui long bat vi tri trong cai dat.',
        'uz': 'GPS o\'chiq. Sozlamalarda joylashuvni yoqing.',
        'km': 'GPS បិទ។ សូមបើក GPS ក្នុងការកំណត់។',
      }));
      _setGpsMsg(null);
      return false;
    }

    // ② 권한 확인 및 요청
    _setGpsMsg(context.tr({
      'ko': '🔐 위치 권한 확인 중...',
      'en': '🔐 Checking location permission...',
      'vi': '🔐 Dang kiem tra quyen vi tri...',
      'uz': '🔐 Joylashuv ruxsati tekshirilmoqda...',
      'km': '🔐 កំពុងពិនិត្យសិទ្ធិទីតាំង...',
    }));

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackBar(context.tr({
          'ko': '위치 권한이 거부되었습니다.\nChrome 주소창 자물쇠 → 위치 → 허용',
          'en': 'Location denied.\nChrome address bar lock → Location → Allow',
          'vi': 'Quyen vi tri bi tu choi.\nChrome → Khoa dia chi → Vi tri → Cho phep',
          'uz': 'Ruxsat rad etildi.\nChrome → Qulf → Joylashuv → Ruxsat bering',
          'km': 'សិទ្ធិបានបដិសេធ។\nChrome → សោ → ទីតាំង → អនុញ្ញាត',
        }));
        _setGpsMsg(null);
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // PWA에서는 openAppSettings()가 Chrome 설정으로 이동 안 됨
      // 직접 안내 다이얼로그 표시
      _setGpsMsg(null);
      await _showPermissionGuideDialog();
      return false;
    }

    // ③ 위치 가져오기 (medium → low 순으로 시도)
    _setGpsMsg(context.tr({
      'ko': '📍 현재 위치 확인 중... (최대 15초)',
      'en': '📍 Getting location... (up to 15s)',
      'vi': '📍 Dang lay vi tri... (toi da 15 giay)',
      'uz': '📍 Joylashuv olinmoqda... (15 soniyagacha)',
      'km': '📍 កំពុងទទួល GPS... (រហូតដល់ 15 វិនាទី)',
    }));

    Position? pos;

    // 먼저 medium으로 시도
    try {
      pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 15),
      );
    } catch (_) {
      // 실패 시 low로 재시도 (특정 폰 / PWA 환경)
      _setGpsMsg(context.tr({
        'ko': '📍 GPS 재시도 중...',
        'en': '📍 Retrying GPS...',
        'vi': '📍 Thu lai GPS...',
        'uz': '📍 GPS qayta urinmoqda...',
        'km': '📍 កំពុងសាកម្ដងទៀត...',
      }));
      try {
        pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
          timeLimit: const Duration(seconds: 10),
        );
      } catch (e) {
        debugPrint("GPS 실패: $e");
        _showSnackBar(context.tr({
          'ko': 'GPS 신호를 받을 수 없습니다.\nChrome 설정 → 위치 → 허용 후 다시 시도해주세요.',
          'en': 'Cannot get GPS signal.\nChrome settings → Location → Allow, then retry.',
          'vi': 'Khong the nhan tin hieu GPS.\nCai dat Chrome → Vi tri → Cho phep roi thu lai.',
          'uz': 'GPS signali yo\'q.\nChrome sozlamalari → Joylashuv → Ruxsat, keyin qayta urining.',
          'km': 'មិនអាចទទួល GPS បាន។\nការកំណត់ Chrome → ទីតាំង → អនុញ្ញាត រួចព្យាយាមម្ដងទៀត។',
        }));
        _setGpsMsg(null);
        return false;
      }
    }

    _setGpsMsg(null);

    // ④ 거리 계산
    final dist = Geolocator.distanceBetween(
        pos.latitude, pos.longitude, companyLat, companyLng);

    if (dist <= checkRadius) return true;

    _showSnackBar(context.tr({
      'ko': '회사 반경 밖입니다. (현재 거리: ${dist.toInt()}m)',
      'en': 'Outside company area. (${dist.toInt()}m away)',
      'vi': 'Ngoai khu vuc cong ty. (Cach ${dist.toInt()}m)',
      'uz': 'Kompaniya hududidan tashqarida. (${dist.toInt()}m)',
      'km': 'នៅក្រៅតំបន់ក្រុមហ៊ុន។ (${dist.toInt()}m)',
    }));
    return false;
  }

  // PWA에서 위치 권한 영구 거부 시 안내 다이얼로그
  Future<void> _showPermissionGuideDialog() async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.location_off_rounded, color: Colors.redAccent),
          const SizedBox(width: 8),
          Text(context.tr({
            'ko': '위치 권한 필요',
            'en': 'Location Permission Required',
            'vi': 'Can quyen vi tri',
            'uz': 'Joylashuv ruxsati kerak',
            'km': 'ត្រូវការសិទ្ធិទីតាំង',
          }), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr({
              'ko': 'Chrome 브라우저에서 위치를 허용해주세요:',
              'en': 'Allow location in Chrome browser:',
              'vi': 'Cho phep vi tri trong trinh duyet Chrome:',
              'uz': 'Chrome brauzerda joylashuvga ruxsat bering:',
              'km': 'អនុញ្ញាតទីតាំងនៅក្នុង Chrome:',
            }), style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            _guideStep('1', context.tr({
              'ko': 'Chrome 주소창 왼쪽 자물쇠 🔒 탭',
              'en': 'Tap the lock 🔒 in Chrome address bar',
              'vi': 'Nhan o khoa 🔒 tren thanh dia chi Chrome',
              'uz': 'Chrome manzil satridagi qulf 🔒 ni bosing',
              'km': 'ចុចសោ 🔒 នៅ Chrome',
            })),
            _guideStep('2', context.tr({
              'ko': '사이트 설정 → 위치',
              'en': 'Site settings → Location',
              'vi': 'Cai dat trang web → Vi tri',
              'uz': 'Sayt sozlamalari → Joylashuv',
              'km': 'ការកំណត់គេហទំព័រ → ទីតាំង',
            })),
            _guideStep('3', context.tr({
              'ko': '"허용" 선택 후 다시 시도',
              'en': 'Select "Allow" then retry',
              'vi': 'Chon "Cho phep" roi thu lai',
              'uz': '"Ruxsat" ni tanlang va qayta urining',
              'km': 'ជ្រើស "អនុញ្ញាត" រួចព្យាយាមម្ដងទៀត',
            })),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr(AppStrings.confirm),
                style: const TextStyle(fontWeight: FontWeight.w800)),
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
          child: Center(child: Text(num,
              style: const TextStyle(color: Colors.white, fontSize: 12,
                  fontWeight: FontWeight.w900))),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text,
            style: const TextStyle(fontSize: 13, height: 1.4))),
      ]),
    );
  }

  Future<void> _recordTime(bool isCheckIn) async {
    setState(() { _isSubmitting = true; _gpsStatusMsg = null; });

    final messengerState = ScaffoldMessenger.of(context); // await 전에 캡처
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
        await supabase.from('attendance')
            .update({'check_out': timeStr})
            .eq('id', _todayAttendance!['id']);
      }
      await _fetchAttendance();
      if (mounted) {
        _showSnackBar(context.tr(isCheckIn ? {
          'ko': '정상 출근되었습니다. ✅',
          'en': 'Checked in successfully. ✅',
          'vi': 'Da cham cong vao. ✅',
          'uz': 'Muvaffaqiyatli kirish. ✅',
          'km': 'បានចូលធ្វើការដោយជោគជ័យ។ ✅',
        } : {
          'ko': '정상 퇴근되었습니다. ✅',
          'en': 'Checked out successfully. ✅',
          'vi': 'Da cham cong ra. ✅',
          'uz': 'Muvaffaqiyatli chiqish. ✅',
          'km': 'បានចេញពីការងារដោយជោគជ័យ។ ✅',
        }));
      }
    } catch (e) {
      messengerState.showSnackBar(SnackBar(
        content: Text(context.tr({
          'ko': '기록 중 오류가 발생했습니다.',
          'en': 'An error occurred while recording.',
          'vi': 'Co loi xay ra khi ghi.',
          'uz': 'Yozishda xato yuz berdi.',
          'km': 'មានកំហុសកើតឡើងពេលកត់ត្រា។',
        }), style: const TextStyle(fontWeight: FontWeight.w700)),
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator(color: _primary)));
    }

    final checkIn  = _todayAttendance?['check_in']  ?? '--:--';
    final checkOut = _todayAttendance?['check_out'] ?? '--:--';

    final langCode = context.langCode;
    final now = DateTime.now();
    final dateStr = langCode == 'ko'
        ? DateFormat('yyyy년 MM월 dd일 (E)', 'ko_KR').format(now)
        : DateFormat('EEE, MMM dd yyyy').format(now);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: Text(context.tr(AppStrings.attendance),
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: _text,
        elevation: 0,
        surfaceTintColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFF0F2F8)),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: Column(children: [
            // 날짜 뱃지
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                  color: _primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20)),
              child: Text(dateStr,
                  style: const TextStyle(
                      color: _primary, fontWeight: FontWeight.w800, fontSize: 13)),
            ),
            const SizedBox(height: 16),

            // 실시간 시계
            StreamBuilder(
              stream: Stream.periodic(const Duration(seconds: 1)),
              builder: (_, __) => Text(
                DateFormat('HH:mm:ss').format(DateTime.now()),
                style: const TextStyle(
                    fontSize: 48, fontWeight: FontWeight.w900,
                    letterSpacing: -2, color: _text),
              ),
            ),
            const SizedBox(height: 28),

            // 출근/퇴근 시간
            Row(children: [
              _timeUnit(
                context.tr({'ko': '출근', 'en': 'In', 'vi': 'Vao', 'uz': 'Kirish', 'km': 'ចូល'}),
                checkIn, _success, Icons.login_rounded,
              ),
              const SizedBox(width: 12),
              _timeUnit(
                context.tr({'ko': '퇴근', 'en': 'Out', 'vi': 'Ra', 'uz': 'Chiqish', 'km': 'ចេញ'}),
                checkOut, _warning, Icons.logout_rounded,
              ),
            ]),
            const SizedBox(height: 20),

            // GPS 상태 메시지
            if (_gpsStatusMsg != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _primary),
                  ),
                  const SizedBox(width: 10),
                  Text(_gpsStatusMsg!,
                      style: const TextStyle(
                          fontSize: 12, color: _primary, fontWeight: FontWeight.w700)),
                ]),
              ),
              const SizedBox(height: 12),
            ],

            // 출퇴근 버튼
            if (_isSubmitting && _gpsStatusMsg == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: CircularProgressIndicator(color: _primary),
              )
            else
              Row(children: [
                Expanded(child: _actionBtn(
                  context.tr({'ko': '출근하기', 'en': 'Check In', 'vi': 'Cham vao', 'uz': 'Kirish', 'km': 'ចូលធ្វើការ'}),
                  _todayAttendance == null && !_isSubmitting,
                  _primary,
                  () => _recordTime(true),
                )),
                const SizedBox(width: 12),
                Expanded(child: _actionBtn(
                  context.tr({'ko': '퇴근하기', 'en': 'Check Out', 'vi': 'Cham ra', 'uz': 'Chiqish', 'km': 'ចេញពីការងារ'}),
                  _todayAttendance != null &&
                      _todayAttendance?['check_out'] == null &&
                      !_isSubmitting,
                  _warning,
                  () => _recordTime(false),
                )),
              ]),

            // PWA 위치 안내 (상시 표시)
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.info_outline_rounded, size: 16, color: Colors.amber),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  context.tr({
                    'ko': 'GPS가 안 될 경우: Chrome 주소창 🔒 → 위치 → 허용',
                    'en': 'GPS issue? Chrome 🔒 → Location → Allow',
                    'vi': 'GPS khong hoat dong? Chrome 🔒 → Vi tri → Cho phep',
                    'uz': "GPS ishlamasa: Chrome 🔒 → Joylashuv → Ruxsat",
                    'km': 'GPS មិនដំណើរការ? Chrome 🔒 → ទីតាំង → អនុញ្ញាត',
                  }),
                  style: const TextStyle(
                      fontSize: 11, color: Colors.amber,
                      fontWeight: FontWeight.w700, height: 1.4),
                )),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _timeUnit(String label, String time, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 6),
          Text(time, style: const TextStyle(
              fontSize: 20, fontWeight: FontWeight.w900, color: _text)),
        ]),
      ),
    );
  }

  Widget _actionBtn(String label, bool enabled, Color color, VoidCallback onTap) {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: enabled ? onTap : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFF0F2F8),
          disabledForegroundColor: _sub,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(label,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      ),
    );
  }
}