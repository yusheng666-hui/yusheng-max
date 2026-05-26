import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../camera/domain/providers.dart';
import '../../../recommendation/domain/services/styling_service.dart';

/// Compact styling card showing wardrobe color suggestions and prop recommendations.
///
/// Positioned on the left side of the camera view.
/// Shows color swatches, style tags, and prop icons with usage tips.
class StylingCard extends ConsumerWidget {
  const StylingCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final styling = ref.watch(stylingRecommendationProvider);
    if (styling == null) return const SizedBox.shrink();

    return Container(
      width: 130,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _sectionLabel('穿搭', Icons.checkroom),
          const SizedBox(height: 6),

          // Color swatches
          ...styling.wardrobe.suggestedColors.take(3).map((c) => _colorChip(c)),
          const SizedBox(height: 6),

          // Style tags
          Wrap(
            spacing: 4,
            runSpacing: 2,
            children: styling.wardrobe.styleTags.take(2).map((tag) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 8,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 6),

          // Props
          _sectionLabel('道具', Icons.category),
          const SizedBox(height: 4),
          ...styling.props.take(3).map((p) => _propRow(p)),

          // Pairing tip
          if (styling.wardrobe.pairingTip.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              styling.wardrobe.pairingTip,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 8,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionLabel(String title, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: Colors.pinkAccent.withOpacity(0.8)),
        const SizedBox(width: 4),
        Text(
          title,
          style: TextStyle(
            color: Colors.pinkAccent.withOpacity(0.8),
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _colorChip(ColorSuggestion color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: Color(color.hexColor),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24),
              boxShadow: [
                BoxShadow(
                  color: Color(color.hexColor).withOpacity(0.4),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  color.name,
                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w500),
                ),
                Text(
                  color.reason,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 7),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _propRow(PropRecommendation prop) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Text(prop.icon, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prop.name,
                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w500),
                ),
                Text(
                  prop.usageTip,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 7),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
