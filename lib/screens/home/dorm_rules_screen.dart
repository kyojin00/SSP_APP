import 'package:flutter/material.dart';

class DormRulesScreen extends StatefulWidget {
  const DormRulesScreen({Key? key}) : super(key: key);

  @override
  State<DormRulesScreen> createState() => _DormRulesScreenState();
}

class _DormRulesScreenState extends State<DormRulesScreen> {
  String _lang = 'ko';

  static const _primary = Color(0xFF2E6BFF);
  static const _bg      = Color(0xFFF4F6FB);
  static const _text    = Color(0xFF1A1D2E);
  static const _sub     = Color(0xFF8A93B0);

  // ── 언어 목록 ──
  static const List<Map<String, String>> _langs = [
    {'code': 'ko', 'flag': '🇰🇷', 'label': '한국어'},
    {'code': 'en', 'flag': '🇺🇸', 'label': 'English'},
    {'code': 'vi', 'flag': '🇻🇳', 'label': 'Tiếng Việt'},
    {'code': 'uz', 'flag': '🇺🇿', 'label': "O'zbek"},
    {'code': 'km', 'flag': '🇰🇭', 'label': 'ខ្មែរ'},
  ];

  // ── 규정 내용 (규정별로 분리) ──
  static const Map<String, List<Map<String, dynamic>>> _rules = {
    'ko': [
      {'icon': Icons.no_drinks_rounded,      'title': '음주 및 소란 금지',    'desc': '기숙사 내 음주 및 소란 행위를 엄격히 금지합니다.'},
      {'icon': Icons.electrical_services_rounded, 'title': '전열기구 사용 주의', 'desc': '전기 장판 등 전열기구 사용 시 화재 예방에 주의 바랍니다.'},
      {'icon': Icons.night_shelter_rounded,  'title': '외부인 출입 금지',      'desc': '기숙사 내 외부인 무단 출입을 금지합니다.'},
      {'icon': Icons.volume_off_rounded,     'title': '심야 정숙',            'desc': '오후 10시 이후 소음 발생 행위를 금지합니다.'},
      {'icon': Icons.cleaning_services_rounded,'title': '청결 유지',           'desc': '공용 공간은 항상 깨끗하게 사용해 주세요.'},
      {'icon': Icons.warning_amber_rounded,  'title': '벌점 퇴실 기준',       'desc': '벌점 3점 이상 시 즉시 퇴실 조치됩니다.'},
    ],
    'en': [
      {'icon': Icons.no_drinks_rounded,      'title': 'No Alcohol & Noise',   'desc': 'Alcohol consumption and loud noise are strictly prohibited.'},
      {'icon': Icons.electrical_services_rounded, 'title': 'Heater Safety',   'desc': 'Be careful when using electric heaters to prevent fires.'},
      {'icon': Icons.night_shelter_rounded,  'title': 'No Visitors',          'desc': 'Unauthorized visitors are not allowed in the dormitory.'},
      {'icon': Icons.volume_off_rounded,     'title': 'Quiet Hours',          'desc': 'No noise after 10:00 PM.'},
      {'icon': Icons.cleaning_services_rounded,'title': 'Keep Clean',         'desc': 'Please keep all common areas clean at all times.'},
      {'icon': Icons.warning_amber_rounded,  'title': 'Demerit Policy',       'desc': 'Eviction is immediate upon reaching 3 demerit points.'},
    ],
    'vi': [
      {'icon': Icons.no_drinks_rounded,      'title': 'Cấm rượu & ồn ào',    'desc': 'Nghiêm cấm uống rượu và gây ồn ào trong ký túc xá.'},
      {'icon': Icons.electrical_services_rounded, 'title': 'An toàn điện',    'desc': 'Cẩn thận khi sử dụng thiết bị sưởi điện để phòng cháy.'},
      {'icon': Icons.night_shelter_rounded,  'title': 'Cấm người ngoài',      'desc': 'Không cho phép người ngoài vào ký túc xá.'},
      {'icon': Icons.volume_off_rounded,     'title': 'Giờ yên tĩnh',        'desc': 'Không được gây tiếng ồn sau 22:00.'},
      {'icon': Icons.cleaning_services_rounded,'title': 'Giữ sạch sẽ',       'desc': 'Hãy giữ sạch tất cả các khu vực chung.'},
      {'icon': Icons.warning_amber_rounded,  'title': 'Quy định điểm phạt',  'desc': 'Bị đuổi ngay khi tích lũy 3 điểm phạt.'},
    ],
    'uz': [
      {'icon': Icons.no_drinks_rounded,      'title': 'Ichimlik & shovqin taqiqlangan', 'desc': 'Yotoqxonada ichimlik ichish va shovqin ko\'tarish qat\'iyan taqiqlanadi.'},
      {'icon': Icons.electrical_services_rounded, 'title': 'Elektr xavfsizligi', 'desc': 'Yong\'in oldini olish uchun elektr isitgichlardan ehtiyotkorlik bilan foydalaning.'},
      {'icon': Icons.night_shelter_rounded,  'title': 'Tashqi shaxslar taqiqlangan', 'desc': 'Yotoqxonaga ruxsatsiz tashqi shaxslarning kirishiga yo\'l qo\'yilmaydi.'},
      {'icon': Icons.volume_off_rounded,     'title': 'Sokin vaqt',          'desc': 'Kechki soat 22:00 dan keyin shovqin qilish taqiqlanadi.'},
      {'icon': Icons.cleaning_services_rounded,'title': 'Tozalikni saqlang', 'desc': 'Umumiy joylarni doimo toza tutishingizni so\'raymiz.'},
      {'icon': Icons.warning_amber_rounded,  'title': 'Jarima ballari qoidasi', 'desc': '3 ta jarima balliga yetganda darhol chiqarib yuboriladi.'},
    ],
    'km': [
      {'icon': Icons.no_drinks_rounded,      'title': 'ហាមស្រា & សំឡេងរំខាន', 'desc': 'ហាមផឹកស្រា និងបង្កើតសំឡេងរំខាននៅក្នុងអាគារស្នាក់នៅ។'},
      {'icon': Icons.electrical_services_rounded, 'title': 'ការប្រុងប្រយ័ត្នអគ្គិសនី', 'desc': 'ប្រយ័ត្នពេលប្រើឧបករណ៍កំដៅអគ្គិសនី ដើម្បីការពារអគ្គីភ័យ។'},
      {'icon': Icons.night_shelter_rounded,  'title': 'ហាមបុគ្គលខាងក្រៅ',  'desc': 'មិនអនុញ្ញាតឱ្យបុគ្គលខាងក្រៅចូលអាគារស្នាក់នៅទេ។'},
      {'icon': Icons.volume_off_rounded,     'title': 'ម៉ោងស្ងាត់',         'desc': 'មិនអនុញ្ញាតឱ្យបង្កើតសំឡេងរំខានបន្ទាប់ម៉ោង ២២:០០។'},
      {'icon': Icons.cleaning_services_rounded,'title': 'រក្សាអនាម័យ',      'desc': 'សូមរក្សាទីតាំងរួមឱ្យស្អាតជានិច្ច។'},
      {'icon': Icons.warning_amber_rounded,  'title': 'គោលការណ៍ពិន្ទុទណ្ឌ', 'desc': 'នឹងត្រូវបណ្តេញចេញភ្លាមៗ នៅពេលឈានដល់ ៣ ពិន្ទុទណ្ឌ។'},
    ],
  };

