/// Horizontal preset carousel for post-shot editing.
///
/// Shows preset thumbnails with name and style tags. User swipes to
/// preview different presets applied to their photo.

import 'package:flutter/material.dart';
import '../../domain/services/preset_loader.dart';
import '../../../shared/models/preset.dart';

class PresetPanel extends StatelessWidget {
  final List<Preset> presets;
  final String? activePresetId;
  final ValueChanged<Preset> onPresetSelected;

  const PresetPanel({
    super.key,
    required this.presets,
    this.activePresetId,
    required this.onPresetSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (presets.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 16, bottom: 4),
            child: Text(
              '推荐预设',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: presets.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final preset = presets[index];
                final isActive = preset.presetId == activePresetId;
                return _PresetChip(
                  preset: preset,
                  isActive: isActive,
                  onTap: () => onPresetSelected(preset),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  final Preset preset;
  final bool isActive;
  final VoidCallback onTap;

  const _PresetChip({
    required this.preset,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 72,
        decoration: BoxDecoration(
          color: isActive
              ? Colors.amber.withOpacity(0.15)
              : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? Colors.amber : Colors.white12,
            width: isActive ? 1.5 : 0.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Color indicator bar (simplified preview of the LUT effect)
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: _buildGradient(preset.styleTags),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              preset.name.zh,
              style: TextStyle(
                color: isActive ? Colors.amber : Colors.white70,
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              preset.styleTags.take(2).join('·'),
              style: TextStyle(
                color: Colors.white30,
                fontSize: 9,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  LinearGradient _buildGradient(List<String> tags) {
    final colors = <Color>[];
    for (final tag in tags) {
      switch (tag) {
        case 'warm':
          colors.add(Colors.orange);
          break;
        case 'cool':
          colors.add(Colors.blue);
          break;
        case 'vintage':
          colors.add(Colors.brown);
          break;
        case 'bright':
          colors.add(Colors.yellow.shade100);
          break;
        case 'moody':
          colors.add(Colors.blueGrey);
          break;
        case 'vivid':
          colors.add(Colors.pinkAccent);
          break;
        case 'black-and-white':
          colors.add(Colors.grey);
          colors.add(Colors.black);
          break;
        case 'fresh':
          colors.add(Colors.cyan);
          break;
      }
    }
    if (colors.isEmpty) {
      colors.addAll([Colors.white24, Colors.white54]);
    }
    if (colors.length == 1) {
      colors.add(colors.first.withOpacity(0.5));
    }
    return LinearGradient(colors: colors);
  }
}
