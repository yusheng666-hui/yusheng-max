/// Hybrid scene analyzer — TFLite classifier with rule-based fallback.
///
/// Attempts to use a TFLite MobileNetV3 scene classifier when available.
/// Falls back to the existing rule-based SceneAnalyzer for environments
/// where the model file isn't present or inference fails.
///
/// Also wires depth estimation and lighting analysis for rich scene features.

import 'dart:typed_data';
import 'scene_analyzer.dart';
import 'tflite_scene_classifier.dart';
import 'tflite_depth_estimator.dart';
import '../../../../shared/models/scene_features.dart';

/// Rich scene analysis combining multiple ML and rule-based sources.
class RichSceneResult {
  final String sceneClass;
  final String fineSceneId;
  final double sceneConfidence;
  final String timeOfDay;
  final List<String> colorPalette;
  final String label;
  final LightingInfo lighting;
  final SpatialInfo spatial;
  final bool usedTFLite;
  final int? tfliteInferenceMs;
  final double? subjectDistanceM;
  final bool hasGroundPlane;

  const RichSceneResult({
    required this.sceneClass,
    this.fineSceneId = '',
    required this.sceneConfidence,
    required this.timeOfDay,
    required this.colorPalette,
    required this.label,
    required this.lighting,
    required this.spatial,
    required this.usedTFLite,
    this.tfliteInferenceMs,
    this.subjectDistanceM,
    this.hasGroundPlane = false,
  });
}

/// Orchestrates TFLite and rule-based scene analysis with graceful degradation.
class HybridSceneAnalyzer {
  final TFLiteSceneClassifier _tfClassifier = TFLiteSceneClassifier();
  final TFLiteDepthEstimator _tfDepth = TFLiteDepthEstimator();
  final SceneAnalyzer _ruleAnalyzer = SceneAnalyzer();

  bool _modelsLoaded = false;

  bool get isTFLiteAvailable => _modelsLoaded;

  /// Initialize ML models. Call once at startup.
  Future<void> init() async {
    final sceneOk = await _tfClassifier.load();
    final depthOk = await _tfDepth.load();
    _modelsLoaded = sceneOk; // depth is optional
  }

  /// Analyze scene from a camera frame (preferred, uses TFLite).
  ///
  /// [imageBytes] — raw RGB pixel buffer.
  /// [width], [height] — frame dimensions.
  /// Returns a rich result with ML predictions plus rule-based enrichment.
  RichSceneResult analyzeFromFrame({
    required Uint8List imageBytes,
    required int width,
    required int height,
    required DateTime now,
  }) {
    final tod = _timeOfDayFromHour(now.hour);

    // Run TFLite scene classification
    TFLiteSceneResult? tfResult;
    if (_modelsLoaded) {
      tfResult = _tfClassifier.classify(
        imageBytes: imageBytes,
        width: width,
        height: height,
      );
    }

    final ruleResult = _ruleAnalyzer.analyze(
      now: now,
      tfliteClass: tfResult?.primaryLabel,
    );

    // Run depth estimation if model is available
    DepthEstimationResult? depthResult;
    if (_tfDepth.isLoaded) {
      depthResult = _tfDepth.estimate(
        imageBytes: imageBytes,
        imageWidth: width,
        imageHeight: height,
      );
    }

    // Merge: prefer TFLite scene class, use rules for time/color enrichment
    final sceneClass = tfResult?.primaryLabel ?? ruleResult.sceneClass;
    final confidence = tfResult?.confidence ?? ruleResult.confidence;
    final palette = ruleResult.colorPalette;

    // Lighting estimation from time of day + scene
    final lighting = _estimateLighting(sceneClass, tod);

    // Spatial info from depth
    final spatial = depthResult != null
        ? SpatialInfo(
            dominantPlanes: depthResult.hasGroundPlane
                ? [const PlaneInfo(type: 'ground', center: [0.5, 0.8, 0.0], normal: [0.0, 1.0, 0.0])]
                : [],
            depthRange: [depthResult.minDepth, depthResult.maxDepth],
          )
        : ruleSpatialFallback();

    return RichSceneResult(
      sceneClass: sceneClass,
      fineSceneId: ruleResult.fineSceneId,
      sceneConfidence: confidence,
      timeOfDay: tod,
      colorPalette: palette,
      label: ruleResult.label,
      lighting: lighting,
      spatial: spatial,
      usedTFLite: tfResult != null,
      tfliteInferenceMs: tfResult?.inferenceMs,
      subjectDistanceM: depthResult?.subjectDistanceM,
      hasGroundPlane: depthResult?.hasGroundPlane ?? false,
    );
  }

  /// Fallback: rule-based analysis only (when no frame available).
  RichSceneResult analyzeFromRules({required DateTime now}) {
    final result = _ruleAnalyzer.analyze(now: now);
    final tod = result.timeOfDay;
    final lighting = _estimateLighting(result.sceneClass, tod);

    return RichSceneResult(
      sceneClass: result.sceneClass,
      fineSceneId: result.fineSceneId,
      sceneConfidence: result.confidence,
      timeOfDay: tod,
      colorPalette: result.colorPalette,
      label: result.label,
      lighting: lighting,
      spatial: ruleSpatialFallback(),
      usedTFLite: false,
    );
  }

  /// Release all resources.
  void dispose() {
    _tfClassifier.dispose();
    _tfDepth.dispose();
  }

  // ── Helpers ──

  String _timeOfDayFromHour(int hour) {
    if (hour >= 5 && hour < 7) return 'dawn';
    if (hour >= 7 && hour < 10) return 'morning';
    if (hour >= 10 && hour < 16) return 'afternoon';
    if (hour >= 16 && hour < 18) return 'golden-hour';
    if (hour >= 18 && hour < 20) return 'dusk';
    return 'night';
  }

  LightingInfo _estimateLighting(String sceneClass, String tod) {
    double intensity = 0.65;
    double colorTemp = 5500;
    double contrastRatio = 2.5;

    switch (tod) {
      case 'dawn':
        intensity = 0.35; colorTemp = 3500; contrastRatio = 2.0;
      case 'morning':
        intensity = 0.65; colorTemp = 5000; contrastRatio = 2.5;
      case 'afternoon':
        intensity = 1.0; colorTemp = 5500; contrastRatio = 3.0;
      case 'golden-hour':
        intensity = 0.6; colorTemp = 3200; contrastRatio = 2.0;
      case 'dusk':
        intensity = 0.25; colorTemp = 3800; contrastRatio = 3.5;
      case 'night':
        intensity = 0.1; colorTemp = 4500; contrastRatio = 4.0;
    }

    // Scene adjustments
    if (sceneClass.contains('night')) {
      intensity = 0.1; contrastRatio = 4.0;
    } else if (sceneClass.contains('beach')) {
      contrastRatio = 3.5;
    } else if (sceneClass.contains('indoor')) {
      intensity *= 0.5; colorTemp = 4500;
    }

    return LightingInfo(
      direction: [0.5, 0.3, 0.8],
      intensity: intensity,
      colorTemp: colorTemp,
      contrastRatio: contrastRatio,
    );
  }

  SpatialInfo ruleSpatialFallback() {
    return const SpatialInfo(
      dominantPlanes: [],
      depthRange: [0.3, 25.0],
    );
  }
}
