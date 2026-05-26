/// Intelligent preset recommendation engine for post-shot color grading.
///
/// Combines scene type, lighting conditions, time of day, and user style
/// preferences to score all 10 built-in presets and return top-N matches
/// with human-readable recommendation reasons in Chinese.

import 'preset_loader.dart';
import '../../../../shared/models/preset.dart';
import '../../../camera/domain/services/lighting_analyzer.dart';

class PresetRecommendation {
  final Preset preset;
  final double score;
  final String reasonZh;

  const PresetRecommendation({
    required this.preset,
    required this.score,
    required this.reasonZh,
  });
}

class PresetRecommendationService {
  final PresetLoader _loader;

  PresetRecommendationService(this._loader);

  /// Recommend top-N presets for the current scene context.
  ///
  /// [sceneClass] — e.g. "outdoor-nature", "street", "night-scene"
  /// [lighting] — optional lighting analysis result at capture time
  /// [preferredStyles] — user's preferred style tags (from profile)
  /// [timeOfDay] — "golden-hour", "morning", "afternoon", "night", etc.
  /// [limit] — max presets to return (default 3)
  List<PresetRecommendation> recommend({
    required String sceneClass,
    LightingAnalysisResult? lighting,
    List<String> preferredStyles = const [],
    String timeOfDay = 'afternoon',
    int limit = 3,
  }) {
    final all = _loader.allPresets;
    if (all.isEmpty) return [];

    final lightingTag = _lightingToTag(lighting, timeOfDay);
    final scored = <_ScoredPreset>[];

    for (final preset in all) {
      double score = 0;
      final reasonParts = <String>[];

      // ── Scene match (weight: up to 30%) ──
      final sceneHits = _matchTags(sceneClass, preset.bestFor.sceneTypes);
      if (sceneHits.exact > 0) {
        score += 30;
        // Don't add "适合场景" reason — it's the baseline
      } else if (sceneHits.fuzzy > 0) {
        score += 15;
      } else if (preset.bestFor.sceneTypes.contains('all')) {
        score += 20;
      }

      // ── Lighting match (weight: up to 25%) ──
      if (lightingTag != null) {
        final lightHits = _matchTags(lightingTag, preset.bestFor.lighting);
        if (lightHits.exact > 0) {
          score += 25;
          if (lightingTag == 'golden-hour') {
            reasonParts.add('黄金时刻光线温暖，适合此预设');
          } else if (lightingTag == 'night' || lightingTag == 'low-light') {
            reasonParts.add('暗光环境下此预设能突出氛围');
          } else if (lightingTag == 'back-light') {
            reasonParts.add('逆光场景下此预设可保留暗部细节');
          }
        } else if (lightHits.fuzzy > 0) {
          score += 10;
        } else if (preset.bestFor.lighting.contains('all')) {
          score += 15;
        }
      }

      // ── Style match (weight: up to 20%) ──
      int styleHits = 0;
      for (final ps in preferredStyles) {
        if (preset.styleTags.contains(ps)) styleHits++;
        if (preset.bestFor.styles.contains(ps)) styleHits++;
      }
      score += (styleHits * 5).clamp(0, 20);
      if (styleHits >= 2) {
        reasonParts.add('符合你偏好的风格');
      }

      // ── Time-of-day bonus (weight: up to 15%) ──
      final todBonus = _timeOfDayBonus(timeOfDay, preset);
      score += todBonus.score;
      if (todBonus.reason != null) {
        reasonParts.add(todBonus.reason!);
      }

      // ── Popularity / quality bonus (weight: up to 10%) ──
      if (preset.metadata.avgRating >= 4.5) score += 10;
      else if (preset.metadata.avgRating >= 4.0) score += 6;
      else if (preset.metadata.avgRating >= 3.5) score += 3;

      // ── Category-specific bonus for portrait scenes ──
      if (sceneClass.contains('indoor') && preset.styleTags.contains('portrait')) {
        score += 10;
        reasonParts.add('室内人像场景，突出肤色质感');
      } else if ((sceneClass.contains('beach') || sceneClass.contains('outdoor')) &&
          preset.styleTags.contains('vivid')) {
        score += 8;
        reasonParts.add('户外风光场景，色彩鲜明更有层次');
      } else if (sceneClass.contains('night') && preset.styleTags.contains('moody')) {
        score += 10;
        reasonParts.add('夜景氛围，情绪感调色更出片');
      } else if (sceneClass.contains('street') &&
          (preset.styleTags.contains('vintage') || preset.styleTags.contains('film'))) {
        score += 8;
        reasonParts.add('街拍场景，胶片质感增添故事感');
      }

      // ── Build reason ──
      String reasonZh;
      if (reasonParts.isEmpty) {
        reasonZh = _defaultReason(preset, sceneClass);
      } else {
        reasonZh = reasonParts.join('，');
      }

      scored.add(_ScoredPreset(preset, score, reasonZh));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored
        .take(limit)
        .map((s) => PresetRecommendation(
              preset: s.preset,
              score: s.score,
              reasonZh: s.reason,
            ))
        .toList();
  }

  /// Map lighting analysis to a tag usable for preset matching.
  String? _lightingToTag(LightingAnalysisResult? lighting, String timeOfDay) {
    if (lighting == null) {
      // Fallback to time-of-day-based lighting assumption
      switch (timeOfDay) {
        case 'golden-hour':
          return 'golden-hour';
        case 'morning':
          return 'soft-light';
        case 'afternoon':
          return 'front-light';
        case 'night':
          return 'night';
        default:
          return null;
      }
    }

    if (lighting.backlight.isBacklit) return 'back-light';

    switch (lighting.quality) {
      case LightQualityType.soft:
        return 'soft-light';
      case LightQualityType.diffused:
        return 'overcast';
      case LightQualityType.hard:
        return 'hard-light';
    }
  }

  /// Score bonus based on time of day.
  _TodBonus _timeOfDayBonus(String timeOfDay, Preset preset) {
    final tags = preset.styleTags;
    final name = preset.name.zh;

    switch (timeOfDay) {
      case 'golden-hour':
        if (tags.contains('warm') || tags.contains('golden')) {
          return _TodBonus(15, '黄金时刻搭配暖调预设，光影氛围最佳');
        }
        if (tags.contains('vivid') || name.contains('HDR')) {
          return _TodBonus(10, '黄金时刻光线充足，HDR细节丰富');
        }
        return _TodBonus(5, null);

      case 'night':
        if (tags.contains('moody') || tags.contains('cool') || tags.contains('night')) {
          return _TodBonus(12, '夜景暗光，情绪调色营造氛围感');
        }
        if (tags.contains('black-and-white')) {
          return _TodBonus(10, '夜景黑白，去除杂色突出光影对比');
        }
        if (tags.contains('retro') || tags.contains('hong-kong')) {
          return _TodBonus(8, '夜景霓虹，港风预设与霓虹灯天然匹配');
        }
        return _TodBonus(3, null);

      case 'morning':
      case 'dawn':
        if (tags.contains('fresh') || tags.contains('airy') || tags.contains('clean')) {
          return _TodBonus(12, '清晨光线柔和，清新调色更显通透');
        }
        if (tags.contains('soft')) {
          return _TodBonus(8, '晨光柔和，低对比预设保留氛围');
        }
        return _TodBonus(4, null);

      case 'afternoon':
        if (tags.contains('vivid') || tags.contains('bright')) {
          return _TodBonus(8, '午后阳光强烈，鲜艳预设可平衡曝光');
        }
        if (tags.contains('vintage') || tags.contains('faded')) {
          return _TodBonus(6, '午后强光下褪色预设减少刺眼感');
        }
        return _TodBonus(2, null);

      default:
        return _TodBonus(0, null);
    }
  }

  String _defaultReason(Preset preset, String sceneClass) {
    final name = preset.name.zh;
    final tags = preset.styleTags.take(3).join('、');
    return '「$name」预设（$tags）适合当前场景，试试看效果';
  }
}

class _TagMatch {
  final int exact;
  final int fuzzy;
  const _TagMatch(this.exact, this.fuzzy);
}

_TagMatch _matchTags(String target, List<String> candidates) {
  int exact = 0;
  int fuzzy = 0;
  for (final c in candidates) {
    if (c == 'all') continue; // handled by caller
    if (c == target) {
      exact++;
    } else if (target.contains(c) || c.contains(target)) {
      fuzzy++;
    }
  }
  return _TagMatch(exact, fuzzy);
}

class _ScoredPreset {
  final Preset preset;
  final double score;
  final String reason;
  _ScoredPreset(this.preset, this.score, this.reason);
}

class _TodBonus {
  final double score;
  final String? reason;
  _TodBonus(this.score, this.reason);
}
