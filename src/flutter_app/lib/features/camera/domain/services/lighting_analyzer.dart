/// On-device lighting analyzer — no ML model required.
///
/// Analyzes camera frame luminance data to determine:
/// - Light quality (hard / soft / diffused)
/// - Backlight condition (subject darker than background)
/// - Actionable lighting tips for the user
///
/// Works on the NV21 Y-plane only — no chrominance needed.
/// Downsampled for speed: ~5k samples from any resolution.

import 'dart:math';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import '../../../shared/models/scene_features.dart';

enum LightQualityType {
  /// Harsh light — strong shadows, high contrast (midday sun, direct flash)
  hard,

  /// Soft light — gentle shadows, moderate contrast (cloudy, shade, window light)
  soft,

  /// Very even light — minimal shadows (overcast, indoor diffuse)
  diffused,
}

class BacklightInfo {
  final bool isBacklit;
  final double severity; // 0.0–1.0
  final double centerMean; // average luminance 0–255
  final double peripheryMean;

  const BacklightInfo({
    required this.isBacklit,
    required this.severity,
    required this.centerMean,
    required this.peripheryMean,
  });
}

class LightingAnalysisResult {
  final LightingInfo baseInfo;
  final LightQualityType quality;
  final double qualityConfidence;
  final BacklightInfo backlight;
  final List<String> tips;

  const LightingAnalysisResult({
    required this.baseInfo,
    required this.quality,
    required this.qualityConfidence,
    required this.backlight,
    required this.tips,
  });
}

class LightingAnalyzer {
  /// Sample every Nth pixel horizontally and vertically.
  static const int _sampleStride = 8;

  /// Center region as fraction of frame dimensions.
  static const double _centerFraction = 0.35;

  /// Luminance above which a pixel is "bright".
  static const int _brightThreshold = 200;

  /// Luminance below which a pixel is "dark".
  static const int _darkThreshold = 60;

  /// Bright pixel ratio in periphery that triggers backlight suspicion.
  static const double _backlightBrightRatio = 0.35;

  /// Luminance ratio (periphery / center) above which backlight is flagged.
  static const double _backlightLuminanceRatio = 1.5;

  /// Analyze lighting from a camera frame (NV21 format, Y-plane).
  ///
  /// Returns null if the frame data is unusable.
  LightingAnalysisResult? analyzeFrame(
    CameraImage image, {
    required String sceneClass,
    required String timeOfDay,
  }) {
    final yPlane = image.planes[0];
    final width = image.width;
    final height = image.height;
    final bytes = yPlane.bytes;
    final bytesPerRow = yPlane.bytesPerRow;

    if (bytes.isEmpty || width == 0 || height == 0) return null;

    // Downsample and collect luminance samples, split by region
    final centerSamples = <int>[];
    final peripherySamples = <int>[];
    final allSamples = <int>[];

    final centerLeft = (width * ((1 - _centerFraction) / 2)).round();
    final centerTop = (height * ((1 - _centerFraction) / 2)).round();
    final centerRight = (width * (1 - (1 - _centerFraction) / 2)).round();
    final centerBottom = (height * (1 - (1 - _centerFraction) / 2)).round();

    for (int y = 0; y < height; y += _sampleStride) {
      final rowOffset = y * bytesPerRow;
      for (int x = 0; x < width; x += _sampleStride) {
        final idx = rowOffset + x;
        if (idx >= bytes.length) break;
        final lum = bytes[idx];

        allSamples.add(lum);

        final inCenter = x >= centerLeft &&
            x <= centerRight &&
            y >= centerTop &&
            y <= centerBottom;

        if (inCenter) {
          centerSamples.add(lum);
        } else {
          peripherySamples.add(lum);
        }
      }
    }

    if (allSamples.isEmpty) return null;

    // Compute statistics
    final quality = _classifyQuality(allSamples, timeOfDay);
    final backlight = _detectBacklight(centerSamples, peripherySamples);
    final tips = _generateTips(quality, backlight, sceneClass, timeOfDay);

    // Build enriched LightingInfo
    final centerMean = centerSamples.isNotEmpty
        ? centerSamples.reduce((a, b) => a + b) / centerSamples.length
        : 128.0;
    final peripheryMean = peripherySamples.isNotEmpty
        ? peripherySamples.reduce((a, b) => a + b) / peripherySamples.length
        : 128.0;
    final overallMean = allSamples.reduce((a, b) => a + b) / allSamples.length;

    final intensity = (overallMean / 255.0).clamp(0.0, 1.0);
    final contrastRatio = _computeContrast(allSamples);

    // Lighting direction: compare left vs right, top vs bottom
    final direction = _estimateDirection(
      bytes, width, height, bytesPerRow, _sampleStride,
    );

    final baseInfo = LightingInfo(
      direction: direction,
      intensity: intensity,
      colorTemp: _estimateColorTemp(timeOfDay),
      contrastRatio: contrastRatio,
      quality: quality.name,
      isBacklit: backlight.isBacklit,
      backlightSeverity: backlight.severity,
    );

    return LightingAnalysisResult(
      baseInfo: baseInfo,
      quality: quality,
      qualityConfidence: _qualityConfidence(allSamples, quality),
      backlight: backlight,
      tips: tips,
    );
  }

