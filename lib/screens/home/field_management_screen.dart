import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'report_fault_screen.dart';

class FieldManagementScreen extends StatefulWidget {
  final bool isAdmin;
  const FieldManagementScreen({Key? key, required this.isAdmin}) : super(key: key);

  @override
  State<FieldManagementScreen> createState() => _FieldManagementScreenState();
}

class _FieldManagementScreenState extends State<FieldManagementScreen> {
  final supabase = Supabase.instance.client;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: const Text("현장관리 (설비고장)", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _buildReportStream(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportFaultScreen())),
        backgroundColor: Colors.orangeAccent,
        icon: const Icon(Icons.report_problem_rounded, color: Colors.white),
        label: const Text("고장 신고하기", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }

  Widget _buildReportStream() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase.from('equipment_reports').stream(primaryKey: ['id']).order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final reports = snapshot.data!;

        if (reports.isEmpty) return const Center(child: Text("접수된 고장 신고가 없습니다."));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: reports.length,
          itemBuilder: (context, index) {
            final report = reports[index];
            return _reportCard(report);
          },
        );
      },
    );
  }

  Widget _reportCard(Map<String, dynamic> report) {
    bool isUrgent = report['priority'] == 'URGENT';
    String status = report['status'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isUrgent ? Colors.redAccent.withOpacity(0.3) : Colors.black.withOpacity(0.05)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ReportDetailScreen(report: report, isAdmin: widget.isAdmin)),
            );
          },
          child: Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Hero(
                  tag: 'img_${report['id']}',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(report['image_url'], width: 60, height: 60, fit: BoxFit.cover),
                  ),
                ),
                title: Row(
                  children: [
                    if (isUrgent)
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                        child: const Text("긴급", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    Expanded(child: Text(report['title'], style: const TextStyle(fontWeight: FontWeight.bold))),
                  ],
                ),
                subtitle: Text("${report['reporter_name']} | ${DateFormat('MM/dd HH:mm').format(DateTime.parse(report['created_at']))}"),
                trailing: _statusBadge(status),
              ),
              if (widget.isAdmin && status != 'COMPLETED')
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _updateStatus(report['id'], 'COMPLETED'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, elevation: 0),
                          icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                          label: const Text("수리 완료 처리", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              // ✅ 완료된 항목에 완료 표시 배너
              if (status == 'COMPLETED')
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.08),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_rounded, color: Colors.green, size: 16),
                      SizedBox(width: 6),
                      Text("수리 완료", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color color = Colors.grey;
    String label = "대기";
    if (status == 'COMPLETED') { color = Colors.green; label = "완료"; }
    else if (status == 'ASSIGNED') { color = Colors.orange; label = "진행중"; }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Future<void> _updateStatus(String id, String status) async {
    try {
      await supabase.from('equipment_reports').update({'status': status}).eq('id', id);
      if (!mounted) return;
      // ✅ 완료 처리 후 스낵바 표시
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text("수리 완료 처리되었습니다."),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        ),
      );
      // Stream이 자동으로 갱신되지만 명시적으로 UI 리빌드
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("처리 중 오류가 발생했습니다."),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

// ==========================================
// 📄 상세 페이지 위젯
// ==========================================
class ReportDetailScreen extends StatelessWidget {
  final Map<String, dynamic> report;
  final bool isAdmin;

  const ReportDetailScreen({Key? key, required this.report, required this.isAdmin}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final createdAt = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(report['created_at']));

    return Scaffold(
      appBar: AppBar(
        title: const Text("신고 상세 내역", style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: 'img_${report['id']}',
              child: Container(
                width: double.infinity,
                height: 300,
                decoration: BoxDecoration(
                  image: DecorationImage(image: NetworkImage(report['image_url']), fit: BoxFit.cover),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _categoryBadge(report['priority']),
                      _statusTag(report['status']),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(report['title'], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                  const Divider(height: 32),
                  _infoRow(Icons.person_outline, "신고자", report['reporter_name']),
                  _infoRow(Icons.business_outlined, "부서", report['dept_category']),
                  _infoRow(Icons.access_time, "신고일시", createdAt),
                  const SizedBox(height: 24),
                  const Text("고장 상세 내용", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                    child: Text(report['content'] ?? "상세 설명이 없습니다.", style: const TextStyle(fontSize: 15, height: 1.5)),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          Text("$label: ", style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _categoryBadge(String priority) {
    bool isUrgent = priority == 'URGENT';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isUrgent ? Colors.red : Colors.grey[200],
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isUrgent ? "긴급 고장" : "일반 고장",
        style: TextStyle(color: isUrgent ? Colors.white : Colors.black54, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  Widget _statusTag(String status) {
    return Text(
      status == 'COMPLETED' ? "● 수리 완료" : "● 처리 대기중",
      style: TextStyle(
        color: status == 'COMPLETED' ? Colors.green : Colors.orange,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}