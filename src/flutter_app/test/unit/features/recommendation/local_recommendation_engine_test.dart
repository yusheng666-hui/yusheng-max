import 'package:flutter_test/flutter_test.dart';
import 'package:pose_craft/features/recommendation/domain/services/local_recommendation_engine.dart';
import 'package:pose_craft/features/recommendation/domain/services/local_pose_loader.dart';

/// Build a minimal [LocalPose] for testing.
LocalPose _makePose({
  required String id,
  required String sceneKey,
  List<String> style = const [],
  String difficulty = 'beginner',
  double qualityScore = 4.0,
  String category = 'solo',
}) {
  return LocalPose(
    poseId: id,
    sceneKey: sceneKey,
    bodyPosition: 'standing',
    subPosition: '',
    style: style,
    difficulty: difficulty,
    qualityScore: qualityScore,
    expression: const [],
    category: category,
    personCount: 1,
    raw: {
      'pose_id': id,
      'name': {'zh': id, 'en': id},
      'taxonomy': {
        'scene_type': [sceneKey],
        'style': style,
        'difficulty': difficulty,
        'category': category,
      },
      'skeleton_3d': {
        'keypoints': [],
        'anchor_point': 'mid_hip',
      },
      'description': {'zh': ''},
      'guidance': {'zh': ''},
      'camera_params': {},
    },
  );
}

/// Fake loader with pre-populated poses.
class FakeLocalPoseLoader extends LocalPoseLoader {
  final Map<String, List<LocalPose>> _byScene;

  FakeLocalPoseLoader(this._byScene);

  @override
  Map<String, List<LocalPose>> get posesByScene => _byScene;

  @override
  bool get isLoaded => true;

  @override
  List<LocalPose> getPosesForScene(String sceneKey) {
    return _byScene[sceneKey] ?? _byScene['outdoor'] ?? [];
  }
}

