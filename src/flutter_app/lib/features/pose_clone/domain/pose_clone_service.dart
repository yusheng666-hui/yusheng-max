/// Static-image pose detector for the clone feature.
///
/// Runs ML Kit PoseDetection on a single image file and converts
/// the detected landmarks into the app's Skeleton3D / Keypoint format.

import 'dart:typed_data';
import 'dart:io';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart' as mlkit;
import '../../../shared/models/pose.dart';

/// Mapping from ML Kit PoseLandmarkType index to human-readable keypoint name.
const _landmarkNames = {
  0: 'nose', 1: 'left_eye_inner', 2: 'left_eye', 3: 'left_eye_outer',
  4: 'right_eye_inner', 5: 'right_eye', 6: 'right_eye_outer',
  7: 'left_ear', 8: 'right_ear', 9: 'mouth_left', 10: 'mouth_right',
  11: 'left_shoulder', 12: 'right_shoulder', 13: 'left_elbow', 14: 'right_elbow',
  15: 'left_wrist', 16: 'right_wrist', 17: 'left_pinky', 18: 'right_pinky',
  19: 'left_index', 20: 'right_index', 21: 'left_thumb', 22: 'right_thumb',
  23: 'left_hip', 24: 'right_hip', 25: 'left_knee', 26: 'right_knee',
  27: 'left_ankle', 28: 'right_ankle', 29: 'left_heel', 30: 'right_heel',
  31: 'left_foot_index', 32: 'right_foot_index',
};

/// Result of cloning a pose from a static photo.
class CloneResult {
  final Uint8List imageBytes;
  final Skeleton3D skeleton;
  final double confidence; // fraction of keypoints with likelihood > 0.5

  const CloneResult({
    required this.imageBytes,
    required this.skeleton,
    required this.confidence,
  });
}

class PoseCloneService {
  mlkit.PoseDetector? _detector;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _detector = mlkit.PoseDetector(
      options: mlkit.PoseDetectorOptions(
        poseDetectionMode: mlkit.PoseDetectionMode.stream,
      ),
    );
    _initialized = true;
  }

  /// Detect pose from a static image file, returning skeleton + confidence.
  Future<CloneResult?> detectFromFile(String filePath) async {
    if (!_initialized) await initialize();

    try {
      final inputImage = mlkit.InputImage.fromFilePath(filePath);
      final poses = await _detector!.processImage(inputImage);

      if (poses.isEmpty) return null;

      final pose = poses.first;
      final keypoints = <Keypoint>[];
      int reliableCount = 0;

      for (final lm in pose.landmarks.values) {
        final reliable = lm.likelihood > 0.5;
        if (reliable) reliableCount++;
        keypoints.add(Keypoint(
          id: lm.type.index,
          name: _landmarkNames[lm.type.index] ?? 'unknown',
          x: lm.x,
          y: lm.y,
          z: lm.z,
          visibility: lm.likelihood,
        ));
      }

      final confidence = keypoints.isNotEmpty
          ? reliableCount / keypoints.length
          : 0.0;

      final skeleton = Skeleton3D(keypoints: keypoints, anchorPoint: 'mid_hip');

      final imageBytes = await File(filePath).readAsBytes();

      return CloneResult(
        imageBytes: imageBytes,
        skeleton: skeleton,
        confidence: confidence,
      );
    } catch (e) {
      print('PoseCloneService: detection failed — $e');
      return null;
    }
  }

  /// Convert a Skeleton3D to JSON for persistence.
  static Map<String, dynamic> skeletonToJson(Skeleton3D sk) {
    return {
      'keypoints': sk.keypoints.map((kp) => {
        'id': kp.id,
        'name': kp.name,
        'x': kp.x,
        'y': kp.y,
        'z': kp.z,
        'visibility': kp.visibility,
      }).toList(),
      'anchor_point': sk.anchorPoint,
    };
  }

  /// Restore a Skeleton3D from persisted JSON.
  static Skeleton3D skeletonFromJson(Map<String, dynamic> json) {
    return Skeleton3D(
      keypoints: (json['keypoints'] as List<dynamic>?)
              ?.map((kp) => Keypoint(
                    id: (kp['id'] as num?)?.toInt() ?? 0,
                    name: kp['name'] as String? ?? '',
                    x: (kp['x'] as num?)?.toDouble() ?? 0,
                    y: (kp['y'] as num?)?.toDouble() ?? 0,
                    z: (kp['z'] as num?)?.toDouble() ?? 0,
                    visibility: (kp['visibility'] as num?)?.toDouble() ?? 1.0,
                  ))
              .toList() ??
          [],
      anchorPoint: json['anchor_point'] as String? ?? 'mid_hip',
    );
  }

  Future<void> dispose() async {
    _initialized = false;
    await _detector?.close();
    _detector = null;
  }
}
