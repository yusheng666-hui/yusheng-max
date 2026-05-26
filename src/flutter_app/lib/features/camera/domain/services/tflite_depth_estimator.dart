/// TFLite depth estimation wrapper — MiDaS/Depth-Anything compatible.
///
/// Performs monocular depth estimation from a single camera frame.
/// Outputs a relative-inverse depth map that can be used for:
/// - Standing position recommendations (finding flat ground planes)
/// - Safe distance estimation for subject placement
/// - "Step forward/back" AR guidance precision
///
/// Model expected: MiDaS Small v2.1 (256×256 input) or Depth-Anything-Small.
/// Input: 256×256 RGB, normalized.
/// Output: float32 depth map of shape [1, 256, 256] (inverse depth, higher = closer).

import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import '../../../../core/constants.dart';

/// Depth estimation result containing the full depth map and derived metrics.
class DepthEstimationResult {
  /// Relative inverse-depth map (higher values = closer to camera).
  /// Shape: [height, width] matching input size.
  final Float32List depthMap;

  /// Width of the depth map in pixels.
  final int width;

  /// Height of the depth map in pixels.
  final int height;

  /// Minimum depth value (farthest point).
  final double minDepth;

  /// Maximum depth value (closest point).
  final double maxDepth;

  /// Estimated distance to the primary subject in meters (approximate).
  final double subjectDistanceM;

  /// Whether a flat ground plane was detected in the lower portion.
  final bool hasGroundPlane;

  /// Inference time in milliseconds.
  final int inferenceMs;

  const DepthEstimationResult({
    required this.depthMap,
    required this.width,
    required this.height,
    required this.minDepth,
    required this.maxDepth,
    required this.subjectDistanceM,
    required this.hasGroundPlane,
    required this.inferenceMs,
  });
}

/// Wraps a TFLite monocular depth estimation model (MiDaS / Depth-Anything).
class TFLiteDepthEstimator {
  Interpreter? _interpreter;
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;

  /// Load the depth model from assets.
  Future<bool> load() async {
    try {
      _interpreter = await Interpreter.fromAsset(
        MlModels.depthEstimation,
        options: InterpreterOptions()
          ..threads = 4
          ..useXNNPACK = true,
      );
      _interpreter!.allocateTensors();
      _isLoaded = true;
      return true;
    } catch (_) {
      _isLoaded = false;
      return false;
    }
  }

  /// Estimate depth from a single image frame.
  ///
  /// Returns null if the model isn't loaded.
  /// [imageBytes] is raw RGB data (3 bytes per pixel).
  DepthEstimationResult? estimate({
    required Uint8List imageBytes,
    required int imageWidth,
    required int imageHeight,
  }) {
    if (!_isLoaded || _interpreter == null) return null;

    final sw = Stopwatch()..start();

    final inputShape = _interpreter!.getInputTensor(0).shape;
    final modelSize = inputShape[1]; // typically 256 for MiDaS

    // Preprocess
    final input = _preprocessForDepth(imageBytes, imageWidth, imageHeight, modelSize);

    // Allocate output
    final outputShape = _interpreter!.getOutputTensor(0).shape;
    final outH = outputShape[1];
    final outW = outputShape[2];
    final output = Float32List(outH * outW);

    // Run
    _interpreter!.run(input, output);

    sw.stop();

    // Normalize depth to [0, 1] range (inverse depth → depth)
    double minVal = output[0];
    double maxVal = output[0];
    for (int i = 1; i < output.length; i++) {
      if (output[i] < minVal) minVal = output[i];
      if (output[i] > maxVal) maxVal = output[i];
    }

    final range = maxVal - minVal;
    if (range > 0) {
      for (int i = 0; i < output.length; i++) {
        output[i] = (output[i] - minVal) / range;
      }
    }

    // Estimate subject distance from center region
    final subjectDist = _estimateSubjectDistance(output, outW, outH);

    // Check for ground plane in bottom third
    final hasGround = _detectGroundPlane(output, outW, outH);

    return DepthEstimationResult(
      depthMap: output,
      width: outW,
      height: outH,
      minDepth: minVal,
      maxDepth: maxVal,
      subjectDistanceM: subjectDist,
      hasGroundPlane: hasGround,
      inferenceMs: sw.elapsedMilliseconds,
    );
  }

  /// Preprocess image for MiDaS: resize to modelSize, normalize.
  Float32List _preprocessForDepth(
    Uint8List bytes,
    int width,
    int height,
    int modelSize,
  ) {
    final input = Float32List(modelSize * modelSize * 3);
    final xRatio = width / modelSize;
    final yRatio = height / modelSize;

    for (int y = 0; y < modelSize; y++) {
      for (int x = 0; x < modelSize; x++) {
        final srcX = (x * xRatio).round().clamp(0, width - 1);
        final srcY = (y * yRatio).round().clamp(0, height - 1);
        final srcIdx = (srcY * width + srcX) * 3;
        final dstIdx = (y * modelSize + x) * 3;

        if (srcIdx + 2 < bytes.length) {
          // MiDaS normalization: mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]
          input[dstIdx] = ((bytes[srcIdx].toDouble() / 255.0) - 0.485) / 0.229;
          input[dstIdx + 1] = ((bytes[srcIdx + 1].toDouble() / 255.0) - 0.456) / 0.224;
          input[dstIdx + 2] = ((bytes[srcIdx + 2].toDouble() / 255.0) - 0.406) / 0.225;
        }
      }
    }

    return input;
  }

  /// Estimate distance to the primary subject from the center of the depth map.
  double _estimateSubjectDistance(Float32List depth, int w, int h) {
    // Sample center 20% of the frame
    final cx = w ~/ 2;
    final cy = h ~/ 2;
    final sampleW = (w * 0.2).round();
    final sampleH = (h * 0.2).round();

    double sum = 0;
    int count = 0;
    for (int y = cy - sampleH ~/ 2; y < cy + sampleH ~/ 2; y++) {
      for (int x = cx - sampleW ~/ 2; x < cx + sampleW ~/ 2; x++) {
        if (x >= 0 && x < w && y >= 0 && y < h) {
          sum += depth[y * w + x];
          count++;
        }
      }
    }

    if (count == 0) return 2.0;
    final avgInverse = sum / count;
    // Convert relative depth to approximate meters (very approximate)
    // Assumes max depth ≈ 20m, so normalized depth * 20
    return (1.0 - avgInverse) * 20.0;
  }

  /// Detect if the bottom third of the depth map contains a flat plane.
  bool _detectGroundPlane(Float32List depth, int w, int h) {
    final bottomStart = (h * 2 / 3).round();
    double sum = 0;
    int count = 0;

    for (int y = bottomStart; y < h; y++) {
      for (int x = 0; x < w; x += 4) {
        // Sample every 4th pixel
        sum += depth[y * w + x];
        count++;
      }
    }

    if (count == 0) return false;

    final avg = sum / count;
    // Check variance in bottom region — low variance = flat plane
    double variance = 0;
    for (int y = bottomStart; y < h; y++) {
      for (int x = 0; x < w; x += 4) {
        final diff = depth[y * w + x] - avg;
        variance += diff * diff;
      }
    }
    variance /= count;

    // Threshold: variance < 0.01 suggests a flat surface
    return variance < 0.01;
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isLoaded = false;
  }
}
