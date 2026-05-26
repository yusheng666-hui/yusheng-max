/// Providers for Pose Clone feature.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'pose_clone_service.dart';
import 'clone_store.dart';
import '../../../shared/models/pose.dart';

/// Singleton clone service.
final poseCloneServiceProvider = Provider<PoseCloneService>((ref) {
  final svc = PoseCloneService();
  ref.onDispose(() => svc.dispose());
  return svc;
});

/// Clone store for persisting cloned poses.
final cloneStoreProvider = Provider<CloneStore>((ref) {
  return CloneStore();
});

/// All cloned pose entries.
final clonedPosesProvider = Provider<List<ClonedPoseEntry>>((ref) {
  return ref.watch(cloneStoreProvider).entries;
});

/// Current clone in-progress result (from detection, before saving).
final cloneResultProvider = StateProvider<CloneResult?>((ref) => null);

/// Whether detection is in progress.
final isDetectingProvider = StateProvider<bool>((ref) => false);

/// Clone skeleton target for AR replication mode.
/// When set, the AR overlay renders this skeleton as the alignment target.
final cloneTargetSkeletonProvider = StateProvider<Skeleton3D?>((ref) => null);
