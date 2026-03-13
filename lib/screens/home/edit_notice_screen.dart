import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditNoticeScreen extends StatefulWidget {
  final Map<String, dynamic> notice;
  const EditNoticeScreen({Key? key, required this.notice}) : super(key: key);

  @override
  State<EditNoticeScreen> createState() => _EditNoticeScreenState();
}

class _EditNoticeScreenState extends State<EditNoticeScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;

  late String _selectedCategory;
  String? _existingImageUrl;

  Uint8List? _imageBytes;
  XFile? _pickedFile;
  final ImagePicker _picker = ImagePicker();

  bool _isSaving = false;

  // ✅ 카테고리 목록 (TEST는 기본적으로 숨김)
  final List<Map<String, String>> _categories = [
    {'value': 'ALL', 'label': '전체 공지'},
    {'value': 'OFFICE', 'label': '사무실'},
    {'value': 'STEEL', 'label': '스틸'},
    {'value': 'BOX', 'label': '박스'},
    {'value': 'SEYOUNG', 'label': '세영'},
    // {'value': 'TEST', 'label': '비밀 테스트'},
  ];

  // Theme (작성 화면과 통일)
  static const _primary = Color(0xFF2E6BFF);
  static const _primary2 = Color(0xFF4FB2FF);
  static const _bg = Color(0xFFF6F8FC);
  static const _card = Colors.white;

  int get _titleLen => _titleController.text.trim().length;
  int get _contentLen => _contentController.text.trim().length;

  @override
  void initState() {
    super.initState();

    _titleController = TextEditingController(text: (widget.notice['title'] ?? '').toString());
    _contentController = TextEditingController(text: (widget.notice['content'] ?? '').toString());
    _selectedCategory = (widget.notice['target_category'] ?? 'ALL').toString();
    _existingImageUrl = widget.notice['image_url']?.toString();

    // ✅ 글자수 카운터 갱신
    _titleController.addListener(() => setState(() {}));
    _contentController.addListener(() => setState(() {}));

    // ✅ TEST 같은 “목록에 없는 값”이 들어와도 드롭다운이 안 터지게 안전처리
    if (!_categories.any((c) => c['value'] == _selectedCategory)) {
      // 화면에서만 임시로 보이게(값 유지)
     _categories.add({'value': _selectedCategory, 'label': '(${_selectedCategory}) 숨김 카테고리'});
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _pickedFile = picked;
          _imageBytes = bytes;
        });
      }
    } catch (e) {
      _showSnackBar("이미지 선택 실패: $e");
    }
  }

  Future<void> _updateNotice() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty || content.isEmpty) {
      _showSnackBar("제목과 내용을 입력해주세요.");
      return;
    }

    setState(() => _isSaving = true);
    try {
      String? imageUrl = _existingImageUrl;

      if (_imageBytes != null && _pickedFile != null) {
        final path = 'notices/${DateTime.now().millisecondsSinceEpoch}.jpg';

        await Supabase.instance.client.storage.from('notice-images').uploadBinary(
              path,
              _imageBytes!,
              fileOptions: const FileOptions(contentType: 'image/jpeg'),
            );

        imageUrl = Supabase.instance.client.storage.from('notice-images').getPublicUrl(path);
      }

      await Supabase.instance.client.from('notices').update({
        'title': title,
        'content': content,
        'target_category': _selectedCategory,
        'image_url': imageUrl,
      }).eq('id', widget.notice['id']);

      if (!mounted) return;
      _showSnackBar("성공적으로 수정되었습니다.", isError: false);
      Navigator.pop(context, true);
    } catch (e) {
      _showSnackBar("수정 실패: $e");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : _primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    final selectedLabel =
        _categories.firstWhere((c) => c['value'] == _selectedCategory)['label'] ?? _selectedCategory;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text("공지사항 수정", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _headerHintCard(selectedLabel: selectedLabel),
              const SizedBox(height: 14),

              _sectionTitle("이미지"),
              const SizedBox(height: 10),
              _imageCard(),
              const SizedBox(height: 18),

              _sectionTitle("수정 내용"),
              const SizedBox(height: 10),
              _editCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerHintCard({required String selectedLabel}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_primary, _primary2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: _primary.withOpacity(0.22), blurRadius: 18, offset: const Offset(0, 10)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.22)),
            ),
            child: const Icon(Icons.edit_note_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "대상: $selectedLabel",
                  style: TextStyle(color: Colors.white.withOpacity(0.95), fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  "수정 후 저장하면 즉시 반영됩니다.",
                  style: TextStyle(color: Colors.white.withOpacity(0.88), fontWeight: FontWeight.w600, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.black.withOpacity(0.55)),
    );
  }

  Widget _imageCard() {
    return InkWell(
      onTap: _pickImage,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 190,
        width: double.infinity,
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _primary.withOpacity(0.10), width: 2),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.035), blurRadius: 12, offset: const Offset(0, 6)),
          ],
        ),
        child: (_imageBytes != null || (_existingImageUrl != null && _existingImageUrl!.isNotEmpty))
            ? _imagePreview()
            : _imageEmpty(),
      ),
    );
  }

  Widget _imagePreview() {
    return Stack(
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: _imageBytes != null
                ? Image.memory(_imageBytes!, fit: BoxFit.cover)
                : Image.network(
                    _existingImageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Center(child: Text("이미지를 표시할 수 없습니다.")),
                  ),
          ),
        ),
        Positioned(
          left: 12,
          top: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.45),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              "미리보기",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
            ),
          ),
        ),
        Positioned(
          right: 10,
          top: 10,
          child: Row(
            children: [
              _pillIconBtn(
                icon: Icons.edit_rounded,
                label: "변경",
                onTap: _pickImage,
              ),
              const SizedBox(width: 8),
              _pillIconBtn(
                icon: Icons.delete_outline_rounded,
                label: "삭제",
                onTap: () => setState(() {
                  _pickedFile = null;
                  _imageBytes = null;
                  _existingImageUrl = null;
                }),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _imageEmpty() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: _primary.withOpacity(0.08), shape: BoxShape.circle),
          child: const Icon(Icons.add_photo_alternate_rounded, size: 34, color: _primary),
        ),
        const SizedBox(height: 10),
        const Text("이미지 변경 (선택)", style: TextStyle(color: _primary, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text("탭해서 갤러리에서 선택", style: TextStyle(color: Colors.black.withOpacity(0.45), fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _editCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.035), blurRadius: 14, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCategoryDropdown(),
          const SizedBox(height: 16),

          _fieldLabelRow("공지 제목", "$_titleLen자"),
          const SizedBox(height: 8),
          _customTextField(
            controller: _titleController,
            hint: "사원들이 한눈에 알아볼 수 있는 제목",
            icon: Icons.title_rounded,
            maxLines: 1,
          ),

          const SizedBox(height: 16),

          _fieldLabelRow("상세 내용", "$_contentLen자"),
          const SizedBox(height: 8),
          _customTextField(
            controller: _contentController,
            hint: "전달할 내용을 자세히 적어주세요.",
            icon: Icons.subject_rounded,
            maxLines: 8,
          ),
        ],
      ),
    );
  }

  Widget _fieldLabelRow(String label, String right) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
        const Spacer(),
        Text(right, style: TextStyle(color: Colors.black.withOpacity(0.45), fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedCategory,
      decoration: InputDecoration(
        labelText: "공지 대상 부서",
        prefixIcon: const Icon(Icons.group_work_rounded, color: _primary),
        filled: true,
        fillColor: _bg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      items: _categories
          .map((c) => DropdownMenuItem(
                value: c['value'],
                child: Text(c['label']!),
              ))
          .toList(),
      onChanged: (val) => setState(() => _selectedCategory = val!),
    );
  }

  Widget _customTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      textInputAction: maxLines == 1 ? TextInputAction.next : TextInputAction.newline,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400], fontWeight: FontWeight.w600),
        prefixIcon: Icon(icon, color: _primary, size: 20),
        filled: true,
        fillColor: _bg,
        alignLabelWithHint: true,
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
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 14, offset: const Offset(0, -6)),
          ],
        ),
        child: SizedBox(
          height: 54,
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _updateNotice,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              disabledBackgroundColor: Colors.grey[400],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.check_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text("수정 완료하기",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _pillIconBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.45),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
