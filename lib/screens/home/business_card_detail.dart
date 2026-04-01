import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'business_card_screen.dart';

class BizCardDetailSheet extends StatefulWidget {
  final Map<String, dynamic> card;
  final SupabaseClient supabase;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const BizCardDetailSheet({
    Key? key,
    required this.card,
    required this.supabase,
    required this.onDelete,
    required this.onEdit,
  }) : super(key: key);

  @override
  State<BizCardDetailSheet> createState() => _BizCardDetailSheetState();
}

class _BizCardDetailSheetState extends State<BizCardDetailSheet> {
  bool _showImage = false;
  final Set<String> _copiedFields = {};

  void _copy(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    setState(() => _copiedFields.add(label));
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copiedFields.remove(label));
    });
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('명함 삭제', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text('${widget.card['name']} 명함을\n삭제하시겠습니까?',
            style: const TextStyle(fontSize: 14, height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.supabase.from('business_cards').delete().eq('id', widget.card['id']);
    if (mounted) { Navigator.pop(context); widget.onDelete(); }
  }

  @override
  Widget build(BuildContext context) {
    final c        = widget.card;
    final name     = c['name']      as String? ?? '-';
    final company  = c['company']   as String? ?? '';
    final dept     = c['department']as String? ?? '';
    final position = c['position']  as String? ?? '';
    final imageUrl = c['image_url'] as String?;
    final color    = bcCardColor(name);
    final date     = c['created_at'] != null
        ? DateFormat('yyyy.MM.dd').format(DateTime.parse(c['created_at'])) : '';

    // 연락처 항목 리스트
    final contacts = <_ContactItem>[
      if ((c['mobile']  ?? '').isNotEmpty)
        _ContactItem(Icons.smartphone_rounded, '휴대폰',   c['mobile'],  color, true),
      if ((c['phone']   ?? '').isNotEmpty)
        _ContactItem(Icons.phone_rounded,      '대표전화', c['phone'],   color, true),
      if ((c['email']   ?? '').isNotEmpty)
        _ContactItem(Icons.email_rounded,      '이메일',   c['email'],   color, true),
      if ((c['address'] ?? '').isNotEmpty)
        _ContactItem(Icons.location_on_rounded,'주소',     c['address'], color, true),
      if ((c['website'] ?? '').isNotEmpty)
        _ContactItem(Icons.language_rounded,   '웹사이트', c['website'], color, true),
      if ((c['memo']    ?? '').isNotEmpty)
        _ContactItem(Icons.sticky_note_2_rounded,'메모',   c['memo'],    color, false),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 20),
      decoration: BoxDecoration(
          color: const Color(0xFFF8F9FE),
          borderRadius: BorderRadius.circular(28)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // ── 핸들
        Container(width: 40, height: 4,
            margin: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2))),

        // ── 명함 카드
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: _buildCard(name, company, dept, position, imageUrl, color),
        ),

        // ── 원본 이미지 펼치기
        if (_showImage && imageUrl != null && imageUrl.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(imageUrl, width: double.infinity,
                  fit: BoxFit.contain,
                  headers: const {'Cache-Control': 'no-cache'},
                  errorBuilder: (_, __, ___) => const SizedBox()),
            ),
          ),

        // ── 연락처 섹션
        if (contacts.isNotEmpty) ...[
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Container(width: 3, height: 14,
                  decoration: BoxDecoration(color: color,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
              const Text('연락처', style: TextStyle(fontSize: 12,
                  fontWeight: FontWeight.w800, color: bcSub)),
            ]),
          ),
          const SizedBox(height: 8),
          Flexible(child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Column(children: [
              // 연락처 그리드 카드
              Container(
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
                        blurRadius: 10, offset: const Offset(0, 3))]),
                child: Column(children: contacts.asMap().entries.map((e) {
                  final idx  = e.key;
                  final item = e.value;
                  final isLast = idx == contacts.length - 1;
                  return _contactRow(item, isLast);
                }).toList()),
              ),
              const SizedBox(height: 12),
              // 하단 등록일 + 삭제
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.calendar_today_rounded, size: 11,
                        color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Text(date, style: TextStyle(fontSize: 11, color: Colors.grey[500],
                        fontWeight: FontWeight.w500)),
                  ]),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _delete,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.withOpacity(0.15))),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.delete_outline_rounded, size: 14, color: Colors.red),
                      SizedBox(width: 4),
                      Text('삭제', style: TextStyle(
                          color: Colors.red, fontSize: 12,
                          fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
            ]),
          )),
        ] else
          const SizedBox(height: 20),
      ]),
    );
  }

  Widget _buildCard(String name, String company, String dept,
      String position, String? imageUrl, Color color) {
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;
    return GestureDetector(
      onTap: hasImage ? () => setState(() => _showImage = !_showImage) : null,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [color, Color.lerp(color, Colors.black, 0.25)!],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.35),
                blurRadius: 20, offset: const Offset(0, 8)),
            BoxShadow(color: color.withOpacity(0.15),
                blurRadius: 40, offset: const Offset(0, 16)),
          ],
        ),
        child: Stack(children: [
          // 배경 장식 원
          Positioned(right: -20, top: -20,
            child: Container(width: 100, height: 100,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.06)))),
          Positioned(right: 30, bottom: -30,
            child: Container(width: 70, height: 70,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.04)))),
          // 내용
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              // 회사명
              if (company.isNotEmpty)
                Text(company.toUpperCase(),
                    style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.6),
                        fontWeight: FontWeight.w700, letterSpacing: 1.2)),
              if (company.isNotEmpty) const SizedBox(height: 8),
              // 이름
              Text(name, style: const TextStyle(fontSize: 24,
                  fontWeight: FontWeight.w900, color: Colors.white, height: 1.1)),
              const SizedBox(height: 6),
              // 직책 · 부서
              if (position.isNotEmpty || dept.isNotEmpty)
                Row(children: [
                  if (position.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6)),
                      child: Text(position, style: const TextStyle(
                          fontSize: 11, color: Colors.white,
                          fontWeight: FontWeight.w700)),
                    ),
                  if (position.isNotEmpty && dept.isNotEmpty)
                    const SizedBox(width: 6),
                  if (dept.isNotEmpty)
                    Text(dept, style: TextStyle(fontSize: 11,
                        color: Colors.white.withOpacity(0.75),
                        fontWeight: FontWeight.w500)),
                ]),
            ])),
            const SizedBox(width: 12),
            // 이미지 or 이니셜
            Column(children: [
              Container(
                width: 58, height: 58,
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                    boxShadow: [BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 8, offset: const Offset(0, 3))]),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: hasImage
                      ? Image.network(imageUrl!, fit: BoxFit.cover,
                          headers: const {'Cache-Control': 'no-cache'},
                          errorBuilder: (_, __, ___) => _initials(name))
                      : _initials(name),
                ),
              ),
              if (hasImage) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(5)),
                  child: Text(_showImage ? '접기' : '원본 보기',
                      style: TextStyle(fontSize: 9,
                          color: Colors.white.withOpacity(0.8),
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ]),
          ]),
        ]),
      ),
    );
  }

  Widget _initials(String name) => Container(
    color: Colors.white.withOpacity(0.15),
    child: Center(child: Text(name.isNotEmpty ? name[0] : '?',
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900,
            color: Colors.white))),
  );

  Widget _contactRow(_ContactItem item, bool isLast) {
    final copied = _copiedFields.contains(item.label);
    return GestureDetector(
      onLongPress: item.copyable ? () => _copy(item.value, item.label) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
            color: copied ? Colors.green.withOpacity(0.04) : Colors.transparent,
            borderRadius: isLast
                ? const BorderRadius.vertical(bottom: Radius.circular(18))
                : null),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(children: [
              // 아이콘
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: copied
                        ? Colors.green.withOpacity(0.12)
                        : item.color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(item.icon, size: 16,
                    color: copied ? Colors.green : item.color),
              ),
              const SizedBox(width: 12),
              // 텍스트
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(item.label, style: const TextStyle(
                      fontSize: 10, color: bcSub, fontWeight: FontWeight.w600)),
                  if (copied) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(5)),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.check_circle_rounded,
                            size: 8, color: Colors.green),
                        SizedBox(width: 3),
                        Text('복사됨', style: TextStyle(
                            fontSize: 9, fontWeight: FontWeight.w800,
                            color: Colors.green)),
                      ]),
                    ),
                  ],
                ]),
                const SizedBox(height: 2),
                Text(item.value, style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: copied ? Colors.green.shade700 : bcText)),
              ])),
              // 복사 버튼
              if (item.copyable)
                GestureDetector(
                  onTap: () => _copy(item.value, item.label),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: copied
                            ? Colors.green.withOpacity(0.1)
                            : item.color.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: copied
                                ? Colors.green.withOpacity(0.25)
                                : item.color.withOpacity(0.12))),
                    child: Icon(
                        copied ? Icons.check_rounded : Icons.copy_rounded,
                        size: 15,
                        color: copied ? Colors.green : item.color.withOpacity(0.7)),
                  ),
                ),
            ]),
          ),
          if (!isLast) Divider(height: 1, indent: 52,
              color: Colors.grey.withOpacity(0.08)),
        ]),
      ),
    );
  }
}

class _ContactItem {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool copyable;
  _ContactItem(this.icon, this.label, this.value, this.color, this.copyable);
}