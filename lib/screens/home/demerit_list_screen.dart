import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class DemeritListScreen extends StatefulWidget {
  final bool isAdmin;
  const DemeritListScreen({Key? key, required this.isAdmin}) : super(key: key);

  @override
  State<DemeritListScreen> createState() => _DemeritListScreenState();
}

class _DemeritListScreenState extends State<DemeritListScreen> {
  final supabase = Supabase.instance.client;

  bool _isLoading = true;
  List<Map<String, dynamic>> _demerits = [];

  static const _red    = Color(0xFFFF4D64);
  static const _bg     = Color(0xFFF4F6FB);
  static const _sub    = Color(0xFF8A93B0);
  static const _text   = Color(0xFF1A1D2E);

  @override
  void initState() {
    super.initState();
    _fetchDemerits();
  }

  Future<void> _fetchDemerits() async {
    setState(() => _isLoading = true);
    try {
      var query = supabase.from('dorm_demerits').select('*');
      if (!widget.isAdmin) {
        query = query.eq('user_id', supabase.auth.currentUser!.id);
      }
      final data = await query.order('created_at', ascending: false);
      setState(() {
        _demerits = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("벌점 로드 에러: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteDemerit(Map<String, dynamic> item) async {
    final name   = item['resident_name'] ?? '해당 사원';
    final points = item['points'] ?? 0;
    final reason = item['reason'] ?? '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: _red, size: 22),
          const SizedBox(width: 8),
          const Text("벌점 삭제", style: TextStyle(fontWeight: FontWeight.w900)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _red.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("대상: $name",
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text("점수: $points점 / 사유: $reason",
                      style: const TextStyle(fontSize: 12, color: _sub)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text("이 벌점 기록을 삭제하시겠습니까?",
                style: TextStyle(fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("취소")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("삭제"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await supabase
          .from('dorm_demerits')
          .delete()
          .eq('id', item['id'].toString());
      _showSnack("벌점이 삭제되었습니다. ✅");
      _fetchDemerits();
    } catch (e) {
      _showSnack("삭제 실패: $e");
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final totalPoints =
        _demerits.fold(0, (s, i) => s + (i['points'] as int? ?? 0));
    final isWarning = totalPoints >= 3;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: Text(widget.isAdmin ? "전체 벌점 현황" : "나의 벌점 내역",
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: _text,
        elevation: 0,
        surfaceTintColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFF0F2F8)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchDemerits,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _red))
          : Column(
              children: [
                // ─── 요약 카드 ───
                if (!widget.isAdmin)
                  _buildMyTotalCard(totalPoints, isWarning)
                else
                  _buildAdminSummaryCard(totalPoints),

                // ─── 목록 ───
                Expanded(
                  child: _demerits.isEmpty
                      ? _buildEmpty()
                      : RefreshIndicator(
                          onRefresh: _fetchDemerits,
                          color: _red,
                          child: ListView.builder(
                            padding:
                                const EdgeInsets.fromLTRB(16, 12, 16, 40),
                            itemCount: _demerits.length,
                            itemBuilder: (_, i) =>
                                _buildDemeritCard(_demerits[i]),
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  // 사원용 요약 카드
  Widget _buildMyTotalCard(int total, bool isWarning) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isWarning
              ? [const Color(0xFFFF4D64), const Color(0xFFFF8C42)]
              : [const Color(0xFF2E6BFF), const Color(0xFF4FB2FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isWarning ? _red : const Color(0xFF2E6BFF))
                .withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("나의 누적 벌점",
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text("$total",
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      height: 1)),
              const SizedBox(width: 4),
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text("점",
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
              ),
            ]),
            if (isWarning) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8)),
                child: const Text("⚠️ 퇴실 경고 대상입니다.",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ]),
        ),
        Icon(
          isWarning
              ? Icons.warning_amber_rounded
              : Icons.verified_user_rounded,
          color: Colors.white.withOpacity(0.3),
          size: 56,
        ),
      ]),
    );
  }

  // 관리자용 요약 카드
  Widget _buildAdminSummaryCard(int total) {
    // 인원별 합산
    final byPerson = <String, int>{};
    for (final d in _demerits) {
      final name = d['resident_name'] ?? '미상';
      byPerson[name] = (byPerson[name] ?? 0) + (d['points'] as int? ?? 0);
    }
    final warningCount = byPerson.values.where((p) => p >= 3).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _summaryPill("총 벌점", "$total점", _red),
          Container(width: 1, height: 36, color: const Color(0xFFF0F2F8)),
          _summaryPill("부과 건수", "${_demerits.length}건", const Color(0xFFFF8C42)),
          Container(width: 1, height: 36, color: const Color(0xFFF0F2F8)),
          _summaryPill("경고 대상", "$warningCount명", const Color(0xFF7C5CDB)),
        ],
      ),
    );
  }

  Widget _summaryPill(String label, String value, Color color) {
    return Column(children: [
      Text(value,
          style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w900, color: color)),
      const SizedBox(height: 3),
      Text(label,
          style: const TextStyle(fontSize: 11, color: _sub, fontWeight: FontWeight.w600)),
    ]);
  }

  Widget _buildDemeritCard(Map<String, dynamic> item) {
    final points   = item['points'] as int? ?? 0;
    final reason   = item['reason'] ?? '사유 없음';
    final name     = item['resident_name'] ?? '-';
    final dateStr  = item['created_at'] != null
        ? DateFormat('yyyy.MM.dd').format(DateTime.parse(item['created_at']).toLocal())
        : '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: Row(children: [
        // 점수 뱃지
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
              color: _red.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("-$points",
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: _red)),
              const Text("점",
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: _red)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // 내용
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (widget.isAdmin) ...[
              Row(children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                      color: const Color(0xFF2E6BFF).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(5)),
                  child: Text(name,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2E6BFF))),
                ),
              ]),
              const SizedBox(height: 4),
            ],
            Text(reason,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _text)),
            const SizedBox(height: 3),
            Text(dateStr,
                style: const TextStyle(fontSize: 11, color: _sub)),
          ]),
        ),
        // 삭제 버튼 (관리자만)
        if (widget.isAdmin)
          GestureDetector(
            onTap: () => _deleteDemerit(item),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _red.withOpacity(0.07),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.delete_outline_rounded,
                  color: _red, size: 18),
            ),
          ),
      ]),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.check_circle_outline_rounded,
            size: 52, color: Colors.grey[300]),
        const SizedBox(height: 12),
        Text("부과된 벌점이 없습니다.",
            style: TextStyle(color: Colors.grey[400])),
      ]),
    );
  }
}