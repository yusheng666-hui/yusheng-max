import 'package:flutter/material.dart';
import '../../../recommendation/domain/services/local_pose_loader.dart';

/// Card widget for the Pose Square grid.
///
/// Shows a placeholder silhouette, pose name, style tags, and vote indicator.
class PoseGridCard extends StatelessWidget {
  final LocalPose pose;
  final int userVote;
  final bool isCollected;
  final VoidCallback onTap;

  const PoseGridCard({
    super.key,
    required this.pose,
    this.userVote = 0,
    this.isCollected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final raw = pose.raw;
    final name = (raw['name'] as Map<String, dynamic>? ?? {})['zh'] as String? ?? pose.poseId;
    final desc = (raw['description'] as Map<String, dynamic>? ?? {})['zh'] as String? ?? '';
    final metadata = raw['metadata'] as Map<String, dynamic>? ?? {};
    final popScore = (metadata['popularity_score'] as num?)?.toDouble() ?? 0;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isCollected ? Colors.amber.withOpacity(0.7) : Colors.white12,
            width: isCollected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Placeholder silhouette area
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF252525),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                ),
                child: Center(
                  child: Icon(
                    Icons.accessibility_new,
                    size: 42,
                    color: Colors.white.withOpacity(0.15),
                  ),
                ),
              ),
            ),
            // Info section
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (popScore > 0)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                userVote == 1 ? Icons.thumb_up : Icons.thumb_up_alt_outlined,
                                size: 12,
                                color: userVote == 1 ? Colors.amber : Colors.white24,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                popScore.toStringAsFixed(0),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.35),
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (desc.isNotEmpty)
                      Text(
                        desc,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.35),
                          fontSize: 10,
                        ),
                      ),
                    const Spacer(),
                    // Style tags
                    if (pose.style.isNotEmpty)
                      Wrap(
                        spacing: 4,
                        runSpacing: 2,
                        children: pose.style.take(2).map((s) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              s,
                              style: TextStyle(
                                color: Colors.amber.withOpacity(0.6),
                                fontSize: 8,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
