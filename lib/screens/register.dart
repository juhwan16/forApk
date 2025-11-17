import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
  final ImagePicker _picker = ImagePicker();

  File? _selectedImage;
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

  // 이미지 선택
  Future<void> _pickImage() async {
    final XFile? xfile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 85,
    );

    if (xfile == null) return;

    setState(() {
      _selectedImage = File(xfile.path);
    });
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
      // 서버로 전송할 body
      final body = {
        'location': location,
        'expireDate': expireDate,
      };

      final res = await httpPost(
        '/api/v1/extinguishers',
        body,
        context: context,
        auth: true, // ★★★ 여기 핵심: 토큰 붙여서 호출 ★★★
      );

      final data = jsonDecode(res.body);

      if (res.statusCode == 201 && data['ok'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('소화기가 등록되었습니다.')),
        );

        _locationController.clear();
        _expireDateController.clear();

        setState(() => _selectedImage = null);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '등록 실패: ${data['error'] ?? data['detail'] ?? '알 수 없는 오류'}',
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
                    children: [
                      // 위치 입력
                      TextField(
                        controller: _locationController,
                        decoration: const InputDecoration(
                          labelText: '소화기 위치',
                          hintText: '예: 1층 로비, 2층 계단 앞',
                          prefixIcon: Icon(Icons.place_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 사용 가능 기간
                      TextField(
                        controller: _expireDateController,
                        decoration: const InputDecoration(
                          labelText: '사용 가능 기간 (YYYY-MM-DD)',
                          hintText: '예: 2026-12-31',
                          prefixIcon: Icon(Icons.calendar_month_outlined),
                        ),
                        keyboardType: TextInputType.datetime,
                      ),
                      const SizedBox(height: 16),

                      // 이미지 선택 박스 (현재는 UI만, 업로드는 다음 단계)
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          width: double.infinity,
                          height: 160,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.grey.shade400,
                            ),
                            color: Colors.grey.shade100,
                          ),
                          child: _selectedImage == null
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.image_outlined,
                                      size: 40,
                                      color: Colors.grey.shade600,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '이미지 선택 (선택 사항)',
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                )
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Image.file(
                                    _selectedImage!,
                                    width: double.infinity,
                                    height: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('이미지 다시 선택'),
                        ),
                      ),

                      const SizedBox(height: 16),

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
                '※ 등록된 소화기는 "소화기 목록" 탭에서 확인할 수 있습니다.\n'
                '※ 이미지는 현재 기기에서만 표시되며, 서버 저장 기능은 다음 단계에서 추가됩니다.',
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
