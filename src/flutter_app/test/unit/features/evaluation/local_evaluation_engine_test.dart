import 'package:flutter_test/flutter_test.dart';
import 'package:pose_craft/features/evaluation/domain/services/local_evaluation_engine.dart';
import 'package:pose_craft/features/ar/domain/services/alignment_scorer.dart';
import 'package:pose_craft/features/camera/domain/services/lighting_analyzer.dart';
import 'package:pose_craft/features/camera/domain/services/expression_detector.dart';
import 'package:pose_craft/shared/models/evaluation.dart';
import 'package:pose_craft/shared/models/scene_features.dart';

void main() {
  late LocalEvaluationEngine engine;

  setUp(() {
    engine = LocalEvaluationEngine();
  });

  // ── Helpers ───────────────────────────────────────────────────

  AlignmentResult perfectAlignment() => AlignmentResult(
        overallScore: 0.95,
        torsoScore: 0.95,
        armsScore: 0.93,
        legsScore: 0.94,
        headScore: 0.96,
        matchedKeypoints: 33,
        hints: const [],
      );

  BacklightInfo noBacklight() => const BacklightInfo(
        isBacklit: false,
        severity: 0,
        centerMean: 140,
        peripheryMean: 130,
      );

  LightingAnalysisResult softLight() => LightingAnalysisResult(
        baseInfo: const LightingInfo(
          direction: [0.5, 0.3, 0.8],
          intensity: 0.6,
          colorTemp: 5000,
          contrastRatio: 2.0,
        ),
        quality: LightQualityType.soft,
        qualityConfidence: 0.8,
        backlight: noBacklight(),
        tips: const [],
      );

  LightingInfo tempBacklightInfo() {
    return const LightingInfo(
      direction: [0.5, 0.3, 0.8],
      intensity: 0.4,
      colorTemp: 5000,
      contrastRatio: 3.0,
      isBacklit: true,
      backlightSeverity: 0.7,
    );
  }

  LightingAnalysisResult backlight() {
    final tips = ['逆光拍摄，下次试试换个角度或打开闪光灯'];
    return LightingAnalysisResult(
      baseInfo: tempBacklightInfo(),
      quality: LightQualityType.soft,
      qualityConfidence: 0.7,
      backlight: const BacklightInfo(
        isBacklit: true,
        severity: 0.7,
        centerMean: 50,
        peripheryMean: 220,
      ),
      tips: tips,
    );
  }

  ExpressionResult smile() {
    return ExpressionResult(
      expression: ExpressionType.bigSmile,
      confidence: 0.9,
      smilingProbability: 0.8,
      leftEyeOpen: 0.95,
      rightEyeOpen: 0.95,
      label: '大笑',
    );
  }

  ExpressionResult neutral() {
    return ExpressionResult(
      expression: ExpressionType.neutral,
      confidence: 0.85,
      smilingProbability: 0.1,
      leftEyeOpen: 0.9,
      rightEyeOpen: 0.9,
      label: '面无表情',
    );
  }

  // ── Tests ─────────────────────────────────────────────────────

  group('LocalEvaluationEngine.evaluate()', () {
    test('perfect alignment + soft light + smile → grade A+', () {
      final result = engine.evaluate(
        alignment: perfectAlignment(),
        lighting: softLight(),
        expression: smile(),
        sceneClass: 'outdoor-nature',
        timeOfDay: 'golden-hour',
      );

      expect(result.overallScore, greaterThanOrEqualTo(8.5));
      expect(result.grade, anyOf('A', 'A+'));
      expect(result.encouragement, isNotEmpty);
      expect(result.dimensions.length, 4);
    });

    test('null alignment → poseScore 5.0 with no-person tip', () {
      final result = engine.evaluate(
        alignment: null,
        lighting: softLight(),
        expression: smile(),
        sceneClass: 'outdoor-nature',
        timeOfDay: 'afternoon',
      );

      final poseDimension = result.dimensions.firstWhere((d) => d.labelZh == '姿势');
      expect(poseDimension.score, 5.0);
      expect(
        result.improvementTips,
        contains('未检测到人物，切换到摄影师模式可获取构图建议'),
      );
    });

    test('null lighting → falls back to time-of-day score', () {
      final result = engine.evaluate(
        alignment: perfectAlignment(),
        lighting: null,
        expression: smile(),
        sceneClass: 'outdoor-nature',
        timeOfDay: 'golden-hour',
      );

      final lightDimension = result.dimensions.firstWhere((d) => d.labelZh == '光线');
      expect(lightDimension.score, 8.5); // golden-hour default
    });

    test('null expression → exprScore 6.0 with no-face message', () {
      final result = engine.evaluate(
        alignment: perfectAlignment(),
        lighting: softLight(),
        expression: null,
        sceneClass: 'outdoor-nature',
        timeOfDay: 'afternoon',
      );

      final exprDimension = result.dimensions.firstWhere((d) => d.labelZh == '表情');
      expect(exprDimension.score, 6.0);
      expect(exprDimension.feedbackZh, '未检测到面部表情');
    });

    test('backlight → produces backlight tip', () {
      final result = engine.evaluate(
        alignment: perfectAlignment(),
        lighting: backlight(),
        expression: neutral(),
        sceneClass: 'outdoor-nature',
        timeOfDay: 'afternoon',
      );

      final lightDimension = result.dimensions.firstWhere((d) => d.labelZh == '光线');
      expect(lightDimension.score, lessThan(6.0));
      expect(
        result.improvementTips,
        contains('逆光拍摄，下次试试换个角度或打开闪光灯'),
      );
    });

    test('neutral expression → lower expression score', () {
      final result = engine.evaluate(
        alignment: perfectAlignment(),
        lighting: softLight(),
        expression: neutral(),
        sceneClass: 'indoor',
        timeOfDay: 'afternoon',
      );

      final exprDimension = result.dimensions.firstWhere((d) => d.labelZh == '表情');
      expect(exprDimension.score, 5.5);
      expect(exprDimension.feedbackZh, contains('笑'));
    });

    test('bad alignment → hints included in tips', () {
      final badAlignment = AlignmentResult(
        overallScore: 0.3,
        torsoScore: 0.3,
        armsScore: 0.25,
        legsScore: 0.28,
        headScore: 0.35,
        matchedKeypoints: 15,
        hints: const ['左肩往左移', '右肘往上抬'],
      );

      final result = engine.evaluate(
        alignment: badAlignment,
        lighting: softLight(),
        expression: smile(),
        sceneClass: 'outdoor-nature',
        timeOfDay: 'afternoon',
      );

      final poseDimension = result.dimensions.firstWhere((d) => d.labelZh == '姿势');
      expect(poseDimension.score, lessThan(6.0));
      expect(result.improvementTips, contains('左肩往左移'));
    });

    test('deduplicates tips', () {
      // The evaluation engine may add "逆光" tip if backlit,
      // but should not duplicate tips already present in alignment hints
      final result = engine.evaluate(
        alignment: perfectAlignment(),
        lighting: backlight(),
        expression: neutral(),
        sceneClass: 'outdoor-nature',
        timeOfDay: 'afternoon',
      );

      // Each tip should appear only once
      final deduplicated = result.improvementTips.toSet().toList();
      expect(result.improvementTips.length, deduplicated.length);
    });

    test('night timeOfDay → low default lighting score', () {
      final result = engine.evaluate(
        alignment: perfectAlignment(),
        lighting: null,
        expression: smile(),
        sceneClass: 'outdoor-nature',
        timeOfDay: 'night',
      );

      final lightDimension = result.dimensions.firstWhere((d) => d.labelZh == '光线');
      expect(lightDimension.score, 3.0);
    });

    test('correct encouragement for each grade', () {
      // A+: almost perfect
      final aPlus = engine.evaluate(
        alignment: perfectAlignment(),
        lighting: softLight(),
        expression: ExpressionResult(
          expression: ExpressionType.laugh,
          confidence: 0.95,
          smilingProbability: 0.9,
          leftEyeOpen: 0.95,
          rightEyeOpen: 0.95,
          label: '大笑',
        ),
        sceneClass: 'outdoor-nature',
        timeOfDay: 'golden-hour',
      );

      expect(aPlus.overallScore, greaterThanOrEqualTo(9.0));
      expect(aPlus.encouragement, contains('几乎完美'));
    });
  });

  group('_lightingFromTimeOfDay', () {
    test('each time of day gives expected score', () {
      // Tested indirectly through evaluate() with null lighting
      final goldenHour = engine.evaluate(
        alignment: perfectAlignment(),
        lighting: null,
        expression: smile(),
        sceneClass: 'outdoor',
        timeOfDay: 'golden-hour',
      );
      expect(
        goldenHour.dimensions.firstWhere((d) => d.labelZh == '光线').score,
        8.5,
      );

      final morning = engine.evaluate(
        alignment: perfectAlignment(),
        lighting: null,
        expression: smile(),
        sceneClass: 'outdoor',
        timeOfDay: 'morning',
      );
      expect(
        morning.dimensions.firstWhere((d) => d.labelZh == '光线').score,
        7.0,
      );

      final night = engine.evaluate(
        alignment: perfectAlignment(),
        lighting: null,
        expression: smile(),
        sceneClass: 'outdoor',
        timeOfDay: 'night',
      );
      expect(
        night.dimensions.firstWhere((d) => d.labelZh == '光线').score,
        3.0,
      );
    });
  });
}
