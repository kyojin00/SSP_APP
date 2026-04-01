// import 'package:flutter/material.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:intl/intl.dart';
// import 'field_management_screen.dart';
// import 'dorm_management_screen.dart';

// class MealStatsScreen extends StatefulWidget {
//   final Map<String, dynamic> userProfile;
//   const MealStatsScreen({Key? key, required this.userProfile}) : super(key: key);

//   @override
//   State<MealStatsScreen> createState() => _MealStatsScreenState();
// }

// class _MealStatsScreenState extends State<MealStatsScreen> with TickerProviderStateMixin {
//   final supabase = Supabase.instance.client;
//   String _mealType = 'LUNCH';
//   late final AnimationController _fadeCtrl;
//   late final Animation<double> _fadeAnim;

//   // 색상 팔레트 (화이트 테마)
//   static const _bg       = Color(0xFFF4F6FB);
//   static const _surface  = Color(0xFFFFFFFF);
//   static const _card     = Color(0xFFFFFFFF);
//   static const _blue     = Color(0xFF2E6BFF);
//   static const _teal     = Color(0xFF0BC5C5);
//   static const _orange   = Color(0xFFFF8C42);
//   static const _purple   = Color(0xFF7C5CDB);
//   static const _red      = Color(0xFFFF4D64);
//   static const _textPri  = Color(0xFF1A1D2E);
//   static const _textSub  = Color(0xFF8A93B0);

//   @override
//   void initState() {
//     super.initState();
//     _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
//     _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
//     _fadeCtrl.forward();
//   }

//   @override
//   void dispose() {
//     _fadeCtrl.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
//     final dayLabel = DateFormat('MM월 dd일 (E)', 'ko_KR').format(DateTime.now());

//     return Scaffold(
//       backgroundColor: _bg,
//       appBar: AppBar(
//         backgroundColor: Colors.white,
//         foregroundColor: _textPri,
//         elevation: 0,
//         surfaceTintColor: Colors.white,
//         title: const Text("관제 센터", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: _textPri)),
//         centerTitle: true,
//         actions: [
//           GestureDetector(
//             onTap: () => setState(() {}),
//             child: Container(
//               margin: const EdgeInsets.only(right: 16),
//               padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
//               decoration: BoxDecoration(
//                 color: _blue.withOpacity(0.15),
//                 borderRadius: BorderRadius.circular(8),
//                 border: Border.all(color: _blue.withOpacity(0.3)),
//               ),
//               child: Row(mainAxisSize: MainAxisSize.min, children: [
//                 const Icon(Icons.refresh_rounded, size: 14, color: _blue),
//                 const SizedBox(width: 4),
//                 const Text("새로고침", style: TextStyle(fontSize: 12, color: _blue, fontWeight: FontWeight.bold)),
//               ]),
//             ),
//           ),
//         ],
//       ),
//       body: FadeTransition(
//         opacity: _fadeAnim,
//         child: SingleChildScrollView(
//           physics: const BouncingScrollPhysics(),
//           padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               // ─── 헤더 날짜/상태 ───
//               _buildHeader(dayLabel),
//               const SizedBox(height: 24),

//               // ─── 상단 숫자 카드 3개 ───
//               _buildTopStatCards(today),
//               const SizedBox(height: 28),

//               // ─── 기숙사 현황 ───
//               _sectionLabel("기숙사 수용 현황", Icons.domain_rounded, _purple),
//               const SizedBox(height: 12),
//               _buildDormSection(),
//               const SizedBox(height: 28),

//               // ─── 식수 현황 ───
//               _sectionLabel("식수 신청 현황", Icons.restaurant_menu_rounded, _orange),
//               const SizedBox(height: 12),
//               _buildMealSection(today),
//               const SizedBox(height: 28),

