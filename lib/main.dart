import 'package:flutter/material.dart';
import 'camera_screen.dart';

void main() {
  runApp(const ISLApp());
}

class ISLApp extends StatelessWidget {
  const ISLApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ISL Translator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const CameraScreen(),
    );
  }
}