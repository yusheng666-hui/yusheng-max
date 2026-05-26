import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../camera/domain/providers.dart';
import '../../../camera/domain/services/pose_detector.dart';
import '../../../shared/models/recommendation.dart';

/// AR skeleton overlay rendered on top of the camera preview.
///
/// Draws the target pose skeleton (from recommendations) and the user's
/// detected skeleton (from MediaPipe) so the user can visually align.
/// Also shows a real-time alignment score ring.
class ArOverlay extends ConsumerWidget {
  const ArOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recommendations = ref.watch(currentRecommendationsProvider);
    final detectedPoses = ref.watch(detectedPosesProvider);
    final activeIndex = ref.watch(activeRecommendationIndexProvider);
    final alignment = ref.watch(alignmentResultProvider);

    final activeRec = recommendations?.recommendations.isNotEmpty == true &&
            activeIndex < recommendations!.recommendations.length
        ? recommendations.recommendations[activeIndex]
        : null;

    final size = MediaQuery.of(context).size;

    return Stack(
      children: [
        IgnorePointer(
          child: CustomPaint(
            painter: _SkeletonOverlayPainter(
              targetPose: activeRec,
              userPoses: detectedPoses,
            ),
            size: size,
          ),
        ),
        // Alignment score ring + correction hints
        if (alignment != null)
          Positioned(
            top: MediaQuery.of(context).padding.top + 70,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _AlignmentRing(alignment: alignment),
                if (alignment.hints.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _CorrectionHints(hints: alignment.hints),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// MediaPipe pose connections — which keypoint pairs form bones.
const _poseConnections = [
  [11, 12], [11, 23], [12, 24], [23, 24],
  [11, 13], [13, 15],
  [12, 14], [14, 16],
  [23, 25], [25, 27],
  [24, 26], [26, 28],
  [0, 1], [0, 4], [1, 2], [4, 5], [2, 3], [5, 6],
  [9, 10],
];

/// Per-person skeleton colors (up to 5 people).
const _userColors = [
  Colors.cyanAccent,
  Colors.magentaAccent,
  Colors.yellowAccent,
  Colors.orangeAccent,
  Colors.limeAccent,
];

class _SkeletonOverlayPainter extends CustomPainter {
  final PoseRecommendation? targetPose;
  final List<DetectedPose> userPoses;

  _SkeletonOverlayPainter({this.targetPose, this.userPoses = const []});

  @override
  void paint(Canvas canvas, Size size) {
    if (targetPose != null && targetPose!.skeleton.keypoints.isNotEmpty) {
      _drawSkeleton(
        canvas, size, targetPose!.skeleton.keypoints,
        Colors.white.withOpacity(0.8), Colors.white.withOpacity(0.2), 3.0,
      );
    }

    for (int i = 0; i < userPoses.length && i < _userColors.length; i++) {
      final keypoints = _extractUserKeypoints(userPoses[i], size);
      if (keypoints.isNotEmpty) {
        final color = _userColors[i];
        _drawSkeleton(
          canvas, size, keypoints,
          color.withOpacity(0.9), color.withOpacity(0.3), 2.5,
        );
      }
    }

    _drawCompositionGrid(canvas, size);
  }

  List<_PaintKeypoint> _extractUserKeypoints(DetectedPose pose, Size size) {
    return pose.keypoints.map((k) {
      return _PaintKeypoint(
        x: k.x * size.width,
        y: k.y * size.height,
        likelihood: k.likelihood,
      );
    }).toList();
  }

  void _drawSkeleton(Canvas canvas, Size size, List<dynamic> keypoints,
      Color lineColor, Color pointColor, double pointRadius) {
    final points = <_PaintKeypoint>[];
    for (final k in keypoints) {
      double? kx, ky, likelihood;
      if (k is Keypoint) {
        kx = k.x; ky = k.y; likelihood = k.visibility;
      } else {
        try {
          kx = (k.x as num).toDouble();
          ky = (k.y as num).toDouble();
          likelihood = k.likelihood is num ? (k.likelihood as num).toDouble() : 1.0;
        } catch (_) {
          continue;
        }
      }
      points.add(_PaintKeypoint(
        x: kx * size.width, y: ky * size.height, likelihood: likelihood,
      ));
    }

    if (points.length < 33) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    paint.color = lineColor;
    paint.strokeWidth = pointRadius * 0.8;

    for (final conn in _poseConnections) {
      final a = conn[0], b = conn[1];
      if (a >= points.length || b >= points.length) continue;
      if (points[a].likelihood < 0.3 || points[b].likelihood < 0.3) continue;
      canvas.drawLine(
        Offset(points[a].x, points[a].y),
        Offset(points[b].x, points[b].y),
        paint,
      );
    }

    paint.style = PaintingStyle.fill;
    for (int i = 0; i < points.length; i++) {
      if (points[i].likelihood < 0.3) continue;
      final radius = (i <= 10 || (i >= 15 && i <= 22)) ? pointRadius * 1.4 : pointRadius;
      paint.color = pointColor;
      canvas.drawCircle(Offset(points[i].x, points[i].y), radius + 2, paint);
      paint.color = lineColor;
      canvas.drawCircle(Offset(points[i].x, points[i].y), radius, paint);
    }

    if (targetPose != null) {
      final standX = (targetPose!.standingPosition[0].clamp(-1.0, 1.0) + 1) / 2 * size.width;
      final standY = size.height * 0.85;
      final indicatorPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withOpacity(0.5);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(standX, standY), width: size.width * 0.3, height: size.height * 0.08),
        indicatorPaint,
      );
      canvas.drawCircle(Offset(standX, standY - size.height * 0.02), 6,
        Paint()..style = PaintingStyle.fill..color = Colors.white.withOpacity(0.6));
    }
  }

  void _drawCompositionGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = Colors.white.withOpacity(0.15);
    final thirdW = size.width / 3;
    final thirdH = size.height / 3;
    canvas.drawLine(Offset(thirdW, 0), Offset(thirdW, size.height), paint);
    canvas.drawLine(Offset(thirdW * 2, 0), Offset(thirdW * 2, size.height), paint);
    canvas.drawLine(Offset(0, thirdH), Offset(size.width, thirdH), paint);
    canvas.drawLine(Offset(0, thirdH * 2), Offset(size.width, thirdH * 2), paint);
  }

  @override
  bool shouldRepaint(covariant _SkeletonOverlayPainter oldDelegate) => true;
}

/// Alignment score ring gauge displayed over the AR view.
class _AlignmentRing extends StatelessWidget {
  final AlignmentResult alignment;

  const _AlignmentRing({required this.alignment});

  Color get _color {
    if (alignment.overallScore >= 0.8) return Colors.greenAccent;
    if (alignment.overallScore >= 0.65) return Colors.amber;
    if (alignment.overallScore >= 0.5) return Colors.orange;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black54,
          border: Border.all(color: Colors.white12),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: CircularProgressIndicator(
                value: alignment.overallScore,
                strokeWidth: 4,
                backgroundColor: Colors.white.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(_color),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${alignment.percentage}',
                  style: TextStyle(
                    color: _color,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  alignment.grade,
                  style: TextStyle(
                    color: _color.withOpacity(0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PaintKeypoint {
  final double x;
  final double y;
  final double likelihood;

  const _PaintKeypoint({required this.x, required this.y, this.likelihood = 1.0});
}

/// Correction hint chips displayed below the alignment score ring.
class _CorrectionHints extends StatelessWidget {
  final List<String> hints;

  const _CorrectionHints({required this.hints});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 6,
        runSpacing: 4,
        children: hints.map((hint) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.adjust, size: 10, color: Colors.cyanAccent.withOpacity(0.6)),
                const SizedBox(width: 4),
                Text(
                  hint,
                  style: TextStyle(
                    color: Colors.cyanAccent.withOpacity(0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
