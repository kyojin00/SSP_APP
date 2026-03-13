import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReportFaultScreen extends StatefulWidget {
  const ReportFaultScreen({Key? key}) : super(key: key);

  @override
  State<ReportFaultScreen> createState() => _ReportFaultScreenState();
}

class _ReportFaultScreenState extends State<ReportFaultScreen>
    with SingleTickerProviderStateMixin {

  final _titleCtrl   = TextEditingController();
  final _contentCtrl = TextEditingController();
  String    _priority    = 'NORMAL';
  Uint8List? _imageBytes;
  bool      _isSaving   = false;

  late AnimationController _animCtrl;
  late Animation<double>   _fadeAnim;

  static const _bg      = Color(0xFFF0F2F7);
  static const _surface = Colors.white;
  static const _ink     = Color(0xFF1A1D2E);
  static const _orange  = Color(0xFFFF7A2F);
  static const _red     = Color(0xFFFF3B3B);

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 50);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() => _imageBytes = bytes);
    }
  }

  Future<void> _submit() async {
    if (_imageBytes == null) {
      _snack("현장 사진을 촬영해주세요.", isError: true);
      return;
    }
    if (_titleCtrl.text.trim().isEmpty) {
      _snack("고장 설비명을 입력해주세요.", isError: true);
      return;
    }
    setState(() => _isSaving = true);
    try {
      final user    = Supabase.instance.client.auth.currentUser!;
      final profile = await Supabase.instance.client
          .from('profiles').select().eq('id', user.id).single();

      final fileName = 'faults/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await Supabase.instance.client.storage
          .from('notice-images').uploadBinary(fileName, _imageBytes!);
      final imageUrl = Supabase.instance.client.storage
          .from('notice-images').getPublicUrl(fileName);

      await Supabase.instance.client.from('equipment_reports').insert({
        'reporter_id':   user.id,
        'reporter_name': profile['full_name'],
        'dept_category': profile['dept_category'],
        'title':         _titleCtrl.text.trim(),
        'content':       _contentCtrl.text.trim(),
        'priority':      _priority,
        'image_url':     imageUrl,
      });

      if (!mounted) return;
      _snack("신고가 등록되었습니다.");
      Navigator.pop(context);
    } catch (e) {
      debugPrint("신고 등록 오류: $e");
      if (mounted) _snack("등록 중 오류가 발생했습니다.", isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
      backgroundColor: isError ? _red : _ink,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text("고장 신고 접수",
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: _ink)),
        backgroundColor: _surface,
        foregroundColor: _ink,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.black.withOpacity(0.07)),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 48),
          child: Column(children: [
            // ── 사진 영역
            _photoSection(),
            const SizedBox(height: 16),
            // ── 긴급도
            _prioritySection(),
            const SizedBox(height: 16),
            // ── 설비명 + 증상
            _formSection(),
            const SizedBox(height: 28),
            // ── 제출 버튼
            _submitButton(),
          ]),
        ),
      ),
    );
  }

  // ── 사진 촬영 섹션
  Widget _photoSection() {
    return _card(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
          child: Row(children: [
            _iconBox(Icons.camera_enhance_rounded, _orange),
            const SizedBox(width: 12),
            const Text("현장 사진", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: _ink)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _red.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
              child: const Text("필수", style: TextStyle(fontSize: 11, color: _red, fontWeight: FontWeight.w900)),
            ),
          ]),
        ),
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            height: 220,
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            decoration: BoxDecoration(
              color: _imageBytes != null ? null : _orange.withOpacity(0.04),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _imageBytes != null
                    ? Colors.transparent
                    : _orange.withOpacity(0.35),
                width: 1.5,
              ),
            ),
            child: _imageBytes != null
                ? Stack(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.memory(_imageBytes!, width: double.infinity,
                          height: double.infinity, fit: BoxFit.cover),
                    ),
                    // 재촬영 버튼
                    Positioned(
                      bottom: 10, right: 10,
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.refresh_rounded, color: Colors.white, size: 14),
                            SizedBox(width: 5),
                            Text("재촬영", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                          ]),
                        ),
                      ),
                    ),
                  ])
                : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: _orange.withOpacity(0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.camera_enhance_rounded, size: 36, color: _orange),
                    ),
                    const SizedBox(height: 14),
                    const Text("탭하여 촬영",
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _orange)),
                    const SizedBox(height: 4),
                    Text("고장 부위를 명확하게 촬영해주세요",
                        style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.4))),
                  ]),
          ),
        ),
      ]),
    );
  }

  // ── 긴급도 섹션
  Widget _prioritySection() {
    return _card(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _iconBox(Icons.flag_rounded, const Color(0xFFFF3B3B)),
          const SizedBox(width: 12),
          const Text("긴급도 구분", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: _ink)),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _priorityChip('NORMAL', '일반', '순차 처리', const Color(0xFF2E6BFF), Icons.schedule_rounded)),
          const SizedBox(width: 12),
          Expanded(child: _priorityChip('URGENT', '긴급', '즉시 조치', _red, Icons.warning_rounded)),
        ]),
      ]),
    );
  }

  Widget _priorityChip(String value, String label, String sub, Color color, IconData icon) {
    final sel = _priority == value;
    return GestureDetector(
      onTap: () => setState(() => _priority = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: sel ? color.withOpacity(0.08) : Colors.black.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: sel ? color : Colors.black.withOpacity(0.09),
            width: sel ? 1.8 : 1,
          ),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: sel ? color.withOpacity(0.12) : Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: sel ? color : Colors.black38, size: 18),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w900,
              color: sel ? color : Colors.black54,
            )),
            Text(sub, style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600,
              color: sel ? color.withOpacity(0.7) : Colors.black38,
            )),
          ]),
          const Spacer(),
          if (sel)
            Icon(Icons.check_circle_rounded, color: color, size: 20),
        ]),
      ),
    );
  }

  // ── 폼 섹션
  Widget _formSection() {
    return _card(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _iconBox(Icons.build_rounded, const Color(0xFF7C5CDB)),
          const SizedBox(width: 12),
          const Text("고장 정보 입력", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: _ink)),
        ]),
        const SizedBox(height: 20),

        // 설비명
        _fieldLabel("고장 설비명", isRequired: true),
        const SizedBox(height: 8),
        TextField(
          controller: _titleCtrl,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _ink),
          decoration: _inputDeco(hint: "예) 3호 프레스, 컨베이어 벨트 A"),
        ),
        const SizedBox(height: 20),

        // 증상
        _fieldLabel("상세 고장 증상"),
        const SizedBox(height: 8),
        TextField(
          controller: _contentCtrl,
          maxLines: 4,
          style: const TextStyle(fontSize: 15, color: _ink, height: 1.6),
          decoration: _inputDeco(hint: "이상 증상을 최대한 자세히 설명해주세요\n예) 가동 시 이상 소음 발생, 출력 저하 등"),
        ),
      ]),
    );
  }

  // ── 제출 버튼
  Widget _submitButton() {
    return GestureDetector(
      onTap: _isSaving ? null : _submit,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        height: 58,
        decoration: BoxDecoration(
          gradient: _isSaving
              ? null
              : const LinearGradient(colors: [_orange, Color(0xFFFF5E3A)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
          color: _isSaving ? Colors.black12 : null,
          borderRadius: BorderRadius.circular(18),
          boxShadow: _isSaving ? [] : [
            BoxShadow(color: _orange.withOpacity(0.4), blurRadius: 18, offset: const Offset(0, 8)),
          ],
        ),
        child: Center(
          child: _isSaving
              ? const SizedBox(width: 24, height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
              : const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Text("신고 등록", style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5)),
                ]),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════
  // Atoms
  // ══════════════════════════════════════════

  Widget _card({required Widget child, EdgeInsets? padding}) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
            blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(22), child: child),
    );
  }

  Widget _iconBox(IconData icon, Color color) => Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(11)),
    child: Icon(icon, color: color, size: 18),
  );

  Widget _fieldLabel(String label, {bool isRequired = false}) {
    return Row(children: [
      Text(label, style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF4A4D5E))),
      if (isRequired) ...[
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: _red.withOpacity(0.09), borderRadius: BorderRadius.circular(6)),
          child: const Text("필수",
              style: TextStyle(fontSize: 10, color: _red, fontWeight: FontWeight.w900)),
        ),
      ],
    ]);
  }

  InputDecoration _inputDeco({required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 13.5, color: Colors.black.withOpacity(0.3), height: 1.5),
      filled: true,
      fillColor: Colors.black.withOpacity(0.03),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.black.withOpacity(0.09)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.black.withOpacity(0.09)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _orange, width: 1.5),
      ),
    );
  }
}