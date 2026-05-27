/// Offline recommendation engine — mirrors the Python backend logic in Dart.
///
/// Uses the local 300-pose database with the same scoring algorithm:
/// scene match (50) + style match (up to 25) + difficulty match (up to 10) +
/// quality bonus + MMR diversity re-ranking.

import 'dart:math';
import 'local_pose_loader.dart';
import 'recommendation_service.dart';
import '../../../../shared/models/recommendation.dart';
import '../../../../shared/models/pose.dart';

/// Scene class to internal key mapping.
/// Maps all TFLite 20-class labels and taxonomy poseDbKeys to the 6 internal
/// pose-DB keys used for matching.
const _sceneClassMap = <String, String>{
  'outdoor-nature': 'outdoor',
  'outdoor': 'outdoor',
  'urban-street': 'street',
  'street': 'street',
  'urban': 'street',
  'indoor': 'indoor',
  'indoor-cafe': 'indoor',
  'indoor-home': 'indoor',
  'beach': 'beach',
  'beach-coast': 'beach',
  'night-scene': 'night',
  'night': 'night',
  'night-neon': 'night',
  'mountain': 'outdoor',
  'lake-river': 'outdoor',
  'forest': 'outdoor',
  'garden-park': 'outdoor',
  'snow': 'outdoor',
  'sunset-sunrise': 'outdoor',
  'rainy-street': 'street',
  'neon-light': 'night',
  'library': 'indoor',
  'gym-fitness': 'indoor',
  'restaurant': 'indoor',
  'market-bazaar': 'street',
  'stadium': 'outdoor',
};

/// Style expansion map — user preference → matching pose styles.
const _styleMap = <String, List<String>>{
  'fresh': ['fresh', 'natural'],
  'cool': ['cool', 'elegant'],
  'sweet': ['sweet', 'fresh'],
  'elegant': ['elegant', 'cool'],
  'casual': ['casual', 'natural'],
  'natural': ['natural', 'casual'],
};

/// Offline recommendation engine using the local pose database.
class LocalRecommendationEngine {
  final LocalPoseLoader _loader;
  final Random _random = Random(42); // seed for reproducibility

  LocalRecommendationEngine(this._loader);

  bool get isReady => _loader.isLoaded;

