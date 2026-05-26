import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/providers.dart';

/// Camera mode toggle: selfie (front) vs photographer (rear).
class ModeSwitcher extends ConsumerWidget {
  final VoidCallback? onSwitch;

  const ModeSwitcher({super.key, this.onSwitch});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSelfie = ref.watch(isSelfieModeProvider);

    return GestureDetector(
      onTap: onSwitch,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelfie ? Icons.camera_front : Icons.camera_rear,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 4),
            Text(
              isSelfie ? '自拍' : '摄影',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
