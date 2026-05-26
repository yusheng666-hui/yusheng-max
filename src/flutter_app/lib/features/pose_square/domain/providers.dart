/// Providers for Pose Square feature.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'pose_square_store.dart';
import '../../camera/domain/providers.dart';
import '../../recommendation/domain/services/local_pose_loader.dart';

/// Singleton store for votes and collections.
final poseSquareStoreProvider = Provider<PoseSquareStore>((ref) {
  return PoseSquareStore();
});

/// All loaded poses from the local DB.
final allPosesProvider = Provider<List<LocalPose>>((ref) {
  final loader = ref.watch(localPoseLoaderProvider).valueOrNull;
  if (loader == null) return [];
  // Collect all poses from all scenes
  final seen = <String>{};
  final all = <LocalPose>[];
  for (final list in loader.posesByScene.values) {
    for (final pose in list) {
      if (seen.add(pose.poseId)) {
        all.add(pose);
      }
    }
  }
  return all;
});

/// Grid filter state.
class PoseSquareFilter {
  final String? bodyPosition;
  final String? difficulty;
  final String? style;

  const PoseSquareFilter({this.bodyPosition, this.difficulty, this.style});

  bool get isEmpty => bodyPosition == null && difficulty == null && style == null;

  PoseSquareFilter copyWith({String? bodyPosition, String? difficulty, String? style, bool clear = false}) {
    if (clear) return const PoseSquareFilter();
    return PoseSquareFilter(
      bodyPosition: bodyPosition ?? this.bodyPosition,
      difficulty: difficulty ?? this.difficulty,
      style: style ?? this.style,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PoseSquareFilter &&
          bodyPosition == other.bodyPosition &&
          difficulty == other.difficulty &&
          style == other.style;

  @override
  int get hashCode => Object.hash(bodyPosition, difficulty, style);
}

final poseSquareFilterProvider = StateProvider<PoseSquareFilter>((ref) {
  return const PoseSquareFilter();
});

/// Poses after applying active filters.
final filteredPosesProvider = Provider<List<LocalPose>>((ref) {
  final all = ref.watch(allPosesProvider);
  final filter = ref.watch(poseSquareFilterProvider);

  if (filter.isEmpty) return all;

  return all.where((pose) {
    if (filter.bodyPosition != null && pose.bodyPosition != filter.bodyPosition) {
      return false;
    }
    if (filter.difficulty != null && pose.difficulty != filter.difficulty) {
      return false;
    }
    if (filter.style != null && !pose.style.contains(filter.style)) {
      return false;
    }
    return true;
  }).toList();
});

/// User's vote for a specific pose (-1, 0, or 1).
final poseVoteProvider = Provider.family<int, String>((ref, poseId) {
  return ref.watch(poseSquareStoreProvider).voteFor(poseId);
});

/// Whether a pose is in the user's collection.
final isPoseCollectedProvider = Provider.family<bool, String>((ref, poseId) {
  return ref.watch(poseSquareStoreProvider).isCollected(poseId);
});

/// All collected poses.
final collectedPosesProvider = Provider<List<LocalPose>>((ref) {
  final all = ref.watch(allPosesProvider);
  final store = ref.watch(poseSquareStoreProvider);
  return all.where((p) => store.isCollected(p.poseId)).toList();
});
