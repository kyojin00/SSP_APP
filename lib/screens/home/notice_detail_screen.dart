import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:translator/translator.dart';
import 'edit_notice_screen.dart';

class NoticeDetailScreen extends StatefulWidget {
  final Map<String, dynamic> notice;
  final bool isAdmin;

  const NoticeDetailScreen({Key? key, required this.notice, required this.isAdmin}) : super(key: key);

  @override
  State<NoticeDetailScreen> createState() => _NoticeDetailScreenState();
}

class _NoticeDetailScreenState extends State<NoticeDetailScreen> {
  bool _isDeleting = false;
  
  // 💡 번역 관련 상태 변수
  String _displayTitle = "";
  String _displayContent = "";
  bool _isTranslating = false;
  final GoogleTranslator _translator = GoogleTranslator();

  // 💡 황교진 사원님의 Supabase UUID를 여기에 넣으세요 (비밀 필터링용)
  // 예: "550e8400-e29b-41d4-a716-446655440000"
  final String _myUuid = "b72e0fb3-1632-480c-afff-33f8348e2aeb";

  @override
  void initState() {
    super.initState();
    _displayTitle = widget.notice['title'];
    _displayContent = widget.notice['content'];
    _markAsRead();
  }

  // 💡 다국어 번역 핵심 로직 (에러 방지 강화 버전)
  Future<void> _translateTo(String languageCode) async {
    if (languageCode == 'ko') {
      setState(() {
        _displayTitle = widget.notice['title'];
        _displayContent = widget.notice['content'];
      });
      return;
    }

    setState(() => _isTranslating = true);
    try {
      // 원문이 이미 해당 언어일 경우 translator 패키지가 에러를 낼 수 있으므로 예외처리
      final titleTrans = await _translator.translate(widget.notice['title'], to: languageCode);
      final contentTrans = await _translator.translate(widget.notice['content'], to: languageCode);
      
      setState(() {
        _displayTitle = titleTrans.text;
        _displayContent = contentTrans.text;
      });
    } catch (e) {
      debugPrint("번역 에러: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("번역 중 오류가 발생했습니다. (동일 언어 여부 확인)")),
        );
      }
    } finally {
      if (mounted) setState(() => _isTranslating = false);
    }
  }

  Future<void> _markAsRead() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // 💡 테스트(TEST) 카테고리 공지는 읽음 처리를 남기지 않도록 설정 (선택 사항)
      if (widget.notice['target_category'] == 'TEST') return;

      await Supabase.instance.client.from('notice_reads').upsert({
        'notice_id': widget.notice['id'],
        'user_id': user.id,
        'read_at': DateTime.now().toIso8601String(),
      }, onConflict: 'notice_id,user_id');
    } catch (e) {
      debugPrint("읽음 처리 중 오류: $e");
    }
  }

  Future<void> _deleteNotice(BuildContext context) async {
    setState(() => _isDeleting = true);
    try {
      await Supabase.instance.client.from('notices').delete().eq('id', widget.notice['id']);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("공지사항이 정상적으로 삭제되었습니다."), backgroundColor: Colors.blueGrey),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("삭제 실패: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<List<Map<String, dynamic>>> _getReaderNames(List<Map<String, dynamic>> logs) async {
    final userIds = logs.map((log) => log['user_id'].toString()).toSet().toList();
    if (userIds.isEmpty) return [];
    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('full_name, dept_category')
          .filter('id', 'in', userIds);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    // 💡 보안 로직: 만약 카테고리가 'TEST'인데 접속자가 사원님이 아니라면 화면을 차단
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (widget.notice['target_category'] == 'TEST' && (currentUser == null || currentUser.id != _myUuid)) {
      return const Scaffold(body: Center(child: Text("접근 권한이 없는 공지입니다.")));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("공지 상세 내용"),
        elevation: 0,
        actions: [
          if (widget.isAdmin) ...[
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => EditNoticeScreen(notice: widget.notice)),
                );
                if (result == true && mounted) Navigator.pop(context, true);
              },
            ),
            IconButton(
              icon: _isDeleting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red))
                  : const Icon(Icons.delete_forever, color: Colors.red),
              onPressed: _isDeleting ? null : () => _showDeleteDialog(),
            ),
          ]
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTranslationBar(), 
            
            if (_isTranslating) const LinearProgressIndicator(minHeight: 2),
            
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.isAdmin) ...[
                    _buildAdminStatistics(),
                    const SizedBox(height: 25),
                  ],
                  Row(
                    children: [
                      _buildCategoryBadge(widget.notice['target_category']),
                      const SizedBox(width: 10),
                      Text(
                        widget.notice['created_at'].toString().substring(0, 10),
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _displayTitle,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const Divider(height: 40, thickness: 1),
                  if (widget.notice['image_url'] != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          widget.notice['image_url'], 
                          width: double.infinity, 
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => 
                              const Center(child: Text("이미지를 표시할 수 없습니다.")),
                        ),
                      ),
                    ),
                  Text(
                    _displayContent,
                    style: const TextStyle(fontSize: 16, height: 1.7, color: Colors.black87),
                  ),
                  const SizedBox(height: 20),
                  _buildReadStatus(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTranslationBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.blueGrey[900],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.translate, size: 18, color: Colors.yellowAccent),
              SizedBox(width: 8),
              Text(
                "Select Language (번역)",
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildLangBtn("🇰🇷 KR", "ko"),
                _buildLangBtn("🇻🇳 VN", "vi"),
                _buildLangBtn("🇰🇭 KH", "km"),
                _buildLangBtn("🇹🇭 TH", "th"),
                _buildLangBtn("🇺🇿 UZ", "uz"),
                _buildLangBtn("🇺🇸 US", "en"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLangBtn(String label, String code) {
    return GestureDetector(
      onTap: () => _translateTo(code),
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  Widget _buildAdminStatistics() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client.from('notice_reads').stream(primaryKey: ['id']).eq('notice_id', widget.notice['id']),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final readLogs = snapshot.data!;
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _getReaderNames(readLogs),
          builder: (context, nameSnapshot) {
            if (!nameSnapshot.hasData) return const SizedBox();
            final readers = nameSnapshot.data!;
            return Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("📊 부서별 확인 현황 (관리자용)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 15)),
                  const SizedBox(height: 16),
                  _buildStatBar("사무실", readers.where((r) => r['dept_category'] == 'OFFICE').length, 13, Colors.blue),
                  const SizedBox(height: 10),
                  _buildStatBar("스틸", readers.where((r) => r['dept_category'] == 'STEEL').length, 33, Colors.indigo),
                  const SizedBox(height: 10),
                  _buildStatBar("박스", readers.where((r) => r['dept_category'] == 'BOX').length, 21, Colors.orange),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatBar(String label, int current, int total, Color color) {
    double ratio = total > 0 ? current / total : 0.0;
    if (ratio > 1.0) ratio = 1.0;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            Text("$current / $total 명", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(value: ratio, backgroundColor: color.withOpacity(0.1), valueColor: AlwaysStoppedAnimation(color), minHeight: 8),
        ),
      ],
    );
  }

  Widget _buildReadStatus() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client.from('notice_reads').stream(primaryKey: ['id']).eq('notice_id', widget.notice['id']),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final readLogs = snapshot.data!;
        final count = readLogs.length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(height: 50),
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 22),
                const SizedBox(width: 8),
                Text("확인 완료: $count명", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey)),
              ],
            ),
            const SizedBox(height: 16),
            if (widget.isAdmin && count > 0)
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _getReaderNames(readLogs),
                builder: (context, nameSnapshot) {
                  final users = nameSnapshot.data ?? [];
                  return Wrap(
                    spacing: 10, runSpacing: 10,
                    children: users.map((user) => Chip(
                      label: Text(user['full_name'] ?? '알 수 없음', style: const TextStyle(fontSize: 13)),
                      backgroundColor: Colors.blue.withOpacity(0.08),
                      avatar: const Icon(Icons.person, size: 16, color: Colors.blue),
                    )).toList(),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("삭제 확인"),
        content: const Text("이 공지사항을 정말 삭제하시겠습니까?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("취소")),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteNotice(context);
            },
            child: const Text("삭제", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBadge(String category) {
    Color badgeColor = Colors.blue;
    if (category == 'TEST') badgeColor = Colors.purple; // 테스트는 보라색으로 구분

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: badgeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(category, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: badgeColor)),
    );
  }
}