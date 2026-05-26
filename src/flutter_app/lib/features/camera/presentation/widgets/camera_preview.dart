import 'package:flutter/material.dart';
import 'package:camera/camera.dart' as cam;

/// Displays the live camera preview filling the screen.
///
/// Uses the camera package's built-in preview widget with proper
/// aspect ratio handling to fill the full screen.
class CameraPreview extends StatelessWidget {
  final cam.CameraController controller;

  const CameraPreview({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return const SizedBox.shrink();
    }

    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: controller.value.previewSize!.height,
            height: controller.value.previewSize!.width,
            child: cam.CameraPreview(controller),
          ),
        ),
      ),
    );
  }
}