//               // ─── 설비 고장 현황 ───
//               _sectionLabel("현장 설비 현황", Icons.build_circle_rounded, _teal),
//               const SizedBox(height: 12),
//               _buildFaultSection(),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   // ─────────────────────────────────────────────────────────
//   // 헤더
//   // ─────────────────────────────────────────────────────────
//   Widget _buildHeader(String dayLabel) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//       decoration: BoxDecoration(
//         color: _surface,
//         borderRadius: BorderRadius.circular(14),
//         border: Border.all(color: Colors.white.withOpacity(0.05)),
//       ),
//       child: Row(
//         children: [
//           Container(width: 8, height: 8, decoration: const BoxDecoration(color: _teal, shape: BoxShape.circle)),
//           const SizedBox(width: 8),
//           const Text("LIVE", style: TextStyle(color: _teal, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.5)),
//           const Spacer(),
//           Text(dayLabel, style: const TextStyle(color: _textSub, fontSize: 13, fontWeight: FontWeight.w500)),
//         ],
//       ),
//     );
//   }

//   // ─────────────────────────────────────────────────────────
//   // 상단 숫자 카드 3개 (기숙사 총원 / 중식 / 설비 대기)
//   // ─────────────────────────────────────────────────────────
//   Widget _buildTopStatCards(String today) {
//     return FutureBuilder<List<dynamic>>(
//       future: Future.wait([
//         supabase.from('dorm_rooms').select('current_occupancy'),
//         supabase.from('meal_requests').select('is_eating, meal_type').eq('meal_date', today),
//         supabase.from('equipment_reports').select('status'),
//       ]),
//       builder: (context, snap) {
//         int dormTotal = 0, lunchTotal = 0, faultPending = 0;
//         if (snap.hasData) {
//           for (final r in snap.data![0] as List) dormTotal += (r['current_occupancy'] as int? ?? 0);
//           for (final r in snap.data![1] as List) {
//             if (r['meal_type'] == 'LUNCH' && r['is_eating'] == true) lunchTotal++;
//           }
//           for (final r in snap.data![2] as List) {
//             if (r['status'] == 'PENDING') faultPending++;
//           }
//         }
//         return Row(
//           children: [
//             _topCard("기숙 인원", "$dormTotal 명", Icons.hotel_rounded, _purple),
//             const SizedBox(width: 10),
//             _topCard("오늘 중식", "$lunchTotal 명", Icons.lunch_dining_rounded, _orange),
//             const SizedBox(width: 10),
//             _topCard("수리 대기", "$faultPending 건", Icons.warning_amber_rounded, _red),
//           ],
//         );
//       },
//     );
//   }

