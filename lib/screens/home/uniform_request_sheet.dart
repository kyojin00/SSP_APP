part of 'uniform_request_screen.dart';

class _ItemLine {
  String item;
  final TextEditingController sizeCtrl;
  final TextEditingController quantityCtrl;
  _ItemLine({required this.item})
      : sizeCtrl     = TextEditingController(),
        quantityCtrl = TextEditingController(text: '1');
  void dispose() { sizeCtrl.dispose(); quantityCtrl.dispose(); }
}

// ══════════════════════════════════════════
// 신청 바텀시트
// ══════════════════════════════════════════

class UniformRequestSheet extends StatefulWidget {
  final Map<String, dynamic> userProfile;
  final Future<void> Function({required List<Map<String, dynamic>> items, required String reason}) onSubmit;
  const UniformRequestSheet({required this.userProfile, required this.onSubmit});
  @override
  State<UniformRequestSheet> createState() => _UniformRequestSheetState();
}

class _UniformRequestSheetState extends State<UniformRequestSheet>
    with SingleTickerProviderStateMixin {
  late TabController _catCtrl;
  final List<_ItemLine> _lines = [_ItemLine(item: _kClothingItems[0])];
  final _reasonCtrl = TextEditingController();
  bool _isLoading = false;

  // 현재 탭에 맞는 품목 목록
  List<String> get _currentItems =>
      _catCtrl.index == 0 ? _kClothingItems : _kSafetyItems;

  @override
  void initState() {
    super.initState();
    _catCtrl = TabController(length: 2, vsync: this);
    _catCtrl.addListener(() {
      if (!_catCtrl.indexIsChanging) {
        // 탭 전환 시 품목을 해당 카테고리 첫 번째로 초기화
        setState(() {
          for (final l in _lines) {
            l.item = _currentItems[0];
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _catCtrl.dispose();
    for (final l in _lines) l.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  void _addLine() => setState(() => _lines.add(_ItemLine(item: _currentItems[0])));

  void _removeLine(int i) {
    if (_lines.length <= 1) return;
    setState(() { _lines[i].dispose(); _lines.removeAt(i); });
  }

  Future<void> _submit() async {
    for (var i = 0; i < _lines.length; i++) {
      final noSize = ['면장갑','반코팅장갑','코팅장갑'].contains(_lines[i].item);
      if (!noSize && _lines[i].sizeCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${i+1}번 품목의 사이즈를 입력해주세요'))); return;
      }
      if ((int.tryParse(_lines[i].quantityCtrl.text.trim()) ?? 0) < 1) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${i+1}번 품목의 수량을 확인해주세요'))); return;
      }
    }
    setState(() => _isLoading = true);
    Navigator.pop(context);
    await widget.onSubmit(
      items: _lines.map((l) {
        final noSize = ['면장갑','반코팅장갑','코팅장갑'].contains(l.item);
        return {
          'item':     l.item,
          'size':     noSize ? 'FREE' : l.sizeCtrl.text.trim(),
          'quantity': int.parse(l.quantityCtrl.text.trim()),
        };
      }).toList(),
      reason: _reasonCtrl.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom     = MediaQuery.of(context).viewInsets.bottom;
    final screenH    = MediaQuery.of(context).size.height;
    return Container(
      constraints: BoxConstraints(maxHeight: screenH * 0.9),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      padding: EdgeInsets.fromLTRB(22, 22, 22, 16 + bottom),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          Row(children: [
            Container(padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(color: _uPrimary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.checkroom_rounded, color: _uPrimary, size: 22)),
            const SizedBox(width: 12),
            Expanded(child: Text(context.tr(AppStrings.uniformTitle), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
            GestureDetector(
              onTap: _addLine,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(color: _uPrimary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.add_rounded, color: _uPrimary, size: 16),
                  const SizedBox(width: 4),
                  Text(context.tr(AppStrings.uniformAddItem), style: TextStyle(color: _uPrimary, fontSize: 12, fontWeight: FontWeight.w800)),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 20),

          // 카테고리 탭
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF4F6FB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _catCtrl,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.black54,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              indicator: BoxDecoration(
                color: _uPrimary,
                borderRadius: BorderRadius.circular(10),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              tabs: [
                Tab(text: context.tr(AppStrings.uniformCatClothing)),
                Tab(text: context.tr(AppStrings.uniformCatSafety)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 품목 라인 목록
          for (var i = 0; i < _lines.length; i++) _buildLine(i, _lines[i]),

          const SizedBox(height: 16),
          Align(alignment: Alignment.centerLeft,
              child: Text(context.tr(AppStrings.uniformReasonLabel), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1A1D2E)))),
          const SizedBox(height: 8),
          TextField(
            controller: _reasonCtrl, maxLines: 2,
            decoration: InputDecoration(
              hintText: context.tr(AppStrings.uniformReasonHint), filled: true, fillColor: Color(0xFFF4F6FB),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(backgroundColor: _uPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: Text(_lines.length == 1 ? context.tr(AppStrings.uniformSubmitOne) : context.tr(AppStrings.uniformSubmitMany).replaceAll('{n}', '\${_lines.length}'),
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildLine(int index, _ItemLine line) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FC), borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _uPrimary.withOpacity(0.12)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: _uPrimary, borderRadius: BorderRadius.circular(6)),
              child: Text('${index+1}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900))),
          const SizedBox(width: 8),
          Text('품목 ${index+1}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1A1D2E))),
          const Spacer(),
          if (_lines.length > 1)
            GestureDetector(
              onTap: () => _removeLine(index),
              child: Container(padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                  child: const Icon(Icons.close_rounded, size: 16, color: Colors.redAccent)),
            ),
        ]),
        const SizedBox(height: 12),
        Text(context.tr(AppStrings.uniformItemLabel), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1A1D2E))),
        const SizedBox(height: 6),
        // 의류 탭이면 하계 라벨 표시
        if (_catCtrl.index == 0) ...[
          Row(children: [
            Container(width: 3, height: 13,
                decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 6),
            Text(context.tr(AppStrings.uniformSummer), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.orange)),
          ]),
          const SizedBox(height: 4),
        ],
        Wrap(spacing: 6, runSpacing: 6, children: _currentItems.map((item) {
          final sel = line.item == item;
          // 의류 탭일 때 동계 시작 전 구분선
          final isWinterStart = _catCtrl.index == 0 && item == '동잠바';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isWinterStart) ...[
                const SizedBox(height: 6),
                Row(children: [
                  Container(width: 3, height: 13,
                      decoration: BoxDecoration(color: Colors.blueGrey, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 6),
                  Text(context.tr(AppStrings.uniformWinter), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.blueGrey)),
                ]),
                const SizedBox(height: 4),
              ],
              GestureDetector(
                onTap: () => setState(() => line.item = item),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                  decoration: BoxDecoration(
                    color: sel ? _uPrimary : Colors.white, borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: sel ? _uPrimary : Colors.black.withOpacity(0.1)),
                  ),
                  child: Text(item, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                      color: sel ? Colors.white : Colors.black87)),
                ),
              ),
            ],
          );
        }).toList()),
        const SizedBox(height: 12),
        // 장갑류는 사이즈 없음
        if (!['면장갑','반코팅장갑','코팅장갑'].contains(line.item)) ...[
          Text(context.tr(AppStrings.uniformSizeLabel), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1A1D2E))),
          const SizedBox(height: 6),
          TextField(
            controller: line.sizeCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: context.tr(AppStrings.uniformSizeHint),
              filled: true, fillColor: Colors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
        ],
        // 수량
        Text(context.tr(AppStrings.uniformQtyLabel), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1A1D2E))),
        const SizedBox(height: 6),
        Row(children: [
          _qBtn(Icons.remove_rounded, () {
            final v = int.tryParse(line.quantityCtrl.text) ?? 1;
            if (v > 1) setState(() => line.quantityCtrl.text = '${v - 1}');
          }),
          const SizedBox(width: 8),
          SizedBox(
            width: 64,
            child: TextField(
              controller: line.quantityCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
              decoration: InputDecoration(
                filled: true, fillColor: Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _qBtn(Icons.add_rounded, () {
            final v = int.tryParse(line.quantityCtrl.text) ?? 1;
            setState(() => line.quantityCtrl.text = '${v + 1}');
          }),
        ]),
      ]),
    );
  }

  Widget _qBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(width: 32, height: 32,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.black.withOpacity(0.1))),
      child: Icon(icon, size: 16, color: Colors.black54)),
  );
}