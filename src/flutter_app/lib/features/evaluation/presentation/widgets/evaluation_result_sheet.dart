/// Bottom sheet overlay showing photo evaluation results after capture.
///
/// Displays overall score with grade, per-dimension breakdown,
/// improvement tips, preset color grading suggestions, and action buttons.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/evaluation.dart';
import '../../domain/providers.dart';
import '../../domain/services/preset_recommendation_service.dart';

class EvaluationResultSheet extends ConsumerWidget {
  final EvaluationResult result;
  final VoidCallback? onRetake;
  final void Function(String presetId)? onApplyPreset;

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
    void Function(String presetId)? onApplyPreset,
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
  Widget build(BuildContext context, WidgetRef ref) {
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

            // ── Preset color grading recommendation card ─────────
            _PresetRecommendationCard(onApplyPreset: onApplyPreset),
            if (onApplyPreset != null) const SizedBox(height: 16),

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
                      onPressed: () {
                        final pid = ref
                            .read(currentPresetRecommendationsProvider)
                            .firstOrNull
                            ?.preset.presetId;
                        if (pid != null) {
                          onApplyPreset!(pid);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        '应用预设: ${ref.watch(currentPresetRecommendationsProvider).firstOrNull?.preset.name.zh ?? "自动"}',
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

/// Shows recommended presets with reasoning text.
class _PresetRecommendationCard extends ConsumerStatefulWidget {
  final void Function(String presetId)? onApplyPreset;

  const _PresetRecommendationCard({this.onApplyPreset});

  @override
  ConsumerState<_PresetRecommendationCard> createState() =>
      _PresetRecommendationCardState();
}

class _PresetRecommendationCardState
    extends ConsumerState<_PresetRecommendationCard> {
  int _selectedIdx = 0;

  @override
  Widget build(BuildContext context) {
    final recs = ref.watch(currentPresetRecommendationsProvider);
    if (recs.isEmpty) return const SizedBox.shrink();

    if (_selectedIdx >= recs.length) _selectedIdx = 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.color_lens, size: 14, color: Colors.amber),
            const SizedBox(width: 6),
            const Text(
              '推荐调色预设',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...List.generate(recs.length, (i) {
          final rec = recs[i];
          final isActive = i == _selectedIdx;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _RecommendationRow(
              rec: rec,
              isActive: isActive,
              onTap: () => setState(() => _selectedIdx = i),
              onApply: widget.onApplyPreset != null
                  ? () => widget.onApplyPreset!(rec.preset.presetId)
                  : null,
            ),
          );
        }),
      ],
    );
  }
}

class _RecommendationRow extends StatelessWidget {
  final PresetRecommendation rec;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback? onApply;

  const _RecommendationRow({
    required this.rec,
    required this.isActive,
    required this.onTap,
    this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.amber.withOpacity(0.08)
              : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? Colors.amber.withOpacity(0.4) : Colors.white10,
          ),
        ),
        child: Row(
          children: [
            // Color indicator / icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: _buildRecGradient(rec.preset.styleTags),
              ),
              child: Center(
                child: Text(
                  '${(rec.score / 100 * 10).toStringAsFixed(1)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        rec.preset.name.zh,
                        style: TextStyle(
                          color: isActive ? Colors.amber : Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      ...rec.preset.styleTags.take(2).map(
                            (t) => Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Text(
                                '#$t',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.3),
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    rec.reasonZh,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (onApply != null && isActive)
              GestureDetector(
                onTap: onApply,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    '应用',
                    style: TextStyle(color: Colors.amber, fontSize: 11),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  LinearGradient _buildRecGradient(List<String> tags) {
    final colors = <Color>[];
    for (final tag in tags) {
      switch (tag) {
        case 'warm':
          colors.add(Colors.orange);
          break;
        case 'cool':
          colors.add(Colors.blue);
          break;
        case 'vintage':
        case 'retro':
          colors.add(Colors.brown);
          break;
        case 'bright':
        case 'vivid':
          colors.add(Colors.amber);
          break;
        case 'moody':
        case 'dark':
          colors.add(Colors.blueGrey);
          break;
        case 'black-and-white':
          colors.add(Colors.grey);
          colors.add(Colors.black);
          break;
        case 'fresh':
        case 'clean':
        case 'airy':
          colors.add(Colors.cyan.shade100);
          break;
        case 'film':
          colors.add(Colors.deepOrange.shade100);
          break;
        default:
          break;
      }
    }
    if (colors.isEmpty) {
      colors.addAll([Colors.white24, Colors.white54]);
    }
    if (colors.length == 1) {
      colors.add(colors.first.withOpacity(0.5));
    }
    return LinearGradient(colors: colors);
  }
}
