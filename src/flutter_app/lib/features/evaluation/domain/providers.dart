/// Riverpod providers for preset loading, GPU LUT engine, and editing state.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'services/preset_loader.dart';
import 'services/gpu_lut_engine.dart';
import 'services/local_evaluation_engine.dart';
import '../../../shared/models/preset.dart';

// ── Preset Loading ──────────────────────────────────────────────

/// The PresetLoader instance, initialized lazily.
/// Uses fire-and-forget init pattern (same as HybridSceneAnalyzer).
final presetLoaderProvider = Provider<PresetLoader>((ref) {
  final loader = PresetLoader();
  loader.load();
  return loader;
});

// ── GPU LUT Engine ──────────────────────────────────────────────

/// GPU-accelerated Hald CLUT engine for real-time preset preview.
final gpuLutEngineProvider = Provider<GpuLutEngine>((ref) {
  final engine = GpuLutEngine();
  engine.init();
  return engine;
});

/// Local evaluation engine — scores photos without cloud API.
final localEvaluationEngineProvider = Provider<LocalEvaluationEngine>((ref) {
  return LocalEvaluationEngine();
});

// ── Active Preset ───────────────────────────────────────────────

/// The currently selected preset in the editing UI.
final activePresetProvider = StateProvider<Preset?>((ref) => null);

// ── Slider Overrides ────────────────────────────────────────────

/// User adjustment overrides on top of preset defaults.
/// Key = param name (exposure, contrast, etc.), Value = current value.
final sliderOverridesProvider =
    StateProvider<Map<String, double>>((ref) => {});

// ── Computed: Effective Adjustments ─────────────────────────────

/// Merged preset defaults + user slider overrides.
final effectiveAdjustmentsProvider =
    Provider<Map<String, double>>((ref) {
  final preset = ref.watch(activePresetProvider);
  final overrides = ref.watch(sliderOverridesProvider);

  final defaults = <String, double>{
    'exposure': 0,
    'contrast': 0,
    'highlights': 0,
    'shadows': 0,
    'saturation': 0,
    'vibrance': 0,
    'temperature': 0,
    'tint': 0,
    'vignette': 0,
    'grain': 0,
  };

  if (preset != null) {
    final adj = preset.adjustments;
    defaults['exposure'] = adj.exposure;
    defaults['contrast'] = adj.contrast;
    defaults['highlights'] = adj.highlights;
    defaults['shadows'] = adj.shadows;
    defaults['saturation'] = adj.saturation;
    defaults['vibrance'] = adj.vibrance;
    defaults['temperature'] = adj.temperature;
    defaults['tint'] = adj.tint;
    defaults['vignette'] = adj.vignette;
    defaults['grain'] = adj.grain;
  }

  final result = Map<String, double>.from(defaults);
  for (final entry in overrides.entries) {
    if (result.containsKey(entry.key)) {
      result[entry.key] = entry.value;
    }
  }
  return result;
});
