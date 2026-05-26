/// Clone result page — shows extracted skeleton overlaid on the photo,
/// with save/retry/replicate actions.
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../domain/providers.dart';
import '../domain/clone_store.dart';
import '../domain/pose_clone_service.dart';
import '../../../shared/models/pose.dart';
import '../../../shared/widgets/section_label.dart';

class CloneResultPage extends ConsumerStatefulWidget {
  /// If provided, view/edit an existing saved entry.
  final ClonedPoseEntry? existingEntry;

  const CloneResultPage({super.key, this.existingEntry});

  @override
  ConsumerState<CloneResultPage> createState() => _CloneResultPageState();
}

class _CloneResultPageState extends ConsumerState<CloneResultPage> {
  late final TextEditingController _nameCtrl;
  bool _saved = false;
  bool _isExisting = false;

  @override
  void initState() {
    super.initState();
    _isExisting = widget.existingEntry != null;
    _saved = _isExisting;
    _nameCtrl = TextEditingController(
      text: widget.existingEntry?.name ?? '我的克隆姿势',
    );
    if (_isExisting) {
      // Restore the clone result from existing entry (image on disk)
      ref.read(cloneResultProvider.notifier).state = CloneResult(
        imageBytes: widget.existingEntry!.thumbBytes ?? Uint8List(0),
        skeleton: widget.existingEntry!.skeleton,
        confidence: widget.existingEntry!.confidence,
      );
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final result = ref.read(cloneResultProvider);
    if (result == null) return;

    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入姿势名称')),
      );
      return;
    }

    final store = ref.read(cloneStoreProvider);
    await store.load();

    final id = widget.existingEntry?.id ?? const Uuid().v4();
    await store.addEntry(
      id: id,
      name: name,
      imageBytes: result.imageBytes,
      skeleton: result.skeleton,
      confidence: result.confidence,
    );

    setState(() => _saved = true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('姿势已保存')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(cloneResultProvider);

    if (result == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D0D0D),
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: const Center(
          child: Text('暂无检测结果',
              style: TextStyle(color: Colors.white38)),
        ),
      );
    }

    final kpCount = result.skeleton.keypoints.length;
    final confPct = (result.confidence * 100).toInt();

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        title: Text(_isExisting ? '已保存姿势' : '检测结果'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (!_saved)
            TextButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined, size: 18),
              label: const Text('保存'),
              style: TextButton.styleFrom(foregroundColor: Colors.amber),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo with skeleton overlay
            _SkeletonOverlay(
              imageBytes: result.imageBytes,
              skeleton: result.skeleton,
            ),
            const SizedBox(height: 16),

            // Stats row
            Row(
              children: [
                _StatChip(
                  icon: Icons.accessibility_new,
                  label: '$kpCount 关键点',
                  color: Colors.amber,
                ),
                const SizedBox(width: 12),
                _StatChip(
                  icon: confPct >= 60
                      ? Icons.check_circle_outline
                      : Icons.warning_amber_outlined,
                  label: '置信度 $confPct%',
                  color: confPct >= 60 ? Colors.green : Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Name input
            SectionLabel(label: '姿势名称'),
            const SizedBox(height: 8),
            TextField(
              controller: _nameCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                hintText: '输入姿势名称...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
              ),
            ),
            const SizedBox(height: 24),

            // Keypoint detail
            SectionLabel(label: '关键点详情'),
            const SizedBox(height: 8),
            _KeypointGrid(keypoints: result.skeleton.keypoints),
            const SizedBox(height: 28),

            // Replicate button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  // Set the clone skeleton as AR target
                  ref.read(cloneTargetSkeletonProvider.notifier).state =
                      result.skeleton;
                  // Navigate back to camera
                  Navigator.popUntil(context, (r) => r.isFirst);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('克隆姿势已加载，打开AR即可对齐复刻'),
                    ),
                  );
                },
                icon: const Icon(Icons.flip_camera_android),
                label: const Text('开始AR复刻此姿势',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Draws the photo with skeleton keypoints and connections overlaid.
class _SkeletonOverlay extends StatelessWidget {
  final Uint8List imageBytes;
  final Skeleton3D skeleton;

  const _SkeletonOverlay({
    required this.imageBytes,
    required this.skeleton,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxHeight: 360),
        color: Colors.white.withOpacity(0.03),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _SkeletonPainter(
                keypoints: skeleton.keypoints,
              ),
              child: Image.memory(
                imageBytes,
                fit: BoxFit.contain,
                width: double.infinity,
                height: constraints.maxHeight,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SkeletonPainter extends CustomPainter {
  final List<Keypoint> keypoints;

  _SkeletonPainter({required this.keypoints});

  static const _connections = [
    // Torso
    [11, 12], [11, 23], [12, 24], [23, 24],
    // Left arm
    [11, 13], [13, 15],
    // Right arm
    [12, 14], [14, 16],
    // Left leg
    [23, 25], [25, 27],
    // Right leg
    [24, 26], [26, 28],
    // Face
    [0, 1], [0, 4], [1, 2], [2, 3], [4, 5], [5, 6],
    [1, 7], [4, 8], [9, 10],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // Build lookup: id → offset
    final lookup = <int, Offset>{};
    for (final kp in keypoints) {
      lookup[kp.id] = Offset(kp.x * size.width, kp.y * size.height);
    }

    // Draw connections
    final linePaint = Paint()
      ..color = Colors.amber.withOpacity(0.7)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final pair in _connections) {
      final a = lookup[pair[0]];
      final b = lookup[pair[1]];
      if (a != null && b != null) {
        canvas.drawLine(a, b, linePaint);
      }
    }

    // Draw keypoints
    final dotPaint = Paint()
      ..color = Colors.amber
      ..style = PaintingStyle.fill;

    final dotPaintLow = Paint()
      ..color = Colors.amber.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    for (final kp in keypoints) {
      final pos = lookup[kp.id];
      if (pos == null) continue;
      final isReliable = kp.visibility > 0.5;
      canvas.drawCircle(
        pos,
        isReliable ? 4.5 : 3.0,
        isReliable ? dotPaint : dotPaintLow,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SkeletonPainter old) =>
      old.keypoints != keypoints;
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: 13)),
        ],
      ),
    );
  }
}

class _KeypointGrid extends StatelessWidget {
  final List keypoints;
  const _KeypointGrid({required this.keypoints});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: keypoints.map((kp) {
        final reliable = kp.visibility > 0.5;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: (reliable ? Colors.amber : Colors.white).withOpacity(0.06),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: (reliable ? Colors.amber : Colors.white).withOpacity(0.15),
            ),
          ),
          child: Text(
            kp.name,
            style: TextStyle(
              color:
                  reliable ? Colors.amber.withOpacity(0.8) : Colors.white38,
              fontSize: 11,
            ),
          ),
        );
      }).toList(),
    );
  }
}
