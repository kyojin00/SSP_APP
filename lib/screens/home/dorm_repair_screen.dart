import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class DormRepairScreen extends StatefulWidget {
  final Map<String, dynamic> userProfile;
  final bool isAdmin;

  const DormRepairScreen({Key? key, required this.userProfile, required this.isAdmin}) : super(key: key);

  @override
  State<DormRepairScreen> createState() => _DormRepairScreenState();
}

class _DormRepairScreenState extends State<DormRepairScreen> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _reports = [];
  String _filterStatus = '전체'; // 필터 상태

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  Future<void> _fetchReports() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      var query = supabase.from('dorm_repairs').select('*');
      if (!widget.isAdmin) {
        query = query.eq('user_id', supabase.auth.currentUser!.id);
      }
      final data = await query.order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _reports = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("신고 로드 에러: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openRepairDialog() async {
    // DB에서 호실 목록 먼저 로드
    List<Map<String, dynamic>> rooms = [];
    try {
      final data = await supabase.from('dorm_rooms').select('id, room_number').order('room_number');
      rooms = List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint("호실 로드 실패: $e");
    }
    if (!mounted) return;

    String? selectedRoomNumber;
    final contentController = TextEditingController();
    String category = '시설고장';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 드래그 핸들
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 20),
                const Text("고장 / 비품 신고", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 20),

                // 카테고리 칩 선택
                const Text("카테고리", style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ['시설고장', '비품요청', '기타문의'].map((s) {
                    final selected = category == s;
                    return ChoiceChip(
                      label: Text(s),
                      selected: selected,
                      onSelected: (_) => setDialogState(() => category = s),
                      selectedColor: const Color(0xFF2E6BFF),
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // 호실 선택 (DB 목록)
                const Text("호실 선택", style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                rooms.isEmpty
                    ? const Text("호실 정보를 불러올 수 없습니다.", style: TextStyle(color: Colors.grey, fontSize: 13))
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: rooms.map((room) {
                          final roomNum = room['room_number'] as String;
                          final isSelected = selectedRoomNumber == roomNum;
                          return GestureDetector(
                            onTap: () => setDialogState(() => selectedRoomNumber = roomNum),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF2E6BFF) : Colors.grey.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF2E6BFF) : Colors.grey.withOpacity(0.2),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.door_front_door_rounded, size: 14,
                                      color: isSelected ? Colors.white : Colors.grey),
                                  const SizedBox(width: 5),
                                  Text(roomNum, style: TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.bold,
                                    color: isSelected ? Colors.white : Colors.black87,
                                  )),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                const SizedBox(height: 16),

                // 내용 입력
                TextField(
                  controller: contentController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: "상세 내용",
                    hintText: "고장 내용이나 요청 사항을 적어주세요.",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (selectedRoomNumber == null || contentController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("호실과 내용을 모두 입력해주세요."), behavior: SnackBarBehavior.floating),
                        );
                        return;
                      }
                      await supabase.from('dorm_repairs').insert({
                        'user_id': supabase.auth.currentUser!.id,
                        'full_name': widget.userProfile['full_name'],
                        'category': category,
                        'room_number': selectedRoomNumber,
                        'content': contentController.text.trim(),
                        'status': '접수완료',
                      });
                      if (context.mounted) Navigator.pop(context);
                      _fetchReports();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E6BFF),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text("신고 등록", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _updateStatus(String id, String newStatus) async {
    try {
      await supabase.from('dorm_repairs').update({'status': newStatus}).eq('id', id);
      _fetchReports();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("상태가 '$newStatus'(으)로 변경되었습니다."),
          backgroundColor: _statusColor(newStatus),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint("상태 변경 실패: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // 필터 적용
    final filtered = _filterStatus == '전체'
        ? _reports
        : _reports.where((r) => r['status'] == _filterStatus).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: const Text("고장 및 비품 신고", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 상단 요약 + 필터 바
                _buildSummaryAndFilter(),
                // 목록
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _fetchReports,
                    child: filtered.isEmpty
                        ? _buildEmpty()
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) => _buildRepairCard(filtered[index]),
                          ),
                  ),
                ),
              ],
            ),
      floatingActionButton: !widget.isAdmin
          ? FloatingActionButton.extended(
              onPressed: _openRepairDialog,
              label: const Text("신고하기", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              icon: const Icon(Icons.add_comment_rounded, color: Colors.white),
              backgroundColor: const Color(0xFF2E6BFF),
            )
          : null,
    );
  }

  // 요약 카운트 + 필터 칩
  Widget _buildSummaryAndFilter() {
    final total = _reports.length;
    final pending = _reports.where((r) => r['status'] == '접수완료').length;
    final inProgress = _reports.where((r) => r['status'] == '수리중').length;
    final done = _reports.where((r) => r['status'] == '완료').length;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 요약 카운트 행
          Row(
            children: [
              _summaryChip("전체 $total", Colors.blueGrey),
              const SizedBox(width: 8),
              _summaryChip("접수 $pending", Colors.grey),
              const SizedBox(width: 8),
              _summaryChip("수리중 $inProgress", Colors.orange),
              const SizedBox(width: 8),
              _summaryChip("완료 $done", Colors.green),
            ],
          ),
          const SizedBox(height: 10),
          // 필터 칩
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['전체', '접수완료', '수리중', '완료'].map((s) {
                final selected = _filterStatus == s;
                return Padding(
                  padding: const EdgeInsets.only(right: 8, bottom: 10),
                  child: FilterChip(
                    label: Text(s),
                    selected: selected,
                    onSelected: (_) => setState(() => _filterStatus = s),
                    selectedColor: const Color(0xFF2E6BFF).withOpacity(0.15),
                    checkmarkColor: const Color(0xFF2E6BFF),
                    labelStyle: TextStyle(
                      color: selected ? const Color(0xFF2E6BFF) : Colors.grey[700],
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    ),
                    side: BorderSide(color: selected ? const Color(0xFF2E6BFF) : Colors.grey.withOpacity(0.3)),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_rounded, size: 52, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text("해당하는 신고 내역이 없습니다.", style: TextStyle(color: Colors.grey[400])),
        ],
      ),
    );
  }

  Widget _buildRepairCard(Map<String, dynamic> item) {
    final status = item['status'] as String;
    final color = _statusColor(status);
    final icon = _statusIcon(status);
    final category = item['category'] as String;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          // 카드 상단: 카테고리 + 상태
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Text(status, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.blueGrey.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                  child: Text(category, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                ),
              ],
            ),
          ),

          // 카드 본문
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 호실 + 이름
                Row(
                  children: [
                    const Icon(Icons.door_front_door_rounded, size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(item['room_number'], style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    const Spacer(),
                    Text(
                      item['full_name'],
                      style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // 내용
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F8FB),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(item['content'], style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87)),
                ),
                const SizedBox(height: 10),

                // 날짜
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded, size: 13, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('yyyy.MM.dd HH:mm').format(DateTime.parse(item['created_at'])),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),

                // 관리자 상태 변경 버튼
                if (widget.isAdmin) ...[
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  const Text("상태 변경", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: ['접수완료', '수리중', '완료'].map((s) {
                      final isSelected = status == s;
                      final btnColor = _statusColor(s);
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            child: OutlinedButton(
                              onPressed: isSelected ? null : () => _updateStatus(item['id'].toString(), s),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: isSelected ? btnColor : Colors.transparent,
                                side: BorderSide(color: isSelected ? btnColor : Colors.grey.withOpacity(0.3)),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: Text(
                                s,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : Colors.grey,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case '완료': return Colors.green;
      case '수리중': return Colors.orange;
      default: return Colors.blueGrey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case '완료': return Icons.check_circle_rounded;
      case '수리중': return Icons.build_rounded;
      default: return Icons.inbox_rounded;
    }
  }
}