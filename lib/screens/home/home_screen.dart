import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../auth/login_screen.dart';
import 'notice_detail_screen.dart';
import 'write_notice_screen.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final supabase = Supabase.instance.client;
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _setupPushNotifications();
  }

  // FCM 토큰 설정 및 저장
  Future<void> _setupPushNotifications() async {
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      final user = supabase.auth.currentUser;

      if (fcmToken != null && user != null) {
        await supabase.from('user_device_tokens').upsert({
          'user_id': user.id,
          'token': fcmToken,
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'user_id');
        debugPrint("[FCM] 토큰 저장/업데이트 성공");
      }
    } catch (e) {
      debugPrint("[FCM] 토큰 저장 실패: $e");
    }
  }

  // 유저 프로필 정보 로드
  Future<void> _loadUserProfile() async {
    final user = supabase.auth.currentUser;
    if (user != null) {
      try {
        final data = await supabase
            .from('profiles')
            .select()
            .eq('id', user.id)
            .single();
        setState(() {
          _userProfile = data;
          _isLoading = false;
        });
      } catch (e) {
        debugPrint("프로필 로드 에러: $e");
      }
    }
  }

  // 💡 로그아웃 확인 팝업창 추가
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text("로그아웃", style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text("정말 로그아웃 하시겠습니까?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), // 취소 버튼
              child: const Text("취소", style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // 팝업 닫기
                _handleSignOut(); // 실제 로그아웃 실행
              },
              child: const Text("확인", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // 로그아웃 처리
  Future<void> _handleSignOut() async {
    await supabase.auth.signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F7FA),
        body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final isAdmin = _userProfile!['role'] == 'ADMIN';
    final myDept = _userProfile!['dept_category'];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('승산팩', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
        centerTitle: false,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.grey),
            onPressed: _showLogoutDialog, // 💡 직접 로그아웃 대신 팝업 함수 호출
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildUserHeader(),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 10, 20, 5),
            child: Text("공지사항 리스트", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Expanded(child: _buildNoticeStream(isAdmin, myDept)),
        ],
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              backgroundColor: Colors.blueAccent,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text("공지작성", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const WriteNoticeScreen()));
              },
            )
          : null,
    );
  }

  Widget _buildUserHeader() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Colors.blueAccent, Colors.blue]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.white.withOpacity(0.2),
            radius: 25,
            child: const Icon(Icons.person, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("${_userProfile!['full_name']} 님", 
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(5)),
                child: Text("${_userProfile!['dept_category']} 소속", 
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoticeStream(bool isAdmin, String myDept) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase.from('notices').stream(primaryKey: ['id']).order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint("Stream Error: ${snapshot.error}");
          return _buildStatusMessage("공지사항을 불러오는 중...");
        }

        if (snapshot.connectionState == ConnectionState.waiting || !snapshot.hasData) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(strokeWidth: 2),
                SizedBox(height: 16),
                Text("공지사항을 불러오는 중...", style: TextStyle(color: Colors.grey, fontSize: 14)),
              ],
            ),
          );
        }

        final allNotices = snapshot.data!;
        final filteredNotices = allNotices.where((notice) {
          final target = notice['target_category'];
          if (target == 'TEST') {
            return myDept == 'TEST';
          }
          if (isAdmin) return true;
          return target == 'ALL' || target == myDept;
        }).toList();

        if (filteredNotices.isEmpty) {
          return _buildStatusMessage("표시할 공지사항이 없습니다.");
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {}); 
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: filteredNotices.length,
            itemBuilder: (context, index) {
              final notice = filteredNotices[index];
              final DateTime createdAt = DateTime.parse(notice['created_at']).toLocal();
              final String dateKey = DateFormat('yyyy년 MM월 dd일').format(createdAt);

              bool showDateHeader = false;
              if (index == 0) {
                showDateHeader = true;
              } else {
                final DateTime prevDate = DateTime.parse(filteredNotices[index - 1]['created_at']).toLocal();
                final String prevDateKey = DateFormat('yyyy년 MM월 dd일').format(prevDate);
                if (dateKey != prevDateKey) showDateHeader = true;
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showDateHeader) _buildDateHeader(dateKey),
                  _buildNoticeCard(notice, isAdmin, createdAt),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildDateHeader(String date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              date,
              style: const TextStyle(
                color: Colors.blueAccent,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const Expanded(child: Divider(indent: 10, endIndent: 10, thickness: 0.5)),
        ],
      ),
    );
  }

  Widget _buildNoticeCard(Map<String, dynamic> notice, bool isAdmin, DateTime createdAt) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(context, MaterialPageRoute(
              builder: (context) => NoticeDetailScreen(notice: notice, isAdmin: isAdmin),
            ));
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _getCategoryBadge(notice['target_category']),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(notice['title'], 
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), 
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            DateFormat('HH:mm').format(createdAt),
                            style: TextStyle(fontSize: 12, color: Colors.blueAccent.withOpacity(0.6), fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              notice['content'], 
                              style: TextStyle(fontSize: 13, color: Colors.grey[600]), 
                              maxLines: 1, overflow: TextOverflow.ellipsis
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey[300]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _getCategoryBadge(String category) {
    Color color;
    IconData icon;
    switch (category) {
      case 'OFFICE': color = Colors.blue; icon = Icons.business; break;
      case 'STEEL': color = Colors.blueGrey; icon = Icons.precision_manufacturing; break;
      case 'BOX': color = Colors.orange; icon = Icons.inventory_2; break;
      case 'TEST': color = Colors.purple; icon = Icons.bug_report; break;
      default: color = Colors.redAccent; icon = Icons.campaign;
    }
    return Container(
      width: 48, height: 48,
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, color: color, size: 24),
    );
  }

  Widget _buildStatusMessage(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.info_outline, color: Colors.grey[300], size: 60),
          const SizedBox(height: 10),
          Text(msg, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}