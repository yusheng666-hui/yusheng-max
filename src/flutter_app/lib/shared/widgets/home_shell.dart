/// Home shell with bottom navigation bar.
///
/// Wraps CameraPage, PoseSquarePage, and ProfilePage in an IndexedStack
/// with a 3-tab BottomNavigationBar. Sets bottomNavInsetProvider so
/// CameraPage can adjust its bottom padding.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/camera/domain/providers.dart';
import '../../features/camera/presentation/camera_page.dart';
import '../../features/pose_square/presentation/pose_square_page.dart';
import '../../features/profile/presentation/profile_page.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _currentIndex = 0;

  static const _tabs = <_TabDef>[
    _TabDef(label: '拍摄', icon: Icons.camera_alt),
    _TabDef(label: '姿势广场', icon: Icons.auto_awesome),
    _TabDef(label: '我的', icon: Icons.person_outline),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(bottomNavInsetProvider.notifier).state = kBottomNavigationBarHeight;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          CameraPage(),
          PoseSquarePage(),
          ProfilePage(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        backgroundColor: const Color(0xFF0D0D0D),
        selectedItemColor: Colors.amber,
        unselectedItemColor: Colors.white38,
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        items: _tabs
            .map((t) => BottomNavigationBarItem(
                  icon: Icon(t.icon),
                  label: t.label,
                ))
            .toList(),
      ),
    );
  }
}

class _TabDef {
  final String label;
  final IconData icon;

  const _TabDef({required this.label, required this.icon});
}
