import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController     = TextEditingController();

  String _selectedDept     = 'MANAGEMENT';
  String _selectedPosition = '사원';
  bool   _isLoading = false;
  bool   _obscurePw = true;

  static const _bg      = Color(0xFFEDF0F5);
  static const _primary = Color(0xFF2E6BFF);

  static const _departments = [
    {'value': 'MANAGEMENT', 'label': '관리부'},
    {'value': 'PRODUCTION', 'label': '생산관리부'},
    {'value': 'SALES',      'label': '영업부'},
    {'value': 'RND',        'label': '연구소'},
    {'value': 'STEEL',      'label': '스틸생산부'},
    {'value': 'BOX',        'label': '박스생산부'},
    {'value': 'DELIVERY',   'label': '포장납품부'},
    {'value': 'SSG',        'label': '에스에스지'},
    {'value': 'CLEANING',   'label': '환경미화'},
    {'value': 'NUTRITION',  'label': '영양사'},
  ];

  static const _positions = [
    '사원', '주임', '대리', '과장', '차장', '부장',
  ];

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    final email    = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name     = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty || name.isEmpty) {
      _snack("모든 정보를 입력해주세요.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // ✅ Auth 회원가입만 수행 (profiles upsert 제거: RLS 충돌 방지)
      await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name':     name,
          'dept_category': _selectedDept,
          'position':      _selectedPosition,
        },
      );

      if (!mounted) return;
      _snack("회원가입 인증 메일이 발송되었습니다. 메일함을 확인해주세요!");
      Navigator.pop(context);
    } on AuthException catch (error) {
      if (!mounted) return;
      String msg = error.message;

      if (error.statusCode == '429' || msg.toLowerCase().contains('rate limit')) {
        msg = "너무 자주 시도했습니다. 잠시 후 다시 시도해주세요.";
      } else if (msg.toLowerCase().contains('already registered')) {
        msg = "이미 가입된 이메일입니다.";
      } else if (msg.toLowerCase().contains('password')) {
        msg = "비밀번호가 너무 짧습니다.";
      }

      _snack(msg, isError: true);
    } catch (e) {
      debugPrint("회원가입 오류: $e");
      if (!mounted) return;
      _snack("서버 연결에 실패했습니다.", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
      backgroundColor: isError ? Colors.redAccent : const Color(0xFF1A1D2E),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ));
  }

  InputDecoration _dec({
    required String label,
    required IconData icon,
    String? hint,
    Widget? suffixIcon,
  }) =>
      InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
            color: Colors.black54,
            fontWeight: FontWeight.w600,
            fontSize: 14),
        hintText: hint,
        hintStyle: TextStyle(color: Colors.black.withOpacity(0.3), fontSize: 13),
        prefixIcon: Icon(icon, color: _primary, size: 22),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFFFBFBFC),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
                color: Colors.black.withOpacity(0.1), width: 1.2)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
                color: Colors.black.withOpacity(0.08), width: 1.2)),
        focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
            borderSide: BorderSide(color: _primary, width: 2.0)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text("회원가입",
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.black.withOpacity(0.05), height: 1),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // 헤더
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [_primary, _primary.withOpacity(0.75)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                          color: _primary.withOpacity(0.2),
                          blurRadius: 15,
                          offset: const Offset(0, 8))
                    ],
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.security_rounded,
                          color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                        child: Text(
                      "환영합니다!\n정확한 정보를 입력하여 가입을 시작하세요.",
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.95),
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          height: 1.3),
                    )),
                  ]),
                ),
                const SizedBox(height: 22),

                // 기본 정보 카드
                _card(title: "사용자 기본 정보", icon: Icons.person_rounded, children: [
                  TextField(
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    decoration:
                        _dec(label: "성함", icon: Icons.person_outline_rounded, hint: "성함을 입력하세요"),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: _dec(
                        label: "이메일 주소",
                        icon: Icons.alternate_email_rounded,
                        hint: "example@email.com"),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePw,
                    textInputAction: TextInputAction.done,
                    decoration: _dec(
                      label: "비밀번호",
                      icon: Icons.lock_outline_rounded,
                      hint: "8자 이상 입력하세요",
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _obscurePw = !_obscurePw),
                        icon: Icon(_obscurePw ? Icons.visibility_off : Icons.visibility),
                        color: Colors.black38,
                        iconSize: 20,
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 14),

                // 부서 + 직급 카드
                _card(title: "소속 및 직급", icon: Icons.badge_rounded, children: [
                  DropdownButtonFormField<String>(
                    value: _selectedDept,
                    icon: const Icon(Icons.arrow_drop_down_circle_outlined, color: _primary),
                    decoration: _dec(label: "소속 부서", icon: Icons.apartment_rounded),
                    items: _departments
                        .map((d) => DropdownMenuItem(
                              value: d['value'],
                              child: Text(d['label']!, style: const TextStyle(fontWeight: FontWeight.w700)),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedDept = v!),
                    dropdownColor: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  const SizedBox(height: 20),

                  Row(children: [
                    const Icon(Icons.badge_outlined, color: _primary, size: 20),
                    const SizedBox(width: 8),
                    const Text("직급 선택",
                        style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w700, fontSize: 14)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: _primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(_selectedPosition,
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
                    ),
                  ]),
                  const SizedBox(height: 12),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _positions.map((p) {
                      final selected = _selectedPosition == p;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedPosition = p),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: selected ? _primary : const Color(0xFFF4F6FB),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selected ? _primary : Colors.black.withOpacity(0.08),
                              width: selected ? 0 : 1,
                            ),
                            boxShadow: selected
                                ? [
                                    BoxShadow(
                                        color: _primary.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3)),
                                  ]
                                : [],
                          ),
                          child: Text(
                            p,
                            style: TextStyle(
                              color: selected ? Colors.white : const Color(0xFF4A4D5E),
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ]),
                const SizedBox(height: 28),

                // 제출 버튼
                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _signUp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      elevation: 5,
                      shadowColor: _primary.withOpacity(0.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                        : const Text("계정 생성하기",
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                  ),
                ),
                const SizedBox(height: 18),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.info_outline_rounded, size: 14, color: Colors.black.withOpacity(0.4)),
                  const SizedBox(width: 6),
                  Text(
                    "이메일 인증이 완료되어야 로그인이 가능합니다.",
                    style: TextStyle(
                        color: Colors.black.withOpacity(0.5),
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5),
                  ),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.06), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _primary, size: 17),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
                fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF1A1D2E)),
          ),
        ]),
        const SizedBox(height: 18),
        ...children,
      ]),
    );
  }
}