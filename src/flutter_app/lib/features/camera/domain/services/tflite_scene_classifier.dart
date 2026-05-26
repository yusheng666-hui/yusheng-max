/// TFLite scene classifier wrapper — MobileNetV3-based 20-class scene recognition.
///
/// Replaces the rule-based SceneAnalyzer when a .tflite model file is present
/// in assets/models/. Falls back gracefully to null if the model isn't available,
/// allowing the pipeline to use rule-based analysis instead.
///
/// Model expected: MobileNetV3-Small trained on Places365 subset or custom 20-class set.
/// Input: 224×224 RGB, normalized to [-1, 1] or [0, 1] depending on model metadata.
/// Output: float32 logits of shape [1, 20].

import 'dart:math' as math;
import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import '../../../../core/constants.dart';

/// 20 scene class labels matching model output order.
const sceneLabels = [
  'outdoor-nature',    // 0
  'urban-street',       // 1
  'indoor',             // 2
  'beach',              // 3
  'night-scene',        // 4
  'indoor-cafe',        // 5
  'indoor-home',        // 6
  'mountain',           // 7
  'lake-river',         // 8
  'forest',             // 9
  'garden-park',        // 10
  'snow',               // 11
  'sunset-sunrise',     // 12
  'rainy-street',       // 13
  'neon-light',         // 14
  'library',            // 15
  'gym-fitness',        // 16
  'restaurant',         // 17
  'market-bazaar',      // 18
  'stadium',            // 19
];

/// Result from the TFLite scene classifier.
class TFLiteSceneResult {
  /// Primary scene label
  final String primaryLabel;

  /// Confidence score for primary label [0.0–1.0]
  final double confidence;

  /// Top 3 labels with confidence scores
  final List<({String label, double confidence})> top3;

  /// Raw inference time in milliseconds
  final int inferenceMs;

  const TFLiteSceneResult({
    required this.primaryLabel,
    required this.confidence,
    required this.top3,
    required this.inferenceMs,
  });
}

/// Wraps a TFLite MobileNetV3 scene classifier with preprocessing and postprocessing.
class TFLiteSceneClassifier {
  Interpreter? _interpreter;
  bool _isLoaded = false;

  /// Whether the model is loaded and ready for inference.
  bool get isLoaded => _isLoaded;

  /// Load the model from assets and allocate tensors.
  /// Returns true on success, false if model file is not available.
  Future<bool> load() async {
    try {
      _interpreter = await Interpreter.fromAsset(
        MlModels.sceneClassifier,
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

  /// Run scene classification on an image buffer.
  ///
  /// [imageBytes] is the raw RGB pixel data (3 bytes per pixel).
  /// [width] and [height] are the original image dimensions.
  TFLiteSceneResult? classify({
    required Uint8List imageBytes,
    required int width,
    required int height,
  }) {
    if (!_isLoaded || _interpreter == null) return null;

    final sw = Stopwatch()..start();

    final inputShape = _interpreter!.getInputTensor(0).shape;
    final modelSize = inputShape[1]; // typically 224
    final inputType = _interpreter!.getInputTensor(0).type;

    // Preprocess: resize + normalize
    final input = _preprocess(imageBytes, width, height, modelSize, inputType);

    // Output buffer — must match model output type (float32)
    final outputShape = _interpreter!.getOutputTensor(0).shape;
    final output = Float32List(outputShape[1]);

    // Run inference
    _interpreter!.run(input, output);
    final logits = output;

    sw.stop();

    // Softmax + top-3
    final top3 = _topK(logits, 3);
    final primary = top3.first;

    return TFLiteSceneResult(
      primaryLabel: sceneLabels[primary.$1],
      confidence: primary.$2,
      top3: top3.map((t) => (label: sceneLabels[t.$1], confidence: t.$2)).toList(),
      inferenceMs: sw.elapsedMilliseconds,
    );
  }

  /// Preprocess image: center-crop, resize, normalize.
  Float32List _preprocess(
    Uint8List bytes,
    int width,
    int height,
    int modelSize,
    int inputType,
  ) {
    // Determine if model expects [-1,1] or [0,1] normalization
    final quantParams = _interpreter!.getInputTensor(0).quantParams;
    final scale = quantParams?.scale ?? 0.0;
    final zeroPoint = quantParams?.zeroPoint ?? 0;
    final isQuantized = scale != 0.0;

    final input = Float32List(modelSize * modelSize * 3);

    // Center-crop to square
    final cropSize = width < height ? width : height;
    final cropX = (width - cropSize) ~/ 2;
    final cropY = (height - cropSize) ~/ 2;

    // Bilinear resize from crop to modelSize×modelSize
    final xRatio = cropSize / modelSize;
    final yRatio = cropSize / modelSize;

    for (int y = 0; y < modelSize; y++) {
      for (int x = 0; x < modelSize; x++) {
        final srcX = (cropX + x * xRatio).round().clamp(0, width - 1);
        final srcY = (cropY + y * yRatio).round().clamp(0, height - 1);
        final srcIdx = (srcY * width + srcX) * 3;

        final idx = (y * modelSize + x) * 3;
        if (srcIdx + 2 < bytes.length) {
          final r = bytes[srcIdx];
          final g = bytes[srcIdx + 1];
          final b = bytes[srcIdx + 2];

          if (isQuantized) {
            input[idx] = ((r.toDouble() / 255.0) / scale + zeroPoint).roundToDouble();
            input[idx + 1] = ((g.toDouble() / 255.0) / scale + zeroPoint).roundToDouble();
            input[idx + 2] = ((b.toDouble() / 255.0) / scale + zeroPoint).roundToDouble();
          } else {
            // Float model: normalize to [-1, 1] (standard MobileNet preprocessing)
            input[idx] = (r.toDouble() / 127.5) - 1.0;
            input[idx + 1] = (g.toDouble() / 127.5) - 1.0;
            input[idx + 2] = (b.toDouble() / 127.5) - 1.0;
          }
        }
      }
    }

    return input;
  }

  /// Top-K indices and values from logits, applying softmax.
  List<(int, double)> _topK(Float32List logits, int k) {
    // Softmax
    double maxLogit = logits[0];
    for (int i = 1; i < logits.length; i++) {
      if (logits[i] > maxLogit) maxLogit = logits[i];
    }

    double sum = 0.0;
    final probs = Float32List(logits.length);
    for (int i = 0; i < logits.length; i++) {
      probs[i] = math.exp(logits[i] - maxLogit);
      sum += probs[i];
    }
    for (int i = 0; i < probs.length; i++) {
      probs[i] /= sum;
    }

    // Find top K
    final indexed = <(int, double)>[];
    for (int i = 0; i < probs.length; i++) {
      indexed.add((i, probs[i]));
    }
    indexed.sort((a, b) => b.$2.compareTo(a.$2));
    return indexed.take(k).toList();
  }

  /// Release TFLite resources.
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isLoaded = false;
  }
}
