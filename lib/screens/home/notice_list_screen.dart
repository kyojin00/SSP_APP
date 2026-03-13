import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'notice_detail_screen.dart';
import 'write_notice_screen.dart';

class NoticeListScreen extends StatefulWidget {
  final bool isAdmin;
  final String myDept;

  const NoticeListScreen({
    Key? key,
    required this.isAdmin,
    required this.myDept,
  }) : super(key: key);

  @override
  State<NoticeListScreen> createState() => _NoticeListScreenState();
}

class _NoticeListScreenState extends State<NoticeListScreen> {
  final supabase = Supabase.instance.client;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: const Text("공지 / 지시", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: Colors.black.withOpacity(0.05), height: 1.0),
        ),
      ),
      body: _buildNoticeStream(),
      floatingActionButton: widget.isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WriteNoticeScreen()),
              ),
              backgroundColor: const Color(0xFF2E6BFF),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text("공지작성", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }

  Widget _buildNoticeStream() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase.from('notices').stream(primaryKey: ['id']).order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (snapshot.hasError) return _buildStatusMessage("데이터를 불러올 수 없습니다.");
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(strokeWidth: 2));

        final allNotices = snapshot.data!;
        final filteredNotices = allNotices.where((notice) {
          final target = notice['target_category'];
          if (target == 'TEST') return widget.myDept == 'TEST';
          if (widget.isAdmin) return true;
          return target == 'ALL' || target == widget.myDept;
        }).toList();

        if (filteredNotices.isEmpty) return _buildStatusMessage("표시할 공지사항이 없습니다.");

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredNotices.length,
          itemBuilder: (context, index) {
            final notice = filteredNotices[index];
            final createdAt = DateTime.parse(notice['created_at']).toLocal();
            
            // 날짜 구분선 로직
            bool showDateHeader = false;
            if (index == 0) {
              showDateHeader = true;
            } else {
              final prevDate = DateTime.parse(filteredNotices[index - 1]['created_at']).toLocal();
              if (DateFormat('yyyy-MM-dd').format(createdAt) != DateFormat('yyyy-MM-dd').format(prevDate)) {
                showDateHeader = true;
              }
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showDateHeader) _buildDateDivider(createdAt),
                _noticeTile(notice, createdAt),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDateDivider(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final itemDate = DateTime(date.year, date.month, date.day);

    String dateText = (itemDate == today) ? "오늘" : (itemDate == yesterday) ? "어제" : DateFormat('yyyy년 MM월 dd일').format(date);

    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 12, left: 4),
      child: Row(
        children: [
          Text(dateText, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF2E6BFF))),
          const SizedBox(width: 12),
          Expanded(child: Container(height: 1, color: Colors.black.withOpacity(0.05))),
        ],
      ),
    );
  }

  Widget _noticeTile(Map<String, dynamic> notice, DateTime createdAt) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(0.03)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => NoticeDetailScreen(notice: notice, isAdmin: widget.isAdmin)),
        ),
        leading: _categoryIcon(notice['target_category'] ?? 'ALL'),
        title: Text(notice['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            "${DateFormat('HH:mm').format(createdAt)}  |  ${notice['content']}",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.black.withOpacity(0.5), fontSize: 13),
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.black26),
      ),
    );
  }

  Widget _categoryIcon(String category) {
    Color color = Colors.blue;
    IconData icon = Icons.campaign;
    if (category == 'OFFICE') { color = Colors.blue; icon = Icons.business; }
    else if (category == 'STEEL') { color = Colors.blueGrey; icon = Icons.precision_manufacturing; }
    else if (category == 'BOX') { color = Colors.orange; icon = Icons.inventory_2; }
    
    return Container(
      width: 44, height: 44,
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
      child: Icon(icon, color: color, size: 22),
    );
  }

  Widget _buildStatusMessage(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.info_outline, color: Colors.black12, size: 60),
          const SizedBox(height: 12),
          Text(msg, style: const TextStyle(color: Colors.black38, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}