  // ── Light quality classification ──────────────────────────────

  LightQualityType _classifyQuality(List<int> samples, String timeOfDay) {
    if (samples.isEmpty) return LightQualityType.soft;

    // Count bright and dark pixels
    int brightCount = 0;
    int darkCount = 0;
    for (final s in samples) {
      if (s >= _brightThreshold) brightCount++;
      if (s <= _darkThreshold) darkCount++;
    }

    final brightRatio = brightCount / samples.length;
    final darkRatio = darkCount / samples.length;

    // Hard light: both bright highlights AND dark shadows present
    if (brightRatio > 0.15 && darkRatio > 0.10) {
      return LightQualityType.hard;
    }

    // Diffused: very few bright or dark extremes, everything mid-range
    if (brightRatio < 0.05 && darkRatio < 0.05) {
      return LightQualityType.diffused;
    }

    return LightQualityType.soft;
  }

  double _qualityConfidence(List<int> samples, LightQualityType quality) {
    if (samples.isEmpty) return 0.5;
    final stdDev = _stdDev(samples, samples.reduce((a, b) => a + b) / samples.length);

    switch (quality) {
      case LightQualityType.hard:
        return (stdDev / 80.0).clamp(0.5, 1.0);
      case LightQualityType.soft:
        return ((40.0 - (stdDev - 40.0).abs()) / 40.0).clamp(0.4, 0.9);
      case LightQualityType.diffused:
        return ((30.0 - stdDev) / 30.0).clamp(0.5, 1.0);
    }
  }

  // ── Backlight detection ────────────────────────────────────────

  BacklightInfo _detectBacklight(List<int> center, List<int> periphery) {
    if (center.isEmpty || periphery.isEmpty) {
      return const BacklightInfo(
        isBacklit: false, severity: 0, centerMean: 128, peripheryMean: 128,
      );
    }

    final centerMean = center.reduce((a, b) => a + b) / center.length;
    final peripheryMean = periphery.reduce((a, b) => a + b) / periphery.length;

    // Count bright pixels in periphery
    final brightInPeriphery = periphery.where((p) => p >= _brightThreshold).length;
    final brightRatio = brightInPeriphery / periphery.length;

    final luminanceRatio = centerMean > 0 ? peripheryMean / centerMean : 1.0;

    final isBacklit = luminanceRatio > _backlightLuminanceRatio &&
        brightRatio > _backlightBrightRatio;

    // Severity: how much brighter the periphery is
    final severity = isBacklit
        ? ((luminanceRatio - 1.0) / 3.0).clamp(0.1, 1.0)
        : 0.0;

    return BacklightInfo(
      isBacklit: isBacklit,
      severity: severity,
      centerMean: centerMean,
      peripheryMean: peripheryMean,
    );
  }

  // ── Direction estimation ──────────────────────────────────────