void main() {
  // ── Shared test data ────────────────────────────────────────────

  final outdoorPoses = [
    _makePose(id: 'out-1', sceneKey: 'outdoor', style: ['fresh', 'natural'], difficulty: 'beginner', qualityScore: 4.5),
    _makePose(id: 'out-2', sceneKey: 'outdoor', style: ['cool', 'elegant'], difficulty: 'intermediate', qualityScore: 4.0),
    _makePose(id: 'out-3', sceneKey: 'outdoor', style: ['casual', 'natural'], difficulty: 'beginner', qualityScore: 3.5),
    _makePose(id: 'out-4', sceneKey: 'outdoor', style: ['sweet', 'fresh'], difficulty: 'advanced', qualityScore: 4.2),
    _makePose(id: 'out-5', sceneKey: 'outdoor', style: ['fresh', 'casual'], difficulty: 'beginner', qualityScore: 4.8),
  ];

  final streetPoses = [
    _makePose(id: 'str-1', sceneKey: 'street', style: ['cool', 'vintage'], difficulty: 'intermediate', qualityScore: 4.3),
  ];

  final indoorPoses = [
    _makePose(id: 'ind-1', sceneKey: 'indoor', style: ['sweet', 'casual'], difficulty: 'beginner', category: 'couple', qualityScore: 4.1),
  ];

  final sceneMap = <String, List<LocalPose>>{
    'outdoor': outdoorPoses,
    'street': streetPoses,
    'indoor': indoorPoses,
  };

  LocalRecommendationEngine _engine() {
    return LocalRecommendationEngine(FakeLocalPoseLoader(sceneMap));
  }

  // ── Tests ──────────────────────────────────────────────────────

  group('LocalRecommendationEngine.recommend()', () {
    test('DEBUG: dump internal state', () {
      // Verify the fake loader works
      final loader = FakeLocalPoseLoader(sceneMap);
      final directPoses = loader.getPosesForScene('outdoor');
      if (directPoses.isEmpty) {
        fail('FakeLoader.getPosesForScene("outdoor") returned empty. '
            'sceneMap keys: ${sceneMap.keys}, '
            'outdoor entry: ${sceneMap["outdoor"]?.length} poses, '
            'loader.isLoaded=${loader.isLoaded}, '
            'loader.posesByScene.keys=${loader.posesByScene.keys}');
      }

      final engine = LocalRecommendationEngine(loader);
      final response = engine.recommend(sceneClass: 'outdoor-nature', topK: 3);
      if (response.recommendations.isEmpty) {
        fail('recommend returned empty. '
            'totalCandidates=${response.totalCandidates}, '
            'sceneDetected=${response.sceneDetected}, '
            'isReady=${engine.isReady}, '
            'directPosesFromLoader=${directPoses.length}');
      }
      expect(response.recommendations, isNotEmpty);
    });

    test('returns results for scene with poses', () {
      final engine = _engine();
      final response = engine.recommend(sceneClass: 'outdoor-nature', topK: 3);

      expect(response.recommendations, isNotEmpty);
      expect(response.recommendations.length, lessThanOrEqualTo(3));
      expect(response.sceneDetected, 'outdoor-nature');
    });

    test('falls back to outdoor for unknown scene', () {
      final engine = _engine();
      final response = engine.recommend(sceneClass: 'mountain', topK: 3);

      expect(response.recommendations, isNotEmpty);
      // mountain maps to outdoor via _sceneClassMap
    });

    test('returns empty for no matching poses and no outdoor fallback', () {
      final emptyLoader = FakeLocalPoseLoader(<String, List<LocalPose>>{});
      final engine = LocalRecommendationEngine(emptyLoader);
      final response = engine.recommend(sceneClass: 'outdoor-nature', topK: 3);

      expect(response.recommendations, isEmpty);
    });

    test('skipPoseIds filters out poses', () {
      final engine = _engine();
      final allResults = engine.recommend(sceneClass: 'outdoor-nature', topK: 5);

      if (allResults.recommendations.length > 1) {
        final skipId = allResults.recommendations.first.poseId;
        final filtered = engine.recommend(
          sceneClass: 'outdoor-nature',
          topK: 5,
          skipPoseIds: {skipId},
        );

        final filteredIds = filtered.recommendations.map((r) => r.poseId).toSet();
        expect(filteredIds.contains(skipId), isFalse);
      }
    });

    test('category filter works', () {
      final engine = _engine();
      final coupleResults = engine.recommend(
        sceneClass: 'indoor',
        category: 'couple',
        topK: 3,
      );

      expect(coupleResults.recommendations, isNotEmpty);
      for (final r in coupleResults.recommendations) {
        expect(r.poseId, startsWith('ind-'));
      }
    });

    test('category filter returns empty when no match', () {
      final engine = _engine();
      final results = engine.recommend(
        sceneClass: 'outdoor-nature',
        category: 'couple',
        topK: 3,
      );

      // outdoor poses are all 'solo', so couple filter should yield empty
      expect(results.recommendations, isEmpty);
    });

    test('style preference boosts matching poses', () {
      final engine = _engine();

      final withFresh = engine.recommend(
        sceneClass: 'outdoor-nature',
        preferredStyles: ['fresh'],
        topK: 5,
      );

      expect(withFresh.recommendations, isNotEmpty);
      // top result should have 'fresh' in its styles
      final topStyles = withFresh.recommendations.first.styles;
      expect(topStyles.any((s) => s.contains('fresh')), isTrue);
    });

    test('difficulty match adds bonus', () {
      final engine = _engine();

      final beginnerResults = engine.recommend(
        sceneClass: 'outdoor-nature',
        preferredDifficulty: 'beginner',
        topK: 5,
      );

      expect(beginnerResults.recommendations, isNotEmpty);
    });

    test('likedPoseIds boosts those poses', () {
      final engine = _engine();
      final likedId = 'out-5'; // highest quality score outdoor pose

      final results = engine.recommend(
        sceneClass: 'outdoor-nature',
        likedPoseIds: {likedId},
        topK: 5,
      );

      expect(results.recommendations, isNotEmpty);
      // The liked pose should rank high (likely first due to bonus)
      final topIds = results.recommendations.map((r) => r.poseId).take(2).toList();
      expect(topIds.contains(likedId), isTrue);
    });

    test('results sorted by rank ascending', () {
      final engine = _engine();
      final response = engine.recommend(sceneClass: 'outdoor-nature', topK: 3);

      for (int i = 0; i < response.recommendations.length - 1; i++) {
        expect(
          response.recommendations[i].rank,
          lessThan(response.recommendations[i + 1].rank),
        );
      }
    });

    test('MMR diversity re-ranking produces varied results', () {
      final engine = _engine();
      final response = engine.recommend(
        sceneClass: 'outdoor-nature',
        topK: 3,
        preferredStyles: ['fresh', 'natural'],
      );

      expect(response.recommendations.length, lessThanOrEqualTo(3));
      // Each result should be unique
      final ids = response.recommendations.map((r) => r.poseId).toSet();
      expect(ids.length, response.recommendations.length);
    });

    test('scene class mapping: night-scene → night', () {
      final nightPoses = [
        _makePose(id: 'night-1', sceneKey: 'night', style: ['moody']),
      ];
      final loader = FakeLocalPoseLoader({'night': nightPoses});
      final engine = LocalRecommendationEngine(loader);
      final response = engine.recommend(sceneClass: 'night-scene', topK: 3);

      expect(response.recommendations, isNotEmpty);
      expect(response.recommendations.first.poseId, 'night-1');
    });

    test('scene class mapping: urban-street → street', () {
      final engine = _engine();
      final response = engine.recommend(sceneClass: 'urban-street', topK: 3);

      expect(response.recommendations, isNotEmpty);
      expect(response.recommendations.first.poseId, startsWith('str-'));
    });

    test('isReady delegates to loader', () {
      final engine = _engine();
      expect(engine.isReady, isTrue);
    });

    test('topK limits result count', () {
      final engine = _engine();
      final response = engine.recommend(sceneClass: 'outdoor-nature', topK: 2);

      expect(response.recommendations.length, lessThanOrEqualTo(2));
    });
  });
}
