import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'signup_screen.dart';
import '../home/home_screen.dart';
import '../../services/onesignal_linker.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading       = false;
  bool _isGoogleLoading = false;
  bool _isKakaoLoading  = false;
  bool _obscurePw       = true;

  static const _primary = Color(0xFF2E6BFF);
  static const _bg      = Color(0xFFEDF0F5);

  Future<void> _saveOneSignalIdIfAny() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final onesignalId = await OneSignalLinker.linkAndGetId(user.id);
      if (onesignalId == null) {
        debugPrint("[OneSignal] skip (not web or not ready)");
        return;
      }

      await supabase.from('user_onesignal').delete().eq('user_id', user.id);
      await supabase.from('user_onesignal').insert({
        'user_id': user.id,
        'onesignal_id': onesignalId,
        'updated_at': DateTime.now().toIso8601String(),
      });

      debugPrint("[OneSignal] saved: $onesignalId");
    } catch (e) {
      debugPrint("[OneSignal] save error: $e");
    }
  }

  Future<void> _signIn() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      _snack('이메일과 비밀번호를 입력해주세요.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email:    _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // ✅ 로그인 직후 OneSignal(웹/PWA) 유저 연결 + onesignalId 저장
      await _saveOneSignalIdIfAny();

      if (!mounted) return;
      _goHome();
    } on AuthException catch (e) {
      _snack(_authError(e), isError: true);
    } catch (_) {
      _snack('서버 연결 오류가 발생했습니다.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isGoogleLoading = true);
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.ssspapp://login-callback',
        authScreenLaunchMode: LaunchMode.inAppWebView,
      );
    } on AuthException catch (e) {
      _snack(_authError(e), isError: true);
    } catch (_) {
      _snack('구글 로그인에 실패했습니다.', isError: true);
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  Future<void> _signInWithKakao() async {
    setState(() => _isKakaoLoading = true);
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.kakao,
        redirectTo: 'io.supabase.ssspapp://login-callback',
        authScreenLaunchMode: LaunchMode.inAppWebView,
      );
    } on AuthException catch (e) {
      _snack(_authError(e), isError: true);
    } catch (_) {
      _snack('카카오 로그인에 실패했습니다.', isError: true);
    } finally {
      if (mounted) setState(() => _isKakaoLoading = false);
    }
  }

  void _goHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  String _authError(AuthException e) {
    if (e.message.contains('Invalid login credentials')) return '이메일 또는 비밀번호가 틀렸습니다.';
    if (e.message.contains('Email not confirmed'))       return '이메일 인증이 필요합니다.';
    if (e.statusCode == '429')                           return '너무 자주 시도했습니다. 잠시 후 다시 시도해주세요.';
    return '로그인 실패: ${e.message}';
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.redAccent : null,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  InputDecoration _dec({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
          color: Colors.black54, fontWeight: FontWeight.w600, fontSize: 14),
      prefixIcon: Icon(icon, color: _primary, size: 22),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFFBFBFC),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.1), width: 1.2)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.08), width: 1.2)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _primary, width: 2.0)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.factory_rounded, size: 64, color: _primary),
                    const SizedBox(height: 16),
                    const Text("승산팩",
                        style: TextStyle(
                            fontSize: 32, fontWeight: FontWeight.w900,
                            color: _primary, letterSpacing: 1.5),
                        textAlign: TextAlign.center),
                    const Text("스마트 공지사항 시스템",
                        style: TextStyle(
                            fontSize: 14, color: Colors.black45,
                            fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 48),

                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                            color: Colors.black.withOpacity(0.06), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 20, offset: const Offset(0, 10))
                        ],
                      ),
                      child: Column(children: [
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: _dec(label: '이메일 주소', icon: Icons.email_rounded),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePw,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _signIn(),
                          decoration: _dec(
                            label: '비밀번호',
                            icon: Icons.lock_rounded,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePw ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                color: Colors.black26,
                              ),
                              onPressed: () => setState(() => _obscurePw = !_obscurePw),
                            ),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _signIn,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                          elevation: 4,
                          shadowColor: _primary.withOpacity(0.4),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18)),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24, height: 24,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 3))
                            : const Text("로그인하기",
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Row(children: [
                      Expanded(child: Divider(color: Colors.black.withOpacity(0.12))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Text("또는",
                            style: TextStyle(
                                color: Colors.black.withOpacity(0.4),
                                fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                      Expanded(child: Divider(color: Colors.black.withOpacity(0.12))),
                    ]),
                    const SizedBox(height: 20),

                    SizedBox(
                      height: 56,
                      child: OutlinedButton(
                        onPressed: _isGoogleLoading ? null : _signInWithGoogle,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF1A1D2E),
                          side: BorderSide(color: Colors.black.withOpacity(0.15), width: 1.5),
                          elevation: 2,
                          shadowColor: Colors.black.withOpacity(0.06),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18)),
                        ),
                        child: _isGoogleLoading
                            ? const SizedBox(
                                width: 22, height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.5))
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 24, height: 24,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.black.withOpacity(0.1)),
                                    ),
                                    child: const Center(
                                      child: Text("G",
                                          style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 14, color: Color(0xFF4285F4))),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text("Google로 계속하기",
                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    SizedBox(
                      height: 56,
                      child: OutlinedButton(
                        onPressed: _isKakaoLoading ? null : _signInWithKakao,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0xFFFEE500),
                          foregroundColor: const Color(0xFF1A1D2E),
                          side: BorderSide(
                              color: const Color(0xFFFEE500).withOpacity(0.5), width: 1.5),
                          elevation: 2,
                          shadowColor: const Color(0xFFFEE500).withOpacity(0.3),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18)),
                        ),
                        child: _isKakaoLoading
                            ? const SizedBox(
                                width: 22, height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5, color: Color(0xFF3A1D1D)))
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 24, height: 24,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF3A1D1D).withOpacity(0.08),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Center(
                                      child: Text("K",
                                          style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 14, color: Color(0xFF3A1D1D))),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text("카카오로 계속하기",
                                      style: TextStyle(
                                          fontSize: 15, fontWeight: FontWeight.w800,
                                          color: Color(0xFF3A1D1D))),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("계정이 없으신가요?",
                            style: TextStyle(color: Colors.black45, fontWeight: FontWeight.w600)),
                        TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => SignUpScreen()),
                          ),
                          child: const Text("회원가입",
                              style: TextStyle(
                                  color: _primary, fontWeight: FontWeight.w900,
                                  decoration: TextDecoration.underline)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}