  List<double> _estimateDirection(
    Uint8List bytes, int width, int height, int bytesPerRow, int stride,
  ) {
    double leftSum = 0, rightSum = 0, topSum = 0, bottomSum = 0;
    int leftN = 0, rightN = 0, topN = 0, bottomN = 0;
    final midX = width ~/ 2;
    final midY = height ~/ 2;

    for (int y = 0; y < height; y += stride) {
      final rowOffset = y * bytesPerRow;
      for (int x = 0; x < width; x += stride) {
        final idx = rowOffset + x;
        if (idx >= bytes.length) break;
        final lum = bytes[idx];

        if (x < midX) { leftSum += lum; leftN++; }
        else { rightSum += lum; rightN++; }

        if (y < midY) { topSum += lum; topN++; }
        else { bottomSum += lum; bottomN++; }
      }
    }

    if (leftN == 0 || rightN == 0 || topN == 0 || bottomN == 0) {
      return [0.5, 0.3, 0.8];
    }

    final leftAvg = leftSum / leftN;
    final rightAvg = rightSum / rightN;
    final topAvg = topSum / topN;
    final bottomAvg = bottomSum / bottomN;

    // Direction vector: [x_bias, y_bias, z_forward]
    // A positive x means light comes from right side
    final dx = ((rightAvg - leftAvg) / 128.0).clamp(-1.0, 1.0);
    // A positive y means light comes from top
    final dy = ((bottomAvg - topAvg) / 128.0).clamp(-1.0, 1.0);

    return [dx, dy, 0.8];
  }

  // ── Tips generation ────────────────────────────────────────────

  List<String> _generateTips(
    LightQualityType quality,
    BacklightInfo backlight,
    String sceneClass,
    String timeOfDay,
  ) {
    final tips = <String>[];

    // Backlight takes priority — it ruins photos the most
    if (backlight.isBacklit) {
      tips.add('你正处于逆光环境，建议打开闪光灯或 HDR 模式补光');
      if (sceneClass == 'outdoor-nature' || sceneClass == 'outdoor' || sceneClass == 'beach') {
        tips.add('逆光时可以尝试拍摄剪影风格，侧身站立效果更好');
      }
      return tips;
    }

    // Light quality tips
    switch (quality) {
      case LightQualityType.hard:
        tips.add('光线比较硬，面部阴影会比较重');
        tips.add('建议移到阴影处或树荫下，光线会更柔和均匀');
        break;
      case LightQualityType.soft:
        tips.add('光线柔和，非常适合拍摄人像');
        if (timeOfDay == 'golden-hour') {
          tips.add('黄金时刻光线最佳，面向光源让脸部更立体');
        }
        break;
      case LightQualityType.diffused:
        tips.add('光线均匀柔和，拍出来皮肤质感会很好');
        break;
    }

    // Scene-specific lighting advice
    if (sceneClass.contains('night')) {
      tips.add('夜间光线不足，建议寻找橱窗灯或路灯作为面光');
    } else if (sceneClass.contains('indoor') && quality == LightQualityType.hard) {
      tips.add('室内强光可拉上窗帘或用柔光布遮挡');
    }

    return tips;
  }

  // ── Statistics helpers ─────────────────────────────────────────

  double _stdDev(List<int> samples, double mean) {
    if (samples.length < 2) return 0;
    double sumSq = 0;
    for (final s in samples) {
      final d = s - mean;
      sumSq += d * d;
    }
    return sqrt(sumSq / (samples.length - 1));
  }

  double _computeContrast(List<int> samples) {
    if (samples.length < 10) return 2.5;
    final sorted = List<int>.from(samples)..sort();
    final p10 = sorted[(sorted.length * 0.1).round()];
    final p90 = sorted[(sorted.length * 0.9).round()];
    if (p10 == 0) return 4.0;
    return (p90 / p10).clamp(1.0, 10.0);
  }

  double _estimateColorTemp(String timeOfDay) {
    switch (timeOfDay) {
      case 'dawn': return 3500;
      case 'morning': return 5000;
      case 'afternoon': return 5500;
      case 'golden-hour': return 3200;
      case 'dusk': return 3800;
      case 'night': return 4500;
      default: return 5500;
    }
  }
}
