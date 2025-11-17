// C:\project\smart_extinguisher_app-main\lib\screens\register.dart
// lib/screens/register.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:smart_extinguisher_app/screens/login_screen.dart';
import 'package:smart_extinguisher_app/utils/http_helper.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _expireDateController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _locationController.dispose();
    _expireDateController.dispose();
    super.dispose();
  }

  // 로그아웃
  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  // 소화기 등록
  Future<void> _registerExtinguisher() async {
    final location = _locationController.text.trim();
    final expireDate = _expireDateController.text.trim(); // YYYY-MM-DD

    if (location.isEmpty || expireDate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모든 항목을 입력해주세요.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final body = {
        'location': location,
        'expireDate': expireDate,
        // 초기 상태는 항상 꺼짐으로 등록
        'isLightOn': false,
        'isSoundOn': false,
      };

      final res = await httpPost(
        '/api/v1/extinguishers',
        body,
        context: context,
        auth: true,
      );

      Map<String, dynamic> data = {};
      try {
        data = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {
        // 응답이 비어 있거나 JSON 이 아닐 수도 있음
      }

      // 200 또는 201 이면 성공으로 간주 (서버가 ok 플래그를 안줘도 되도록)
      if (res.statusCode == 200 || res.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('소화기가 등록되었습니다.')),
        );

        _locationController.clear();
        _expireDateController.clear();
      } else {
        final msg =
            (data['error'] ?? data['detail'] ?? data['message'] ?? '알 수 없는 오류')
                .toString();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '등록 실패: $msg',
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류 발생: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('소화기 등록'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: '로그아웃',
            onPressed: _logout,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '새로운 소화기 등록',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '소화기 위치와 사용 가능 기간을 입력해 주세요.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),

              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _locationController,
                        decoration: const InputDecoration(
                          labelText: '소화기 위치',
                          hintText: '예: 1층 로비, 2층 계단 앞',
                          prefixIcon: Icon(Icons.place_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _expireDateController,
                        decoration: const InputDecoration(
                          labelText: '사용 가능 기간 (YYYY-MM-DD)',
                          hintText: '예: 2026-12-31',
                          prefixIcon: Icon(Icons.calendar_month_outlined),
                        ),
                        keyboardType: TextInputType.datetime,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : ElevatedButton.icon(
                                onPressed: _registerExtinguisher,
                                icon: const Icon(Icons.add),
                                label: const Text(
                                  '소화기 등록',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 48),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),
              Text(
                '※ 등록된 소화기는 "소화기 목록" 탭에서 확인할 수 있습니다.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
