part of 'cleaning_screen.dart';

class _ResidentsSheet extends StatefulWidget {
  final List<String> rooms;
  const _ResidentsSheet({required this.rooms});

  @override
  State<_ResidentsSheet> createState() => _ResidentsSheetState();
}

class _ResidentsSheetState extends State<_ResidentsSheet> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _residents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadResidents();
  }

  Future<void> _loadResidents() async {
    try {
      List data;
      if (widget.rooms.length == 1) {
        data = await supabase
            .from('dorm_residents')
            .select('resident_name, room_number')
            .eq('room_number', widget.rooms.first)
            .order('room_number');
      } else {
        data = await supabase
            .from('dorm_residents')
            .select('resident_name, room_number')
            .inFilter('room_number', widget.rooms)
            .order('room_number');
      }
      if (mounted) {
        setState(() {
          _residents = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('거주자 로드 실패: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _flag(String? nationality) {
    switch (nationality) {
      case 'KR': return '🇰🇷';
      case 'VN': return '🇻🇳';
      case 'UZ': return '🇺🇿';
      case 'KH': return '🇰🇭';
      default:   return '🌏';
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomTitle = widget.rooms.join(' / ');

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // 핸들
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2)),
        ),

        // 제목
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.people_rounded,
                color: Colors.teal, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(roomTitle,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1A1D2E))),
                  Text(context.tr(AppStrings.cleaningResidents),
                      style: const TextStyle(
                          fontSize: 12, color: Colors.grey)),
                ]),
          ),
        ]),

        const SizedBox(height: 20),

        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: CircularProgressIndicator(),
          )
        else if (_residents.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(children: [
              Icon(Icons.person_off_rounded,
                  size: 48, color: Colors.grey[300]),
              const SizedBox(height: 12),
              Text(context.tr(AppStrings.cleaningNoResidents),
                  style: const TextStyle(color: Colors.grey)),
            ]),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _residents.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final r = _residents[i];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 4, vertical: 4),
                leading: CircleAvatar(
                  backgroundColor: Colors.teal.withOpacity(0.1),
                  child: const Icon(Icons.person_rounded,
                      color: Colors.teal, size: 20),
                ),
                title: Text(r['resident_name'] ?? '-',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
                subtitle: Text(r['room_number'] ?? '',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey[500])),
                trailing: null,
              );
            },
          ),
      ]),
    );
  }
}