// C:\project\smart_extinguisher_app-main\lib\screens\login_screen.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:smart_extinguisher_app/screens/register_user_screen.dart';
import 'package:smart_extinguisher_app/utils/http_helper.dart';
import 'main_navigator.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String _email = '';
  String _password = '';
  bool _isLoading = false;
  bool _isPasswordObscured = true;

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  void _navigateToMainScreen() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const MainNavigator()),
    );
  }

  Future<void> _handleLogin() async {
    if (_email.isEmpty || _password.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('아이디와 비밀번호를 모두 입력해주세요.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final data = {
      'username': _email.trim().toLowerCase(),
      'password': _password.trim(),
    };

    try {
      // 로그인은 auth:false (토큰 없음)
      final response = await httpPost(
        '/api/v1/login',
        data,
        context: context,
        auth: false,
      );

      if (!mounted) return;

      Map<String, dynamic> responseBody = {};
      try {
        responseBody = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        // JSON 파싱 실패 시 빈 맵
      }

      // 서버는 { token: "..."} 형태로 응답한다고 가정
      final dynamic tokenField = responseBody['token'];
      final String? token = tokenField is String ? tokenField : null;

      if (response.statusCode == 200 && token != null && token.isNotEmpty) {
        // 로그인 성공
        await _saveToken(token);
        _navigateToMainScreen();
      } else {
        final String msg =
            (responseBody['detail'] ?? responseBody['error'] ?? '알 수 없는 오류')
                .toString();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('로그인 실패: $msg'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류 발생: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToRegister() {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        // 여기서 이제 실제로 존재하는 RegisterUserScreen 으로 이동
        builder: (context) => const RegisterUserScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: Image.asset(
                  'assets/images/fire_icon.png',
                  height: 100,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '로그인',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '소화기 관리를 위해 로그인해주세요.',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Column(
                    children: [
                      TextField(
                        decoration: const InputDecoration(
                          labelText: '이메일(아이디)',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        onChanged: (v) => _email = v,
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        decoration: InputDecoration(
                          labelText: '비밀번호',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordObscured
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: Colors.grey[600],
                            ),
                            onPressed: () => setState(
                              () => _isPasswordObscured = !_isPasswordObscured,
                            ),
                          ),
                        ),
                        obscureText: _isPasswordObscured,
                        onChanged: (v) => _password = v,
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _handleLogin,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52),
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        '로그인',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: _navigateToRegister,
                child: const Text('계정이 없으신가요? 회원가입'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
