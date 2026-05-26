import 'package:equatable/equatable.dart';
import 'pose.dart';

/// A single pose recommendation returned from the cloud engine.
class PoseRecommendation extends Equatable {
  final String poseId;
  final int rank;
  final double score;
  final String name;
  final String description;
  final Skeleton3D skeleton;
  final String guidanceText;
  final List<String> voiceGuidance;
  final List<double> standingPosition;
  final PhotographerAngle? photographerAngle;
  final CompositionHints? compositionHints;
  final String? lightingTip;
  final String? referenceImageUrl;
  final CameraParams? cameraParams;
  final List<String> styles;

  const PoseRecommendation({
    required this.poseId,
    required this.rank,
    required this.score,
    this.name = '',
    this.description = '',
    required this.skeleton,
    required this.guidanceText,
    required this.voiceGuidance,
    required this.standingPosition,
    this.photographerAngle,
    this.compositionHints,
    this.lightingTip,
    this.referenceImageUrl,
    this.cameraParams,
    this.styles = const [],
  });

  factory PoseRecommendation.fromJson(Map<String, dynamic> json) {
    final skData = json['skeleton_3d'] as Map<String, dynamic>? ?? {};
    final kpList = (skData['keypoints'] as List<dynamic>?)
            ?.map((k) => Keypoint(
                  id: (k['id'] as num?)?.toInt() ?? 0,
                  name: k['name'] as String? ?? '',
                  x: (k['x'] as num?)?.toDouble() ?? 0,
                  y: (k['y'] as num?)?.toDouble() ?? 0,
                  z: (k['z'] as num?)?.toDouble() ?? 0,
                  visibility: (k['visibility'] as num?)?.toDouble() ?? 1.0,
                ))
            .toList() ??
        [];

    CameraParams? camParams;
    if (json['camera_params'] != null) {
      camParams = CameraParams.fromJson(json['camera_params'] as Map<String, dynamic>);
    }

    return PoseRecommendation(
      poseId: json['pose_id'] as String? ?? '',
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      score: (json['score'] as num?)?.toDouble() ?? 0,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      skeleton: Skeleton3D(
        keypoints: kpList,
        anchorPoint: skData['anchor_point'] as String? ?? 'mid_hip',
      ),
      guidanceText: json['guidance_text'] as String? ?? '',
      voiceGuidance: (json['voice_guidance'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      standingPosition: (json['standing_position'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [0.0, 2.0, 0.0],
      lightingTip: json['lighting_tip'] as String?,
      referenceImageUrl: json['reference_image_url'] as String?,
      cameraParams: camParams,
      styles: (json['styles'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  @override
  List<Object?> get props => [poseId, rank, score, styles];
}

/// Camera parameters for beginner and advanced modes.
class CameraParams extends Equatable {
  final Map<String, dynamic> beginner;
  final Map<String, dynamic> advanced;
  final String? rationale;

  const CameraParams({
    required this.beginner,
    required this.advanced,
    this.rationale,
  });

  factory CameraParams.fromJson(Map<String, dynamic> json) {
    return CameraParams(
      beginner: json['beginner'] as Map<String, dynamic>? ?? {},
      advanced: json['advanced'] as Map<String, dynamic>? ?? {},
      rationale: json['rationale'] as String?,
    );
  }

  // Beginner getters
  String get beginnerMode => beginner['mode'] as String? ?? 'auto';
  String get beginnerHdr => beginner['hdr'] as String? ?? 'auto';
  String get beginnerFlash => beginner['flash'] as String? ?? 'off';

  // Advanced getters
  int get advancedIso => (advanced['iso'] as num?)?.toInt() ?? 100;
  String get advancedShutter => advanced['shutter_speed'] as String? ?? '1/250';
  double get advancedAperture => (advanced['aperture'] as num?)?.toDouble() ?? 5.6;
  double get advancedEv => (advanced['ev_compensation'] as num?)?.toDouble() ?? 0.0;
  int get advancedWb => (advanced['white_balance'] as num?)?.toInt() ?? 5000;
  String get advancedMetering => advanced['metering_mode'] as String? ?? 'matrix';
  String get advancedMeteringTarget => advanced['metering_target'] as String? ?? 'face';
  String get advancedFocusMode => advanced['focus_mode'] as String? ?? 'af-s';
  String get advancedFocusPoint => advanced['focus_point'] as String? ?? 'face';
  bool get advancedRaw => advanced['raw'] as bool? ?? false;
  String get advancedColorProfile => advanced['color_profile'] as String? ?? 'standard';

  @override
  List<Object?> get props => [beginner, advanced, rationale];
}

class PhotographerAngle extends Equatable {
  final double pitch;
  final double yaw;
  final String height;

  const PhotographerAngle({
    required this.pitch,
    required this.yaw,
    required this.height,
  });

  @override
  List<Object?> get props => [pitch, yaw, height];
}

class CompositionHints extends Equatable {
  final bool ruleOfThirdsGrid;
  final String alignment;

  const CompositionHints({
    required this.ruleOfThirdsGrid,
    required this.alignment,
  });

  @override
  List<Object?> get props => [ruleOfThirdsGrid, alignment];
}
