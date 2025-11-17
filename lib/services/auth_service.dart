// lib/services/auth_service.dart
import 'package:http/http.dart' as http;
import 'dart:convert';

class AuthService {
  // 로그인 메소드 수정: inviteCode 매개변수 추가
  Future<bool> login(String username, String password, String inviteCode) async {
    final url = Uri.parse('https://your-api-url/api/v1/login');  // 로그인 API URL
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'username': username,
        'password': password,
        'inviteCode': inviteCode, // 초대코드 추가
      }),
    );

    if (response.statusCode == 200) {
      // 서버에서 JWT 토큰을 받아서 저장
      final data = json.decode(response.body);
      String token = data['token'];  // JWT 토큰 받아오기
      // 토큰을 SharedPreferences 등에 저장하고, 로그인 상태를 유지
      return true;
    } else {
      // 로그인 실패
      return false;
    }
  }
}
