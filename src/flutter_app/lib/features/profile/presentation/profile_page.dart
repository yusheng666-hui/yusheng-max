/// User profile page with style preference questionnaire.
///
/// First-time users configure their style preferences, difficulty level,
/// and basic attributes. Returning users can update preferences.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';
import '../../camera/domain/providers.dart';

const _styleOptions = [
  ('fresh', '清新', Icons.wb_sunny_outlined),
  ('sweet', '甜美', Icons.favorite_border),
  ('cool', '酷飒', Icons.bolt),
  ('elegant', '优雅', Icons.auto_awesome),
  ('casual', '随性', Icons.weekend),
  ('natural', '自然', Icons.park_outlined),
];

const _difficultyOptions = [
  ('beginner', '新手'),
  ('intermediate', '进阶'),
];

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _nameCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  bool _loading = false;
  bool _saved = false;
  String? _error;

  final _selectedStyles = <String>{'natural', 'fresh'};
  String _difficulty = 'beginner';
  String _level = 'beginner';
  String _gender = 'unspecified';
  String _skinTone = 'medium';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _heightCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      await api.registerUser(profile: {
        'display_name': _nameCtrl.text.isNotEmpty ? _nameCtrl.text : '新用户',
        'preferred_styles': _selectedStyles.toList(),
        'preferred_difficulty': _difficulty,
        'photography_level': _level,
        'gender': _gender,
        'skin_tone': _skinTone,
        'height_cm': double.tryParse(_heightCtrl.text) ?? 165.0,
      });

      final svc = ref.read(recommendationServiceProvider);
      svc.setPreferredStyles(_selectedStyles.toList());
      svc.setPreferredDifficulty(_difficulty);

      setState(() {
        _loading = false;
        _saved = true;
      });
    } on ApiException catch (e) {
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        title: const Text('风格偏好'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_saved)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Icon(Icons.check_circle, color: Colors.greenAccent),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel('昵称'),
            const SizedBox(height: 6),
            TextField(
              controller: _nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDec('给自己起个名字'),
            ),
            const SizedBox(height: 20),

            _sectionLabel('喜欢的拍摄风格（可多选）'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _styleOptions.map((s) {
                final (id, label, icon) = s;
                final selected = _selectedStyles.contains(id);
                return _ChipOption(
                  label: label,
                  icon: icon,
                  selected: selected,
                  onTap: () {
                    setState(() {
                      if (selected) {
                        _selectedStyles.remove(id);
                      } else {
                        _selectedStyles.add(id);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            _sectionLabel('姿势难度偏好'),
            const SizedBox(height: 6),
            Row(
              children: _difficultyOptions.map((d) {
                final (id, label) = d;
                final selected = _difficulty == id;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: id == 'beginner' ? 8 : 0),
                    child: _ChipOption(
                      label: label,
                      selected: selected,
                      onTap: () => setState(() => _difficulty = id),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            _sectionLabel('摄影水平'),
            const SizedBox(height: 6),
            _segmentedBar(
              const ['beginner', 'hobbyist', 'advanced'],
              const ['小白', '爱好者', '进阶'],
              _level,
              (v) => setState(() => _level = v),
            ),
            const SizedBox(height: 20),

            _sectionLabel('性别'),
            const SizedBox(height: 6),
            _segmentedBar(
              const ['unspecified', 'female', 'male'],
              const ['保密', '女', '男'],
              _gender,
              (v) => setState(() => _gender = v),
            ),
            const SizedBox(height: 20),

            _sectionLabel('肤色'),
            const SizedBox(height: 6),
            _segmentedBar(
              const ['fair', 'light', 'medium', 'tan'],
              const ['白皙', '自然偏白', '自然', '小麦色'],
              _skinTone,
              (v) => setState(() => _skinTone = v),
            ),
            const SizedBox(height: 20),

            _sectionLabel('身高 (cm)'),
            const SizedBox(height: 6),
            TextField(
              controller: _heightCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDec('165'),
            ),
            const SizedBox(height: 32),

            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
              ),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _loading || _saved ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _saved ? Colors.green : Colors.amber,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_saved ? '已保存' : '保存偏好',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _segmentedBar(List<String> values, List<String> labels, String current, ValueChanged<String> onChanged) {
    return Row(
      children: List.generate(values.length, (i) {
        final selected = values[i] == current;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < values.length - 1 ? 6 : 0),
            child: _ChipOption(
              label: labels[i],
              selected: selected,
              onTap: () => onChanged(values[i]),
            ),
          ),
        );
      }),
    );
  }

  InputDecoration _inputDec(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}

Widget _sectionLabel(String text) {
  return Text(text, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13, fontWeight: FontWeight.w500));
}

class _ChipOption extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _ChipOption({required this.label, this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.amber.withOpacity(0.15) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? Colors.amber : Colors.white10, width: selected ? 1.5 : 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: selected ? Colors.amber : Colors.white38),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.amber : Colors.white70,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
