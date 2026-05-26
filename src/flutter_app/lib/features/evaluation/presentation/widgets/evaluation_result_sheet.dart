/// Bottom sheet overlay showing photo evaluation results after capture.
///
/// Displays overall score with grade, per-dimension breakdown,
/// improvement tips, and a recommended preset for post-processing.

import 'package:flutter/material.dart';
import '../../../shared/models/evaluation.dart';

class EvaluationResultSheet extends StatelessWidget {
  final EvaluationResult result;
  final VoidCallback? onRetake;
  final VoidCallback? onApplyPreset;

  const EvaluationResultSheet({
    super.key,
    required this.result,
    this.onRetake,
    this.onApplyPreset,
  });

  /// Show this sheet as a modal bottom sheet.
  static Future<void> show(
    BuildContext context,
    EvaluationResult result, {
    VoidCallback? onRetake,
    VoidCallback? onApplyPreset,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EvaluationResultSheet(
        result: result,
        onRetake: onRetake,
        onApplyPreset: onApplyPreset,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomPadding),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Grade + score header
            _GradeHeader(grade: result.grade, score: result.overallScore),
            const SizedBox(height: 4),
            Text(
              result.encouragement,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
            ),
            const SizedBox(height: 20),

            // Dimension breakdown
            ...result.dimensions.map((d) => _DimensionRow(score: d)),
            const SizedBox(height: 20),

            // Improvement tips
            if (result.improvementTips.isNotEmpty) ...[
              Text(
                '改进建议',
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              ...result.improvementTips.map((tip) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.tips_and_updates, size: 14, color: Colors.amber),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(tip, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                        ),
                      ],
                    ),
                  )),
            ],
            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onRetake ?? () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('重拍'),
                  ),
                ),
                if (onApplyPreset != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onApplyPreset,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        '应用预设: ${result.presetRecommendation ?? "自动"}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GradeHeader extends StatelessWidget {
  final String grade;
  final double score;

  const _GradeHeader({required this.grade, required this.score});

  Color get _gradeColor {
    switch (grade) {
      case 'A+':
      case 'A':
        return Colors.greenAccent;
      case 'B':
        return Colors.amber;
      case 'C':
        return Colors.orange;
      default:
        return Colors.redAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _gradeColor, width: 3),
            color: _gradeColor.withOpacity(0.1),
          ),
          child: Center(
            child: Text(
              grade,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: _gradeColor,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${score.toStringAsFixed(1)} / 10',
          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _DimensionRow extends StatelessWidget {
  final DimensionScore score;

  const _DimensionRow({required this.score});

  Color get _barColor {
    if (score.score >= 8) return Colors.greenAccent;
    if (score.score >= 6) return Colors.amber;
    if (score.score >= 4) return Colors.orange;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(score.labelZh, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              Text(
                score.score.toStringAsFixed(1),
                style: TextStyle(color: _barColor, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: score.score / 10.0,
              minHeight: 5,
              backgroundColor: Colors.white.withOpacity(0.08),
              valueColor: AlwaysStoppedAnimation<Color>(_barColor),
            ),
          ),
          if (score.feedbackZh.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(score.feedbackZh,
                style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 11)),
          ],
        ],
      ),
    );
  }
}