  /// Recommend poses using the same algorithm as the Python backend.
  /// [category] filters by pose category: solo, couple, friends, family, expression, advanced_solo, or null for all.
  RecommendationResponse recommend({
    required String sceneClass,
    List<String> preferredStyles = const [],
    String preferredDifficulty = 'beginner',
    Set<String> skipPoseIds = const {},
    Set<String> likedPoseIds = const {},
    String? category,
    int topK = 5,
  }) {
    final sceneKey = _sceneClassMap[sceneClass] ?? 'outdoor';

    // Get candidates for this scene
    var candidates = _loader.getPosesForScene(sceneKey);

    // Fallback to outdoor if no poses for scene
    if (candidates.isEmpty) {
      candidates = _loader.getPosesForScene('outdoor');
    }
    if (candidates.isEmpty) {
      return const RecommendationResponse(
        requestId: 'local',
        recommendations: [],
      );
    }

    // Expand candidate pool from adjacent scenes if too few
    if (candidates.length < topK * 3) {
      final extra = <LocalPose>[];
      for (final key in _loader.posesByScene.keys) {
        if (key != sceneKey) {
          extra.addAll(_loader.posesByScene[key]!.take(5));
        }
      }
      candidates = [...candidates, ...extra];
    }

    // Score each candidate
    final scored = <_ScoredPose>[];
    for (final pose in candidates) {
      if (skipPoseIds.contains(pose.poseId)) continue;
      if (category != null && pose.category != category) continue;

      double score = 50.0; // base scene match

      // Style match (up to +25)
      if (preferredStyles.isNotEmpty) {
        int styleHits = 0;
        for (final ps in preferredStyles) {
          for (final s in (_styleMap[ps] ?? [ps])) {
            if (pose.style.contains(s)) {
              styleHits++;
            }
          }
        }
        score += min(styleHits * 8.0, 25.0);
      }

      // Difficulty match (up to +10)
      if (pose.difficulty == preferredDifficulty) {
        score += 10.0;
      } else if (pose.difficulty == 'beginner') {
        score += 5.0;
      }

      // Liked bonus (+10)
      if (likedPoseIds.contains(pose.poseId)) {
        score += 10.0;
      }

      // Quality score
      score += pose.qualityScore * 1.5;

      // Small random jitter for variety
      score += _random.nextDouble() * 6.0 - 3.0;

      scored.add(_ScoredPose(score, pose));
    }

    // Sort by score descending
    scored.sort((a, b) => b.score.compareTo(a.score));

    // MMR diversity re-ranking
    final selected = <_ScoredPose>[];
    final pool = scored.take(min(scored.length, topK * 6)).toList();

    for (int round = 0; round < topK && pool.isNotEmpty; round++) {
      if (selected.isEmpty) {
        selected.add(pool.removeAt(0));
      } else {
        int bestIdx = 0;
        double bestMmr = double.negativeInfinity;

        for (int i = 0; i < pool.length; i++) {
          final styleSet = pool[i].pose.style.toSet();
          double maxSim = 0;
          for (final s in selected) {
            final sSet = s.pose.style.toSet();
            final union = styleSet.union(sSet).length;
            final intersection = styleSet.intersection(sSet).length;
            if (union > 0) {
              maxSim = max(maxSim, intersection / union);
            }
          }
          final mmr = pool[i].score - 0.3 * maxSim * 100;
          if (mmr > bestMmr) {
            bestMmr = mmr;
            bestIdx = i;
          }
        }
        selected.add(pool.removeAt(bestIdx));
      }
    }

    // Convert to PoseRecommendation
    final recs = <PoseRecommendation>[];
    for (int i = 0; i < selected.length; i++) {
      recs.add(_toPoseRecommendation(selected[i], i + 1));
    }

    return RecommendationResponse(
      requestId: 'local-${DateTime.now().millisecondsSinceEpoch}',
      recommendations: recs,
      sceneDetected: sceneClass,
      totalCandidates: recs.length,
    );
  }

  /// Safely convert a dynamic value to Map<String, dynamic>.
  /// Handles both Map<String, dynamic> and Map<dynamic, dynamic> from
  /// json.decode / literal constructors, which are not subtypes of each other.
  static Map<String, dynamic> _safeMap(dynamic v) {
    if (v == null) return {};
    if (v is Map<String, dynamic>) return v;
    return (v as Map).cast<String, dynamic>();
  }

  /// Convert a scored local pose to a [PoseRecommendation].
  PoseRecommendation _toPoseRecommendation(_ScoredPose sp, int rank) {
    final raw = sp.pose.raw;
    final skData = _safeMap(raw['skeleton_3d']);
    final guidance = _safeMap(raw['guidance']);
    final cam = _safeMap(raw['camera_params']);
    final name = _safeMap(raw['name']);
    final desc = _safeMap(raw['description']);
    final photographerTips = _safeMap(guidance['photographer_tips']);

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

    return PoseRecommendation(
      poseId: sp.pose.poseId,
      rank: rank,
      score: double.parse(sp.score.toStringAsFixed(1)),
      name: name['zh'] as String? ?? sp.pose.poseId,
      description: desc['zh'] as String? ?? '',
      skeleton: Skeleton3D(
        keypoints: kpList,
        anchorPoint: skData['anchor_point'] as String? ?? 'mid_hip',
      ),
      guidanceText: photographerTips['zh'] as String? ?? '',
      voiceGuidance: (guidance['voice_guidance'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      standingPosition: [0.0, 2.0, 0.0],
      cameraParams: CameraParams.fromJson(cam),
      styles: sp.pose.style,
    );
  }
}

class _ScoredPose {
  final double score;
  final LocalPose pose;

  _ScoredPose(this.score, this.pose);
}
