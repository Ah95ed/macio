import 'package:flutter/material.dart';
import 'package:point_of_sell/login.dart';

void main() {
  runApp(MacioApp());
}

class MacioApp extends StatelessWidget {
  const MacioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Macio',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
    
      theme: ThemeData.dark().copyWith(
        primaryColor: Color(0xFF1F1F1F),
        scaffoldBackgroundColor: Color(0xFF1F1F1F),
        hintColor: Color(0xFFBB86FC),
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white),
        ),
      ),
      home: LoginPage(),
    );
  }
}
