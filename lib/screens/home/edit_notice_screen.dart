import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditNoticeScreen extends StatefulWidget {
  final Map<String, dynamic> notice;
  const EditNoticeScreen({Key? key, required this.notice}) : super(key: key);

  @override
  _EditNoticeScreenState createState() => _EditNoticeScreenState();
}

class _EditNoticeScreenState extends State<EditNoticeScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late String _selectedCategory;
  String? _existingImageUrl;
  Uint8List? _imageBytes;
  XFile? _pickedFile;
  bool _isSaving = false;

  // 카테고리 목록 정의
  final List<Map<String, String>> _categories = [
    {'value': 'ALL', 'label': '전체 공지'},
    {'value': 'OFFICE', 'label': '사무실'},
    {'value': 'FIELD', 'label': '현장'},
    {'value': 'DORM', 'label': '기숙사'},
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.notice['title']);
    _contentController = TextEditingController(text: widget.notice['content']);
    _selectedCategory = widget.notice['target_category'] ?? 'ALL';
    _existingImageUrl = widget.notice['image_url'];
  }

  Future<void> _updateNotice() async {
    if (_titleController.text.trim().isEmpty) return;
    
    setState(() => _isSaving = true);
    try {
      String? imageUrl = _existingImageUrl;

      // 💡 새 이미지가 선택된 경우에만 업로드 진행
      if (_imageBytes != null && _pickedFile != null) {
        final path = 'notices/${DateTime.now().millisecondsSinceEpoch}.jpg';
        
        // 아이폰 웹 에러 방지를 위해 uploadBinary 사용
        await Supabase.instance.client.storage
            .from('notice-images')
            .uploadBinary(
              path, 
              _imageBytes!,
              fileOptions: const FileOptions(contentType: 'image/jpeg'),
            );
            
        imageUrl = Supabase.instance.client.storage
            .from('notice-images')
            .getPublicUrl(path);
      }

      // DB 업데이트 실행
      await Supabase.instance.client.from('notices').update({
        'title': _titleController.text.trim(),
        'content': _contentController.text.trim(),
        'target_category': _selectedCategory,
        'image_url': imageUrl,
      }).eq('id', widget.notice['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("수정이 완료되었습니다."), backgroundColor: Colors.blue),
        );
        Navigator.pop(context, true); 
      }
    } catch (e) {
      debugPrint("수정 에러 상세: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("수정 실패: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("공지사항 수정")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 이미지 영역
            GestureDetector(
              onTap: () async {
                final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
                if (picked != null) {
                  final bytes = await picked.readAsBytes();
                  setState(() { _pickedFile = picked; _imageBytes = bytes; });
                }
              },
              child: Container(
                height: 200, width: double.infinity,
                decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12)),
                child: _imageBytes != null 
                  ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(_imageBytes!, fit: BoxFit.cover))
                  : (_existingImageUrl != null 
                      ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(_existingImageUrl!, fit: BoxFit.cover))
                      : const Icon(Icons.add_a_photo, size: 40, color: Colors.grey)),
              ),
            ),
            const SizedBox(height: 16),

            // 💡 카테고리 선택 드롭다운 (이 부분이 있어야 수정이 가능함)
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(labelText: '공지 대상', border: OutlineInputBorder()),
              items: _categories.map((c) => DropdownMenuItem(
                value: c['value'], 
                child: Text(c['label']!)
              )).toList(),
              onChanged: (val) => setState(() => _selectedCategory = val!),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _titleController, 
              decoration: const InputDecoration(labelText: '제목', border: OutlineInputBorder())
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _contentController, 
              maxLines: 8, 
              decoration: const InputDecoration(labelText: '내용', border: OutlineInputBorder())
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _updateNotice,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                child: _isSaving 
                  ? const CircularProgressIndicator(color: Colors.white) 
                  : const Text("수정 완료", style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}