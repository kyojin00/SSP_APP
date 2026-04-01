// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui_web' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'business_card_camera.dart';
import 'business_card_detail.dart';

// 공통 상수
const bcPrimary = Color(0xFF2E6BFF);
const bcBg      = Color(0xFFF4F6FB);
const bcText    = Color(0xFF1A1D2E);
const bcSub     = Color(0xFF8A93B0);

// 이름 기반 색상
Color bcCardColor(String name) {
  const colors = [
    Color(0xFF2E6BFF), Color(0xFFFF7A2F), Color(0xFF7C5CDB),
    Color(0xFF00BCD4), Color(0xFFE91E8C), Color(0xFF4CAF50),
    Color(0xFFFF5722), Color(0xFF009688),
  ];
  return colors[name.isNotEmpty ? name.codeUnitAt(0) % colors.length : 0];
}

class BusinessCardScreen extends StatefulWidget {
  const BusinessCardScreen({Key? key}) : super(key: key);
  @override
  State<BusinessCardScreen> createState() => _BusinessCardScreenState();
}

class _BusinessCardScreenState extends State<BusinessCardScreen> {
  final supabase = Supabase.instance.client;
  bool   _isLoading   = true;
  List<Map<String, dynamic>> _cards = [];
  String _searchQuery = '';

  @override
  void initState() { super.initState(); _loadCards(); }

  Future<void> _loadCards() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final myId = supabase.auth.currentUser?.id;
      if (myId == null) return;
      final data = await supabase
          .from('business_cards').select()
          .eq('owner_id', myId)
          .order('created_at', ascending: false);
      if (mounted) setState(() => _cards = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      debugPrint('명함 로드 실패: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_searchQuery.isEmpty) return _cards;
    final q = _searchQuery.toLowerCase();
    return _cards.where((c) =>
      (c['name']       ?? '').toLowerCase().contains(q) ||
      (c['company']    ?? '').toLowerCase().contains(q) ||
      (c['department'] ?? '').toLowerCase().contains(q) ||
      (c['position']   ?? '').toLowerCase().contains(q) ||
      (c['email']      ?? '').toLowerCase().contains(q)
    ).toList();
  }

  Future<void> _openCamera() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const BizCardCameraScreen()),
    );
    if (result == null || !mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BizCardScanDialog(
        base64Data: result['base64'] as String,
        mimeType:   result['mimeType'] as String,
        imageBytes: result['bytes'] as Uint8List,
        onSaved:    _loadCards,
        supabase:   supabase,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      backgroundColor: bcBg,
      appBar: AppBar(
        title: const Text('명함 지갑',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: bcText,
        elevation: 0,
        surfaceTintColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFF0F2F8)),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadCards),
        ],
      ),
      body: Column(children: [
        // 검색바
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: '이름, 회사, 부서 검색',
              hintStyle: const TextStyle(color: bcSub, fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded, color: bcSub, size: 20),
              filled: true, fillColor: bcBg,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
          ),
        ),
        Container(height: 1, color: const Color(0xFFF0F2F8)),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: bcPrimary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8)),
              child: Text('${filtered.length}장',
                  style: const TextStyle(fontSize: 12, color: bcPrimary,
                      fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
        Container(height: 1, color: const Color(0xFFF0F2F8)),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: bcPrimary))
              : filtered.isEmpty
                  ? _empty()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) => _cardTile(filtered[i]),
                    ),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCamera,
        backgroundColor: bcPrimary,
        icon: const Icon(Icons.camera_alt_rounded, color: Colors.white),
        label: const Text('명함 촬영',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
      ),
    );
  }

  Widget _empty() => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(Icons.credit_card_off_rounded, size: 56, color: Colors.grey[300]),
    const SizedBox(height: 14),
    Text(_searchQuery.isEmpty ? '저장된 명함이 없습니다' : '검색 결과가 없습니다',
        style: const TextStyle(color: bcSub, fontSize: 14)),
    if (_searchQuery.isEmpty) ...[
      const SizedBox(height: 20),
      ElevatedButton.icon(
        onPressed: _openCamera,
        icon: const Icon(Icons.camera_alt_rounded, size: 16),
        label: const Text('첫 명함 추가'),
        style: ElevatedButton.styleFrom(
            backgroundColor: bcPrimary, foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      ),
    ],
  ]));

  Widget _cardTile(Map<String, dynamic> card) {
    final name     = card['name']       as String? ?? '-';
    final company  = card['company']    as String? ?? '';
    final dept     = card['department'] as String? ?? '';
    final position = card['position']   as String? ?? '';
    final mobile   = card['mobile']     as String? ?? '';
    final email    = card['email']      as String? ?? '';
    final imageUrl = card['image_url']  as String?;
    final color    = bcCardColor(name);

    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => BizCardDetailSheet(
            card: card, supabase: supabase,
            onDelete: _loadCards, onEdit: _loadCards),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
              blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(children: [
          // 이미지 / 아바타
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
            child: imageUrl != null && imageUrl.isNotEmpty
                ? Image.network(imageUrl, width: 90, height: 80, fit: BoxFit.cover,
                    headers: const {'Cache-Control': 'no-cache'},
                    errorBuilder: (_, __, ___) => _avatar(name, color))
                : _avatar(name, color),
          ),
          const SizedBox(width: 14),
          Expanded(child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(name, style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w900, color: bcText)),
                if (position.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text(position, style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w700, color: color)),
                  ),
                ],
              ]),
              const SizedBox(height: 3),
              if (company.isNotEmpty)
                Text(company, style: const TextStyle(fontSize: 12, color: bcSub)),
              if (dept.isNotEmpty)
                Text(dept, style: const TextStyle(fontSize: 11, color: bcSub)),
              const SizedBox(height: 6),
              Row(children: [
                if (mobile.isNotEmpty) _chip(Icons.smartphone_rounded, mobile, color),
                if (mobile.isNotEmpty && email.isNotEmpty) const SizedBox(width: 6),
                if (email.isNotEmpty) _chip(Icons.email_rounded, email, color),
              ]),
            ]),
          )),
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Icon(Icons.chevron_right_rounded, color: Colors.grey[300], size: 20),
          ),
        ]),
      ),
    );
  }

  Widget _avatar(String name, Color color) => Container(
    width: 90, height: 80, color: color.withOpacity(0.08),
    child: Center(child: Text(name.isNotEmpty ? name[0] : '?',
        style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: color))),
  );

  Widget _chip(IconData icon, String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(7)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 10, color: color),
      const SizedBox(width: 3),
      Text(text.length > 12 ? '${text.substring(0, 12)}…' : text,
          style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    ]),
  );
}