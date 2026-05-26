/// Camera movement detail page.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/camera_movements.dart';
import '../../camera/domain/providers.dart';

class MovementDetailPage extends ConsumerStatefulWidget {
  final CameraMovement movement;

  const MovementDetailPage({super.key, required this.movement});

  @override
  ConsumerState<MovementDetailPage> createState() =>
      _MovementDetailPageState();
}

class _MovementDetailPageState extends ConsumerState<MovementDetailPage> {
  late bool _remindEnabled;

  @override
  void initState() {
    super.initState();
    _remindEnabled =
        ref.read(activeMovementProvider)?.id == widget.movement.id;
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.movement;

    final diffLabel = m.difficulty == 'beginner'
        ? '新手'
        : m.difficulty == 'intermediate'
            ? '进阶'
            : '高级';

    final diffColor = m.difficulty == 'beginner'
        ? Colors.green
        : m.difficulty == 'intermediate'
            ? Colors.orange
            : Colors.redAccent;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        title: Text(m.nameZh),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _remindEnabled
                  ? Icons.notifications_active
                  : Icons.notifications_off_outlined,
              color: _remindEnabled ? Colors.amber : Colors.white38,
            ),
            tooltip: '拍摄时提醒',
            onPressed: () {
              setState(() => _remindEnabled = !_remindEnabled);
              ref.read(activeMovementProvider.notifier).state =
                  _remindEnabled ? m : null;
              if (_remindEnabled) {
                ref
                    .read(showMovementOverlayProvider.notifier)
                    .state = true;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_remindEnabled ? '将在拍摄时显示运镜提示' : '已取消运镜提示'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                children: [
                  Text(
                    m.iconSymbol,
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    m.nameZh,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _Chip(label: m.category, color: Colors.amber),
                      const SizedBox(width: 10),
                      _Chip(label: diffLabel, color: diffColor),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Description
            _SectionLabel(label: '手法介绍'),
            const SizedBox(height: 8),
            Text(
              m.description,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 20),

            // Steps
            _SectionLabel(label: '分步指导'),
            const SizedBox(height: 8),
            ...m.steps.asMap().entries.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _StepRow(index: e.key + 1, text: e.value),
                  ),
                ),
            const SizedBox(height: 20),

            // Suitable scenes
            _SectionLabel(label: '适用场景'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: m.suitableScenes
                  .map((s) => _Chip(label: s, color: Colors.white70))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: Colors.amber,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  final int index;
  final String text;

  const _StepRow({required this.index, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              '$index',
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12),
      ),
    );
  }
}
