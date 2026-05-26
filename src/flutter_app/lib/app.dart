import 'package:flutter/material.dart';
import 'shared/widgets/home_shell.dart';

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
      home: const HomeShell(),
    );
  }
}
