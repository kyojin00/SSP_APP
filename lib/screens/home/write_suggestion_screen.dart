import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WriteSuggestionScreen extends StatefulWidget {
  const WriteSuggestionScreen({Key? key}) : super(key: key);

  @override
  State<WriteSuggestionScreen> createState() => _WriteSuggestionScreenState();
}

class _WriteSuggestionScreenState extends State<WriteSuggestionScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  String _category = '인사/노무';
  bool _isAnonymous = true;
  bool _isSubmitting = false;

  Future<void> _submit() async {
    if (_titleController.text.trim().isEmpty || _contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("제목과 내용을 모두 입력해주세요."), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      await Supabase.instance.client.from('suggestions').insert({
        'user_id': user?.id,
        'category': _category,
        'title': _titleController.text.trim(),
        'content': _contentController.text.trim(),
        'is_anonymous': _isAnonymous,
      });
      
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("소중한 의견이 제출되었습니다."), backgroundColor: Colors.indigo),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("제출 실패: $e"), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: const Text("건의/신고 작성", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 안내 문구 카드
            _buildInfoCard(),
            const SizedBox(height: 24),

            // 카테고리 선택
            _buildSectionTitle("제보 분야"),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _category,
              items: ['인사/노무', '생산현장', '안전보건', '시설관리', '기타']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => _category = v!),
              decoration: _inputDecoration("분야를 선택해주세요"),
            ),
            const SizedBox(height: 24),

            // 익명성 설정 카드
            _buildAnonymousSwitch(),
            const SizedBox(height: 24),

            // 제목 입력
            _buildSectionTitle("제목"),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              decoration: _inputDecoration("제목을 입력하세요"),
            ),
            const SizedBox(height: 24),

            // 내용 입력
            _buildSectionTitle("상세 내용"),
            const SizedBox(height: 8),
            TextField(
              controller: _contentController,
              maxLines: 10,
              decoration: _inputDecoration("사안의 일시, 장소, 내용 등을 구체적으로 적어주시면 빠른 처리에 도움이 됩니다."),
            ),
            const SizedBox(height: 32),

            // 제출 버튼
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("제출하기", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }

  // 섹션 제목 스타일
  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87));
  }

  // 상단 안내 정보 카드
  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.indigo.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.indigo.withOpacity(0.1)),
      ),
      child: Row(
        children: const [
          Icon(Icons.info_outline, color: Colors.indigo, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              "회사 발전을 위한 소중한 의견을 들려주세요.\n제출하신 내용은 담당자가 확인 후 처리됩니다.",
              style: TextStyle(fontSize: 13, color: Colors.indigo, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  // 익명 스위치 커스텀 디자인
  Widget _buildAnonymousSwitch() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: SwitchListTile(
        title: const Text("익명 제출 활성화", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: const Text("체크 시 작성자 정보가 비공개 처리됩니다.", style: TextStyle(fontSize: 12)),
        value: _isAnonymous,
        onChanged: (v) => setState(() => _isAnonymous = v),
        activeColor: Colors.indigo,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  // 공통 입력창 스타일
  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.black.withOpacity(0.05)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.indigo, width: 1.5),
      ),
    );
  }
}