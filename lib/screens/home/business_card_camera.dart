// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:convert';
import 'dart:typed_data';
// ignore: undefined_prefixed_name
import 'dart:ui_web' as ui;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'business_card_screen.dart';

// ── 전역 video element (viewFactory 1회 등록 제한 우회)
html.VideoElement? _globalCameraVideo;

// ══════════════════════════════════════════
// 카메라 오버레이 화면
// ══════════════════════════════════════════
class BizCardCameraScreen extends StatefulWidget {
  const BizCardCameraScreen({Key? key}) : super(key: key);
  @override
  State<BizCardCameraScreen> createState() => _BizCardCameraScreenState();
}

class _BizCardCameraScreenState extends State<BizCardCameraScreen> {
  bool _cameraReady = false;
  bool _capturing   = false;

  static const _viewType       = 'biz-card-camera';
  static bool  _viewRegistered = false;

  @override
  void initState() { super.initState(); _startCamera(); }

  Future<void> _startCamera() async {
    try {
      final stream = await html.window.navigator.mediaDevices!.getUserMedia({
        'video': {'facingMode': 'environment',
          'width': {'ideal': 1280}, 'height': {'ideal': 720}},
      });
      _globalCameraVideo?.srcObject?.getTracks().forEach((t) => t.stop());
      _globalCameraVideo = html.VideoElement()
        ..srcObject = stream
        ..autoplay  = true
        ..muted     = true
        ..setAttribute('playsinline', 'true')
        ..style.width     = '100%'
        ..style.height    = '100%'
        ..style.objectFit = 'cover';

      if (!_viewRegistered) {
        // ignore: undefined_prefixed_name
        ui.platformViewRegistry.registerViewFactory(
            _viewType, (_) => _globalCameraVideo!);
        _viewRegistered = true;
      }
      _globalCameraVideo!.play();
      await Future.any([
        _globalCameraVideo!.onLoadedData.first,
        Future.delayed(const Duration(seconds: 3)),
      ]);
      if (mounted) setState(() => _cameraReady = true);
    } catch (e) {
      debugPrint('카메라 실패: $e');
      if (mounted) setState(() => _cameraReady = false);
    }
  }

  @override
  void dispose() {
    _globalCameraVideo?.srcObject?.getTracks().forEach((t) => t.stop());
    _globalCameraVideo = null;
    super.dispose();
  }

