import 'package:flutter/material.dart';
import 'package:smart_extinguisher_app/screens/login_screen.dart';
import 'package:smart_extinguisher_app/screens/main_navigator.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 로그인 토큰 유지 여부 확인
  final prefs = await SharedPreferences.getInstance();
  final savedToken = prefs.getString('auth_token');

  runApp(MyApp(
    isLoggedIn: savedToken != null && savedToken.isNotEmpty,
  ));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Smart Extinguisher App",
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.red,
      ),
      home: isLoggedIn ? const MainNavigator() : const LoginScreen(),
    );
  }
}
