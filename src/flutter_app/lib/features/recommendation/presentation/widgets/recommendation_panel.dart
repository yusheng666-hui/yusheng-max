import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../camera/domain/providers.dart';
import '../../../../shared/models/recommendation.dart';
import '../../domain/services/recommendation_service.dart';
import '../../../../core/user_preference_store.dart';

/// Bottom panel displaying the pose recommendation carousel.
///
/// Shows 5 pose cards the user can swipe through.
/// Each card shows the pose name, camera mode, and guidance text.
class RecommendationPanel extends ConsumerWidget {
  const RecommendationPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final response = ref.watch(currentRecommendationsProvider);
    final activeIndex = ref.watch(activeRecommendationIndexProvider);

    if (response == null || response.recommendations.isEmpty) {
      return Container(
        height: 130,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white54,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '正在分析场景...',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final recs = response.recommendations;

    return Container(
      height: 130,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.65),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: scene + pose count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, size: 14, color: Colors.amber.withOpacity(0.9)),
                const SizedBox(width: 6),
                Text(
                  response.sceneDetected ?? '当前场景',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 11,
                  ),
                ),
                const Spacer(),
                Text(
                  '${recs.length} 个推荐',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Carousel of pose cards
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: recs.length,
              itemBuilder: (context, index) {
                final rec = recs[index];
                final isActive = index == activeIndex;

                return PoseCard(
                  recommendation: rec,
                  isActive: isActive,
                  onTap: () {
                    ref.read(activeRecommendationIndexProvider.notifier).state = index;
                  },
                  onLike: () {
                    final store = ref.read(userPreferenceStoreProvider);
                    store.likePose(rec.poseId, rec.styles);
                    ref.read(activeRecommendationIndexProvider.notifier).state = index;
                  },
                  onSkip: () {
                    final store = ref.read(userPreferenceStoreProvider);
                    store.skipPose(rec.poseId, rec.styles);
                    // Move to next card if available
                    if (index < recs.length - 1) {
                      ref.read(activeRecommendationIndexProvider.notifier).state = index + 1;
                    }
                    // Trigger re-fetch to replace skipped poses
                    final trigger = ref.read(recommendationRefreshTriggerProvider.notifier);
                    trigger.state = trigger.state + 1;
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual pose card in the carousel.
class PoseCard extends StatelessWidget {
  final PoseRecommendation recommendation;
  final bool isActive;
  final VoidCallback? onTap;
  final VoidCallback? onLike;
  final VoidCallback? onSkip;

  const PoseCard({
    super.key,
    required this.recommendation,
    this.isActive = false,
    this.onTap,
    this.onLike,
    this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final cam = recommendation.cameraParams;
    final camLabel = cam != null
        ? '${cam.beginnerMode} ISO${cam.advancedIso}'
        : '';

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 110,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isActive
              ? Colors.white.withOpacity(0.15)
              : Colors.white.withOpacity(0.05),
          border: isActive
              ? Border.all(color: Colors.amber.withOpacity(0.8), width: 2)
              : Border.all(color: Colors.white24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Rank badge + score + action buttons
            Row(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive ? Colors.amber : Colors.white24,
                  ),
                  child: Center(
                    child: Text(
                      '${recommendation.rank}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isActive ? Colors.black : Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '${recommendation.score.toInt()}分',
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
                const Spacer(),
                // Like button
                GestureDetector(
                  onTap: onLike,
                  child: Icon(
                    Icons.favorite_border,
                    size: 14,
                    color: Colors.white.withOpacity(0.4),
                  ),
                ),
                const SizedBox(width: 4),
                // Skip button
                GestureDetector(
                  onTap: onSkip,
                  child: Icon(
                    Icons.close,
                    size: 14,
                    color: Colors.white.withOpacity(0.4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Pose name
            Text(
              recommendation.name.isNotEmpty ? recommendation.name : recommendation.poseId,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white70,
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 2),
            // Camera param hint
            if (camLabel.isNotEmpty)
              Text(
                camLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.amber.withOpacity(0.7),
                  fontSize: 9,
                ),
              ),
            const Spacer(),
            // Guidance snippet
            Text(
              recommendation.guidanceText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 9,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
