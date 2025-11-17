import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// -------------------- 서버 주소 --------------------
const String baseUrl =
    "https://fxrw4kkpbgieegs6kcnhwme6je0evxay.lambda-url.ap-northeast-2.on.aws";

// -------------------- 이미지 주소 --------------------
const String imageRootUrl = baseUrl; // Lambda는 같은 URL 사용

// -------------------- 공통 헤더 생성 --------------------
Future<Map<String, String>> _headers({bool auth = false}) async {
  final headers = {
    "Content-Type": "application/json",
  };

  if (auth) {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("auth_token");

    if (token != null && token.isNotEmpty) {
      headers["Authorization"] = "Bearer $token";
    }
  }

  return headers;
}

// -------------------- 세션 만료 안내 --------------------
void _showTokenExpired(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text("로그인 세션이 만료되었습니다. 다시 로그인해주세요.")),
  );
}

// -------------------- GET --------------------
Future<http.Response> httpGet(
  String path, {
  bool auth = false,
  BuildContext? context,
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
  bool auth = false,
  BuildContext? context,
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
  bool auth = false,
  BuildContext? context,
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

// -------------------- 이미지 업로드 (Multipart) --------------------
Future<http.StreamedResponse> httpUploadImage(
  String path,
  String filePath, {
  required String extinguisherId,
  bool auth = true,
}) async {
  final url = Uri.parse("$baseUrl$path");

  final req = http.MultipartRequest("POST", url);

  if (auth) {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("auth_token");

    if (token != null && token.isNotEmpty) {
      req.headers["Authorization"] = "Bearer $token";
    }
  }

  req.fields["id"] = extinguisherId;
  req.files.add(await http.MultipartFile.fromPath("image", filePath));

  return req.send();
}
