import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'camera_screen.dart';
import 'history_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ISLApp());
}

class ISLApp extends StatelessWidget {
  const ISLApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ISL Bridge',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF1D9E75),
          secondary: Color(0xFF4ade80),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: IndexedStack(
        index: _index,
        children: [
          CameraScreen(onGoToHistory: () => setState(() => _index = 1)),
          HistoryScreen(onGoToTranslate: () => setState(() => _index = 0)),
        ],
      ),
    );
  }
}