//   Widget _topCard(String label, String value, IconData icon, Color color) {
//     return Expanded(
//       child: Container(
//         padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
//         decoration: BoxDecoration(
//           color: _card,
//           borderRadius: BorderRadius.circular(16),
//           border: Border.all(color: color.withOpacity(0.2)),
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Container(
//               padding: const EdgeInsets.all(7),
//               decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
//               child: Icon(icon, color: color, size: 16),
//             ),
//             const SizedBox(height: 12),
//             Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
//             const SizedBox(height: 2),
//             Text(label, style: const TextStyle(fontSize: 11, color: _textSub, fontWeight: FontWeight.w500)),
//           ],
//         ),
//       ),
//     );
//   }

//   // ─────────────────────────────────────────────────────────
//   // 기숙사 섹션
//   // ─────────────────────────────────────────────────────────
//   Widget _buildDormSection() {
//     return FutureBuilder<List<Map<String, dynamic>>>(
//       future: supabase.from('dorm_rooms').select('*').order('room_number'),
//       builder: (context, snap) {
//         if (!snap.hasData) return _loadingBox();
//         final rooms = snap.data!;
//         int cur = 0, max = 0;
//         for (final r in rooms) {
//           cur += (r['current_occupancy'] as int? ?? 0);
//           max += (r['max_capacity'] as int? ?? 0);
//         }
//         final ratio = max > 0 ? cur / max : 0.0;

//         return Container(
//           padding: const EdgeInsets.all(20),
//           decoration: _cardDeco(_purple),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               // 전체 점유율 바
//               Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
//                 const Text("전체 수용률", style: TextStyle(color: _textSub, fontSize: 13)),
//                 Text("$cur / $max 명", style: const TextStyle(color: _textPri, fontWeight: FontWeight.w800, fontSize: 14)),
//               ]),
//               const SizedBox(height: 10),
//               _progressBar(ratio, _purple),
//               const SizedBox(height: 20),
//               // 호실 그리드
//               GridView.builder(
//                 shrinkWrap: true,
//                 physics: const NeverScrollableScrollPhysics(),
//                 itemCount: rooms.length,
//                 gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//                   crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1.9,
//                 ),
//                 itemBuilder: (_, i) {
//                   final r = rooms[i];
//                   final full = r['current_occupancy'] >= r['max_capacity'];
//                   final empty = r['current_occupancy'] == 0;
//                   final dotColor = full ? _red : empty ? _textSub : _teal;
//                   return Container(
//                     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
//                     decoration: BoxDecoration(
//                       color: full ? _red.withOpacity(0.06) : const Color(0xFFF4F6FB),
//                       borderRadius: BorderRadius.circular(10),
//                       border: Border.all(color: dotColor.withOpacity(0.25)),
//                     ),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         Text(r['room_number'], style: const TextStyle(fontSize: 11, color: _textSub, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
//                         const SizedBox(height: 2),
//                         Row(children: [
//                           Container(width: 6, height: 6, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
//                           const SizedBox(width: 5),
//                           Text("${r['current_occupancy']}/${r['max_capacity']}", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: full ? _red : _textPri)),
//                         ]),
//                       ],
//                     ),
//                   );
//                 },
//               ),
//               const SizedBox(height: 16),
//               _detailButton("기숙사 상세 관리", _purple, () => Navigator.push(context, MaterialPageRoute(
//                 builder: (_) => DormManagementScreen(isAdmin: true, userProfile: widget.userProfile)))),
//             ],
//           ),
//         );
//       },
//     );
//   }

//   // ─────────────────────────────────────────────────────────
//   // 식수 섹션 (전체 회원 기준)
//   // ─────────────────────────────────────────────────────────
//   Widget _buildMealSection(String today) {
//     return Container(
//       padding: const EdgeInsets.all(20),
//       decoration: _cardDeco(_orange),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // 중식 / 석식 탭
//           Container(
//             padding: const EdgeInsets.all(4),
//             decoration: BoxDecoration(color: const Color(0xFFF0F2F8), borderRadius: BorderRadius.circular(12)),
//             child: Row(children: [
//               _mealTab("중식", 'LUNCH'),
//               _mealTab("석식", 'DINNER'),
//             ]),
//           ),
//           const SizedBox(height: 20),
//           FutureBuilder<List<dynamic>>(
//             future: Future.wait([
//               supabase.from('profiles').select('id, full_name, dept_category').order('full_name'),
//               supabase.from('meal_requests').select('user_id, is_eating, meal_type').eq('meal_date', today),
//             ]),
//             builder: (context, snap) {
//               if (!snap.hasData) return _loadingBox();

//               final profiles = List<Map<String, dynamic>>.from(snap.data![0] as List);
//               final requests = List<Map<String, dynamic>>.from(snap.data![1] as List);

//               // 이 날짜+타입의 요청만 필터
//               final todayReqs = requests.where((r) => r['meal_type'] == _mealType).toList();

//               // 각 회원 상태 분류
//               final eating    = <Map<String, dynamic>>[];
//               final notEating = <Map<String, dynamic>>[];
//               final noReply   = <Map<String, dynamic>>[];

//               for (final p in profiles) {
//                 final req = todayReqs.where((r) => r['user_id'] == p['id']).firstOrNull;
//                 if (req == null) {
//                   noReply.add(p);
//                 } else if (req['is_eating'] == true) {
//                   eating.add(p);
//                 } else {
//                   notEating.add(p);
//                 }
//               }

//               final total = profiles.length;
//               final ratio = total > 0 ? eating.length / total : 0.0;

//               return Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   // 요약 숫자 카드
//                   Row(children: [
//                     _mealStatBox("식사", "${eating.length}", _orange),
//                     const SizedBox(width: 8),
//                     _mealStatBox("불참", "${notEating.length}", _textSub),
//                     const SizedBox(width: 8),
//                     _mealStatBox("미응답", "${noReply.length}", _red),
//                   ]),
//                   const SizedBox(height: 14),
//                   // 참여율 바
//                   Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
//                     const Text("식사 참여율", style: TextStyle(color: _textSub, fontSize: 12)),
//                     Text("${(ratio * 100).toStringAsFixed(0)}%  (${eating.length}/$total)", style: const TextStyle(color: _orange, fontWeight: FontWeight.w800, fontSize: 12)),
//                   ]),
//                   const SizedBox(height: 6),
//                   _progressBar(ratio, _orange),
//                   const SizedBox(height: 20),

//                   // 식사 그룹
//                   if (eating.isNotEmpty) ...[
//                     _memberGroupHeader("식사", eating.length, _orange),
//                     const SizedBox(height: 8),
//                     _memberChipWrap(eating, _orange),
//                     const SizedBox(height: 16),
//                   ],

//                   // 불참 그룹
//                   if (notEating.isNotEmpty) ...[
//                     _memberGroupHeader("불참", notEating.length, _textSub),
//                     const SizedBox(height: 8),
//                     _memberChipWrap(notEating, _textSub),
//                     const SizedBox(height: 16),
//                   ],

//                   // 미응답 그룹
//                   if (noReply.isNotEmpty) ...[
//                     _memberGroupHeader("미응답", noReply.length, _red),
//                     const SizedBox(height: 8),
//                     _memberChipWrap(noReply, _red),
//                   ],
//                 ],
//               );
//             },
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _memberGroupHeader(String label, int count, Color color) {
//     return Row(children: [
//       Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
//       const SizedBox(width: 6),
//       Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
//       const SizedBox(width: 6),
//       Text("$count 명", style: TextStyle(fontSize: 12, color: color.withOpacity(0.7))),
//     ]);
//   }

//   Widget _memberChipWrap(List<Map<String, dynamic>> members, Color color) {
//     return Wrap(
//       spacing: 7,
//       runSpacing: 7,
//       children: members.map((p) {
//         return Container(
//           padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
//           decoration: BoxDecoration(
//             color: color.withOpacity(0.08),
//             borderRadius: BorderRadius.circular(20),
//             border: Border.all(color: color.withOpacity(0.2)),
//           ),
//           child: Text(
//             p['full_name'] ?? '-',
//             style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color == _textSub ? _textPri : color),
//           ),
//         );
//       }).toList(),
//     );
//   }

//   Widget _mealTab(String label, String type) {
//     final selected = _mealType == type;
//     return Expanded(
//       child: GestureDetector(
//         onTap: () => setState(() => _mealType = type),
//         child: AnimatedContainer(
//           duration: const Duration(milliseconds: 200),
//           padding: const EdgeInsets.symmetric(vertical: 10),
//           decoration: BoxDecoration(
//             color: selected ? _orange : Colors.transparent,
//             borderRadius: BorderRadius.circular(8),
//           ),
//           child: Center(
//             child: Text(label, style: TextStyle(
//               color: selected ? Colors.white : _textSub,
//               fontWeight: FontWeight.w800,
//               fontSize: 13,
//             )),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _mealStatBox(String label, String value, Color color) {
//     return Expanded(
//       child: Container(
//         padding: const EdgeInsets.symmetric(vertical: 14),
//         decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
//         child: Column(children: [
//           Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
//           const SizedBox(height: 2),
//           Text(label, style: const TextStyle(fontSize: 11, color: _textSub)),
//         ]),
//       ),
//     );
//   }

//   // ─────────────────────────────────────────────────────────
//   // 설비 고장 섹션
//   // ─────────────────────────────────────────────────────────
//   Widget _buildFaultSection() {
//     return FutureBuilder<List<Map<String, dynamic>>>(
//       future: supabase.from('equipment_reports').select(),
//       builder: (context, snap) {
//         if (!snap.hasData) return _loadingBox();
//         final data = snap.data!;
//         final pending = data.where((r) => r['status'] == 'PENDING').length;
//         final completed = data.where((r) => r['status'] == 'COMPLETED').length;
//         final urgent = data.where((r) => r['priority'] == 'URGENT' && r['status'] != 'COMPLETED').length;

//         return Container(
//           padding: const EdgeInsets.all(20),
//           decoration: _cardDeco(_teal),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Row(children: [
//                 _faultStatBox("처리 대기", pending, _red),
//                 const SizedBox(width: 10),
//                 _faultStatBox("완료", completed, _teal),
//               ]),
//               if (urgent > 0) ...[
//                 const SizedBox(height: 16),
//                 Container(
//                   padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
//                   decoration: BoxDecoration(
//                     color: _red.withOpacity(0.1),
//                     borderRadius: BorderRadius.circular(10),
//                     border: Border.all(color: _red.withOpacity(0.3)),
//                   ),
//                   child: Row(children: [
//                     const Icon(Icons.warning_amber_rounded, color: _red, size: 16),
//                     const SizedBox(width: 8),
//                     Text("긴급 미처리 $urgent건이 있습니다!", style: const TextStyle(color: _red, fontWeight: FontWeight.bold, fontSize: 13)),
//                   ]),
//                 ),
//               ],
//               const SizedBox(height: 16),
//               _detailButton("현장 관리 화면으로", _teal, () => Navigator.push(context,
//                 MaterialPageRoute(builder: (_) => const FieldManagementScreen(isAdmin: true)))),
//             ],
//           ),
//         );
//       },
//     );
//   }

//   Widget _faultStatBox(String label, int count, Color color) {
//     return Expanded(
//       child: Container(
//         padding: const EdgeInsets.symmetric(vertical: 14),
//         decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.2))),
//         child: Column(children: [
//           Text("$count", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color)),
//           const SizedBox(height: 2),
//           Text(label, style: const TextStyle(fontSize: 11, color: _textSub)),
//         ]),
//       ),
//     );
//   }

//   // ─────────────────────────────────────────────────────────
//   // 공용 위젯
//   // ─────────────────────────────────────────────────────────

//   Widget _sectionLabel(String title, IconData icon, Color color) {
//     return Row(children: [
//       Container(
//         padding: const EdgeInsets.all(6),
//         decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
//         child: Icon(icon, color: color, size: 16),
//       ),
//       const SizedBox(width: 10),
//       Text(title, style: const TextStyle(color: _textPri, fontSize: 15, fontWeight: FontWeight.w800)),
//     ]);
//   }

//   BoxDecoration _cardDeco(Color accent) => BoxDecoration(
//     color: _card,
//     borderRadius: BorderRadius.circular(20),
//     border: Border.all(color: accent.withOpacity(0.12)),
//     boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 16, offset: const Offset(0, 4))],
//   );

//   Widget _progressBar(double value, Color color) {
//     return ClipRRect(
//       borderRadius: BorderRadius.circular(8),
//       child: LinearProgressIndicator(
//         value: value.clamp(0.0, 1.0),
//         minHeight: 7,
//         backgroundColor: Colors.black.withOpacity(0.06),
//         valueColor: AlwaysStoppedAnimation(color),
//       ),
//     );
//   }

//   Widget _detailButton(String label, Color color, VoidCallback onTap) {
//     return SizedBox(
//       width: double.infinity,
//       child: TextButton(
//         onPressed: onTap,
//         style: TextButton.styleFrom(
//           backgroundColor: color.withOpacity(0.1),
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//           padding: const EdgeInsets.symmetric(vertical: 12),
//         ),
//         child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
//           Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
//           const SizedBox(width: 4),
//           Icon(Icons.arrow_forward_ios_rounded, size: 12, color: color),
//         ]),
//       ),
//     );
//   }

//   Widget _loadingBox() => const Padding(
//     padding: EdgeInsets.symmetric(vertical: 24),
//     child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: _blue)),
//   );
// }