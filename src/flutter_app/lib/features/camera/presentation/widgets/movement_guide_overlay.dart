/// Overlay showing the active camera movement guidance tip during shooting.
///
/// Positioned above the PhotographerGuideBar in the camera stack.
/// Only visible in photographer mode when a movement is active.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/providers.dart';
import '../../../video_guide/domain/camera_movements.dart';

class MovementGuideOverlay extends ConsumerWidget {
  const MovementGuideOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSelfie = ref.watch(isSelfieModeProvider);
    final showOverlay = ref.watch(showMovementOverlayProvider);
    final movement = ref.watch(activeMovementProvider);

    if (isSelfie || !showOverlay || movement == null) {
      return const SizedBox.shrink();
    }

    return Positioned(
      bottom: 260,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.75),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Text(
                movement.iconSymbol,
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      movement.nameZh,
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      movement.tipText,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => ref
                    .read(showMovementOverlayProvider.notifier)
                    .state = false,
                child: Icon(Icons.close, color: Colors.white38, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
