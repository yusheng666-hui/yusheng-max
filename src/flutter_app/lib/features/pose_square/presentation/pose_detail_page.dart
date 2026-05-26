/// Pose detail page — full info view with vote, collection, guidance.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/providers.dart';
import '../../recommendation/domain/services/local_pose_loader.dart';
import '../../camera/domain/providers.dart';

class PoseDetailPage extends ConsumerStatefulWidget {
  final String poseId;

  const PoseDetailPage({super.key, required this.poseId});

  @override
  ConsumerState<PoseDetailPage> createState() => _PoseDetailPageState();
}

class _PoseDetailPageState extends ConsumerState<PoseDetailPage> {
  LocalPose? _pose;

  @override
  void initState() {
    super.initState();
    final loader = ref.read(localPoseLoaderProvider).valueOrNull;
    _pose = loader?.getPoseById(widget.poseId);
    if (_pose == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('姿势不存在')),
          );
          Navigator.pop(context);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_pose == null) return const SizedBox.shrink();

    final raw = _pose!.raw;
    final name = _extractZh(raw, 'name') ?? _pose!.poseId;
    final desc = _extractZh(raw, 'description') ?? '';
    final taxonomy = raw['taxonomy'] as Map<String, dynamic>? ?? {};
    final guidance = raw['guidance'] as Map<String, dynamic>? ?? {};
    final suitability = raw['suitability'] as Map<String, dynamic>? ?? {};
    final metadata = raw['metadata'] as Map<String, dynamic>? ?? {};
    final skData = raw['skeleton_3d'] as Map<String, dynamic>? ?? {};
    final cameraParamData = raw['camera_params'] as Map<String, dynamic>? ?? {};

    final styles = (taxonomy['style'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    final bodyPosition = taxonomy['body_position'] as String? ?? '';
    final difficulty = taxonomy['difficulty'] as String? ?? 'beginner';
    final personCount = taxonomy['person_count']?.toString() ?? '1';
    final sceneTypes = (taxonomy['scene_type'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    final popScore = (metadata['popularity_score'] as num?)?.toDouble() ?? 0;
    final qualityScore = (metadata['quality_score'] as num?)?.toDouble() ?? 0;
    final tags = (metadata['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    final kpCount = (skData['keypoints'] as List<dynamic>?)?.length ?? 33;

    final modelTips = _extractZh(guidance, 'model_tips') ?? '';
    final photoTips = (_extractNestedZh(guidance, 'photographer_tips'));
    final steps = (guidance['step_by_step'] as List<dynamic>?)
            ?.map((s) => s is Map<String, dynamic> ? _extractZh(s, null) ?? '' : s.toString())
            .where((s) => s.isNotEmpty)
            .toList() ??
        [];
    final mistakes = (guidance['common_mistakes'] as List<dynamic>?)
            ?.map((m) => m is Map<String, dynamic> ? _extractZh(m, null) ?? '' : m.toString())
            .where((s) => s.isNotEmpty)
            .toList() ??
        [];

    final bodyTypes = (suitability['body_types'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    final clothing = (suitability['clothing'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    final lighting = (suitability['lighting'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

    final store = ref.watch(poseSquareStoreProvider);
    final myVote = store.voteFor(widget.poseId);
    final collected = store.isCollected(widget.poseId);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        title: Text(name, style: const TextStyle(fontSize: 16)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, size: 20),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('分享功能即将上线')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Preview area
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.accessibility_new, size: 64, color: Colors.white.withOpacity(0.12)),
                    const SizedBox(height: 8),
                    Text(
                      '$kpCount 个关键点 · MediaPipe 33',
                      style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Name + description
            Text(name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600)),
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(desc, style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 14, height: 1.5)),
            ],
            const SizedBox(height: 16),

            // Info chips row
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _infoChip('站姿', bodyPosition == 'standing'),
                _infoChip('坐姿', bodyPosition == 'sitting'),
                _infoChip('躺姿', bodyPosition == 'lying'),
                _infoChip(
                  difficulty == 'beginner' ? '新手' : difficulty == 'intermediate' ? '进阶' : '高阶',
                  true,
                ),
                _infoChip(
                  personCount == '1' ? '单人' : personCount == '2' ? '双人' : '多人',
                  true,
                  icon: Icons.people_outline,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Style tags
            if (styles.isNotEmpty) ...[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: styles.map((s) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.withOpacity(0.2)),
                    ),
                    child: Text(s, style: TextStyle(color: Colors.amber.withOpacity(0.8), fontSize: 11)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],

            // Scene types
            if (sceneTypes.isNotEmpty) ...[
              _sectionLabel('适用场景'),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: sceneTypes.map((s) => _tagChip(s)).toList(),
              ),
              const SizedBox(height: 20),
            ],

            // Vote + Collection row
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  // Vote
                  _voteButton(
                    icon: Icons.thumb_up,
                    isActive: myVote == 1,
                    onTap: () {
                      if (myVote == 1) {
                        store.removeVote(widget.poseId);
                      } else {
                        store.upvotePose(widget.poseId);
                      }
                      setState(() {});
                    },
                  ),
                  const SizedBox(width: 6),
                  Text(
                    popScore.toStringAsFixed(0),
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
                  ),
                  const SizedBox(width: 10),
                  _voteButton(
                    icon: Icons.thumb_down,
                    isActive: myVote == -1,
                    onTap: () {
                      if (myVote == -1) {
                        store.removeVote(widget.poseId);
                      } else {
                        store.downvotePose(widget.poseId);
                      }
                      setState(() {});
                    },
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '质量 ${qualityScore.toStringAsFixed(1)}',
                    style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11),
                  ),
                  const Spacer(),
                  // Collection button
                  GestureDetector(
                    onTap: () {
                      store.toggleCollection(widget.poseId);
                      setState(() {});
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: collected ? Colors.amber.withOpacity(0.15) : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: collected ? Colors.amber : Colors.white24,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            collected ? Icons.bookmark : Icons.bookmark_outline,
                            size: 16,
                            color: collected ? Colors.amber : Colors.white38,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            collected ? '已收藏' : '收藏',
                            style: TextStyle(
                              color: collected ? Colors.amber : Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Model tips
            if (modelTips.isNotEmpty) ...[
              _sectionLabel('模特小贴士'),
              const SizedBox(height: 6),
              _infoCard(modelTips),
              const SizedBox(height: 16),
            ],

            // Step-by-step
            if (steps.isNotEmpty) ...[
              _sectionLabel('分步指导'),
              const SizedBox(height: 6),
              ...List.generate(steps.length, (i) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.amber.withOpacity(0.15),
                        ),
                        child: Center(
                          child: Text('${i + 1}', style: TextStyle(color: Colors.amber.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          steps[i],
                          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 16),
            ],

            // Common mistakes
            if (mistakes.isNotEmpty) ...[
              _sectionLabel('常见错误'),
              const SizedBox(height: 6),
              ...mistakes.map((m) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.error_outline, size: 14, color: Colors.red.withOpacity(0.5)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(m, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, height: 1.4)),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 16),
            ],

            // Photographer tips
            if (photoTips != null && photoTips.isNotEmpty) ...[
              _sectionLabel('拍摄建议'),
              const SizedBox(height: 6),
              _infoCard(photoTips),
              const SizedBox(height: 16),
            ],

            // Camera params info
            if (cameraParamData.isNotEmpty) ...[
              _sectionLabel('相机参数'),
              const SizedBox(height: 6),
              _infoCard(
                '推荐模式: ${(cameraParamData['beginner'] as Map<String, dynamic>? ?? {})['mode'] ?? 'auto'}\n'
                'ISO: ${(cameraParamData['advanced'] as Map<String, dynamic>? ?? {})['iso'] ?? 'auto'}\n'
                '快门: ${(cameraParamData['advanced'] as Map<String, dynamic>? ?? {})['shutter_speed'] ?? '1/250'}',
              ),
              const SizedBox(height: 16),
            ],

            // Suitability
            if (bodyTypes.isNotEmpty || clothing.isNotEmpty || lighting.isNotEmpty) ...[
              _sectionLabel('适配条件'),
              const SizedBox(height: 6),
              if (bodyTypes.isNotEmpty)
                _suitabilityRow('体型', bodyTypes),
              if (clothing.isNotEmpty)
                _suitabilityRow('穿搭', clothing),
              if (lighting.isNotEmpty)
                _suitabilityRow('光线', lighting),
            ],
          ],
        ),
      ),
    );
  }

  // ── Helpers ──

  String? _extractZh(Map<String, dynamic> map, String? key) {
    final target = key != null ? map[key] as Map<String, dynamic>? : map;
    if (target == null) return null;
    return target['zh'] as String? ?? target['zh_CN'] as String?;
  }

  String? _extractNestedZh(Map<String, dynamic> map, String key) {
    final nested = map[key] as Map<String, dynamic>?;
    if (nested == null) return null;
    return nested['zh'] as String? ?? nested['zh_CN'] as String?;
  }

  Widget _infoChip(String label, bool filled, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: filled ? Colors.white.withOpacity(0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: filled ? Colors.white24 : Colors.white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: Colors.white38),
            const SizedBox(width: 4),
          ],
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11)),
        ],
      ),
    );
  }

  Widget _tagChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
    );
  }

  Widget _voteButton({required IconData icon, required bool isActive, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(
        icon,
        size: 22,
        color: isActive ? Colors.amber : Colors.white.withOpacity(0.3),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(text, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13, fontWeight: FontWeight.w500));
  }

  Widget _infoCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Text(text, style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 13, height: 1.6)),
    );
  }

  Widget _suitabilityRow(String label, List<String> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 36,
            child: Text(label, style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 11)),
          ),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: items.map((s) => _tagChip(s)).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
