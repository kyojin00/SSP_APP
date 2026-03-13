// meal_menu_screen.dart — 이번주 식단표 조회 + 업로드

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class MealMenuScreen extends StatefulWidget {
  final bool canUpload; // ADMIN 또는 NUTRITION

  const MealMenuScreen({Key? key, required this.canUpload}) : super(key: key);

  @override
  State<MealMenuScreen> createState() => _MealMenuScreenState();
}

class _MealMenuScreenState extends State<MealMenuScreen> {
  final supabase = Supabase.instance.client;

  bool _isLoading = true;
  bool _isUploading = false;
  String? _imageUrl;

  @override
  void initState() {
    super.initState();
    _fetchMenu();
  }

  // 이번주 월요일 날짜 계산
  DateTime _getThisMonday() {
    final now = DateTime.now();
    return now.subtract(Duration(days: now.weekday - 1));
  }

  Future<void> _fetchMenu() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final monday = _getThisMonday();
      final mondayStr = DateFormat('yyyy-MM-dd').format(monday);

      final data = await supabase
          .from('meal_menus')
          .select('image_url, week_start')
          .gte('week_start', mondayStr)
          .order('week_start', ascending: false)
          .limit(1)
          .maybeSingle();

      if (!mounted) return;
      setState(() {
        _imageUrl = data?['image_url'] as String?;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('식단표 로드 실패: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadMenu() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    if (!mounted) return;
    setState(() => _isUploading = true);

    try {
      final bytes = await picked.readAsBytes();
      final monday = _getThisMonday();
      final mondayStr = DateFormat('yyyy-MM-dd').format(monday);
      final fileName = 'menu_$mondayStr.png';

      // Storage 업로드 (덮어쓰기)
      await supabase.storage.from('meal-menus').uploadBinary(
        fileName,
        bytes,
        fileOptions: const FileOptions(
          contentType: 'image/png',
          upsert: true,
        ),
      );

      final url = supabase.storage.from('meal-menus').getPublicUrl(fileName);

      // DB upsert
      await supabase.from('meal_menus').upsert({
        'week_start': mondayStr,
        'image_url': url,
        'uploaded_by': supabase.auth.currentUser?.id,
      }, onConflict: 'week_start');

      if (!mounted) return;
      setState(() {
        _imageUrl = '$url?t=${DateTime.now().millisecondsSinceEpoch}'; // 캐시 무효화
        _isUploading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ 식단표가 업로드되었어요!'),
          backgroundColor: Color(0xFFFF7A2F),
        ),
      );
    } catch (e) {
      debugPrint('식단표 업로드 실패: $e');
      if (!mounted) return;
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ 업로드 실패: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F7),
      appBar: AppBar(
        title: const Text(
          '이번주 식단표',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1D2E),
        elevation: 0,
        surfaceTintColor: Colors.white,
        actions: [
          if (widget.canUpload)
            _isUploading
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFFFF7A2F)),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.upload_rounded),
                    tooltip: '식단표 업로드',
                    onPressed: _uploadMenu,
                  ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF7A2F)))
          : RefreshIndicator(
              color: const Color(0xFFFF7A2F),
              onRefresh: _fetchMenu,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 이미지 or 빈 상태
                    if (_imageUrl != null)
                      _MenuImage(url: _imageUrl!)
                    else
                      _EmptyMenu(
                        canUpload: widget.canUpload,
                        onUpload: _uploadMenu,
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

// ── 식단표 이미지 위젯 (핀치줌 지원)
class _MenuImage extends StatelessWidget {
  final String url;
  const _MenuImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InteractiveViewer(
        minScale: 1.0,
        maxScale: 5.0,
        child: Image.network(
          url,
          fit: BoxFit.contain,
          width: double.infinity,
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            return SizedBox(
              height: 300,
              child: Center(
                child: CircularProgressIndicator(
                  value: progress.expectedTotalBytes != null
                      ? progress.cumulativeBytesLoaded /
                          progress.expectedTotalBytes!
                      : null,
                  color: const Color(0xFFFF7A2F),
                ),
              ),
            );
          },
          errorBuilder: (_, __, ___) => const SizedBox(
            height: 200,
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.broken_image_rounded,
                    size: 48, color: Colors.grey),
                SizedBox(height: 8),
                Text('이미지를 불러올 수 없어요',
                    style: TextStyle(color: Colors.grey)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ── 식단표 없을 때 빈 상태
class _EmptyMenu extends StatelessWidget {
  final bool canUpload;
  final VoidCallback onUpload;
  const _EmptyMenu({required this.canUpload, required this.onUpload});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 260,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFFFF7A2F).withOpacity(0.2), width: 1.5),
      ),
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFFF7A2F).withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.restaurant_menu_rounded,
                size: 40, color: Color(0xFFFF7A2F)),
          ),
          const SizedBox(height: 16),
          const Text(
            '이번주 식단표가 없어요',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1D2E)),
          ),
          const SizedBox(height: 6),
          Text(
            canUpload ? '우측 상단 버튼으로 업로드해주세요' : '아직 등록된 식단표가 없어요',
            style: TextStyle(
                fontSize: 13, color: Colors.black.withOpacity(0.4)),
          ),
          if (canUpload) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF7A2F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
              ),
              onPressed: onUpload,
              icon: const Icon(Icons.upload_rounded, size: 18),
              label: const Text('식단표 업로드',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ]),
      ),
    );
  }
}