  @override
  Widget build(BuildContext context) {
    final rules = _rules[_lang] ?? _rules['ko']!;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text("기숙사 생활 규정",
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
      ),
      body: Column(
        children: [
          // ─── 언어 선택 ───
          _buildLangSelector(),
          // ─── 규정 목록 ───
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              itemCount: rules.length,
              itemBuilder: (_, i) => _buildRuleCard(rules[i], i),
            ),
          ),
          // ─── 동의 버튼 ───
          _buildAgreeButton(context),
        ],
      ),
    );
  }

  // ── 언어 선택 바 ──
  Widget _buildLangSelector() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _langs.map((l) {
            final selected = _lang == l['code'];
            return GestureDetector(
              onTap: () => setState(() => _lang = l['code']!),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? _primary : const Color(0xFFF4F6FB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? _primary : const Color(0xFFE5E8F0),
                  ),
                  boxShadow: selected
                      ? [BoxShadow(color: _primary.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 3))]
                      : [],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(l['flag']!, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 6),
                  Text(l['label']!,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: selected ? Colors.white : _sub)),
                ]),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── 규정 카드 ──
  Widget _buildRuleCard(Map<String, dynamic> rule, int index) {
    final colors = [
      const Color(0xFF2E6BFF),
      const Color(0xFFFF8C42),
      const Color(0xFF8E59FF),
      const Color(0xFF0BC5C5),
      const Color(0xFF0BC5A0),
      const Color(0xFFFF4D64),
    ];
    final color = colors[index % colors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Row(children: [
        // 아이콘
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14)),
          child: Icon(rule['icon'] as IconData, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        // 내용
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 20, height: 20,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Center(
                  child: Text("${index + 1}",
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(rule['title'] as String,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: _text,
                        fontFamily: _lang == 'km' ? 'NotoSansKhmer' : null)),
              ),
            ]),
            const SizedBox(height: 6),
            Text(rule['desc'] as String,
                style: TextStyle(
                    fontSize: 12,
                    color: _sub,
                    height: 1.5,
                    fontFamily: _lang == 'km' ? 'NotoSansKhmer' : null)),
          ]),
        ),
      ]),
    );
  }

  // ── 동의 버튼 ──
  Widget _buildAgreeButton(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, -4))
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(children: [
                  Icon(Icons.check_circle_rounded,
                      color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text("규정을 확인하였습니다.",
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ]),
                backgroundColor: const Color(0xFF0BC5A0),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_rounded, size: 18),
              SizedBox(width: 8),
              Text("규정 확인 및 동의",
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}