import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WriteNoticeScreen extends StatefulWidget {
  const WriteNoticeScreen({super.key});

  @override
  State<WriteNoticeScreen> createState() => _WriteNoticeScreenState();
}

class _WriteNoticeScreenState extends State<WriteNoticeScreen> {
  final _titleController   = TextEditingController();
  final _contentController = TextEditingController();

  String _selectedCategory = 'ALL';
  bool   _isSaving = false;

  Uint8List? _imageBytes;
  XFile?     _pickedFile;
  final ImagePicker _picker = ImagePicker();

  final List<Map<String, String>> _categories = [
    {'value': 'ALL',        'label': '전체 공지'},
    {'value': 'MANAGEMENT', 'label': '관리부'},
    {'value': 'PRODUCTION', 'label': '생산부'},
    {'value': 'SALES',      'label': '영업부'},
    {'value': 'RND',        'label': '연구개발'},
    {'value': 'STEEL',      'label': '철강부'},
    {'value': 'BOX',        'label': '박스부'},
    {'value': 'DELIVERY',   'label': '배송부'},
    {'value': 'SSG',        'label': '에스에스지'},
    {'value': 'CLEANING',   'label': '환경미화'},
    {'value': 'NUTRITION',  'label': '영양사'},
    {'value': 'TEST',       'label': 'TEST'},
  ];

  static const _primary  = Color(0xFF2E6BFF);
  static const _primary2 = Color(0xFF4FB2FF);
  static const _bg       = Color(0xFFF6F8FC);
  static const _card     = Colors.white;

