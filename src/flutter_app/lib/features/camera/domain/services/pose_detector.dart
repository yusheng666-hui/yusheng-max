/// Service that wraps google_mlkit_pose_detection for real-time body keypoint detection.
///
/// Processes camera frames and emits detected [DetectedPose] objects containing
/// 33 MediaPipe-compatible keypoints. Supports multi-person detection (up to 5 poses).

import 'dart:async';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:camera/camera.dart';

/// Detected pose with 33 keypoints in normalized coordinates.
class DetectedPose {
  final List<DetectedKeypoint> keypoints;
  final DateTime timestamp;

  DetectedPose({required this.keypoints, required this.timestamp});

  /// Convert from ML Kit [Pose] to domain model.
  factory DetectedPose.fromMlKit(Pose pose) {
    return DetectedPose(
      keypoints: pose.landmarks.values
          .map((l) => DetectedKeypoint(
                type: l.type.index,
                x: l.x,
                y: l.y,
                z: l.z,
                likelihood: l.likelihood,
              ))
          .toList(),
      timestamp: DateTime.now(),
    );
  }

  /// Whether the pose is detected with sufficient confidence.
  bool get isReliable =>
      keypoints.where((k) => k.likelihood > 0.7).length >= 12;
}

/// A single detected keypoint.
class DetectedKeypoint {
  final int type; // PoseLandmarkType index
  final double x;
  final double y;
  final double z;
  final double likelihood;

  const DetectedKeypoint({
    required this.type,
    required this.x,
    required this.y,
    required this.z,
    required this.likelihood,
  });
}

/// Configuration for the pose detector.
class PoseDetectorConfig {
  final PoseDetectionMode mode;
  final int maxPoses;

  const PoseDetectorConfig({
    this.mode = PoseDetectionMode.stream,
    this.maxPoses = 5,
  });
}

/// Real-time pose detector that processes camera frames.
///
/// Usage:
/// ```dart
/// final detector = PoseDetector();
/// await detector.initialize();
/// detector.onPoseDetected = (pose) { /* render skeleton */ };
/// detector.processFrame(cameraImage);
/// ```
class PoseDetector {
  PoseDetector? _detector;
  final PoseDetectorConfig config;
  bool _isInitialized = false;
  bool _isProcessing = false;

  /// Callback fired when poses are detected from a frame.
  void Function(List<DetectedPose> poses)? onPosesDetected;

  PoseDetector({this.config = const PoseDetectorConfig()});

  bool get isInitialized => _isInitialized;

  /// Initialize the underlying ML Kit pose detector.
  Future<void> initialize() async {
    if (_isInitialized) return;

    _detector = PoseDetector(
      mode: config.mode,
      maxPoses: config.maxPoses,
    );
    _isInitialized = true;
  }

  /// Process a single camera frame for pose detection.
  /// Skips frame if already processing (non-blocking throttle).
  /// Returns list of detected poses (empty if none found).
  Future<List<DetectedPose>> processFrame(CameraImage image) async {
    if (!_isInitialized || _isProcessing) return [];
    _isProcessing = true;

    try {
      final inputImage = _cameraImageToInputImage(image);
      if (inputImage == null) return [];

      final poses = await _detector!.processImage(inputImage);

      if (poses.isNotEmpty) {
        final detected = poses.map((p) => DetectedPose.fromMlKit(p)).toList();
        onPosesDetected?.call(detected);
        return detected;
      }
      return [];
    } catch (e) {
      // Frame processing errors (e.g. invalid format) are non-fatal
      return [];
    } finally {
      _isProcessing = false;
    }
  }

  /// Convert camera image to ML Kit InputImage.
  InputImage? _cameraImageToInputImage(CameraImage image) {
    final rotation = InputImageRotationValue.fromRawValue(0) ??
        InputImageRotation.rotation0deg;

    final format = InputImageFormatValue.fromRawValue(image.format.raw) ??
        InputImageFormat.nv21;

    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  /// Release ML Kit resources.
  Future<void> dispose() async {
    _isInitialized = false;
    await _detector?.close();
    _detector = null;
  }
}
