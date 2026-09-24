import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/game_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  runApp(const DoodleJumpApp());
}

class DoodleJumpApp extends StatelessWidget {
  const DoodleJumpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Doodle Jump',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF43A047)),
        useMaterial3: true,
      ),
      home: const GameScreen(),
    );
  }
}