  int get _titleLen   => _titleController.text.trim().length;
  int get _contentLen => _contentController.text.trim().length;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(() => setState(() {}));
    _contentController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source, imageQuality: 75);
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() { _pickedFile = pickedFile; _imageBytes = bytes; });
      }
    } catch (e) {
      _showSnackBar("이미지 선택 실패: $e");
    }
  }

  Future<void> _saveNotice() async {
    final title   = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty || content.isEmpty) { _showSnackBar("제목과 내용을 입력해주세요."); return; }

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) { _showSnackBar("로그인 상태를 확인해주세요."); return; }

    setState(() => _isSaving = true);
    try {
      String? imageUrl;
      if (_imageBytes != null && _pickedFile != null) {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        final path = 'notices/$fileName';
        await supabase.storage.from('notice-images').uploadBinary(
          path, _imageBytes!,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
        imageUrl = supabase.storage.from('notice-images').getPublicUrl(path);
      }

      // INSERT 시 DB 트리거(trg_notice_onesignal)가 자동으로 알림 발송
      await supabase.from('notices').insert({
        'title': title, 'content': content,
        'target_category': _selectedCategory,
        'author_id': user.id, 'image_url': imageUrl,
      });

      if (!mounted) return;
      Navigator.pop(context, {'success': true, 'pushOk': true});
    } catch (e) {
      if (!mounted) return;
      _showSnackBar("저장 실패: $e");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final selectedLabel =
        _categories.firstWhere((c) => c['value'] == _selectedCategory)['label'] ?? '전체 공지';

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text("공지사항 작성",
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      bottomNavigationBar: _bottomSubmitBar(),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _headerHintCard(selectedLabel: selectedLabel),
            const SizedBox(height: 14),
            _sectionTitle("시각 자료"),
            const SizedBox(height: 10),
            _imagePickerCard(),
            const SizedBox(height: 18),
            _sectionTitle("공지 정보"),
            const SizedBox(height: 10),
            _inputCard(),
            const SizedBox(height: 16),
            if (kIsWeb)
              _miniInfo("웹에서는 기기/브라우저 설정에 따라 카메라 촬영이 제한될 수 있어요. 그럴 땐 갤러리 선택을 이용해주세요."),
          ]),
        ),
      ),
    );
  }

  Widget _headerHintCard({required String selectedLabel}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_primary, _primary2],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: _primary.withOpacity(0.22), blurRadius: 18, offset: const Offset(0, 10))],
      ),
      child: Row(children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.22)),
          ),
          child: const Icon(Icons.campaign_rounded, color: Colors.white, size: 26),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("대상: $selectedLabel",
              style: TextStyle(color: Colors.white.withOpacity(0.95), fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text("제목은 짧고 명확하게, 내용은 핵심을 먼저 적어주세요.",
              style: TextStyle(color: Colors.white.withOpacity(0.88), fontWeight: FontWeight.w600, height: 1.35)),
        ])),
      ]),
    );
  }

  Widget _sectionTitle(String title) => Text(title,
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.black.withOpacity(0.55)));

  Widget _imagePickerCard() {
    return InkWell(
      onTap: _showImageSourceOptions,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 190, width: double.infinity,
        decoration: BoxDecoration(
          color: _card, borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _primary.withOpacity(0.10), width: 2),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.035), blurRadius: 12, offset: const Offset(0, 6))],
        ),
        child: _imageBytes != null ? _imagePreview() : _imageEmpty(),
      ),
    );
  }

  Widget _imagePreview() {
    return Stack(children: [
      Positioned.fill(child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.memory(_imageBytes!, fit: BoxFit.cover))),
      Positioned(left: 12, top: 12,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: Colors.black.withOpacity(0.45), borderRadius: BorderRadius.circular(999)),
          child: const Text("미리보기", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
        ),
      ),
      Positioned(right: 10, top: 10,
        child: Row(children: [
          _pillIconBtn(icon: Icons.edit_rounded, label: "변경", onTap: _showImageSourceOptions),
          const SizedBox(width: 8),
          _pillIconBtn(icon: Icons.delete_outline_rounded, label: "삭제",
              onTap: () => setState(() { _pickedFile = null; _imageBytes = null; })),
        ]),
      ),
    ]);
  }

  Widget _imageEmpty() {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _primary.withOpacity(0.08), shape: BoxShape.circle),
        child: const Icon(Icons.add_photo_alternate_rounded, size: 34, color: _primary),
      ),
      const SizedBox(height: 10),
      const Text("이미지 첨부 (선택)", style: TextStyle(color: _primary, fontWeight: FontWeight.w900)),
      const SizedBox(height: 6),
      Text("탭해서 갤러리/카메라에서 선택",
          style: TextStyle(color: Colors.black.withOpacity(0.45), fontWeight: FontWeight.w600)),
    ]);
  }

  Widget _inputCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card, borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.035), blurRadius: 14, offset: const Offset(0, 8))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildCategoryDropdown(),
        const SizedBox(height: 16),
        _fieldLabelRow("공지 제목", "$_titleLen자"),
        const SizedBox(height: 8),
        _customTextField(controller: _titleController, hint: "사원들이 한눈에 알아볼 수 있는 제목", icon: Icons.title_rounded),
        const SizedBox(height: 16),
        _fieldLabelRow("상세 내용", "$_contentLen자"),
        const SizedBox(height: 8),
        _customTextField(controller: _contentController, hint: "전달할 내용을 자세히 적어주세요.", icon: Icons.subject_rounded, maxLines: 7),
      ]),
    );
  }

  Widget _fieldLabelRow(String label, String right) {
    return Row(children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
      const Spacer(),
      Text(right, style: TextStyle(color: Colors.black.withOpacity(0.45), fontWeight: FontWeight.w700)),
    ]);
  }

  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedCategory,
      decoration: InputDecoration(
        labelText: "공지 대상 부서",
        prefixIcon: const Icon(Icons.group_work_rounded, color: _primary),
        filled: true, fillColor: _bg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      items: _categories.map((c) => DropdownMenuItem(value: c['value'], child: Text(c['label']!))).toList(),
      onChanged: (val) => setState(() => _selectedCategory = val!),
    );
  }

  Widget _customTextField({
    required TextEditingController controller,
    required String hint, required IconData icon, int maxLines = 1,
  }) {
    return TextField(
      controller: controller, maxLines: maxLines,
      textInputAction: maxLines == 1 ? TextInputAction.next : TextInputAction.newline,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400], fontWeight: FontWeight.w600),
        prefixIcon: Icon(icon, color: _primary, size: 20),
        filled: true, fillColor: _bg, alignLabelWithHint: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _primary.withOpacity(0.8), width: 1.6),
        ),
      ),
    );
  }

  Widget _bottomSubmitBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 14, offset: const Offset(0, -6))],
        ),
        child: SizedBox(
          height: 54, width: double.infinity,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveNotice,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary, disabledBackgroundColor: Colors.grey[400],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0,
            ),
            child: _isSaving
                ? const SizedBox(width: 24, height: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.send_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text("공지 발행하기",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
                  ]),
          ),
        ),
      ),
    );
  }

  Widget _pillIconBtn({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.45), borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: Row(children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
        ]),
      ),
    );
  }

  Widget _miniInfo(String text) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Row(children: [
        Icon(Icons.info_outline_rounded, color: Colors.black.withOpacity(0.45)),
        const SizedBox(width: 10),
        Expanded(child: Text(text,
            style: TextStyle(color: Colors.black.withOpacity(0.6), fontWeight: FontWeight.w600, height: 1.3))),
      ]),
    );
  }

  void _showImageSourceOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Wrap(children: [
            Container(
              width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 8),
              child: const Text("이미지 추가", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: _primary),
              title: const Text('갤러리에서 선택', style: TextStyle(fontWeight: FontWeight.w700)),
              onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: _primary),
              title: const Text('직접 촬영하기', style: TextStyle(fontWeight: FontWeight.w700)),
              onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); },
            ),
            const SizedBox(height: 4),
          ]),
        ),
      ),
    );
  }
}