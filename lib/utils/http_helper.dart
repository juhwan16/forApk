import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// -------------------- 서버 주소 --------------------
const String baseUrl =
    "https://fxrw4kkpbgieegs6kcnhwme6je0evxay.lambda-url.ap-northeast-2.on.aws";

// -------------------- 이미지 경로 기본 URL --------------------
const String imageRootUrl = baseUrl;

// -------------------- 공통 헤더 --------------------
Future<Map<String, String>> _headers({bool auth = false}) async {
  final headers = <String, String>{
    'Content-Type': 'application/json',
  };

  if (auth) {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
  }

  return headers;
}

void _showTokenExpired(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text("로그인 세션이 만료되었습니다. 다시 로그인해주세요.")),
  );
}

// -------------------- GET --------------------
Future<http.Response> httpGet(
  String path, {
  BuildContext? context,
  bool auth = false,
}) async {
  final url = Uri.parse("$baseUrl$path");
  final res = await http.get(url, headers: await _headers(auth: auth));

  if (res.statusCode == 401 && context != null) {
    _showTokenExpired(context);
  }

  return res;
}

// -------------------- POST --------------------
Future<http.Response> httpPost(
  String path,
  Map<String, dynamic> body, {
  BuildContext? context,
  bool auth = false,
}) async {
  final url = Uri.parse("$baseUrl$path");
  final res = await http.post(
    url,
    headers: await _headers(auth: auth),
    body: jsonEncode(body),
  );

  if (res.statusCode == 401 && context != null) {
    _showTokenExpired(context);
  }

  return res;
}

// -------------------- PUT --------------------
Future<http.Response> httpPut(
  String path,
  Map<String, dynamic> body, {
  BuildContext? context,
  bool auth = false,
}) async {
  final url = Uri.parse("$baseUrl$path");
  final res = await http.put(
    url,
    headers: await _headers(auth: auth),
    body: jsonEncode(body),
  );

  if (res.statusCode == 401 && context != null) {
    _showTokenExpired(context);
  }

  return res;
}

// -------------------- DELETE --------------------
Future<http.Response> httpDelete(
  String path, {
  BuildContext? context,
  bool auth = false,
}) async {
  final url = Uri.parse("$baseUrl$path");
  final res = await http.delete(
    url,
    headers: await _headers(auth: auth),
  );

  if (res.statusCode == 401 && context != null) {
    _showTokenExpired(context);
  }

  return res;
}
