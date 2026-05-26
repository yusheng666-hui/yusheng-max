import 'package:equatable/equatable.dart';

/// Core pose data model shared across the app.
class Pose extends Equatable {
  final String id;
  final String nameZh;
  final Taxonomy taxonomy;
  final Skeleton3D skeleton;
  final Guidance guidance;
  final Suitability suitability;
  final String? referenceImageUrl;
  final double qualityScore;

  const Pose({
    required this.id,
    required this.nameZh,
    required this.taxonomy,
    required this.skeleton,
    required this.guidance,
    required this.suitability,
    this.referenceImageUrl,
    this.qualityScore = 0.0,
  });

  @override
  List<Object?> get props => [id, qualityScore];
}

class Taxonomy extends Equatable {
  final String personCount;
  final String bodyPosition;
  final List<String> style;
  final List<String> sceneType;
  final String difficulty;

  const Taxonomy({
    required this.personCount,
    required this.bodyPosition,
    required this.style,
    required this.sceneType,
    required this.difficulty,
  });

  @override
  List<Object?> get props => [personCount, bodyPosition, style, sceneType, difficulty];
}

class Skeleton3D extends Equatable {
  final List<Keypoint> keypoints;
  final String anchorPoint;

  const Skeleton3D({
    required this.keypoints,
    this.anchorPoint = 'mid_hip',
  });

  @override
  List<Object?> get props => [keypoints, anchorPoint];
}

class Keypoint extends Equatable {
  final int id;
  final String name;
  final double x;
  final double y;
  final double z;
  final double visibility;

  const Keypoint({
    required this.id,
    required this.name,
    required this.x,
    required this.y,
    required this.z,
    this.visibility = 1.0,
  });

  const Keypoint.empty()
      : id = 0,
        name = '',
        x = 0,
        y = 0,
        z = 0,
        visibility = 0;

  @override
  List<Object?> get props => [id, x, y, z, visibility];
}

class Guidance extends Equatable {
  final String modelTipsZh;
  final List<String> stepByStep;
  final List<String> voiceGuidance;
  final List<String> commonMistakes;

  const Guidance({
    required this.modelTipsZh,
    required this.stepByStep,
    required this.voiceGuidance,
    required this.commonMistakes,
  });

  @override
  List<Object?> get props => [modelTipsZh];
}

class Suitability extends Equatable {
  final List<String> bodyTypes;
  final List<String> clothing;
  final List<String> lighting;

  const Suitability({
    required this.bodyTypes,
    required this.clothing,
    required this.lighting,
  });

  @override
  List<Object?> get props => [bodyTypes, clothing, lighting];
}
