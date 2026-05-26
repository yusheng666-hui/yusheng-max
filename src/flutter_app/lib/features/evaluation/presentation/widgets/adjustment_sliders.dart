/// Collapsible adjustment slider panel for post-processing.
///
/// Provides 8 parameter sliders (exposure, contrast, highlights, shadows,
/// saturation, temperature, vignette, grain) with live value display.
/// Fires [onChanged] on every slider change for real-time shader updates.

import 'package:flutter/material.dart';

class AdjustmentSliders extends StatefulWidget {
  /// Initial values from the selected preset's defaults.
  final Map<String, double> initialValues;

  /// Called with the full map on every slider change.
  final ValueChanged<Map<String, double>> onChanged;

  const AdjustmentSliders({
    super.key,
    required this.initialValues,
    required this.onChanged,
  });

  @override
  State<AdjustmentSliders> createState() => _AdjustmentSlidersState();
}

class _AdjustmentSlidersState extends State<AdjustmentSliders> {
  late Map<String, double> _values;
  bool _expanded = false;

  static const _params = <_SliderParam>[
    _SliderParam('exposure', '曝光', -2.0, 2.0, 0.1),
    _SliderParam('contrast', '对比度', -1.0, 1.0, 0.05),
    _SliderParam('highlights', '高光', -1.0, 1.0, 0.05),
    _SliderParam('shadows', '阴影', -1.0, 1.0, 0.05),
    _SliderParam('saturation', '饱和度', -1.0, 1.0, 0.05),
    _SliderParam('temperature', '色温', -1.0, 1.0, 0.05),
    _SliderParam('vignette', '暗角', 0.0, 2.0, 0.1),
    _SliderParam('grain', '颗粒', 0.0, 1.0, 0.05),
  ];

  @override
  void initState() {
    super.initState();
    _values = Map<String, double>.from(widget.initialValues);
  }

  @override
  void didUpdateWidget(AdjustmentSliders oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset to preset defaults when preset changes
    if (widget.initialValues != oldWidget.initialValues) {
      setState(() {
        _values = Map<String, double>.from(widget.initialValues);
      });
    }
  }

  void _onSliderChanged(String key, double value) {
    setState(() {
      _values[key] = double.parse(value.toStringAsFixed(2));
    });
    widget.onChanged(Map<String, double>.from(_values));
  }

  int _changedCount() {
    return _values.entries
        .where((e) =>
            (widget.initialValues[e.key] ?? 0.0).abs() - e.value.abs() > 0.001)
        .length;
  }

  @override
  Widget build(BuildContext context) {
    final changedCount = _changedCount();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Toggle header
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.white.withOpacity(0.04),
            child: Row(
              children: [
                const Icon(Icons.tune, size: 16, color: Colors.white54),
                const SizedBox(width: 8),
                const Text(
                  '参数调整',
                  style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                ),
                if (changedCount > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$changedCount',
                      style: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
                const Spacer(),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: Colors.white38,
                ),
              ],
            ),
          ),
        ),

        // Sliders
        if (_expanded)
          SizedBox(
            height: 280,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              itemCount: _params.length,
              separatorBuilder: (_, __) => const SizedBox(height: 2),
              itemBuilder: (context, index) {
                final param = _params[index];
                final value = _values[param.key] ?? 0.0;
                final defaultValue = widget.initialValues[param.key] ?? 0.0;
                final isChanged = (value - defaultValue).abs() > 0.001;

                return _SliderRow(
                  label: param.label,
                  value: value,
                  min: param.min,
                  max: param.max,
                  step: param.step,
                  isModified: isChanged,
                  onChanged: (v) => _onSliderChanged(param.key, v),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final double step;
  final bool isModified;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.isModified,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 56,
          child: Row(
            children: [
              if (isModified)
                Container(
                  width: 4,
                  height: 4,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.amber,
                  ),
                ),
              Text(
                label,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () {
            final newVal = (value - step).clamp(min, max);
            onChanged(newVal);
          },
          icon: const Icon(Icons.remove, size: 16),
          color: Colors.white24,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: Colors.amber.withOpacity(0.6),
              inactiveTrackColor: Colors.white.withOpacity(0.1),
              thumbColor: Colors.amber,
              overlayColor: Colors.amber.withOpacity(0.1),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
        IconButton(
          onPressed: () {
            final newVal = (value + step).clamp(min, max);
            onChanged(newVal);
          },
          icon: const Icon(Icons.add, size: 16),
          color: Colors.white24,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
        SizedBox(
          width: 36,
          child: Text(
            value.toStringAsFixed(value == value.roundToDouble() ? 1 : 2),
            style: TextStyle(
              color: isModified ? Colors.amber.withOpacity(0.7) : Colors.white30,
              fontSize: 11,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

class _SliderParam {
  final String key;
  final String label;
  final double min;
  final double max;
  final double step;

  const _SliderParam(this.key, this.label, this.min, this.max, this.step);
}
