import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../camera/domain/providers.dart';
import '../../../recommendation/domain/services/photographer_guidance_service.dart';

/// Horizontal guidance bar showing photographer angle and composition advice.
///
/// Sits above the recommendation panel, giving real-time framing and
/// camera position feedback to the photographer.
class PhotographerGuideBar extends ConsumerWidget {
  const PhotographerGuideBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guidance = ref.watch(photographerGuidanceProvider);
    if (guidance == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          // Angle guidance
          _AngleIndicator(guidance: guidance.angle),
          const SizedBox(width: 8),
          // Divider
          Container(
            width: 1,
            height: 28,
            color: Colors.white.withOpacity(0.12),
          ),
          const SizedBox(width: 8),
          // Composition guidance
          _CompositionIndicator(guidance: guidance.composition),
        ],
      ),
    );
  }
}

/// Camera angle icon + text.
class _AngleIndicator extends StatelessWidget {
  final AngleGuidance guidance;

  const _AngleIndicator({required this.guidance});

  IconData get _icon {
    switch (guidance.height) {
      case 'low':
        return Icons.arrow_downward;
      case 'high':
        return Icons.arrow_upward;
      default:
        return Icons.remove_red_eye;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: Colors.cyanAccent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(_icon, size: 16, color: Colors.cyanAccent.withOpacity(0.9)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '机位',
                  style: TextStyle(
                    color: Colors.cyanAccent.withOpacity(0.7),
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  guidance.instruction,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Composition icon + text + mini grid preview.
class _CompositionIndicator extends StatelessWidget {
  final CompositionGuidance guidance;

  const _CompositionIndicator({required this.guidance});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mini composition preview
          _CompositionPreview(
            technique: guidance.technique,
            placement: guidance.subjectPlacement,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '构图',
                  style: TextStyle(
                    color: Colors.amber.withOpacity(0.7),
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  guidance.instruction,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Mini 26x26 preview of the composition grid.
class _CompositionPreview extends StatelessWidget {
  final String technique;
  final String placement;

  const _CompositionPreview({
    required this.technique,
    required this.placement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: CustomPaint(
        painter: _GridPainter(technique: technique, placement: placement),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  final String technique;
  final String placement;

  _GridPainter({required this.technique, required this.placement});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.3
      ..color = Colors.white.withOpacity(0.3);

    // Rule of thirds grid
    if (technique == 'rule-of-thirds') {
      final thirdW = size.width / 3;
      final thirdH = size.height / 3;
      canvas.drawLine(Offset(thirdW, 0), Offset(thirdW, size.height), gridPaint);
      canvas.drawLine(Offset(thirdW * 2, 0), Offset(thirdW * 2, size.height), gridPaint);
      canvas.drawLine(Offset(0, thirdH), Offset(size.width, thirdH), gridPaint);
      canvas.drawLine(Offset(0, thirdH * 2), Offset(size.width, thirdH * 2), gridPaint);
    } else {
      // Centered: draw subtle crosshair
      canvas.drawLine(Offset(size.width * 0.5, 0), Offset(size.width * 0.5, size.height), gridPaint);
      canvas.drawLine(Offset(0, size.height * 0.5), Offset(size.width, size.height * 0.5), gridPaint);
    }

    // Subject position dot
    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.amber.withOpacity(0.9);

    double cx, cy;
    switch (placement) {
      case 'left-third':
        cx = size.width * 0.33;
        cy = size.height * 0.5;
      case 'right-third':
        cx = size.width * 0.66;
        cy = size.height * 0.5;
      default: // center
        cx = size.width * 0.5;
        cy = size.height * 0.5;
    }

    // Glow
    canvas.drawCircle(Offset(cx, cy), 3, Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.amber.withOpacity(0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));

    canvas.drawCircle(Offset(cx, cy), 1.8, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) => false;
}
