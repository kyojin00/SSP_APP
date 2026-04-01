part of 'uniform_request_screen.dart';

class _DeptSection extends StatefulWidget {
  final String dept;
  final List<Map<String, dynamic>> items;
  final int pendingCount;
  final void Function(String id) onApprove;
  final void Function(String id) onReject;

  const _DeptSection({
    required this.dept,
    required this.items,
    required this.pendingCount,
    required this.onApprove,
    required this.onReject,
  });

  @override
  State<_DeptSection> createState() => _DeptSectionState();
}

class _DeptSectionState extends State<_DeptSection> {
  bool _expanded = true; // 기본 펼침

  static const _deptLabels = {
    'MANAGEMENT':'관리부','PRODUCTION':'생산관리부','SALES':'영업부',
    'RND':'연구소','STEEL':'스틸생산부','BOX':'박스생산부',
    'DELIVERY':'포장납품부','SSG':'에스에스지','CLEANING':'환경미화','NUTRITION':'영양사',
  };

  @override
  Widget build(BuildContext context) {
    final label    = _deptLabels[widget.dept] ?? widget.dept;
    final total    = widget.items.length;
    final pending  = widget.pendingCount;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: pending > 0
                ? Colors.orange.withOpacity(0.3)
                : Colors.black.withOpacity(0.07)),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(children: [
        // ── 헤더 (탭하면 접기/펼치기)
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: pending > 0
                  ? Colors.orange.withOpacity(0.05)
                  : Colors.grey.withOpacity(0.03),
              borderRadius: _expanded
                  ? const BorderRadius.vertical(top: Radius.circular(16))
                  : BorderRadius.circular(16),
            ),
            child: Row(children: [
              // 부서 아이콘
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                    color: _uPrimary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.business_rounded, color: _uPrimary, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w900,
                      color: Color(0xFF1A1D2E))),
                  Text('총 $total건', style: TextStyle(
                      fontSize: 11, color: Colors.black.withOpacity(0.4))),
                ]),
              ),
              // 대기 뱃지
              if (pending > 0)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(8)),
                  child: Text('대기 $pending',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 11,
                          fontWeight: FontWeight.w800)),
                ),
              // 접기/펼치기 아이콘
              AnimatedRotation(
                turns: _expanded ? 0 : -0.5,
                duration: const Duration(milliseconds: 200),
                child: Icon(Icons.keyboard_arrow_down_rounded,
                    color: Colors.black.withOpacity(0.4)),
              ),
            ]),
          ),
        ),

        // ── 카드 목록
        AnimatedCrossFade(
          firstChild: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(children: widget.items.map((r) {
              final status = r['status']?.toString() ?? 'PENDING';
              return UniformRequestCard(
                request:  r,
                isAdmin:  true,
                onApprove: status == 'PENDING'
                    ? () => widget.onApprove(r['id']?.toString() ?? '')
                    : null,
                onReject: status == 'PENDING'
                    ? () => widget.onReject(r['id']?.toString() ?? '')
                    : null,
              );
            }).toList()),
          ),
          secondChild: const SizedBox.shrink(),
          crossFadeState: _expanded
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          duration: const Duration(milliseconds: 200),
        ),
      ]),
    );
  }
}

