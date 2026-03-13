import 'package:flutter/material.dart';
import 'attendance_helper.dart';

class LeaveHistoryTab extends StatelessWidget {
  final List<Map<String, dynamic>> leaveHistory;
  final Future<void> Function() onRefresh;

  const LeaveHistoryTab({
    Key? key,
    required this.leaveHistory,
    required this.onRefresh,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (leaveHistory.isEmpty) {
      return const Center(
          child: Text("올해 사용된 연차 기록이 없습니다.",
              style: TextStyle(color: Colors.grey)));
    }

    // 월별 그룹화
    final Map<String, List<Map<String, dynamic>>> byMonth = {};
    for (final item in leaveHistory) {
      final start = item['start_date'] as String? ?? '';
      final month = start.length >= 7 ? start.substring(0, 7) : '알 수 없음';
      byMonth.putIfAbsent(month, () => []);
      byMonth[month]!.add(item);
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: byMonth.entries.map((entry) {
          final totalDays = entry.value.fold<double>(
              0, (sum, e) => sum + ((e['leave_days'] as num?)?.toDouble() ?? 0));
          final totalStr = totalDays == totalDays.truncateToDouble()
              ? totalDays.toInt().toString()
              : totalDays.toString();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                attendanceSectionHeader(
                    formatMonth(entry.key),
                    Icons.calendar_month_rounded,
                    Colors.teal),
                const Spacer(),
                Text("총 ${totalStr}일 사용",
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ]),
              const SizedBox(height: 10),
              ...entry.value.map(_historyCard),
              const SizedBox(height: 20),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _historyCard(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.event_available_rounded,
              color: Colors.teal, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item['full_name'] ?? '-',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 2),
            Text("${item['start_date']} ~ ${item['end_date']}",
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            if (item['reason']?.isNotEmpty == true)
              Text("사유: ${item['reason']}",
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text("${item['leave_days']}일",
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                  fontSize: 15)),
          attendanceStatusBadge("승인완료", Colors.teal),
        ]),
      ]),
    );
  }
}