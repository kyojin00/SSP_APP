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

class _EditNoticeScreenState extends State<EditNoticeScreen>
    with SingleTickerProviderStateMixin {
  late TextEditingController _titleController;
  late TextEditingController _contentController;

  late String _selectedCategory;
  String? _existingImageUrl;

  Uint8List? _imageBytes;
  XFile? _pickedFile;
  final ImagePicker _picker = ImagePicker();

  bool _isSaving = false;

  late AnimationController _animCtrl;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  // ── 카테고리 목록
  final List<Map<String, String>> _categories = [
    {'value': 'ALL',        'label': '전체 공지'},
    {'value': 'MANAGEMENT', 'label': '관리부'},
    {'value': 'PRODUCTION', 'label': '생산관리부'},
    {'value': 'SALES',      'label': '영업부'},
    {'value': 'RND',        'label': '연구소'},
    {'value': 'STEEL',      'label': '스틸생산부'},
    {'value': 'BOX',        'label': '박스생산부'},
    {'value': 'DELIVERY',   'label': '포장납품부'},
    {'value': 'SSG',        'label': '에스에스지'},
    {'value': 'CLEANING',   'label': '환경미화'},
    {'value': 'NUTRITION',  'label': '영양사'},
  ];

  static const _deptColors = <String, List<Color>>{
    'MANAGEMENT': [Color(0xFF3B5BDB), Color(0xFF748FFC)],
    'PRODUCTION': [Color(0xFF7048E8), Color(0xFFB197FC)],
    'SALES':      [Color(0xFFE8590C), Color(0xFFFF8C42)],
    'RND':        [Color(0xFF0C8599), Color(0xFF38D9A9)],
    'STEEL':      [Color(0xFF495057), Color(0xFF868E96)],
    'BOX':        [Color(0xFF2F9E44), Color(0xFF69DB7C)],
    'DELIVERY':   [Color(0xFFAD1457), Color(0xFFF06595)],
    'SSG':        [Color(0xFF00897B), Color(0xFF26C6BC)],
    'CLEANING':   [Color(0xFF558B2F), Color(0xFF94D82D)],
    'NUTRITION':  [Color(0xFFD84315), Color(0xFFFF8A65)],
    'ALL':        [Color(0xFF1971C2), Color(0xFF4DABF7)],
    'TEST':       [Color(0xFFC92A2A), Color(0xFFFF6B6B)],
  };

  static const _deptIcons = <String, IconData>{
    'MANAGEMENT': Icons.business_center_rounded,
    'PRODUCTION': Icons.precision_manufacturing_rounded,
    'SALES':      Icons.storefront_rounded,
    'RND':        Icons.science_rounded,
    'STEEL':      Icons.construction_rounded,
    'BOX':        Icons.inventory_2_rounded,
    'DELIVERY':   Icons.local_shipping_rounded,
    'SSG':        Icons.store_rounded,
    'CLEANING':   Icons.cleaning_services_rounded,
    'NUTRITION':  Icons.restaurant_rounded,
    'ALL':        Icons.campaign_rounded,
    'TEST':       Icons.bug_report_rounded,
  };

  List<Color> _catGradient(String c) =>
      _deptColors[c] ?? [const Color(0xFF1971C2), const Color(0xFF4DABF7)];
  Color       _catColor(String c)    => _catGradient(c)[0];
  IconData    _catIcon(String c)     => _deptIcons[c] ?? Icons.campaign_rounded;

  int get _titleLen   => _titleController.text.trim().length;
  int get _contentLen => _contentController.text.trim().length;

  @override
  void initState() {
    super.initState();
    _titleController   = TextEditingController(text: (widget.notice['title']   ?? '').toString());
    _contentController = TextEditingController(text: (widget.notice['content'] ?? '').toString());
    _selectedCategory  = (widget.notice['target_category'] ?? 'ALL').toString();
    _existingImageUrl  = widget.notice['image_url']?.toString();

    _titleController.addListener(()   => setState(() {}));
    _contentController.addListener(() => setState(() {}));

    if (!_categories.any((c) => c['value'] == _selectedCategory)) {
      _categories.add({'value': _selectedCategory, 'label': '($_selectedCategory) 숨김 카테고리'});
    }

    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() { _pickedFile = picked; _imageBytes = bytes; });
      }
    } catch (e) {
      _snack("이미지 선택 실패: $e", isError: true);
    }
  }

  Future<void> _updateNotice() async {
    final title   = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty || content.isEmpty) {
      _snack("제목과 내용을 입력해주세요.", isError: true);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isSaving = true);
    try {
      String? imageUrl = _existingImageUrl;
      if (_imageBytes != null && _pickedFile != null) {
        final path = 'notices/${DateTime.now().millisecondsSinceEpoch}.jpg';
        await Supabase.instance.client.storage.from('notice-images').uploadBinary(
          path, _imageBytes!,
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
      messenger.showSnackBar(SnackBar(
        content: const Text("성공적으로 수정되었습니다.", style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF1A1D2E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _snack("수정 실패: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
      backgroundColor: isError ? const Color(0xFFC92A2A) : const Color(0xFF1A1D2E),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ));
  }

  // ══════════════════════════════════════════
  // Build
  // ══════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final grad  = _catGradient(_selectedCategory);
    final color = grad[0];

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F8),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.92),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: const Icon(Icons.close_rounded, color: Color(0xFF1A1D2E), size: 20),
          ),
        ),
        actions: [
          GestureDetector(
            onTap: _isSaving ? null : _updateNotice,
            child: Container(
              margin: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: grad),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: color.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: _isSaving
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : const Row(children: [
                      Icon(Icons.check_rounded, color: Colors.white, size: 17),
                      SizedBox(width: 6),
                      Text("저장", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                    ]),
            ),
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(children: [
                // ── 풀블리드 헤더
                _buildHeroHeader(grad, color),
                // ── 본문
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 48),
                  child: Column(children: [
                    const SizedBox(height: 20),
                    _buildCategoryCard(color),
                    const SizedBox(height: 14),
                    _buildImageCard(color),
                    const SizedBox(height: 14),
                    _buildInputCard(color),
                    const SizedBox(height: 24),
                    _buildSubmitButton(grad, color),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════
  // 히어로 헤더
  // ══════════════════════════════════════════

  Widget _buildHeroHeader(List<Color> grad, Color color) {
    final lightColor = HSLColor.fromColor(color)
        .withLightness((HSLColor.fromColor(color).lightness + 0.18).clamp(0.0, 0.92))
        .toColor();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, lightColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(children: [
        Positioned(right: -40, top: -40,
          child: Container(width: 180, height: 180,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.07)))),
        Positioned(right: 40, bottom: -30,
          child: Container(width: 110, height: 110,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.05)))),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: Icon(_catIcon(_selectedCategory), color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: Colors.white.withOpacity(0.25)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.edit_note_rounded, color: Colors.white, size: 13),
                      const SizedBox(width: 5),
                      const Text("공지사항 수정",
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _titleController.text.trim().isEmpty ? "제목을 입력해주세요" : _titleController.text.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _titleController.text.trim().isEmpty
                          ? Colors.white.withOpacity(0.5)
                          : Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      height: 1.3,
                      letterSpacing: -0.5,
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  // ══════════════════════════════════════════
  // 카테고리 카드
  // ══════════════════════════════════════════

  Widget _buildCategoryCard(Color color) {
    return _card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionLabel(Icons.group_work_rounded, "공지 대상 부서", color),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _categories.map((c) {
              final val = c['value']!;
              final sel = _selectedCategory == val;
              final cg  = _catGradient(val);
              return GestureDetector(
                onTap: () => setState(() => _selectedCategory = val),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    gradient: sel
                        ? LinearGradient(colors: cg)
                        : null,
                    color: sel ? null : Colors.black.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: sel ? Colors.transparent : Colors.black.withOpacity(0.07),
                    ),
                    boxShadow: sel
                        ? [BoxShadow(color: cg[0].withOpacity(0.35), blurRadius: 8, offset: const Offset(0, 3))]
                        : [],
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (sel) ...[
                      Icon(_catIcon(val), color: Colors.white, size: 14),
                      const SizedBox(width: 6),
                    ],
                    Text(c['label']!,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: sel ? Colors.white : const Color(0xFF6B7280),
                        )),
                  ]),
                ),
              );
            }).toList(),
          ),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════
  // 이미지 카드
  // ══════════════════════════════════════════

  Widget _buildImageCard(Color color) {
    final hasImage = _imageBytes != null ||
        (_existingImageUrl != null && _existingImageUrl!.isNotEmpty);
    return _card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionLabel(Icons.image_rounded, "첨부 이미지", color),
          const SizedBox(height: 14),
          if (hasImage)
            _imagePreview(color)
          else
            _imageEmpty(color),
        ]),
      ),
    );
  }

  Widget _imagePreview(Color color) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(children: [
        SizedBox(
          width: double.infinity,
          height: 200,
          child: _imageBytes != null
              ? Image.memory(_imageBytes!, fit: BoxFit.cover)
              : Image.network(
                  _existingImageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey[100],
                    child: const Center(child: Text("이미지를 표시할 수 없습니다.")),
                  ),
                ),
        ),
        // 상단 오버레이
        Positioned(
          top: 0, left: 0, right: 0,
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withOpacity(0.4), Colors.transparent],
              ),
            ),
          ),
        ),
        Positioned(
          top: 10, left: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withOpacity(0.85),
              borderRadius: BorderRadius.circular(99),
            ),
            child: const Text("미리보기",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
          ),
        ),
        Positioned(
          top: 10, right: 10,
          child: Row(children: [
            _overlayBtn(Icons.edit_rounded, "변경", _pickImage),
            const SizedBox(width: 8),
            _overlayBtn(Icons.delete_outline_rounded, "삭제", () => setState(() {
              _pickedFile       = null;
              _imageBytes       = null;
              _existingImageUrl = null;
            })),
          ]),
        ),
      ]),
    );
  }

  Widget _imageEmpty(Color color) {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        width: double.infinity,
        height: 130,
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.18), width: 1.5),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: _catGradient(_selectedCategory)),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: color.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: const Icon(Icons.add_photo_alternate_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 10),
          Text("이미지 변경 (선택)",
              style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 14)),
          const SizedBox(height: 4),
          Text("탭해서 갤러리에서 선택",
              style: TextStyle(color: Colors.black.withOpacity(0.4), fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _overlayBtn(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: Row(children: [
          Icon(icon, color: Colors.white, size: 15),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════
  // 입력 카드
  // ══════════════════════════════════════════

  Widget _buildInputCard(Color color) {
    return _card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionLabel(Icons.subject_rounded, "공지 내용 수정", color),
          const SizedBox(height: 18),

          // 제목
          _inputLabel("공지 제목", "$_titleLen자", color),
          const SizedBox(height: 8),
          _inputField(
            controller: _titleController,
            hint: "사원들이 한눈에 알아볼 수 있는 제목",
            icon: Icons.title_rounded,
            color: color,
            maxLines: 1,
          ),
          const SizedBox(height: 18),

          // 내용
          _inputLabel("상세 내용", "$_contentLen자", color),
          const SizedBox(height: 8),
          _inputField(
            controller: _contentController,
            hint: "전달할 내용을 자세히 적어주세요.\n링크(https://...)를 입력하면 하이퍼링크로 표시됩니다.",
            icon: Icons.notes_rounded,
            color: color,
            maxLines: 8,
          ),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════
  // 제출 버튼
  // ══════════════════════════════════════════

  Widget _buildSubmitButton(List<Color> grad, Color color) {
    return GestureDetector(
      onTap: _isSaving ? null : _updateNotice,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: double.infinity,
        height: 58,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: grad, begin: Alignment.centerLeft, end: Alignment.centerRight),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.4), blurRadius: 18, offset: const Offset(0, 8)),
          ],
        ),
        child: Center(
          child: _isSaving
              ? const SizedBox(width: 24, height: 24,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
              : const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Text("수정 완료하기",
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                ]),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════
  // Atoms
  // ══════════════════════════════════════════

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(20), child: child),
    );
  }

  Widget _sectionLabel(IconData icon, String label, Color color) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
      const SizedBox(width: 10),
      Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF1A1D2E))),
    ]);
  }

  Widget _inputLabel(String label, String right, Color color) {
    return Row(children: [
      Text(label,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.black.withOpacity(0.6))),
      const Spacer(),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(right,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
      ),
    ]);
  }

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required Color color,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      textInputAction: maxLines == 1 ? TextInputAction.next : TextInputAction.newline,
      style: const TextStyle(fontSize: 15, color: Color(0xFF1A1D2E), height: 1.6),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400], fontWeight: FontWeight.w500, height: 1.5),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 14, right: 10),
          child: Icon(icon, color: color, size: 20),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        alignLabelWithHint: true,
        filled: true,
        fillColor: const Color(0xFFF6F8FC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color.withOpacity(0.08), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color.withOpacity(0.7), width: 1.8),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: maxLines == 1 ? 14 : 16,
        ),
      ),
    );
  }
}