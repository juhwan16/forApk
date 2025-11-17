// C:\project\smart_extinguisher_app-main\lib\screens\register_user_screen.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:smart_extinguisher_app/utils/http_helper.dart';

/// ① 소화기 등록 화면 (기존에 사용하던 화면) ------------------------
class RegisterExtinguisherScreen extends StatefulWidget {
  const RegisterExtinguisherScreen({super.key});

  @override
  State<RegisterExtinguisherScreen> createState() =>
      _RegisterExtinguisherScreenState();
}

class _RegisterExtinguisherScreenState
    extends State<RegisterExtinguisherScreen> {
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _expireController = TextEditingController();

  bool _saving = false;

  @override
  void dispose() {
    _locationController.dispose();
    _expireController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null) {
      _expireController.text = picked.toIso8601String().split('T').first;
    }
  }

  Future<void> _save() async {
    final location = _locationController.text.trim();
    final expire = _expireController.text.trim();

    if (location.isEmpty || expire.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('위치와 사용 가능 기간을 입력해주세요.')),
      );
      return;
    }

    setState(() => _saving = true);

    final body = <String, dynamic>{
      'location': location,
      'expireDate': expire,
      // 서버에서 기본 false로 넣지만 명시해도 무방
      'isLightOn': false,
      'isSoundOn': false,
    };

    try {
      final res = await httpPost(
        '/api/v1/extinguishers',
        body,
        context: context,
        auth: true, // ★ 반드시 토큰 포함
      );

      Map<String, dynamic> data = {};
      try {
        data = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {}

      if (res.statusCode == 200 || res.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('소화기가 등록되었습니다.')),
        );
        Navigator.pop(context, true); // 목록에서 리프레시 트리거
      } else {
        if (!mounted) return;
        final msg =
            (data['error'] ?? data['detail'] ?? data['message'] ?? '알 수 없는 오류')
                .toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('등록 실패: $msg'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류 발생: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('소화기 등록'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '새로운 소화기 등록',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                '소화기 위치와 사용 가능 기간을 입력해 주세요.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),

              // 카드 영역
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _locationController,
                        decoration: const InputDecoration(
                          labelText: '소화기 위치',
                        ),
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: _pickDate,
                        child: AbsorbPointer(
                          child: TextField(
                            controller: _expireController,
                            decoration: const InputDecoration(
                              labelText: '사용 가능 기간 (YYYY-MM-DD)',
                              prefixIcon: Icon(Icons.calendar_today),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              SizedBox(
                height: 52,
                child: _saving
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _save,
                        child: const Text('소화기 등록'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ② 사용자 회원가입 화면 (로그인 화면에서 "회원가입" 눌렀을 때 이동) -----
class RegisterUserScreen extends StatefulWidget {
  const RegisterUserScreen({super.key});

  @override
  State<RegisterUserScreen> createState() => _RegisterUserScreenState();
}

class _RegisterUserScreenState extends State<RegisterUserScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _saving = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _registerUser() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('아이디와 비밀번호를 모두 입력해주세요.')),
      );
      return;
    }

    setState(() => _saving = true);

    final body = <String, dynamic>{
      'username': username,
      'password': password,
    };

    try {
      // 회원가입은 로그인과 마찬가지로 auth: false
      final res = await httpPost(
        '/api/v1/register',
        body,
        context: context,
        auth: false,
      );

      Map<String, dynamic> data = {};
      try {
        data = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {}

      if (res.statusCode == 200 || res.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('회원가입이 완료되었습니다. 로그인해주세요.')),
        );
        Navigator.pop(context); // 로그인 화면으로 돌아감
      } else {
        if (!mounted) return;
        final msg =
            (data['error'] ?? data['detail'] ?? data['message'] ?? '알 수 없는 오류')
                .toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('회원가입 실패: $msg')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류 발생: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('회원가입'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '새 계정 만들기',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '앱을 사용하기 위한 아이디와 비밀번호를 입력해주세요.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          labelText: '아이디',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        decoration: const InputDecoration(
                          labelText: '비밀번호',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        obscureText: true,
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 52,
                child: _saving
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _registerUser,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          '회원가입 완료',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
