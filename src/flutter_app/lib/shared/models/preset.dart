/// Preset data models for the post-processing LUT engine.
///
/// Mirrors the JSON schema produced by generate_presets.py.

import 'dart:ui' as ui;

class PresetName {
  final String zh;
  final String en;

  const PresetName({required this.zh, required this.en});

  factory PresetName.fromJson(Map<String, dynamic> json) {
    return PresetName(
      zh: json['zh'] as String? ?? '',
      en: json['en'] as String? ?? '',
    );
  }
}

class LutFiles {
  final String cube33;
  final String hald8;

  const LutFiles({required this.cube33, required this.hald8});

  factory LutFiles.fromJson(Map<String, dynamic> json) {
    return LutFiles(
      cube33: json['cube_33'] as String? ?? '',
      hald8: json['hald_8'] as String? ?? '',
    );
  }
}

class PresetAdjustments {
  final double exposure;
  final double contrast;
  final double highlights;
  final double shadows;
  final double whites;
  final double blacks;
  final double saturation;
  final double vibrance;
  final double temperature;
  final double tint;
  final double sharpness;
  final double noiseReduction;
  final double vignette;
  final double grain;

  const PresetAdjustments({
    this.exposure = 0,
    this.contrast = 0,
    this.highlights = 0,
    this.shadows = 0,
    this.whites = 0,
    this.blacks = 0,
    this.saturation = 0,
    this.vibrance = 0,
    this.temperature = 0,
    this.tint = 0,
    this.sharpness = 0,
    this.noiseReduction = 0,
    this.vignette = 0,
    this.grain = 0,
  });

  factory PresetAdjustments.fromJson(Map<String, dynamic> json) {
    return PresetAdjustments(
      exposure: (json['exposure'] as num?)?.toDouble() ?? 0,
      contrast: (json['contrast'] as num?)?.toDouble() ?? 0,
      highlights: (json['highlights'] as num?)?.toDouble() ?? 0,
      shadows: (json['shadows'] as num?)?.toDouble() ?? 0,
      whites: (json['whites'] as num?)?.toDouble() ?? 0,
      blacks: (json['blacks'] as num?)?.toDouble() ?? 0,
      saturation: (json['saturation'] as num?)?.toDouble() ?? 0,
      vibrance: (json['vibrance'] as num?)?.toDouble() ?? 0,
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0,
      tint: (json['tint'] as num?)?.toDouble() ?? 0,
      sharpness: (json['sharpness'] as num?)?.toDouble() ?? 0,
      noiseReduction: (json['noise_reduction'] as num?)?.toDouble() ?? 0,
      vignette: (json['vignette'] as num?)?.toDouble() ?? 0,
      grain: (json['grain'] as num?)?.toDouble() ?? 0,
    );
  }
}

class PresetBestFor {
  final List<String> sceneTypes;
  final List<String> lighting;
  final List<String> skinTones;
  final List<String> styles;

  const PresetBestFor({
    this.sceneTypes = const [],
    this.lighting = const [],
    this.skinTones = const [],
    this.styles = const [],
  });

  factory PresetBestFor.fromJson(Map<String, dynamic> json) {
    return PresetBestFor(
      sceneTypes: (json['scene_types'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      lighting: (json['lighting'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      skinTones: (json['skin_tones'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      styles: (json['styles'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}

class PresetMetadata {
  final String author;
  final String createdAt;
  final int usageCount;
  final double avgRating;
  final bool isPremium;
  final double? price;

  const PresetMetadata({
    this.author = '',
    this.createdAt = '',
    this.usageCount = 0,
    this.avgRating = 0,
    this.isPremium = false,
    this.price,
  });

  factory PresetMetadata.fromJson(Map<String, dynamic> json) {
    return PresetMetadata(
      author: json['author'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
      usageCount: json['usage_count'] as int? ?? 0,
      avgRating: (json['avg_rating'] as num?)?.toDouble() ?? 0,
      isPremium: json['is_premium'] as bool? ?? false,
      price: (json['price'] as num?)?.toDouble(),
    );
  }
}

class Preset {
  final String presetId;
  final PresetName name;
  final int version;
  final String status;
  final String category;
  final List<String> styleTags;
  final LutFiles lutFiles;
  final PresetAdjustments adjustments;
  final PresetBestFor bestFor;
  final String previewImage;
  final PresetMetadata metadata;

  /// Cached Hald CLUT image for GPU/CPU application.
  ui.Image? haldImage;

  Preset({
    required this.presetId,
    required this.name,
    this.version = 1,
    this.status = 'published',
    this.category = 'style',
    this.styleTags = const [],
    required this.lutFiles,
    required this.adjustments,
    required this.bestFor,
    this.previewImage = '',
    this.metadata = const PresetMetadata(),
    this.haldImage,
  });

  factory Preset.fromJson(Map<String, dynamic> json) {
    return Preset(
      presetId: json['preset_id'] as String? ?? '',
      name: PresetName.fromJson(
          (json['name'] as Map<String, dynamic>?) ?? {}),
      version: json['version'] as int? ?? 1,
      status: json['status'] as String? ?? 'published',
      category: json['category'] as String? ?? 'style',
      styleTags: (json['style_tags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      lutFiles: LutFiles.fromJson(
          (json['lut_files'] as Map<String, dynamic>?) ?? {}),
      adjustments: PresetAdjustments.fromJson(
          (json['adjustments'] as Map<String, dynamic>?) ?? {}),
      bestFor: PresetBestFor.fromJson(
          (json['best_for'] as Map<String, dynamic>?) ?? {}),
      previewImage: json['preview_image'] as String? ?? '',
      metadata: PresetMetadata.fromJson(
          (json['metadata'] as Map<String, dynamic>?) ?? {}),
    );
  }
}

class PresetBundle {
  final int version;
  final String generatedAt;
  final int totalPresets;
  final List<Preset> presets;

  const PresetBundle({
    this.version = 1,
    this.generatedAt = '',
    this.totalPresets = 0,
    this.presets = const [],
  });

  factory PresetBundle.fromJson(Map<String, dynamic> json) {
    return PresetBundle(
      version: json['version'] as int? ?? 1,
      generatedAt: json['generated_at'] as String? ?? '',
      totalPresets: json['total_presets'] as int? ?? 0,
      presets: (json['presets'] as List<dynamic>?)
              ?.map((p) => Preset.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
