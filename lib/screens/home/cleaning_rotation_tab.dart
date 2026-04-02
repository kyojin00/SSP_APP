part of 'cleaning_screen.dart';

class _CleaningRotationTab extends StatelessWidget {
  final _CleaningScreenState state;
  const _CleaningRotationTab({required this.state});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        _FloorRotation(floor: 2, state: state),
        const SizedBox(height: 24),
        _FloorRotation(floor: 3, state: state),
      ]),
    );
  }
}

class _FloorRotation extends StatelessWidget {
  final int floor;
  final _CleaningScreenState state;
  const _FloorRotation({required this.floor, required this.state});

  @override
  Widget build(BuildContext context) {
    final rotations = floor == 2 ? state._rotations2 : state._rotations3;
    final color = floor == 2 ? Colors.blue : Colors.purple;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(children: [
        // 헤더
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.06),
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20)),
          ),
          child: Row(children: [
            Icon(Icons.layers_rounded, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              '$floor${context.tr(AppStrings.cleaningFloorRotation)} '
              '(${rotations.length}${context.tr(AppStrings.cleaningRooms)})',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: color),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => state._saveRotationOrder(floor),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: Text(context.tr(AppStrings.cleaningSave),
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: color)),
              ),
            ),
          ]),
        ),

        // 드래그 리스트
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: rotations.length,
          onReorder: (oldIndex, newIndex) {
            state.setState(() {
              if (newIndex > oldIndex) newIndex--;
              final list =
                  floor == 2 ? state._rotations2 : state._rotations3;
              final item = list.removeAt(oldIndex);
              list.insert(newIndex, item);
            });
          },
          itemBuilder: (context, index) {
            final r = rotations[index];
            return ListTile(
              key: ValueKey(r['id']),
              leading: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: Center(
                  child: Text('${index + 1}',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: color,
                          fontSize: 13)),
                ),
              ),
              title: Text(r['room_label'],
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14)),
              subtitle: r['is_merged'] == true
                  ? Text(context.tr(AppStrings.cleaningMerged),
                      style: const TextStyle(
                          fontSize: 11, color: Colors.orange))
                  : null,
              trailing: const Icon(Icons.drag_handle_rounded,
                  color: Colors.grey),
            );
          },
        ),
      ]),
    );
  }
}
