part of 'uniform_request_screen.dart';

// ══════════════════════════════════════════
// 신청 카드
// ══════════════════════════════════════════

class UniformRequestCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final bool isAdmin;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const UniformRequestCard({Key? key, required this.request, required this.isAdmin,
      required this.onApprove, required this.onReject}) : super(key: key);

  String _dept(BuildContext context, String d) {
    const m = {
      'MANAGEMENT': AppStrings.deptManagement, 'PRODUCTION': AppStrings.deptProduction,
      'SALES': AppStrings.deptSales,           'RND': AppStrings.deptRnd,
      'STEEL': AppStrings.deptSteel,           'BOX': AppStrings.deptBox,
      'DELIVERY': AppStrings.deptDelivery,     'SSG': AppStrings.deptSsg,
      'CLEANING': AppStrings.deptCleaning,     'NUTRITION': AppStrings.deptNutrition,
    };
    final key = m[d];
    return key != null ? context.tr(key) : d;
  }

  String _fmt(String d) {
    try { return DateFormat('yyyy.MM.dd').format(DateTime.parse(d)); }
    catch (_) { return d.length >= 10 ? d.substring(0, 10) : d; }
  }

  @override
  Widget build(BuildContext context) {
    final status       = request['status']?.toString()        ?? 'PENDING';
    final item         = request['item']?.toString()          ?? '-';
    final size         = request['size']?.toString()          ?? '-';
    final quantity     = (request['quantity'] as num?)?.toInt() ?? 0;
    final reason       = request['reason']?.toString()        ?? '';
    final fullName     = request['full_name']?.toString()     ?? '-';
    final dept         = _dept(context, request['dept_category']?.toString() ?? '');
    final createdAt    = request['created_at']?.toString()    ?? '';
    final rejectReason = request['reject_reason']?.toString();
    final approverName = request['approver_name']?.toString();

    final Color sc; final String sl;
    switch (status) {
      case 'APPROVED': sc = Colors.green;     sl = context.tr(AppStrings.uniformStatusApproved); break;
      case 'REJECTED': sc = Colors.redAccent; sl = context.tr(AppStrings.uniformStatusRejected); break;
      default:         sc = Colors.orange;    sl = context.tr(AppStrings.uniformStatusPending);
    }

    // 사이즈 표시 (FREE면 숨김)
    final showSize = size != 'FREE' && size.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(18),
        border: Border.all(color: sc.withOpacity(0.15)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(color: _uPrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.checkroom_rounded, color: _uPrimary, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900,
                color: Color(0xFF1A1D2E))),
            Text(
              showSize
                  ? '${context.tr(AppStrings.uniformSizeLabel)} $size  ·  $quantity${context.tr(AppStrings.members)}'
                  : '$quantity${context.tr(AppStrings.members)}',
              style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.45))),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: sc.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Text(sl, style: TextStyle(color: sc, fontSize: 12, fontWeight: FontWeight.w800)),
          ),
        ]),
        if (isAdmin) ...[
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.person_rounded, size: 13, color: Colors.black.withOpacity(0.35)),
            const SizedBox(width: 4),
            Text('$fullName  ·  $dept',
                style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.45))),
          ]),
        ],
        if (reason.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.description_rounded, size: 13, color: Colors.black.withOpacity(0.35)),
            const SizedBox(width: 4),
            Expanded(child: Text(reason,
                style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.45)))),
          ]),
        ],
        if (rejectReason != null && rejectReason.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.06),
                borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded, size: 13, color: Colors.redAccent),
              const SizedBox(width: 6),
              Expanded(child: Text(
                context.tr(AppStrings.uniformRejectLabel).replaceAll('{r}', rejectReason),
                style: const TextStyle(fontSize: 11, color: Colors.redAccent,
                    fontWeight: FontWeight.w600))),
            ]),
          ),
        ],
        const SizedBox(height: 8),
        Row(children: [
          Icon(Icons.access_time_rounded, size: 12, color: Colors.black.withOpacity(0.3)),
          const SizedBox(width: 4),
          Text(_fmt(createdAt),
              style: TextStyle(fontSize: 11, color: Colors.black.withOpacity(0.35))),
          if (approverName != null) ...[
            const SizedBox(width: 8),
            Text('· $approverName',
                style: TextStyle(fontSize: 11, color: Colors.black.withOpacity(0.35))),
          ],
        ]),
        if (isAdmin && status == 'PENDING' && onApprove != null && onReject != null) ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: onReject,
              style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: Text(context.tr(AppStrings.reject),
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            )),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton(
              onPressed: onApprove,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: Text(context.tr(AppStrings.approve),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            )),
          ]),
        ],
      ]),
    );
  }
}