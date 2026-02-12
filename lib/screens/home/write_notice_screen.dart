import 'dart:typed_data'; // Uint8List 사용을 위해 추가
import 'package:flutter/foundation.dart' show kIsWeb; // 웹 여부 확인용
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WriteNoticeScreen extends StatefulWidget {
  const WriteNoticeScreen({super.key});

  @override
  State<WriteNoticeScreen> createState() => _WriteNoticeScreenState();
}

class _WriteNoticeScreenState extends State<WriteNoticeScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  String _selectedCategory = 'ALL';
  bool _isSaving = false;

  // 💡 웹/모바일 공용을 위해 File 대신 Uint8List와 XFile 사용
  Uint8List? _imageBytes; 
  XFile? _pickedFile;
  final ImagePicker _picker = ImagePicker();

  final List<Map<String, String>> _categories = [
    {'value': 'ALL', 'label': '전체 공지'},
    {'value': 'OFFICE', 'label': '사무실'},
    {'value': 'STEEL', 'label': '스틸'}, 
    {'value': 'BOX', 'label': '박스'},
    // 💡 사원님만 사용할 비밀 테스트 카테고리 추가
    // {'value': 'TEST', 'label': '비밀 테스트'}, 
  ];
  static const String _webhookSecret = 'sspaap_key_123';

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  // 💡 이미지 선택 로직 수정
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 70,
      );
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes(); // 파일을 바이트로 읽음
        setState(() {
          _pickedFile = pickedFile;
          _imageBytes = bytes;
        });
      }
    } catch (e) {
      _showSnackBar("이미지 선택 실패: $e");
    }
  }

  Future<void> _saveNotice() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty || content.isEmpty) {
      _showSnackBar("제목과 내용을 입력해주세요.");
      return;
    }

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      _showSnackBar("로그인 상태를 확인해주세요.");
      return;
    }

    setState(() => _isSaving = true);

    try {
      String? imageUrl;

      // 1) 이미지 업로드 (Binary 방식 사용)
      if (_imageBytes != null && _pickedFile != null) {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        final path = 'notices/$fileName';

        // 💡 .upload 대신 .uploadBinary를 사용하여 아이폰 웹 에러 해결
        await supabase.storage.from('notice-images').uploadBinary(
          path, 
          _imageBytes!,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
        
        imageUrl = supabase.storage.from('notice-images').getPublicUrl(path);
      }

      // 2) 공지 저장
      final inserted = await supabase
          .from('notices')
          .insert({
            'title': title,
            'content': content,
            'target_category': _selectedCategory,
            'author_id': user.id,
            'image_url': imageUrl,
          })
          .select()
          .single();

      // 3) Edge Function 호출
      final pushOk = await _triggerPushNotification(
        noticeId: inserted['id'],
        title: title,
        content: content,
        category: _selectedCategory,
      );

      if (!mounted) return;

      if (pushOk) {
        _showSnackBar("공지가 등록되고 알림이 발송되었습니다.");
      } else {
        _showSnackBar("공지는 등록됐지만, 알림 발송에 일부 실패가 있을 수 있어요.");
      }

      Navigator.pop(context, true); // 성공 신호(true) 전달
    } catch (e) {
      debugPrint("저장 오류: $e");
      if (!mounted) return;
      _showSnackBar("저장 실패: $e");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<bool> _triggerPushNotification({
    required dynamic noticeId,
    required String title,
    required String content,
    required String category,
  }) async {
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'send_notice_push',
        headers: {
          'x-webhook-secret': _webhookSecret,
        },
        body: {
          'notice_id': noticeId,
          'title': title,
          'content': content,
          'target_category': category,
          'secret': _webhookSecret,
        },
      );

      if (res.status == 200 || res.status == 207) return true;
      return false;
    } catch (e) {
      debugPrint("알림 트리거 실패: $e");
      return false;
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("새 공지사항 작성")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildImagePicker(),
            const SizedBox(height: 16),
            _buildCategoryDropdown(),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: '제목', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _contentController,
              decoration: const InputDecoration(labelText: '내용', border: OutlineInputBorder()),
              maxLines: 8,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSaving ? null : _saveNotice,
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              child: _isSaving
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text("공지 올리기"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _showImageSourceOptions,
      child: Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[400]!),
        ),
        child: _imageBytes != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                // 💡 웹/앱 공통 미리보기를 위해 Image.memory 사용
                child: Image.memory(_imageBytes!, fit: BoxFit.cover),
              )
            : const Center(
                child: Icon(Icons.camera_alt, size: 40, color: Colors.grey),
              ),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedCategory,
      decoration: const InputDecoration(labelText: '공지 대상', border: OutlineInputBorder()),
      items: _categories.map((c) => DropdownMenuItem(value: c['value'], child: Text(c['label']!))).toList(),
      onChanged: (val) => setState(() => _selectedCategory = val!),
    );
  }

  void _showImageSourceOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('카메라'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('갤러리'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }
}