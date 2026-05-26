/// AR-style text chip showing expression guidance on the camera view.
///
/// Appears when a face is detected but expression could be improved.
/// Hidden when expression is ideal (bigSmile, laugh).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/providers.dart';
import '../../domain/services/expression_detector.dart';

class ExpressionGuideOverlay extends ConsumerWidget {
  const ExpressionGuideOverlay({super.key});

  IconData _icon(ExpressionType type) {
    switch (type) {
      case ExpressionType.neutral:
        return Icons.sentiment_neutral;
      case ExpressionType.slightSmile:
        return Icons.sentiment_satisfied;
      case ExpressionType.bigSmile:
      case ExpressionType.laugh:
        return Icons.sentiment_very_satisfied;
      case ExpressionType.winking:
        return Icons.face;
      case ExpressionType.eyesClosed:
        return Icons.remove_red_eye_outlined;
    }
  }

  Color _color(ExpressionType type) {
    switch (type) {
      case ExpressionType.neutral:
      case ExpressionType.eyesClosed:
        return Colors.amber;
      case ExpressionType.slightSmile:
        return Colors.lightGreenAccent;
      case ExpressionType.bigSmile:
      case ExpressionType.laugh:
        return Colors.greenAccent;
      case ExpressionType.winking:
        return Colors.cyanAccent;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expression = ref.watch(expressionResultProvider);

    if (expression == null) return const SizedBox.shrink();

    // Don't obstruct the view when expression is already great
    if (expression.guidance == null) return const SizedBox.shrink();

    return Positioned(
      top: MediaQuery.of(context).padding.top + 120,
      left: 0,
      right: 0,
      child: Center(
        child: AnimatedOpacity(
          opacity: expression.guidance != null ? 0.9 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.55),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _color(expression.expression).withOpacity(0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _icon(expression.expression),
                  size: 16,
                  color: _color(expression.expression),
                ),
                const SizedBox(width: 8),
                Text(
                  expression.guidance!,
                  style: TextStyle(
                    color: _color(expression.expression),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
