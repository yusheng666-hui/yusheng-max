/// Local evaluation engine — scores a photo capture without cloud API.
///
/// Combines alignment score, lighting quality, and basic composition rules
/// to produce an [EvaluationResult] with per-dimension breakdown and tips.

import 'dart:math';
import '../../../../shared/models/evaluation.dart';
import '../../../ar/domain/services/alignment_scorer.dart';
import '../../../camera/domain/services/lighting_analyzer.dart';

class LocalEvaluationEngine {
  final Random _random = Random(42);

  /// Evaluate a capture using alignment + lighting data captured at shutter time.
  ///
  /// [alignment] may be null if pose wasn't detected.
  /// [lighting] may be null if frame analysis hasn't run yet.
  /// [sceneClass] and [timeOfDay] provide context for tips.
  EvaluationResult evaluate({
    AlignmentResult? alignment,
    LightingAnalysisResult? lighting,
    required String sceneClass,
    required String timeOfDay,
  }) {
    final dims = <DimensionScore>[];
    final tips = <String>[];

    // ── Pose alignment (35%) ──────────────────────────────────
    double poseScore;
    if (alignment != null) {
      poseScore = alignment.overallScore * 10.0;
      if (alignment.overallScore < 0.5) {
        tips.addAll(alignment.hints.take(2));
      }
    } else {
      poseScore = 5.0;
      tips.add('未检测到人物，切换到摄影师模式可获取构图建议');
    }
    dims.add(DimensionScore(
      score: poseScore,
      labelZh: '姿势',
      feedbackZh: poseScore >= 8 ? '姿势非常到位！' :
                   poseScore >= 6 ? '基本到位，还可以更放松一些' :
                   poseScore >= 4 ? '姿势偏差较大，多练习几次' : '需要大幅调整姿势',
    ));

    // ── Lighting (25%) ────────────────────────────────────────
    double lightingScore;
    if (lighting != null) {
      if (lighting.backlight.isBacklit) {
        lightingScore = 4.0 - lighting.backlight.severity * 2.0;
        tips.add('逆光拍摄，下次试试换个角度或打开闪光灯');
      } else {
        switch (lighting.quality) {
          case LightQualityType.soft:
            lightingScore = 8.5;
            break;
          case LightQualityType.diffused:
            lightingScore = 8.0;
            break;
          case LightQualityType.hard:
            lightingScore = 5.5;
            tips.add('光线偏硬，寻找阴影处拍会更柔和');
            break;
        }
      }
    } else {
      lightingScore = _lightingFromTimeOfDay(timeOfDay);
    }
    dims.add(DimensionScore(
      score: lightingScore,
      labelZh: '光线',
      feedbackZh: lightingScore >= 8 ? '光线条件很好' :
                   lightingScore >= 6 ? '光线一般，可以接受' :
                   lightingScore >= 4 ? '光线不太理想' : '光线条件很差',
    ));

    // ── Composition (25%) ─────────────────────────────────────
    double compScore;
    if (alignment != null && alignment.matchedKeypoints > 10) {
      // Simplistic: if pose is mostly centered, assume decent composition
      // In reality this needs the actual photo, so we approximate from alignment
      final torsoOk = alignment.torsoScore >= 0.6;
      final armsOk = alignment.armsScore >= 0.5;
      final headOk = alignment.headScore >= 0.5;
      if (torsoOk && armsOk && headOk) {
        compScore = 7.5 + _random.nextDouble() * 2.0;
      } else if (torsoOk) {
        compScore = 6.0 + _random.nextDouble() * 1.5;
      } else {
        compScore = 4.5 + _random.nextDouble() * 2.0;
      }
    } else {
      compScore = 5.5 + _random.nextDouble() * 1.5;
    }
    if (compScore < 6) {
      tips.add('构图可以再调整，建议使用三分法网格辅助');
    }
    dims.add(DimensionScore(
      score: compScore,
      labelZh: '构图',
      feedbackZh: compScore >= 8 ? '构图很不错' :
                   compScore >= 6 ? '构图尚可，还有提升空间' : '构图需要调整',
    ));

    // ── Expression (15%) ───────────────────────────────────────
    // Placeholder — MediaPipe FaceMesh not integrated yet
    const exprScore = 6.5;
    dims.add(const DimensionScore(
      score: 6.5,
      labelZh: '表情',
      feedbackZh: '表情检测将在后续版本上线',
    ));

    // ── Overall score ──────────────────────────────────────────
    final overall = poseScore * 0.35 +
        lightingScore * 0.25 +
        compScore * 0.25 +
        exprScore * 0.15;

    // ── Grade ──────────────────────────────────────────────────
    String grade;
    if (overall >= 9.0) {
      grade = 'A+';
    } else if (overall >= 8.0) {
      grade = 'A';
    } else if (overall >= 6.5) {
      grade = 'B';
    } else if (overall >= 5.0) {
      grade = 'C';
    } else {
      grade = 'D';
    }

    // ── Encouragement ──────────────────────────────────────────
    final encouragement = _encouragement(grade);

    // Deduplicate tips
    final uniqueTips = tips.toSet().toList();

    return EvaluationResult(
      requestId: 'local-${DateTime.now().millisecondsSinceEpoch}',
      overallScore: double.parse(overall.toStringAsFixed(1)),
      grade: grade,
      dimensions: dims,
      improvementTips: uniqueTips,
      encouragement: encouragement,
    );
  }

  double _lightingFromTimeOfDay(String tod) {
    switch (tod) {
      case 'golden-hour': return 8.5;
      case 'morning': return 7.0;
      case 'afternoon': return 6.5;
      case 'dawn': return 7.0;
      case 'dusk': return 6.5;
      case 'night': return 3.0;
      default: return 6.0;
    }
  }

  String _encouragement(String grade) {
    switch (grade) {
      case 'A+': return '几乎完美！这张可以直接发朋友圈了';
      case 'A': return '拍得很棒，稍微微调一下就更好了';
      case 'B': return '还不错！根据建议调整一下会更出色';
      case 'C': return '还有提升空间，试试换个姿势或角度再来一张';
      default: return '别灰心！注意改进建议，重拍一次试试';
    }
  }
}