  Future<void> _capture(BuildContext ctx) async {
    if (_globalCameraVideo == null || _capturing) return;
    setState(() => _capturing = true);
    try {
      final vw = _globalCameraVideo!.videoWidth  > 0 ? _globalCameraVideo!.videoWidth  : 1280;
      final vh = _globalCameraVideo!.videoHeight > 0 ? _globalCameraVideo!.videoHeight : 720;

      final screenW = html.window.innerWidth?.toDouble()  ?? 390;
      final screenH = html.window.innerHeight?.toDouble() ?? 844;
      final frameW  = screenW * 0.88;
      final frameH  = frameW  * 0.58;
      final frameL  = (screenW - frameW) / 2;
      final frameT  = (screenH - frameH) / 2;

      final scaleX = vw / screenW;
      final scaleY = vh / screenH;
      final scale  = scaleX > scaleY ? scaleX : scaleY;
      final offX   = (vw - screenW * scale) / 2;
      final offY   = (vh - screenH * scale) / 2;

      final cropX = (frameL * scale + offX).round();
      final cropY = (frameT * scale + offY).round();
      final cropW = (frameW * scale).round();
      final cropH = (frameH * scale).round();

      final canvas = html.CanvasElement(width: cropW, height: cropH);
      canvas.context2D.drawImageScaledFromSource(
          _globalCameraVideo!, cropX, cropY, cropW, cropH, 0, 0, cropW, cropH);

      final dataUrl = canvas.toDataUrl('image/jpeg', 0.95);
      final b64     = dataUrl.split(',').last;
      final bytes   = base64Decode(b64);

      if (ctx.mounted) {
        Navigator.pop(ctx, {'base64': b64, 'mimeType': 'image/jpeg', 'bytes': bytes});
      }
    } catch (e) {
      debugPrint('캡처 실패: $e');
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _gallery(BuildContext ctx) async {
    final input = html.FileUploadInputElement()..accept = 'image/*';
    input.click();
    await input.onChange.first;
    if (input.files == null || input.files!.isEmpty) return;
    final file   = input.files![0];
    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    await reader.onLoad.first;
    final bytes = Uint8List.fromList(reader.result as List<int>);
    final b64   = base64Encode(bytes);
    final mime  = file.type.isNotEmpty ? file.type : 'image/jpeg';
    if (ctx.mounted) {
      Navigator.pop(ctx, {'base64': b64, 'mimeType': mime, 'bytes': bytes});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        Positioned.fill(child: _cameraReady
            ? const HtmlElementView(viewType: _viewType)
            : const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 14),
                Text('카메라 준비 중...', style: TextStyle(color: Colors.white, fontSize: 13)),
              ]))),
        // 명함 프레임
        const Center(child: BizCardFrame()),
        // 상단 안내
        Positioned(
          top: MediaQuery.of(context).padding.top + 16, left: 0, right: 0,
          child: Column(children: [
            const Text('명함을 프레임 안에 맞춰주세요',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 14,
                    fontWeight: FontWeight.w700,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black54)])),
            const SizedBox(height: 4),
            Text('📸 버튼을 눌러 촬영',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12)),
          ]),
        ),
        // 닫기
        Positioned(
          top: MediaQuery.of(context).padding.top + 10, left: 16,
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55), shape: BoxShape.circle),
              child: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
            ),
          ),
        ),
        // 하단 버튼
        Positioned(
          bottom: 48, left: 0, right: 0,
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _sideBtn(Icons.photo_library_rounded, '갤러리', () => _gallery(context)),
            _shutterBtn(context),
            const SizedBox(width: 80),
          ]),
        ),
      ]),
    );
  }

  Widget _sideBtn(IconData icon, String label, VoidCallback onTap) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white,
              fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
      ),
    );

  Widget _shutterBtn(BuildContext ctx) => GestureDetector(
    onTap: _capturing || !_cameraReady ? null : () => _capture(ctx),
    child: Container(
      width: 72, height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        color: Colors.white.withOpacity(0.15),
      ),
      child: Center(child: _capturing
          ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)
          : Container(
              width: 58, height: 58,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.camera_alt_rounded, color: Colors.black87, size: 30))),
    ),
  );
}

// ── 명함 프레임 오버레이
class BizCardFrame extends StatelessWidget {
  const BizCardFrame({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;
    final fw = sw * 0.88;
    final fh = fw * 0.58;
    return SizedBox(width: sw, height: sh,
      child: Stack(children: [
        CustomPaint(size: Size(sw, sh),
            painter: _FrameDimPainter(fw: fw, fh: fh)),
        Center(child: SizedBox(width: fw, height: fh,
          child: Stack(children: [
            _corner(0,      0,      true,  true),
            _corner(fw-28,  0,      false, true),
            _corner(0,      fh-28,  true,  false),
            _corner(fw-28,  fh-28,  false, false),
          ]),
        )),
      ]),
    );
  }
  Widget _corner(double l, double t, bool left, bool top) => Positioned(
    left: l, top: t,
    child: SizedBox(width: 28, height: 28,
        child: CustomPaint(painter: _CornerPainter(left: left, top: top))),
  );
}

class _FrameDimPainter extends CustomPainter {
  final double fw, fh;
  _FrameDimPainter({required this.fw, required this.fh});
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final fl = cx - fw/2, ft = cy - fh/2, fr = cx + fw/2, fb = cy + fh/2;
    final dim = Paint()..color = Colors.black.withOpacity(0.52);
    canvas.drawRect(Rect.fromLTRB(0, 0, size.width, ft), dim);
    canvas.drawRect(Rect.fromLTRB(0, fb, size.width, size.height), dim);
    canvas.drawRect(Rect.fromLTRB(0, ft, fl, fb), dim);
    canvas.drawRect(Rect.fromLTRB(fr, ft, size.width, fb), dim);
    // 프레임 테두리
    canvas.drawRect(Rect.fromLTRB(fl, ft, fr, fb),
        Paint()..color = Colors.white.withOpacity(0.5)
               ..style = PaintingStyle.stroke ..strokeWidth = 1.2);
  }
  @override bool shouldRepaint(_) => false;
}

