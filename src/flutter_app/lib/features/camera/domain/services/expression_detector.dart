/// Expression detection using ML Kit Face Detection.
///
/// Classifies expressions from `smilingProbability`, `leftEyeOpenProbability`,
/// and `rightEyeOpenProbability` into 6 categories, with Chinese guidance text.

import 'dart:ui' show Size;
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

enum ExpressionType {
  /// Smiling prob < 0.25
  neutral,

  /// Smiling prob 0.25–0.55 — gentle smile
  slightSmile,

  /// Smiling prob 0.55–0.85 — bright smile
  bigSmile,

  /// Smiling prob >= 0.85 — laughing
  laugh,

  /// One eye open, one closed
  winking,

  /// Both eyes closed (blink / closed-eye smile)
  eyesClosed,
}

class ExpressionResult {
  final ExpressionType expression;
  final double confidence;
  final double smilingProbability;
  final double leftEyeOpen;
  final double rightEyeOpen;
  final String? guidance;
  final String label;

  const ExpressionResult({
    required this.expression,
    required this.confidence,
    required this.smilingProbability,
    required this.leftEyeOpen,
    required this.rightEyeOpen,
    this.guidance,
    this.label = '',
  });
}

class ExpressionDetector {
  FaceDetector? _detector;
  bool _initialized = false;

  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;
    _detector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        enableLandmarks: false,
        enableContours: false,
        enableTracking: false,
        performanceMode: FaceDetectorMode.fast,
      ),
    );
    _initialized = true;
  }

  /// Process a camera frame and return the expression of the most prominent face.
  ///
  /// Returns null if no face is detected.
  Future<ExpressionResult?> processFrame(CameraImage image) async {
    if (!_initialized || _detector == null) return null;

    try {
      final inputImage = _imageFromCamera(image);
      if (inputImage == null) return null;

      final faces = await _detector!.processImage(inputImage);
      if (faces.isEmpty) return null;

      // Use the largest face (closest to camera)
      final face = _largestFace(faces);
      if (face == null) return null;

      final smiling = face.smilingProbability ?? 0.5;
      final leftEye = face.leftEyeOpenProbability ?? 0.7;
      final rightEye = face.rightEyeOpenProbability ?? 0.7;

      final (expression, confidence) = _classify(smiling, leftEye, rightEye);
      final guidance = _guidance(expression);
      final label = _label(expression);

      return ExpressionResult(
        expression: expression,
        confidence: confidence,
        smilingProbability: smiling,
        leftEyeOpen: leftEye,
        rightEyeOpen: rightEye,
        guidance: guidance,
        label: label,
      );
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    _detector?.close();
    _detector = null;
    _initialized = false;
  }

  // ── Classification ────────────────────────────────────────────

  (ExpressionType, double) _classify(
    double smiling,
    double leftEye,
    double rightEye,
  ) {
    final avgEye = (leftEye + rightEye) / 2.0;

    // Eyes-closed check first
    if (avgEye < 0.3) {
      if (smiling >= 0.5) {
        return (ExpressionType.eyesClosed, avgEye < 0.15 ? 0.9 : 0.7);
      }
      return (ExpressionType.eyesClosed, avgEye < 0.15 ? 0.85 : 0.65);
    }

    // Wink: one eye significantly more closed than the other
    final eyeDiff = (leftEye - rightEye).abs();
    if (eyeDiff > 0.5 && (leftEye < 0.35 || rightEye < 0.35)) {
      return (ExpressionType.winking, (eyeDiff * 1.5).clamp(0.6, 0.95));
    }

    // Smile-based classification
    if (smiling >= 0.85) {
      return (ExpressionType.laugh, smiling);
    }
    if (smiling >= 0.55) {
      return (ExpressionType.bigSmile, smiling);
    }
    if (smiling >= 0.25) {
      return (ExpressionType.slightSmile, smiling);
    }

    return (ExpressionType.neutral, 1.0 - smiling);
  }

  // ── Guidance ───────────────────────────────────────────────────

  String? _guidance(ExpressionType expression) {
    switch (expression) {
      case ExpressionType.neutral:
        return '笑一个，会更自然哦';
      case ExpressionType.slightSmile:
        return '可以笑开一点，露出牙齿更好看';
      case ExpressionType.bigSmile:
        return null; // good — no guidance needed
      case ExpressionType.laugh:
        return null; // great — no guidance
      case ExpressionType.winking:
        return '眨眼抓拍到了！';
      case ExpressionType.eyesClosed:
        return '眼睛睁大一点，别闭眼';
    }
  }

  String _label(ExpressionType expression) {
    switch (expression) {
      case ExpressionType.neutral:
        return '自然';
      case ExpressionType.slightSmile:
        return '微笑';
      case ExpressionType.bigSmile:
        return '灿烂笑';
      case ExpressionType.laugh:
        return '大笑';
      case ExpressionType.winking:
        return '眨眼';
      case ExpressionType.eyesClosed:
        return '闭眼';
    }
  }

  // ── Helpers ────────────────────────────────────────────────────

  InputImage? _imageFromCamera(CameraImage image) {
    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: _rotation(image),
        format: InputImageFormat.nv21,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  InputImageRotation _rotation(CameraImage image) {
    // Camera orientation is typically 90deg for portrait on Android
    return InputImageRotation.rotation90deg;
  }

  Face? _largestFace(List<Face> faces) {
    if (faces.isEmpty) return null;
    Face? largest;
    double maxArea = 0;
    for (final face in faces) {
      final rect = face.boundingBox;
      final area = rect.width * rect.height;
      if (area > maxArea) {
        maxArea = area;
        largest = face;
      }
    }
    return largest;
  }
}
