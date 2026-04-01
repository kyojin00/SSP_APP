import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'write_suggestion_screen.dart';

class SuggestionScreen extends StatefulWidget {
  final bool isAdmin;
  const SuggestionScreen({Key? key, required this.isAdmin}) : super(key: key);

  @override
  State<SuggestionScreen> createState() => _SuggestionScreenState();
}

class _SuggestionScreenState extends State<SuggestionScreen> {
  final supabase = Supabase.instance.client;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: const Text("건의 및 신고함",
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh_rounded))
        ],
      ),
      body: _buildListStream(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const WriteSuggestionScreen())),
        backgroundColor: Colors.indigo[700],
        elevation: 4,
        icon: const Icon(Icons.edit_note_rounded, color: Colors.white),
        label: const Text("의견 작성",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildListStream() {
    final myId = supabase.auth.currentUser?.id;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase
          .from('suggestions')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        final items = snapshot.data ?? [];

        if (items.isEmpty) {
          return Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.inbox_rounded, size: 60, color: Colors.grey[300]),
              const SizedBox(height: 16),
              const Text("접수된 의견이 없습니다.",
                  style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
            ]),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
          itemCount: items.length,
          itemBuilder: (context, index) =>
              _suggestionCard(items[index], myId),
        );
      },
    );
  }

  Future<void> _deleteSuggestion(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('글 삭제',
            style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text('이 건의/신고를 삭제하시겠습니까?\n삭제 후 복구할 수 없습니다.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await supabase.from('suggestions').delete().eq('id', item['id']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('삭제되었습니다.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('삭제 실패: $e')));
      }
    }
  }

  Widget _suggestionCard(Map<String, dynamic> item, String? myId) {
    final isAnonymous = item['is_anonymous'] ?? true;
    final status      = item['status'] ?? 'RECEIVED';
    final isMine      = myId != null && item['user_id'] == myId;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => SuggestionDetailScreen(
                item: item, isAdmin: widget.isAdmin))),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            _buildCategoryIcon(item['category']),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(item['title'],
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Row(children: [
                  Text(
                    isAnonymous
                        ? "익명 제보"
                        : "${item['reporter_name'] ?? '성명불상'}",
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.indigo[400],
                        fontWeight: FontWeight.w600),
                  ),
                  Text(
                    "  •  ${DateFormat('MM/dd').format(DateTime.parse(item['created_at']))}",
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  if (isMine) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: Colors.indigo.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(5)),
                      child: const Text('내 글',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.indigo)),
                    ),
                  ],
                ]),
              ]),
            ),
            const SizedBox(width: 8),
            Column(mainAxisSize: MainAxisSize.min, children: [
              _statusBadge(status),
              // 내 글이면 삭제 버튼
              if (isMine) ...[
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => _deleteSuggestion(item),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(7)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.delete_outline_rounded,
                          size: 12, color: Colors.red),
                      SizedBox(width: 3),
                      Text('삭제',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.red)),
                    ]),
                  ),
                ),
              ],
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _buildCategoryIcon(String? category) {
    IconData icon;
    Color color;
    switch (category) {
      case '인사/노무':
        icon = Icons.people_alt_rounded;
        color = Colors.blue;
        break;
      case '안전보건':
        icon = Icons.health_and_safety_rounded;
        color = Colors.orange;
        break;
      case '생산현장':
        icon = Icons.precision_manufacturing_rounded;
        color = Colors.green;
        break;
      default:
        icon = Icons.campaign_rounded;
        color = Colors.indigo;
    }
    return Container(
      width: 48, height: 48,
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, color: color, size: 24),
    );
  }

  Widget _statusBadge(String status) {
    Color color;
    String label;
    if (status == 'PROGRESS') {
      color = Colors.blue;
      label = "검토중";
    } else if (status == 'COMPLETED') {
      color = Colors.green;
      label = "완료";
    } else {
      color = Colors.grey;
      label = "접수";
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8)),
      child: Text(label,
          style: TextStyle(
              color: color, fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }
}

