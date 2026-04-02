part of 'cleaning_screen.dart';

class _CleaningHistoryTab extends StatelessWidget {
  final _CleaningScreenState state;
  const _CleaningHistoryTab({required this.state});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: state.supabase
          .from('cleaning_schedule')
          .select('*, cleaning_records(*)')
          .order('week_start', ascending: false)
          .limit(40),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final all =
            List<Map<String, dynamic>>.from(snapshot.data as List);
        if (all.isEmpty) {
          return Center(
              child: Text(context.tr(AppStrings.cleaningNoHistory),
                  style: const TextStyle(color: Colors.grey)));
        }

        // week_start 기준 그룹핑
        final grouped = <String, List<Map<String, dynamic>>>{};
        for (final s in all) {
          grouped.putIfAbsent(s['week_start'] as String, () => []).add(s);
        }

        return ListView(
          padding: const EdgeInsets.all(20),
          children: grouped.entries.map((entry) {
            final monday = DateTime.parse(entry.key);
            final sunday = monday.add(const Duration(days: 6));
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    '${DateFormat('MM/dd').format(monday)} ~ '
                    '${DateFormat('MM/dd').format(sunday)}',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey),
                  ),
                ),
                for (final s in entry.value)
                  _HistoryTile(schedule: s, state: state),
                const Divider(),
              ],
            );
          }).toList(),
        );
      },
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final Map<String, dynamic> schedule;
  final _CleaningScreenState state;
  const _HistoryTile({required this.schedule, required this.state});

  @override
  Widget build(BuildContext context) {
    final floor = schedule['floor'] as int;
    final recs = schedule['cleaning_records'] as List?;
    final record =
        (recs != null && recs.isNotEmpty) ? recs.first : null;
    final isDone = record != null;
    final photoUrl = record?['photo_url'] as String?;
    final color = floor == 2 ? Colors.blue : Colors.purple;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDone
            ? Colors.green.withOpacity(0.05)
            : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDone
                ? Colors.green.withOpacity(0.2)
                : Colors.grey.withOpacity(0.2)),
      ),
      child: Row(children: [
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6)),
          child: Text('${floor}층',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: color)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(schedule['room_label'],
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13)),
                Text(
                  DateFormat('MM/dd (E)', 'ko').format(
                      DateTime.parse(schedule['assigned_date'])),
                  style:
                      TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ]),
        ),
        if (photoUrl != null)
          GestureDetector(
            onTap: () => state._showPhotoDialog(photoUrl),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.photo_rounded,
                  size: 16, color: Colors.teal),
            ),
          ),
        const SizedBox(width: 8),
        Icon(
          isDone
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked,
          color: isDone ? Colors.green : Colors.grey[300],
          size: 22,
        ),
      ]),
    );
  }
}
