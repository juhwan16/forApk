import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ExtinguisherService {
  // 소화기 목록 가져오기
  Future<List<dynamic>> getExtinguishers() async {
    String? token = await _getAuthToken();  // 토큰 가져오기

    if (token == null) {
      print('User is not logged in');
      return [];
    }

    final response = await http.get(
      Uri.parse('https://fxrw4kkpbgieegs6kcnhwme6je0evxay.lambda-url.ap-northeast-2.on.aws/api/v1/extinguishers'),
      headers: {
        'Authorization': 'Bearer $token',  // JWT 토큰을 Authorization 헤더에 추가
      },
    );

    final responseBody = json.decode(response.body);

    if (response.statusCode == 200) {
      return responseBody['items'] ?? [];
    } else {
      print('Failed to fetch extinguishers: ${responseBody['error']}');
      return [];
    }
  }

  // 소화기 등록
  Future<void> createExtinguisher(String name, String? imagePath, bool isSoundOn, bool isLightOn) async {
    String? token = await _getAuthToken();  // 토큰 가져오기

    if (token == null) {
      print('User is not logged in');
      return;
    }

    final response = await http.post(
      Uri.parse('https://fxrw4kkpbgieegs6kcnhwme6je0evxay.lambda-url.ap-northeast-2.on.aws/api/v1/extinguishers'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',  // JWT 토큰을 Authorization 헤더에 추가
      },
      body: json.encode({
        'name': name,
        'imagePath': imagePath,
        'isSoundOn': isSoundOn,
        'isLightOn': isLightOn,
      }),
    );

    final responseBody = json.decode(response.body);

    if (response.statusCode == 201) {
      print('Extinguisher created successfully');
    } else {
      print('Failed to create extinguisher: ${responseBody['error']}');
    }
  }

  // JWT 토큰 가져오기
  Future<String?> _getAuthToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }
}