// ══════════════════════════════════════════
// 상세 화면
// ══════════════════════════════════════════
class SuggestionDetailScreen extends StatefulWidget {
  final Map<String, dynamic> item;
  final bool isAdmin;
  const SuggestionDetailScreen(
      {Key? key, required this.item, required this.isAdmin})
      : super(key: key);

  @override
  State<SuggestionDetailScreen> createState() =>
      _SuggestionDetailScreenState();
}

class _SuggestionDetailScreenState extends State<SuggestionDetailScreen> {
  late TextEditingController _commentController;
  String? _status;

  @override
  void initState() {
    super.initState();
    _status = widget.item['status'] ?? 'RECEIVED';
    _commentController =
        TextEditingController(text: widget.item['admin_comment'] ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final date = DateFormat('yyyy.MM.dd HH:mm')
        .format(DateTime.parse(item['created_at']));
    final myId  = Supabase.instance.client.auth.currentUser?.id;
    final isMine = myId != null && item['user_id'] == myId;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("의견 상세 내역",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          // 내 글이면 삭제 버튼
          if (isMine)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              tooltip: '삭제',
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                    title: const Text('글 삭제',
                        style: TextStyle(fontWeight: FontWeight.w900)),
                    content: const Text('이 건의/신고를 삭제하시겠습니까?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('취소')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10))),
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('삭제'),
                      ),
                    ],
                  ),
                );
                if (confirmed != true || !mounted) return;
                await Supabase.instance.client
                    .from('suggestions')
                    .delete()
                    .eq('id', item['id']);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('삭제되었습니다.')));
                }
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            color: Colors.indigo[900],
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              _detailBadge(item['category']),
              const SizedBox(height: 16),
              Text(item['title'],
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.3)),
              const SizedBox(height: 12),
              Text("작성일: $date",
                  style: const TextStyle(color: Colors.white60, fontSize: 13)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              const Text("제보 내용",
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey)),
              const SizedBox(height: 12),
              Text(item['content'],
                  style: const TextStyle(
                      fontSize: 16, height: 1.7, color: Colors.black87)),
              const SizedBox(height: 40),
              const Divider(),
              const SizedBox(height: 30),
              if (widget.isAdmin)
                _buildAdminActionPanel()
              else
                _buildUserResponseView(item['admin_comment']),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildAdminActionPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.indigo.withOpacity(0.1)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.admin_panel_settings_rounded,
              color: Colors.indigo, size: 20),
          SizedBox(width: 8),
          Text("관리자 답변 및 상태 관리",
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.indigo)),
        ]),
        const SizedBox(height: 20),
        DropdownButtonFormField<String>(
          value: _status,
          items: const [
            DropdownMenuItem(value: 'RECEIVED', child: Text("📥 신규 접수")),
            DropdownMenuItem(value: 'PROGRESS', child: Text("⚙️ 검토 및 진행 중")),
            DropdownMenuItem(value: 'COMPLETED', child: Text("✅ 처리 완료")),
          ],
          onChanged: (v) => setState(() => _status = v),
          decoration: _adminInputDecoration("처리 상태"),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _commentController,
          maxLines: 5,
          decoration: _adminInputDecoration("답변 내용 입력"),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity, height: 54,
          child: ElevatedButton(
            onPressed: _saveAdminResponse,
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo[700],
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            child: const Text("답변 등록하기",
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ]),
    );
  }

  Future<void> _saveAdminResponse() async {
    await Supabase.instance.client.from('suggestions').update({
      'status': _status,
      'admin_comment': _commentController.text.trim(),
    }).eq('id', widget.item['id']);
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("답변이 저장되었습니다.")));
  }

  Widget _buildUserResponseView(String? comment) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text("관리자 답변",
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
      const SizedBox(height: 12),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: Colors.indigo.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.indigo.withOpacity(0.1))),
        child: Text(
          comment ?? "담당자가 내용을 확인 중입니다. 잠시만 기다려 주세요.",
          style: TextStyle(
              fontSize: 15,
              height: 1.6,
              color: Colors.indigo[900],
              fontStyle:
                  comment == null ? FontStyle.italic : FontStyle.normal),
        ),
      ),
    ]);
  }

  InputDecoration _adminInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none),
    );
  }

  Widget _detailBadge(String? text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8)),
      child: Text(text ?? "기타",
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }
}