import 'package:flutter/material.dart';

import 'pages/login_page.dart';
import 'pages/login_success_page.dart';
import 'pages/main_page.dart';
import 'pages/register_page.dart';
import 'pages/splash_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Attendance App',
      theme: ThemeData(
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.grey[100],
          foregroundColor: const Color.fromRGBO(0, 0, 0, 0.867),
          elevation: 0,
          centerTitle: true,
        ),
        cardColor: Colors.white,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.grey[100],
      ),
      debugShowCheckedModeBanner: false,
      initialRoute: "/",
      routes: {
        "/": (_) => const SplashPage(),
        "/login": (_) => const LoginPage(),
        "/register": (_) => const RegisterPage(),
        "/main": (_) => const MainPage(),
        "/login-success": (_) => const LoginSuccessPage(), // Route baru
      },
    );
  }
}
