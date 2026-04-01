import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class HealthScreen extends StatefulWidget {
  final bool isAdmin;
  const HealthScreen({Key? key, required this.isAdmin}) : super(key: key);

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  final supabase = Supabase.instance.client;

  bool _isLoading = true;
  List<Map<String, dynamic>> _records = [];
  List<Map<String, dynamic>> _profiles = [];
  String _searchQuery = '';
  String _selectedDept = 'ALL';

  static const _primary = Color(0xFF2E6BFF);
  static const _bg      = Color(0xFFF4F6FB);
  static const _text    = Color(0xFF1A1D2E);
  static const _sub     = Color(0xFF8A93B0);

  static const _deptList = [
    'ALL','MANAGEMENT','PRODUCTION','SALES','RND','STEEL',
    'BOX','DELIVERY','SSG','CLEANING','NUTRITION',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        supabase.from('health_records')
            .select()
            .order('consultation_date', ascending: false),
        supabase.from('profiles')
            .select('id, full_name, dept_category, position')
            .order('full_name'),
      ]);
      if (!mounted) return;
      setState(() {
        _records  = List<Map<String, dynamic>>.from(results[0] as List);
        _profiles = List<Map<String, dynamic>>.from(results[1] as List);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('건강 기록 로드 실패: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _deptLabel(String d) {
    const m = {
      'MANAGEMENT':'관리부','PRODUCTION':'생산관리부','SALES':'영업부',
      'RND':'연구소','STEEL':'스틸생산부','BOX':'박스생산부',
      'DELIVERY':'포장납품부','SSG':'에스에스지',
      'CLEANING':'환경미화','NUTRITION':'영양사',
    };
    return m[d] ?? d;
  }

  Color _deptColor(String d) {
    const m = {
      'MANAGEMENT': Color(0xFF2E6BFF),'PRODUCTION': Color(0xFFFF7A2F),
      'SALES': Color(0xFF7C5CDB),     'RND': Color(0xFF00BCD4),
      'STEEL': Color(0xFFE91E8C),     'BOX': Color(0xFF4CAF50),
      'DELIVERY': Color(0xFFFF5722),  'SSG': Color(0xFF607D8B),
      'CLEANING': Color(0xFFFFC107),  'NUTRITION': Color(0xFF9C27B0),
    };
    return m[d] ?? _primary;
  }

  List<Map<String, dynamic>> get _filtered {
    var list = List<Map<String, dynamic>>.from(_records);
    if (_selectedDept != 'ALL') {
      list = list.where((r) => r['dept_category'] == _selectedDept).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((r) =>
          (r['full_name'] as String? ?? '').toLowerCase().contains(q)).toList();
    }
    return list;
  }


  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('건강 리포트',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
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
            icon: const Icon(Icons.add_rounded),
            tooltip: '기록 추가',
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(
                  builder: (_) => HealthRecordFormScreen(
                      profiles: _profiles, isAdmin: widget.isAdmin)));
              _loadData();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : Column(children: [
              // 검색 + 부서 필터
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Column(children: [
                  TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: '이름 검색',
                      hintStyle: TextStyle(color: _sub, fontSize: 13),
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: _sub, size: 20),
                      filled: true, fillColor: _bg,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 30,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: _deptList.map((d) {
                        final sel = _selectedDept == d;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedDept = d),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: sel ? _primary : _bg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              d == 'ALL' ? '전체' : _deptLabel(d),
                              style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w700,
                                color: sel ? Colors.white : _sub),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ]),
              ),
              // 요약
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: Row(children: [
                  Text('총 ${filtered.length}건',
                      style: TextStyle(fontSize: 12,
                          color: _sub, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  // 진단별 카운트
                  ..._diagnosisSummary(filtered).entries.take(4).map((e) =>
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6)),
                      child: Text('${e.key} ${e.value}',
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w700,
                              color: Colors.redAccent)),
                    )),
                ]),
              ),
              Container(height: 1, color: const Color(0xFFF0F2F8)),
              // 목록
              Expanded(
                child: filtered.isEmpty
                    ? Center(child: Column(
                        mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.health_and_safety_outlined,
                              size: 52, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          Text('건강 기록이 없습니다',
                              style: TextStyle(color: _sub)),
                        ]))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => _recordCard(filtered[i]),
                      ),
              ),
            ]),
    );
  }

  Map<String, int> _diagnosisSummary(List<Map<String, dynamic>> records) {
    final map = <String, int>{};
    for (final r in records) {
      for (final d in (r['diagnoses'] as List? ?? [])) {
        map[d.toString()] = (map[d.toString()] ?? 0) + 1;
      }
    }
    final sorted = Map.fromEntries(
        map.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));
    return sorted;
  }

  void _showDetail(BuildContext context, Map<String, dynamic> r) {
    final name      = r['full_name']         as String? ?? '-';
    final dept      = r['dept_category']     as String? ?? '';
    final date      = r['consultation_date'] as String? ?? '';
    final gender    = r['gender']            as String? ?? '-';
    final drinking  = r['drinking']          as String? ?? '';
    final smoking   = r['smoking']           as String? ?? '';
    final exercise  = r['exercise']          as String? ?? '';
    final bpSys     = r['bp_systolic']       as int?;
    final bpDia     = r['bp_diastolic']      as int?;
    final sugar     = r['blood_sugar']       as int?;
    final weight    = r['weight'];
    final diagnoses = (r['diagnoses'] as List? ?? []).cast<String>();
    final recommend = r['recommendations']   as String? ?? '';
    final followUp  = r['follow_up']         as String? ?? '';
    final consultant = r['consultant']       as String? ?? '';
    final notes     = r['notes']             as String? ?? '';
    final dc        = _deptColor(dept);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(children: [
            // 핸들
            Container(width: 36, height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2))),
            // 헤더
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(children: [
                CircleAvatar(radius: 24, backgroundColor: dc.withOpacity(0.1),
                    child: Text(name.isNotEmpty ? name[0] : '?',
                        style: TextStyle(fontSize: 18,
                            fontWeight: FontWeight.w900, color: dc))),
                const SizedBox(width: 14),
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w900, color: _text)),
                  const SizedBox(height: 3),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: dc.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6)),
                      child: Text(_deptLabel(dept),
                          style: TextStyle(fontSize: 11,
                              fontWeight: FontWeight.w700, color: dc)),
                    ),
                    const SizedBox(width: 6),
                    Text(date, style: TextStyle(fontSize: 12, color: _sub)),
                    const SizedBox(width: 6),
                    Text(gender, style: TextStyle(fontSize: 12, color: _sub)),
                  ]),
                ])),
                if (widget.isAdmin)
                  GestureDetector(
                    onTap: () async {
                      Navigator.pop(context);
                      await Navigator.push(context, MaterialPageRoute(
                          builder: (_) => HealthRecordFormScreen(
                              profiles: _profiles, isAdmin: widget.isAdmin,
                              existingRecord: r)));
                      _loadData();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: _bg,
                          borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.edit_rounded,
                          size: 18, color: _sub),
                    ),
                  ),
              ]),
            ),
            Divider(height: 1, color: Colors.black.withOpacity(0.06)),
            // 본문
            Expanded(child: ListView(
              controller: ctrl,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                // 진단
                if (diagnoses.isNotEmpty) ...[
                  _detailSection('🏥 진단/소견',
                      Wrap(spacing: 8, runSpacing: 6,
                          children: diagnoses.map((d) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                                color: Colors.redAccent.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: Colors.redAccent.withOpacity(0.25))),
                            child: Text(d, style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700,
                                color: Colors.redAccent)),
                          )).toList())),
                  const SizedBox(height: 14),
                ],
                // 측정 수치
                _detailSection('💉 측정 수치',
                  Row(children: [
                    _detailVital('혈압',
                        (bpSys != null && bpDia != null)
                            ? '$bpSys / $bpDia' : '-',
                        Icons.favorite_rounded, Colors.red),
                    const SizedBox(width: 10),
                    _detailVital('혈당',
                        sugar != null ? '$sugar mg/dL' : '-',
                        Icons.water_drop_rounded, Colors.orange),
                    const SizedBox(width: 10),
                    _detailVital('체중',
                        weight != null ? '$weight kg' : '-',
                        Icons.monitor_weight_rounded,
                        const Color(0xFF2E6BFF)),
                  ]),
                ),
                const SizedBox(height: 14),
                // 생활습관
                _detailSection('🚬 생활습관',
                  Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    if (drinking.isNotEmpty)
                      _detailRow('음주', drinking),
                    if (smoking.isNotEmpty)
                      _detailRow('흡연', smoking),
                    if (exercise.isNotEmpty)
                      _detailRow('운동', exercise),
                    if (drinking.isEmpty && smoking.isEmpty && exercise.isEmpty)
                      Text('기록 없음',
                          style: TextStyle(fontSize: 13, color: _sub)),
                  ]),
                ),
                const SizedBox(height: 14),
                // 건의사항
                if (recommend.isNotEmpty) ...[
                  _detailSection('📋 건의사항',
                      Text(recommend, style: const TextStyle(
                          fontSize: 13, color: _text, height: 1.6))),
                  const SizedBox(height: 14),
                ],
                // 추적 + 상담자
                Row(children: [
                  if (followUp.isNotEmpty) Expanded(child: _detailSection(
                      '📅 추적기간', Text(followUp,
                          style: const TextStyle(fontSize: 13, color: _text)))),
                  if (followUp.isNotEmpty) const SizedBox(width: 10),
                  if (consultant.isNotEmpty) Expanded(child: _detailSection(
                      '👨‍⚕️ 상담자', Text(consultant,
                          style: const TextStyle(fontSize: 13, color: _text)))),
                ]),
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _detailSection('📝 기타',
                      Text(notes, style: const TextStyle(
                          fontSize: 13, color: _text, height: 1.5))),
                ],
              ],
            )),
          ]),
        ),
      ),
    );
  }

  Widget _detailSection(String title, Widget content) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w800, color: _text)),
      const SizedBox(height: 8),
      content,
    ]);
  }

  Widget _detailVital(String label, String value, IconData icon, Color color) {
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 5),
        Text(value, style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10, color: _sub)),
      ]),
    ));
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 40, child: Text(label, style: TextStyle(
            fontSize: 12, color: _sub, fontWeight: FontWeight.w600))),
        const SizedBox(width: 10),
        Expanded(child: Text(value, style: const TextStyle(
            fontSize: 13, color: _text, fontWeight: FontWeight.w600))),
      ]),
    );
  }

  Widget _recordCard(Map<String, dynamic> r) {
    final name    = r['full_name']         as String? ?? '-';
    final dept    = r['dept_category']     as String? ?? '';
    final date    = r['consultation_date'] as String? ?? '';
    final bp      = (r['bp_systolic'] != null && r['bp_diastolic'] != null)
        ? '${r['bp_systolic']}/${r['bp_diastolic']}'
        : null;
    final sugar   = r['blood_sugar']       as int?;
    final diagnoses = (r['diagnoses'] as List? ?? []).cast<String>();
    final dc      = _deptColor(dept);

    return GestureDetector(
      onTap: () => _showDetail(context, r),
      child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(radius: 20, backgroundColor: dc.withOpacity(0.1),
              child: Text(name.isNotEmpty ? name[0] : '?',
                  style: TextStyle(fontSize: 15,
                      fontWeight: FontWeight.w900, color: dc))),
          const SizedBox(width: 12),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w800, color: _text)),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: dc.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(5)),
                child: Text(_deptLabel(dept),
                    style: TextStyle(fontSize: 10,
                        fontWeight: FontWeight.w700, color: dc)),
              ),
              const SizedBox(width: 6),
              Text(date, style: TextStyle(fontSize: 11, color: _sub)),
            ]),
          ])),
          // 편집
          if (widget.isAdmin)
            GestureDetector(
              onTap: () async {
                await Navigator.push(context, MaterialPageRoute(
                    builder: (_) => HealthRecordFormScreen(
                        profiles: _profiles, isAdmin: widget.isAdmin,
                        existingRecord: r)));
                _loadData();
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: _bg, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.edit_rounded, size: 16, color: _sub),
              ),
            ),
        ]),
        const SizedBox(height: 10),
        // 진단 뱃지
        if (diagnoses.isNotEmpty) Wrap(spacing: 6, runSpacing: 4,
            children: diagnoses.map((d) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.2))),
              child: Text(d, style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: Colors.redAccent)),
            )).toList()),
        if (diagnoses.isNotEmpty) const SizedBox(height: 8),
        // 수치
        Row(children: [
          if (bp != null) ...[
            _vitalChip(Icons.favorite_rounded, Colors.red, '혈압', bp),
            const SizedBox(width: 8),
          ],
          if (sugar != null)
            _vitalChip(Icons.water_drop_rounded, Colors.orange, '혈당', '$sugar'),
          const Spacer(),
          Icon(Icons.chevron_right_rounded, size: 16, color: _sub.withOpacity(0.5)),
        ]),
      ]),
    ));
  }

  Widget _vitalChip(IconData icon, Color color, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text('$label $value', style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

// ══════════════════════════════════════════
// 입력 폼 화면
// ══════════════════════════════════════════
class HealthRecordFormScreen extends StatefulWidget {
  final List<Map<String, dynamic>> profiles;
  final bool isAdmin;
  final Map<String, dynamic>? existingRecord;

  const HealthRecordFormScreen({
    Key? key,
    required this.profiles,
    required this.isAdmin,
    this.existingRecord,
  }) : super(key: key);

  @override
  State<HealthRecordFormScreen> createState() => _HealthRecordFormScreenState();
}

class _HealthRecordFormScreenState extends State<HealthRecordFormScreen> {
  final supabase   = Supabase.instance.client;
  final _formKey   = GlobalKey<FormState>();
  bool _isSaving   = false;

  static const _primary = Color(0xFF2E6BFF);

  // 선택된 직원
  Map<String, dynamic>? _selectedProfile;

  // 컨트롤러
  final _dateCtrl         = TextEditingController();
  final _drinkingCtrl     = TextEditingController();
  final _smokingCtrl      = TextEditingController();
  final _exerciseCtrl     = TextEditingController();
  final _bpSysCtrl        = TextEditingController();
  final _bpDiaCtrl        = TextEditingController();
  final _bloodSugarCtrl   = TextEditingController();
  final _weightCtrl       = TextEditingController();
  final _recommendCtrl    = TextEditingController();
  final _followUpCtrl     = TextEditingController();
  final _consultantCtrl   = TextEditingController();
  final _notesCtrl        = TextEditingController();

  String _gender = '남';
  final Set<String> _diagnoses = {};

  static const _diagnosisList = [
    '고혈압', '당뇨', '고지혈증', '간장질환', '신장질환',
    '심장질환', '뇌혈관질환', '폐질환', '청력저하', '소음성난청',
    '빈혈', '골다공증', '비만', '기타',
  ];

  @override
  void initState() {
    super.initState();
    _dateCtrl.text = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // 기존 기록 편집
    final r = widget.existingRecord;
    if (r != null) {
      _dateCtrl.text       = r['consultation_date'] ?? _dateCtrl.text;
      _drinkingCtrl.text   = r['drinking']          ?? '';
      _smokingCtrl.text    = r['smoking']            ?? '';
      _exerciseCtrl.text   = r['exercise']           ?? '';
      _bpSysCtrl.text      = r['bp_systolic']?.toString()  ?? '';
      _bpDiaCtrl.text      = r['bp_diastolic']?.toString() ?? '';
      _bloodSugarCtrl.text = r['blood_sugar']?.toString()  ?? '';
      _weightCtrl.text     = r['weight']?.toString()        ?? '';
      _recommendCtrl.text  = r['recommendations']   ?? '';
      _followUpCtrl.text   = r['follow_up']          ?? '';
      _consultantCtrl.text = r['consultant']         ?? '';
      _notesCtrl.text      = r['notes']              ?? '';
      _gender              = r['gender']             ?? '남';
      _diagnoses.addAll((r['diagnoses'] as List? ?? []).cast<String>());
      // 프로필 매칭
      if (r['user_id'] != null) {
        _selectedProfile = widget.profiles.firstWhere(
            (p) => p['id'] == r['user_id'], orElse: () => {});
      }
    }
  }

  @override
  void dispose() {
    for (final c in [_dateCtrl, _drinkingCtrl, _smokingCtrl, _exerciseCtrl,
        _bpSysCtrl, _bpDiaCtrl, _bloodSugarCtrl, _weightCtrl,
        _recommendCtrl, _followUpCtrl, _consultantCtrl, _notesCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_selectedProfile == null && widget.existingRecord == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('직원을 선택해주세요')));
      return;
    }
    setState(() => _isSaving = true);
    try {
      final data = {
        'user_id':          _selectedProfile?['id'] ??
                            widget.existingRecord?['user_id'],
        'full_name':        _selectedProfile?['full_name'] ??
                            widget.existingRecord?['full_name'],
        'dept_category':    _selectedProfile?['dept_category'] ??
                            widget.existingRecord?['dept_category'],
        'consultation_date': _dateCtrl.text,
        'gender':           _gender,
        'drinking':         _drinkingCtrl.text.trim(),
        'smoking':          _smokingCtrl.text.trim(),
        'exercise':         _exerciseCtrl.text.trim(),
        'bp_systolic':      int.tryParse(_bpSysCtrl.text.trim()),
        'bp_diastolic':     int.tryParse(_bpDiaCtrl.text.trim()),
        'blood_sugar':      int.tryParse(_bloodSugarCtrl.text.trim()),
        'weight':           double.tryParse(_weightCtrl.text.trim()),
        'diagnoses':        _diagnoses.toList(),
        'recommendations':  _recommendCtrl.text.trim(),
        'follow_up':        _followUpCtrl.text.trim(),
        'consultant':       _consultantCtrl.text.trim(),
        'notes':            _notesCtrl.text.trim(),
      };

      if (widget.existingRecord != null) {
        await supabase.from('health_records')
            .update(data)
            .eq('id', widget.existingRecord!['id']);
      } else {
        await supabase.from('health_records').insert(data);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('저장 실패: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        title: Text(widget.existingRecord != null ? '건강 기록 수정' : '건강 기록 추가',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1D2E),
        elevation: 0,
        surfaceTintColor: Colors.white,
        actions: [
          _isSaving
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _primary)))
              : TextButton(
                  onPressed: _save,
                  child: const Text('저장',
                      style: TextStyle(color: _primary,
                          fontWeight: FontWeight.w800, fontSize: 15))),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 60),
          children: [
            // ── 직원 선택
            _section('👤 직원 정보', [
              // 직원 드롭다운
              if (widget.existingRecord == null)
                _fieldWrap('직원 선택', DropdownButtonFormField<Map<String, dynamic>>(
                  value: _selectedProfile,
                  decoration: _inputDeco('직원을 선택하세요'),
                  items: widget.profiles.map((p) => DropdownMenuItem(
                    value: p,
                    child: Text('${p['full_name']} (${_deptLabel(p['dept_category'] ?? '')})',
                        style: const TextStyle(fontSize: 13)),
                  )).toList(),
                  onChanged: (v) => setState(() => _selectedProfile = v),
                ))
              else
                _infoRow('직원', widget.existingRecord!['full_name'] ?? '-'),

              _fieldWrap('상담일', TextFormField(
                controller: _dateCtrl,
                readOnly: true,
                decoration: _inputDeco('날짜 선택'),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (d != null) {
                    _dateCtrl.text = DateFormat('yyyy-MM-dd').format(d);
                  }
                },
              )),

              _fieldWrap('성별', Row(children: [
                _genderBtn('남'), const SizedBox(width: 10), _genderBtn('여'),
              ])),
            ]),

            const SizedBox(height: 16),

            // ── 생활습관
            _section('🚬 생활습관', [
              _fieldWrap('음주', TextFormField(
                controller: _drinkingCtrl,
                decoration: _inputDeco('예: 2회/주 소주1병'),
              )),
              _fieldWrap('흡연', TextFormField(
                controller: _smokingCtrl,
                decoration: _inputDeco('예: 10개비/일, 비흡연'),
              )),
              _fieldWrap('운동', TextFormField(
                controller: _exerciseCtrl,
                decoration: _inputDeco('예: 3회/주 30분, 안함'),
              )),
            ]),

            const SizedBox(height: 16),

            // ── 측정 수치
            _section('💉 측정 수치', [
              Row(children: [
                Expanded(child: _fieldWrap('혈압 (수축기)', TextFormField(
                  controller: _bpSysCtrl,
                  keyboardType: TextInputType.number,
                  decoration: _inputDeco('예: 120'),
                ))),
                const SizedBox(width: 10),
                Expanded(child: _fieldWrap('혈압 (이완기)', TextFormField(
                  controller: _bpDiaCtrl,
                  keyboardType: TextInputType.number,
                  decoration: _inputDeco('예: 80'),
                ))),
              ]),
              Row(children: [
                Expanded(child: _fieldWrap('혈당 (mg/dL)', TextFormField(
                  controller: _bloodSugarCtrl,
                  keyboardType: TextInputType.number,
                  decoration: _inputDeco('예: 108'),
                ))),
                const SizedBox(width: 10),
                Expanded(child: _fieldWrap('체중 (kg)', TextFormField(
                  controller: _weightCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: _inputDeco('예: 72.5'),
                ))),
              ]),
            ]),

            const SizedBox(height: 16),

            // ── 진단
            _section('🏥 진단/소견', [
              _fieldWrap('진단 항목 선택', Wrap(
                spacing: 8, runSpacing: 8,
                children: _diagnosisList.map((d) {
                  final sel = _diagnoses.contains(d);
                  return GestureDetector(
                    onTap: () => setState(() {
                      if (sel) _diagnoses.remove(d);
                      else     _diagnoses.add(d);
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: sel ? Colors.redAccent : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: sel
                                ? Colors.redAccent
                                : Colors.black.withOpacity(0.1)),
                      ),
                      child: Text(d, style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: sel ? Colors.white : Colors.black87)),
                    ),
                  );
                }).toList(),
              )),
            ]),

            const SizedBox(height: 16),

            // ── 건의사항
            _section('📋 건의사항', [
              _fieldWrap('상담 후 건의사항', TextFormField(
                controller: _recommendCtrl,
                maxLines: 4,
                decoration: _inputDeco(
                    '예: 1) 약물치료: 고혈압\n2) 생활습관 개선: 체중조절, 금연\n3) 추적기간: 6개월'),
              )),
              _fieldWrap('추적 기간', TextFormField(
                controller: _followUpCtrl,
                decoration: _inputDeco('예: 6개월'),
              )),
              _fieldWrap('상담자', TextFormField(
                controller: _consultantCtrl,
                decoration: _inputDeco('상담자 이름'),
              )),
              _fieldWrap('기타', TextFormField(
                controller: _notesCtrl,
                maxLines: 2,
                decoration: _inputDeco('기타 메모'),
              )),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Text(title, style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w900,
              color: Color(0xFF1A1D2E))),
        ),
        const Divider(height: 1, color: Color(0xFFF0F2F8)),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: children),
        ),
      ]),
    );
  }

  Widget _fieldWrap(String label, Widget field) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700,
            color: Color(0xFF8A93B0))),
        const SizedBox(height: 6),
        field,
      ]),
    );
  }

  Widget _infoRow(String label, String value) {
    return _fieldWrap(label, Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
          color: const Color(0xFFF4F6FB),
          borderRadius: BorderRadius.circular(12)),
      child: Text(value, style: const TextStyle(
          fontSize: 14, fontWeight: FontWeight.w700)),
    ));
  }

  Widget _genderBtn(String g) {
    final sel = _gender == g;
    return GestureDetector(
      onTap: () => setState(() => _gender = g),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: sel ? _primary : const Color(0xFFF4F6FB),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(g, style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w800,
            color: sel ? Colors.white : Colors.black54)),
      ),
    );
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF8A93B0)),
    filled: true, fillColor: const Color(0xFFF4F6FB),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none),
  );

  String _deptLabel(String d) {
    const m = {
      'MANAGEMENT':'관리부','PRODUCTION':'생산관리부','SALES':'영업부',
      'RND':'연구소','STEEL':'스틸생산부','BOX':'박스생산부',
      'DELIVERY':'포장납품부','SSG':'에스에스지',
      'CLEANING':'환경미화','NUTRITION':'영양사',
    };
    return m[d] ?? d;
  }
}