class _CornerPainter extends CustomPainter {
  final bool left, top;
  _CornerPainter({required this.left, required this.top});
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white..style = PaintingStyle.stroke
        ..strokeWidth = 3..strokeCap = StrokeCap.round;
    final x = left ? 0.0 : size.width;
    final y = top  ? 0.0 : size.height;
    final dx = left ? 20.0 : -20.0;
    final dy = top  ? 20.0 : -20.0;
    canvas.drawLine(Offset(x, y), Offset(x+dx, y), p);
    canvas.drawLine(Offset(x, y), Offset(x, y+dy), p);
  }
  @override bool shouldRepaint(_) => false;
}

// ══════════════════════════════════════════
// 스캔 다이얼로그
// ══════════════════════════════════════════
class BizCardScanDialog extends StatefulWidget {
  final String base64Data;
  final String mimeType;
  final Uint8List imageBytes;
  final VoidCallback onSaved;
  final SupabaseClient supabase;

  const BizCardScanDialog({
    Key? key,
    required this.base64Data,
    required this.mimeType,
    required this.imageBytes,
    required this.onSaved,
    required this.supabase,
  }) : super(key: key);

  @override
  State<BizCardScanDialog> createState() => _BizCardScanDialogState();
}

class _BizCardScanDialogState extends State<BizCardScanDialog> {
  bool _scanning = true;
  bool _saving   = false;
  String? _error;

  final _nameCtrl     = TextEditingController();
  final _companyCtrl  = TextEditingController();
  final _deptCtrl     = TextEditingController();
  final _positionCtrl = TextEditingController();
  final _phoneCtrl    = TextEditingController();
  final _mobileCtrl   = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _addressCtrl  = TextEditingController();
  final _websiteCtrl  = TextEditingController();
  final _memoCtrl     = TextEditingController();

