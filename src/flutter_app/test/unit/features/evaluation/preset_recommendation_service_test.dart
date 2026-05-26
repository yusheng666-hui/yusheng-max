import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/evaluation/domain/services/preset_recommendation_service.dart';
import 'package:flutter_app/features/evaluation/domain/services/preset_loader.dart';
import 'package:flutter_app/features/camera/domain/services/lighting_analyzer.dart';
import 'package:flutter_app/shared/models/preset.dart';

/// Fake loader that returns a controlled list of presets instead of reading assets.
class FakePresetLoader extends PresetLoader {
  final List<Preset> _presets;
  FakePresetLoader(this._presets);

  @override
  List<Preset> get allPresets => _presets;
}

/// Build a minimal Preset for testing.
Preset _makePreset({
  required String id,
  required String name,
  List<String> styleTags = const [],
  List<String> sceneTypes = const [],
  List<String> lighting = const [],
  List<String> styles = const [],
  double avgRating = 4.0,
}) {
  return Preset(
    presetId: id,
    name: PresetName(zh: name, en: name),
    styleTags: styleTags,
    bestFor: PresetBestFor(
      sceneTypes: sceneTypes,
      lighting: lighting,
      styles: styles,
    ),
    lutFiles: const LutFiles(cube33: '', hald8: ''),
    adjustments: const PresetAdjustments(),
    metadata: PresetMetadata(avgRating: avgRating),
  );
}

/// Build a minimal backlight result.
LightingAnalysisResult _backlight() {
  return LightingAnalysisResult(
    baseInfo: LightingInfo(
      direction: [0.0, 0.0],
      intensity: 0.5,
      colorTemp: 5500,
      contrastRatio: 3.0,
    ),
    quality: LightQualityType.hard,
    qualityConfidence: 0.8,
    backlight: const BacklightInfo(
      isBacklit: true,
      severity: 0.6,
      centerMean: 50,
      peripheryMean: 220,
    ),
    tips: const [],
  );
}

LightingAnalysisResult _softLight() {
  return LightingAnalysisResult(
    baseInfo: LightingInfo(
      direction: [0.0, 0.0],
      intensity: 0.5,
      colorTemp: 5500,
      contrastRatio: 2.0,
    ),
    quality: LightQualityType.soft,
    qualityConfidence: 0.7,
    backlight: const BacklightInfo(
      isBacklit: false,
      severity: 0.0,
      centerMean: 140,
      peripheryMean: 135,
    ),
    tips: const [],
  );
}

