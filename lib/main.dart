import 'package:flutter/material.dart';
import 'core/constants/app_colors.dart';
import 'features/auth/screens/auth_gate.dart';

void main() {
  runApp(const MetanoiaApp());
}

class MetanoiaApp extends StatelessWidget {
  const MetanoiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Metanoia',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        fontFamily: 'Roboto',
      ),
      home: const AuthGate(),
    );
  }
}