  @override
  void initState() { super.initState(); _scan(); }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _companyCtrl, _deptCtrl, _positionCtrl,
        _phoneCtrl, _mobileCtrl, _emailCtrl, _addressCtrl, _websiteCtrl, _memoCtrl])
      c.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    try {
      final res = await widget.supabase.functions.invoke(
        'scan_business_card',
        body: {'base64': widget.base64Data, 'mimeType': widget.mimeType},
        headers: {'Authorization':
            'Bearer ${widget.supabase.auth.currentSession?.accessToken ?? ''}'},
      );
      final data    = res.data as Map<String, dynamic>;
      final content = (data['content'] as List).first['text'] as String;
      String jsonStr = content.trim().replaceAll('```json', '').replaceAll('```', '').trim();
      final s = jsonStr.indexOf('{'), e = jsonStr.lastIndexOf('}');
      if (s >= 0 && e > s) jsonStr = jsonStr.substring(s, e + 1);
      final parsed = Map<String, dynamic>.from(jsonDecode(jsonStr));
      if (mounted) setState(() {
        _nameCtrl.text     = parsed['name']       ?? '';
        _companyCtrl.text  = parsed['company']    ?? '';
        _deptCtrl.text     = parsed['department'] ?? '';
        _positionCtrl.text = parsed['position']   ?? '';
        _phoneCtrl.text    = parsed['phone']      ?? '';
        _mobileCtrl.text   = parsed['mobile']     ?? '';
        _emailCtrl.text    = parsed['email']      ?? '';
        _addressCtrl.text  = parsed['address']    ?? '';
        _websiteCtrl.text  = parsed['website']    ?? '';
        _scanning = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = '인식 실패 — 직접 입력해주세요'; _scanning = false; });
    }
  }

  Future<String?> _uploadImage() async {
    try {
      final myId = widget.supabase.auth.currentUser?.id ?? 'unknown';
      final path = '$myId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await widget.supabase.storage.from('business-cards').uploadBinary(
        path, widget.imageBytes,
        fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
      );
      return widget.supabase.storage.from('business-cards').getPublicUrl(path);
    } catch (e) {
      debugPrint('이미지 업로드 실패: $e');
      return null;
    }
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이름을 입력해주세요')));
      return;
    }
    setState(() => _saving = true);
    try {
      final imgUrl = await _uploadImage();
      await widget.supabase.from('business_cards').insert({
        'owner_id':   widget.supabase.auth.currentUser?.id,
        'name':       _nameCtrl.text.trim(),
        'company':    _companyCtrl.text.trim(),
        'department': _deptCtrl.text.trim(),
        'position':   _positionCtrl.text.trim(),
        'phone':      _phoneCtrl.text.trim(),
        'mobile':     _mobileCtrl.text.trim(),
        'email':      _emailCtrl.text.trim(),
        'address':    _addressCtrl.text.trim(),
        'website':    _websiteCtrl.text.trim(),
        'memo':       _memoCtrl.text.trim(),
        'image_url':  imgUrl,
      });
      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('명함이 저장됐어요 ✅'),
                backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('저장 실패: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: _scanning ? _scanningView() : _formView(),
      ),
    );
  }

  Widget _scanningView() => Padding(
    padding: const EdgeInsets.all(36),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      ClipRRect(borderRadius: BorderRadius.circular(12),
          child: Image.memory(widget.imageBytes,
              height: 110, width: double.infinity, fit: BoxFit.cover)),
      const SizedBox(height: 24),
      const CircularProgressIndicator(color: bcPrimary),
      const SizedBox(height: 16),
      const Text('명함 분석중입니다.!', style: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w800, color: bcText)),
      const SizedBox(height: 4),
      const Text('잠시만 기다려주세요',
          style: TextStyle(fontSize: 12, color: bcSub)),
    ]),
  );

  Widget _formView() => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
    child: Column(children: [
      Row(children: [
        Container(padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: bcPrimary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.credit_card_rounded, color: bcPrimary, size: 20)),
        const SizedBox(width: 10),
        const Expanded(child: Text('명함 정보 확인',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: bcText))),
        IconButton(onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded)),
      ]),
      const SizedBox(height: 10),
      // 촬영 이미지 미리보기
      ClipRRect(borderRadius: BorderRadius.circular(10),
          child: Image.memory(widget.imageBytes,
              height: 90, width: double.infinity, fit: BoxFit.cover)),
      if (_error != null) ...[
        const SizedBox(height: 8),
        Container(padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.orange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10)),
            child: Text(_error!, style: const TextStyle(fontSize: 12, color: Colors.orange))),
      ],
      const SizedBox(height: 12),
      _field(_nameCtrl,     '이름 *',   Icons.person_rounded),
      _field(_companyCtrl,  '회사',     Icons.business_rounded),
      _field(_deptCtrl,     '부서',     Icons.account_tree_rounded),
      _field(_positionCtrl, '직책',     Icons.work_rounded),
      _field(_phoneCtrl,    '대표전화', Icons.phone_rounded),
      _field(_mobileCtrl,   '휴대폰',  Icons.smartphone_rounded),
      _field(_emailCtrl,    '이메일',  Icons.email_rounded),
      _field(_addressCtrl,  '주소',    Icons.location_on_rounded),
      _field(_websiteCtrl,  '웹사이트', Icons.language_rounded),
      _field(_memoCtrl,     '메모',    Icons.note_rounded, maxLines: 2),
      const SizedBox(height: 16),
      SizedBox(width: double.infinity, height: 50,
        child: ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
              backgroundColor: bcPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          child: _saving
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('저장', style: TextStyle(color: Colors.white,
                  fontSize: 15, fontWeight: FontWeight.w800)),
        ),
      ),
    ]),
  );

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {int maxLines = 1}) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: TextField(
      controller: ctrl, maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18, color: Colors.grey[400]),
        filled: true, fillColor: bcBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        labelStyle: const TextStyle(fontSize: 12, color: bcSub),
      ),
    ),
  );
}
