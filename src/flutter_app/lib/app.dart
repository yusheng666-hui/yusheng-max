import 'package:flutter/material.dart';
import 'features/camera/presentation/camera_page.dart';
import 'features/profile/presentation/profile_page.dart';

class PoseCraftApp extends StatelessWidget {
  const PoseCraftApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PoseCraft',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.black,
        brightness: Brightness.dark,
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const CameraPage(),
      routes: {
        '/profile': (_) => const ProfilePage(),
      },
    );
  }
}
