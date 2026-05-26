import 'package:flutter/material.dart';

/// Circular capture button with white border and inner circle.
class CaptureButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const CaptureButton({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
          color: Colors.white.withOpacity(0.3),
        ),
        child: const Center(
          child: CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white,
          ),
        ),
      ),
    );
  }
}
