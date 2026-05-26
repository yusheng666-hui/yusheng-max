import 'package:equatable/equatable.dart';

/// Scene analysis results sent to the cloud recommendation engine.
class SceneFeatures extends Equatable {
  final String sceneClass;
  final double sceneConfidence;
  final LightingInfo lighting;
  final SpatialInfo spatial;
  final List<String> colorPalette;
  final String timeOfDay;
  final String weather;
  final double crowdDensity;
  final List<double>? gps;

  const SceneFeatures({
    required this.sceneClass,
    required this.sceneConfidence,
    required this.lighting,
    required this.spatial,
    required this.colorPalette,
    required this.timeOfDay,
    required this.weather,
    required this.crowdDensity,
    this.gps,
  });

  Map<String, dynamic> toJson() => {
        'scene_class': sceneClass,
        'scene_confidence': sceneConfidence,
        'lighting': lighting.toJson(),
        'spatial': spatial.toJson(),
        'color_palette': colorPalette,
        'time_of_day': timeOfDay,
        'weather': weather,
        'crowd_density': crowdDensity,
        if (gps != null) 'gps': gps,
      };

  @override
  List<Object?> get props => [sceneClass, sceneConfidence];
}

class LightingInfo extends Equatable {
  final List<double> direction;
  final double intensity;
  final double colorTemp;
  final double contrastRatio;

  /// Light quality classification (hard / soft / diffused).
  final String? quality;

  /// Whether the subject is backlit.
  final bool? isBacklit;

  /// Severity of backlight [0.0–1.0].
  final double? backlightSeverity;

  const LightingInfo({
    required this.direction,
    required this.intensity,
    required this.colorTemp,
    required this.contrastRatio,
    this.quality,
    this.isBacklit,
    this.backlightSeverity,
  });

  Map<String, dynamic> toJson() => {
        'direction': direction,
        'intensity': intensity,
        'color_temp': colorTemp,
        'contrast_ratio': contrastRatio,
        if (quality != null) 'quality': quality,
        if (isBacklit != null) 'is_backlit': isBacklit,
        if (backlightSeverity != null) 'backlight_severity': backlightSeverity,
      };

  @override
  List<Object?> get props => [
        direction,
        intensity,
        colorTemp,
        contrastRatio,
        quality,
        isBacklit,
        backlightSeverity,
      ];
}

class SpatialInfo extends Equatable {
  final List<PlaneInfo> dominantPlanes;
  final List<double> depthRange;

  const SpatialInfo({
    required this.dominantPlanes,
    required this.depthRange,
  });

  Map<String, dynamic> toJson() => {
        'dominant_planes': dominantPlanes.map((p) => p.toJson()).toList(),
        'depth_range': depthRange,
      };

  @override
  List<Object?> get props => [dominantPlanes, depthRange];
}

class PlaneInfo extends Equatable {
  final String type;
  final List<double> center;
  final List<double> normal;

  const PlaneInfo({
    required this.type,
    required this.center,
    required this.normal,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'center': center,
        'normal': normal,
      };

  @override
  List<Object?> get props => [type, center, normal];
}
