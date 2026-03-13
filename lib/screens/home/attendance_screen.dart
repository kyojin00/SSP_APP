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

  Future<bool> _checkGpsLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnackBar(context.tr({
        'ko': 'GPS 서비스가 꺼져 있습니다.',
        'en': 'GPS service is disabled.',
        'vi': 'Dich vu GPS bi tat.',
        'uz': 'GPS xizmati o\'chiq.',
        'km': 'សេវា GPS បានបិទ។',
      }));
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackBar(context.tr({
          'ko': '위치 권한이 거부되었습니다.',
          'en': 'Location permission denied.',
          'vi': 'Quyen vi tri bi tu choi.',
          'uz': 'Joylashuv ruxsati rad etildi.',
          'km': 'សិទ្ធិទីតាំងត្រូវបានបដិសេធ។',
        }));
        return false;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      _showSnackBar(context.tr({
        'ko': '위치 권한을 설정에서 허용해주세요.',
        'en': 'Please allow location in settings.',
        'vi': 'Vui long cho phep vi tri trong cai dat.',
        'uz': 'Sozlamalarda joylashuvga ruxsat bering.',
        'km': 'សូមអនុញ្ញាតទីតាំងនៅក្នុងការកំណត់។',
      }));
      return false;
    }

    final pos  = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
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

  Future<void> _recordTime(bool isCheckIn) async {
    setState(() => _isSubmitting = true);
    final inRange = await _checkGpsLocation();
    if (!inRange) { setState(() => _isSubmitting = false); return; }

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
    } catch (e) {
      _showSnackBar(context.tr({
        'ko': '기록 중 오류가 발생했습니다.',
        'en': 'An error occurred while recording.',
        'vi': 'Co loi xay ra khi ghi.',
        'uz': 'Yozishda xato yuz berdi.',
        'km': 'មានកំហុសកើតឡើងពេលកត់ត្រា។',
      }));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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

    // 날짜 표시: 언어별 포맷
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
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 8))
            ],
          ),
          child: Column(children: [
            // 날짜 뱃지
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                  color: _primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20)),
              child: Text(
                dateStr,
                style: const TextStyle(
                    color: _primary, fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ),
            const SizedBox(height: 16),

            // 실시간 시계
            StreamBuilder(
              stream: Stream.periodic(const Duration(seconds: 1)),
              builder: (_, __) => Text(
                DateFormat('HH:mm:ss').format(DateTime.now()),
                style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -2,
                    color: _text),
              ),
            ),
            const SizedBox(height: 28),

            // 출근/퇴근 시간 표시
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

            // 출퇴근 버튼
            if (_isSubmitting)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: CircularProgressIndicator(color: _primary),
              )
            else
              Row(children: [
                Expanded(child: _actionBtn(
                  context.tr({'ko': '출근하기', 'en': 'Check In', 'vi': 'Cham vao', 'uz': 'Kirish', 'km': 'ចូលធ្វើការ'}),
                  _todayAttendance == null,
                  _primary,
                  () => _recordTime(true),
                )),
                const SizedBox(width: 12),
                Expanded(child: _actionBtn(
                  context.tr({'ko': '퇴근하기', 'en': 'Check Out', 'vi': 'Cham ra', 'uz': 'Chiqish', 'km': 'ចេញពីការងារ'}),
                  _todayAttendance != null && _todayAttendance?['check_out'] == null,
                  _warning,
                  () => _recordTime(false),
                )),
              ]),
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
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 11, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 6),
          Text(time,
              style: const TextStyle(
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