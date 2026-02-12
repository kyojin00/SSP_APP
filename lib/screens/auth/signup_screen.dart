import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SignUpScreen extends StatefulWidget {
  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  String _selectedDept = 'OFFICE'; 
  bool _isLoading = false;

  final List<Map<String, String>> _departments = [
    {'value': 'OFFICE', 'label': '사무실'},
    {'value': 'STEEL', 'label': '스틸'},
    {'value': 'BOX', 'label': '박스'},
  ];

  Future<void> _signUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("모든 정보를 입력해주세요.")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': name,
          'dept_category': _selectedDept,
        },
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("회원가입 인증 메일이 발송되었습니다. 메일함을 확인해주세요!")),
        );
        Navigator.pop(context);
      }
    } on AuthException catch (error) {
      if (!mounted) return;
      
      // 💡 영어 에러 메시지를 한국어로 변환하는 로직
      String errorMessage = error.message;

      // Rate Limit (429) 처리
      if (error.statusCode == '429' || error.message.contains('rate limit')) {
        errorMessage = "너무 자주 시도했습니다. 잠시 후 다시 시도해주세요.";
      } 
      // 기타 주요 에러 처리
      else if (error.message.contains('already registered')) {
        errorMessage = "이미 가입된 이메일입니다.";
      } else if (error.message.contains('Password should be')) {
        errorMessage = "비밀번호가 너무 짧습니다.";
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage), 
          backgroundColor: Colors.redAccent
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("서버 연결에 실패했습니다. 나중에 다시 시도하세요."), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("sspaap 회원가입")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController, 
              decoration: const InputDecoration(labelText: '이름', border: OutlineInputBorder())
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController, 
              decoration: const InputDecoration(labelText: '이메일', border: OutlineInputBorder())
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController, 
              decoration: const InputDecoration(labelText: '비밀번호', border: OutlineInputBorder()), 
              obscureText: true
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              value: _selectedDept,
              decoration: const InputDecoration(labelText: '소속 부서 선택', border: OutlineInputBorder()),
              items: _departments.map((dept) => DropdownMenuItem(
                value: dept['value'], 
                child: Text(dept['label']!)
              )).toList(),
              onChanged: (value) => setState(() => _selectedDept = value!),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _signUp,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
              ),
              child: _isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                : const Text("가입하기", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}