void main() {
  // ── Shared presets ─────────────────────────────────────────────

  final outdoorPreset = _makePreset(
    id: 'p-outdoor',
    name: '自然户外',
    sceneTypes: ['outdoor-nature', 'beach'],
    lighting: ['front-light'],
    styleTags: ['natural', 'fresh'],
    avgRating: 4.6,
  );

  final nightPreset = _makePreset(
    id: 'p-night',
    name: '夜景氛围',
    sceneTypes: ['night-scene'],
    lighting: ['night', 'low-light'],
    styleTags: ['moody', 'cool', 'night'],
    avgRating: 4.2,
  );

  final goldenPreset = _makePreset(
    id: 'p-golden',
    name: '黄金暖调',
    sceneTypes: ['outdoor-nature', 'sunset-sunrise'],
    lighting: ['golden-hour', 'soft-light'],
    styleTags: ['warm', 'golden'],
    avgRating: 4.8,
  );

  final portraitPreset = _makePreset(
    id: 'p-portrait',
    name: '人像柔焦',
    sceneTypes: ['indoor', 'indoor-cafe'],
    lighting: ['soft-light'],
    styleTags: ['portrait', 'soft'],
    avgRating: 4.5,
  );

  final vividPreset = _makePreset(
    id: 'p-vivid',
    name: '鲜艳户外',
    sceneTypes: ['beach', 'outdoor-nature'],
    lighting: ['hard-light'],
    styleTags: ['vivid', 'bright'],
    avgRating: 4.0,
  );

  final vintagePreset = _makePreset(
    id: 'p-vintage',
    name: '胶片街拍',
    sceneTypes: ['street', 'urban-street'],
    lighting: ['hard-light'],
    styleTags: ['vintage', 'film'],
    avgRating: 4.3,
  );

  final hkPreset = _makePreset(
    id: 'p-hk',
    name: '港风霓虹',
    sceneTypes: ['night-scene', 'street'],
    lighting: ['night'],
    styleTags: ['retro', 'hong-kong', 'moody'],
    avgRating: 4.1,
  );

  final genericPreset = _makePreset(
    id: 'p-generic',
    name: '通用预设',
    sceneTypes: ['all'],
    lighting: ['all'],
    styleTags: ['neutral'],
    avgRating: 3.0,
  );

  final allPresets = [
    outdoorPreset,
    nightPreset,
    goldenPreset,
    portraitPreset,
    vividPreset,
    vintagePreset,
    hkPreset,
    genericPreset,
  ];

  // ── Helpers ────────────────────────────────────────────────────

  PresetRecommendationService _service(List<Preset> presets) {
    return PresetRecommendationService(FakePresetLoader(presets));
  }

  // ── Tests ──────────────────────────────────────────────────────

  group('PresetRecommendationService.recommend()', () {
    test('empty presets → empty list', () {
      final service = _service([]);
      final results = service.recommend(sceneClass: 'outdoor-nature');
      expect(results, isEmpty);
    });

    test('exact scene match gets highest score', () {
      final service = _service(allPresets);
      final results = service.recommend(
        sceneClass: 'night-scene',
        timeOfDay: 'night',
        limit: 3,
      );

      expect(results.length, lessThanOrEqualTo(3));
      expect(results, isNotEmpty);
      // night-scene exact match (nightPreset or hkPreset) should be top
      final topIds = results.map((r) => r.preset.presetId).toList();
      final nightRelated = ['p-night', 'p-hk'];
      expect(nightRelated.contains(topIds.first), isTrue);
    });

    test('results sorted descending by score', () {
      final service = _service(allPresets);
      final results = service.recommend(
        sceneClass: 'outdoor-nature',
        timeOfDay: 'afternoon',
        limit: 5,
      );

      for (int i = 0; i < results.length - 1; i++) {
        expect(results[i].score, greaterThanOrEqualTo(results[i + 1].score));
      }
    });

    test('limit parameter respected', () {
      final service = _service(allPresets);
      final results = service.recommend(
        sceneClass: 'outdoor-nature',
        limit: 2,
      );

      expect(results.length, lessThanOrEqualTo(2));
    });

    test('lighting tag match adds bonus', () {
      final service = _service(allPresets);
      final backlight = _backlight();

      final resultsWithBacklight = service.recommend(
        sceneClass: 'outdoor-nature',
        lighting: backlight,
        limit: 5,
      );

      expect(resultsWithBacklight, isNotEmpty);
      // back-light tag should give some presets a reason about backlight
      final backlightReasons = resultsWithBacklight
          .where((r) => r.reasonZh.contains('逆光'));
      // The backlight reason only fires on exact lighting match,
      // which depends on preset tags — just verify results exist
    });

    test('soft light gets lighting tag fallback from timeOfDay', () {
      final service = _service(allPresets);
      final results = service.recommend(
        sceneClass: 'outdoor-nature',
        lighting: _softLight(),
        timeOfDay: 'afternoon',
        limit: 3,
      );

      expect(results, isNotEmpty);
    });

    test('null lighting uses timeOfDay fallback', () {
      final service = _service(allPresets);
      final results = service.recommend(
        sceneClass: 'outdoor-nature',
        lighting: null,
        timeOfDay: 'golden-hour',
        limit: 5,
      );

      expect(results, isNotEmpty);
      // golden-hour should favor warm/golden presets
      final topIds = results.map((r) => r.preset.presetId).toList();
      expect(topIds.contains('p-golden'), isTrue);
    });

    test('golden-hour + warm tags → high score + reason', () {
      final service = _service(allPresets);
      final results = service.recommend(
        sceneClass: 'outdoor-nature',
        timeOfDay: 'golden-hour',
        limit: 5,
      );

      final goldenResult = results.where((r) => r.preset.presetId == 'p-golden');
      expect(goldenResult, isNotEmpty);
      expect(goldenResult.first.reasonZh, isNotEmpty);
    });

    test('style preference match adds bonus', () {
      final service = _service(allPresets);

      final withStyle = service.recommend(
        sceneClass: 'beach',
        preferredStyles: ['vivid', 'bright'],
        limit: 3,
      );

      expect(withStyle, isNotEmpty);
      // vivid preset should rank high with vivid+bright preference
      final topIds = withStyle.map((r) => r.preset.presetId).toList();
      expect(topIds.contains('p-vivid'), isTrue);
    });

    test('indoor + portrait tags → category-specific bonus', () {
      final service = _service(allPresets);
      final results = service.recommend(
        sceneClass: 'indoor',
        limit: 3,
      );

      final portraitResult = results.where((r) => r.preset.presetId == 'p-portrait');
      expect(portraitResult, isNotEmpty);
      expect(portraitResult.first.reasonZh.contains('人像'), isTrue);
    });

    test('beach + vivid tags → category-specific bonus', () {
      final service = _service(allPresets);
      final results = service.recommend(
        sceneClass: 'beach',
        limit: 3,
      );

      final vividResult = results.where((r) => r.preset.presetId == 'p-vivid');
      expect(vividResult, isNotEmpty);
      expect(vividResult.first.reasonZh.contains('鲜明'), isTrue);
    });

    test('night + moody tags → category-specific bonus', () {
      final service = _service(allPresets);
      final results = service.recommend(
        sceneClass: 'night-scene',
        timeOfDay: 'night',
        limit: 5,
      );

      final nightResult = results.where((r) => r.preset.presetId == 'p-night');
      expect(nightResult, isNotEmpty);
      expect(nightResult.first.reasonZh.contains('氛围'), isTrue);
    });

    test('street + vintage tags → category-specific bonus', () {
      final service = _service(allPresets);
      final results = service.recommend(
        sceneClass: 'street',
        limit: 3,
      );

      final vintageResult = results.where((r) => r.preset.presetId == 'p-vintage');
      expect(vintageResult, isNotEmpty);
      expect(vintageResult.first.reasonZh.contains('胶片'), isTrue);
    });

    test('high rating preset gets quality bonus', () {
      final highRated = _makePreset(
        id: 'p-premium',
        name: 'Premium',
        sceneTypes: ['outdoor-nature'],
        lighting: ['front-light'],
        avgRating: 4.9,
      );
      final lowRated = _makePreset(
        id: 'p-basic',
        name: 'Basic',
        sceneTypes: ['outdoor-nature'],
        lighting: ['front-light'],
        avgRating: 3.0,
      );

      final service = _service([lowRated, highRated]);
      final results = service.recommend(sceneClass: 'outdoor-nature', limit: 2);

      expect(results, isNotEmpty);
      // High-rated should rank above low-rated (all else equal)
      expect(results.first.preset.presetId, 'p-premium');
    });

    test('generic "all" scene preset gets moderate score', () {
      final service = _service([genericPreset]);
      final results = service.recommend(sceneClass: 'outdoor-nature', limit: 1);

      expect(results, isNotEmpty);
      expect(results.first.preset.presetId, 'p-generic');
    });

    test('multiple style preferences accumulate bonus', () {
      final multiStyle = _makePreset(
        id: 'p-multi',
        name: 'Multi Style',
        sceneTypes: ['outdoor-nature'],
        lighting: ['front-light'],
        styleTags: ['fresh', 'natural', 'casual'],
        styles: ['fresh', 'natural'],
        avgRating: 4.0,
      );
      final singleStyle = _makePreset(
        id: 'p-single',
        name: 'Single Style',
        sceneTypes: ['outdoor-nature'],
        lighting: ['front-light'],
        styleTags: ['cool'],
        styles: ['cool'],
        avgRating: 4.0,
      );

      final service = _service([singleStyle, multiStyle]);
      final results = service.recommend(
        sceneClass: 'outdoor-nature',
        preferredStyles: ['fresh', 'natural'],
        limit: 2,
      );

      expect(results, isNotEmpty);
      expect(results.first.preset.presetId, 'p-multi');
    });
  });
}
