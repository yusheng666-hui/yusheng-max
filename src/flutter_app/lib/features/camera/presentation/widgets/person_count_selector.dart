/// Horizontal chip selector for person-count mode.
///
/// Toggles between 单人 / 双人 / 闺蜜 / 家庭, which filters the
/// recommendation pool by pose category.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/providers.dart';

const _modes = [
  ('solo', '单人'),
  ('couple', '双人'),
  ('friends', '闺蜜'),
  ('family', '家庭'),
];

class PersonCountSelector extends ConsumerWidget {
  const PersonCountSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMode = ref.watch(personCountModeProvider);
    final personCount = ref.watch(detectedPersonCountProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (mode, label) in _modes)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: GestureDetector(
                onTap: () {
                  ref.read(personCountModeProvider.notifier).state = mode;
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: currentMode == mode
                        ? Colors.white.withOpacity(0.25)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: currentMode == mode
                          ? Colors.white
                          : Colors.white54,
                      fontSize: 13,
                      fontWeight:
                          currentMode == mode ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
          // Person count badge
          if (personCount > 0)
            Container(
              margin: const EdgeInsets.only(left: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.cyanAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$personCount人',
                style: const TextStyle(
                  color: Colors.cyanAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
