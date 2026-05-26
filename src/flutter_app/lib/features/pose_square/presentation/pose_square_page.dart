/// Pose Square — browse all 500 poses with filter chips, vote and collect.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/providers.dart';
import 'widgets/pose_grid_card.dart';
import 'pose_detail_page.dart';

const _filterOptions = [
  ('全部', null, null, null),
  ('站姿', 'standing', null, null),
  ('坐姿', 'sitting', null, null),
  ('躺姿', 'lying', null, null),
  ('新手', null, 'beginner', null),
  ('进阶', null, 'intermediate', null),
  ('清新', null, null, 'fresh'),
  ('甜美', null, null, 'sweet'),
  ('酷飒', null, null, 'cool'),
  ('优雅', null, null, 'elegant'),
];

class PoseSquarePage extends ConsumerStatefulWidget {
  const PoseSquarePage({super.key});

  @override
  ConsumerState<PoseSquarePage> createState() => _PoseSquarePageState();
}

class _PoseSquarePageState extends ConsumerState<PoseSquarePage> {
  @override
  void initState() {
    super.initState();
    ref.read(poseSquareStoreProvider).load();
  }

  @override
  Widget build(BuildContext context) {
    final loader = ref.watch(localPoseLoaderProvider);
    final filtered = ref.watch(filteredPosesProvider);
    final filter = ref.watch(poseSquareFilterProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        title: const Text('姿势广场'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_outline),
            tooltip: '仅看收藏',
            onPressed: () {
              // Toggle: show all collected poses
              final store = ref.read(poseSquareStoreProvider);
              if (store.collectedPoseIds.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('还没有收藏姿势')),
                );
              }
              // For now, just show all — collection filter handled via
              // _filterOptions if needed
            },
          ),
        ],
      ),
      body: loader.isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber, strokeWidth: 2))
          : Column(
              children: [
                // Filter chips
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    itemCount: _filterOptions.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final (label, pos, diff, style) = _filterOptions[index];
                      final isActive = filter.bodyPosition == pos &&
                          filter.difficulty == diff &&
                          filter.style == style;
                      return _FilterChip(
                        label: label,
                        isActive: isActive,
                        onTap: () {
                          ref.read(poseSquareFilterProvider.notifier).state =
                              isActive
                                  ? const PoseSquareFilter()
                                  : PoseSquareFilter(
                                      bodyPosition: pos,
                                      difficulty: diff,
                                      style: style,
                                    );
                        },
                      );
                    },
                  ),
                ),
                // Grid
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Text(
                            '没有找到姿势',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 14,
                            ),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.68,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final pose = filtered[index];
                            final store = ref.watch(poseSquareStoreProvider);
                            return PoseGridCard(
                              pose: pose,
                              userVote: store.voteFor(pose.poseId),
                              isCollected: store.isCollected(pose.poseId),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PoseDetailPage(poseId: pose.poseId),
                                  ),
                                );
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

/// Single filter chip, styled consistently with profile page chips.
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? Colors.amber.withOpacity(0.15) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? Colors.amber : Colors.white10,
            width: isActive ? 1.5 : 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.amber : Colors.white70,
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
