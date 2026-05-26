/// Loads the 300-pose local database from app assets.
///
/// Used as an offline fallback when the cloud backend is unreachable.
/// Parses the full pose JSON including skeletons, guidance, and camera params.

import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// Lightweight pose entry for local matching (subset of full JSON fields).
class LocalPose {
  final String poseId;
  final String sceneKey;
  final String bodyPosition;
  final String subPosition;
  final List<String> style;
  final String difficulty;
  final double qualityScore;
  final List<String> expression;
  final String category;
  final dynamic personCount; // int or String like "2-5"
  final Map<String, dynamic> raw;

  const LocalPose({
    required this.poseId,
    required this.sceneKey,
    required this.bodyPosition,
    required this.subPosition,
    required this.style,
    required this.difficulty,
    required this.qualityScore,
    this.expression = const [],
    this.category = 'solo',
    this.personCount = 1,
    required this.raw,
  });
}

/// Loads and indexes the local pose database for offline use.
class LocalPoseLoader {
  List<LocalPose>? _allPoses;
  Map<String, List<LocalPose>>? _posesByScene;
  bool _loaded = false;

  bool get isLoaded => _loaded;
  int get totalPoses => _allPoses?.length ?? 0;
  Map<String, List<LocalPose>> get posesByScene =>
      _posesByScene ?? {};

  /// Load the pose database from the assets bundle.
  Future<void> load() async {
    if (_loaded) return;

    try {
      final jsonStr = await rootBundle.loadString('assets/poses/local_pose_db.json');
      final data = json.decode(jsonStr) as Map<String, dynamic>;
      final poseList = data['poses'] as List<dynamic>? ?? [];

      _allPoses = [];
      _posesByScene = {};

      for (final p in poseList) {
        final pose = p as Map<String, dynamic>;
        final taxonomy = pose['taxonomy'] as Map<String, dynamic>? ?? {};
        final metadata = pose['metadata'] as Map<String, dynamic>? ?? {};
        final sceneTypes = (taxonomy['scene_type'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];

        final local = LocalPose(
          poseId: pose['pose_id'] as String? ?? '',
          sceneKey: sceneTypes.isNotEmpty ? sceneTypes.first : 'outdoor',
          bodyPosition: taxonomy['body_position'] as String? ?? 'standing',
          subPosition: taxonomy['sub_position'] as String? ?? '',
          style: (taxonomy['style'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [],
          difficulty: taxonomy['difficulty'] as String? ?? 'beginner',
          qualityScore: (metadata['quality_score'] as num?)?.toDouble() ?? 4.0,
          expression: (taxonomy['expression'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [],
          category: taxonomy['category'] as String? ?? 'solo',
          personCount: taxonomy['person_count'] ?? 1,
          raw: pose,
        );

        _allPoses!.add(local);
        for (final scene in sceneTypes) {
          _posesByScene!.putIfAbsent(scene, () => []).add(local);
        }
      }

      _loaded = true;
      print('LocalPoseLoader: loaded ${_allPoses!.length} poses '
          'across ${_posesByScene!.length} scenes');
    } catch (e) {
      print('LocalPoseLoader: failed to load pose DB — $e');
      _allPoses = [];
      _posesByScene = {};
      _loaded = true; // mark loaded to avoid retry loops
    }
  }

  /// Get all poses for a given scene key.
  List<LocalPose> getPosesForScene(String sceneKey) {
    return _posesByScene?[sceneKey] ?? _posesByScene?['outdoor'] ?? [];
  }

  /// Look up a single pose by its ID.
  LocalPose? getPoseById(String poseId) {
    for (final pose in _allPoses ?? <LocalPose>[]) {
      if (pose.poseId == poseId) return pose;
    }
    return null;
  }
}
