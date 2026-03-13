import 'package:flutter/material.dart';

/// 앱 전체에서 재사용하는 Shimmer 스켈레톤 로더
/// shimmer 패키지 없이 순수 Flutter로 구현
class ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const ShimmerBox({
    Key? key,
    required this.width,
    required this.height,
    this.borderRadius,
  }) : super(key: key);

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
            gradient: LinearGradient(
              begin: Alignment(-1.5 + _anim.value * 3, 0),
              end: Alignment(-0.5 + _anim.value * 3, 0),
              colors: const [
                Color(0xFFE8ECF0),
                Color(0xFFF4F6F9),
                Color(0xFFE8ECF0),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 홈 화면 메뉴 그리드 스켈레톤
class HomeMenuSkeleton extends StatelessWidget {
  const HomeMenuSkeleton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      body: CustomScrollView(
        slivers: [
          // AppBar 스켈레톤
          SliverAppBar(
            expandedHeight: 180.0,
            pinned: true,
            backgroundColor: const Color(0xFF2E6BFF),
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1E4AD9), Color(0xFF2E6BFF), Color(0xFF4FB2FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                ShimmerBox(width: 120, height: 22, borderRadius: BorderRadius.circular(6)),
                const SizedBox(height: 16),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 3,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.85,
                  children: List.generate(
                    9,
                    (_) => Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 5))],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ShimmerBox(width: 52, height: 52, borderRadius: BorderRadius.circular(26)),
                          const SizedBox(height: 10),
                          ShimmerBox(width: 56, height: 13, borderRadius: BorderRadius.circular(4)),
                        ],
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
