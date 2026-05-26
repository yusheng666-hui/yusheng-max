/// Loads preset metadata from the local assets bundle.
///
/// Provides fast indexed access to all 10 built-in presets for the
/// post-processing recommendation pipeline.

import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../../../../shared/models/preset.dart';

class PresetLoader {
  PresetBundle? _bundle;
  Map<String, Preset>? _byId;
  bool _loaded = false;

  bool get isLoaded => _loaded;
  int get totalPresets => _bundle?.totalPresets ?? 0;
  List<Preset> get allPresets => _bundle?.presets ?? [];

  /// Load the preset bundle JSON from assets.
  Future<void> load() async {
    if (_loaded) return;

    try {
      final jsonStr =
          await rootBundle.loadString('assets/presets/presets_bundle.json');
      final data = json.decode(jsonStr) as Map<String, dynamic>;
      _bundle = PresetBundle.fromJson(data);
      _byId = {};
      for (final p in _bundle!.presets) {
        _byId![p.presetId] = p;
      }
      _loaded = true;
    } catch (e) {
      print('PresetLoader: failed to load presets — $e');
      _bundle = const PresetBundle();
      _byId = {};
      _loaded = true;
    }
  }

  /// Get a preset by ID.
  Preset? getById(String presetId) => _byId?[presetId];

  /// Get presets suitable for a given scene type.
  List<Preset> getForScene(String sceneClass, {int limit = 5}) {
    if (_bundle == null) return [];
    final scored = <_PresetMatch>[];
    for (final p in _bundle!.presets) {
      int hits = 0;
      if (p.bestFor.sceneTypes.contains(sceneClass)) hits += 3;
      if (p.bestFor.sceneTypes.contains('all')) hits += 2;
      // Fuzzy: check if any scene tag is a substring
      for (final st in p.bestFor.sceneTypes) {
        if (sceneClass.contains(st) || st.contains(sceneClass)) {
          hits += 1;
        }
      }
      if (hits > 0) scored.add(_PresetMatch(p, hits.toDouble()));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(limit).map((s) => s.preset).toList();
  }

  /// Get presets matching user style preferences.
  List<Preset> getForStyles(List<String> preferredStyles, {int limit = 5}) {
    if (_bundle == null || preferredStyles.isEmpty) return [];
    final scored = <_PresetMatch>[];
    for (final p in _bundle!.presets) {
      int hits = 0;
      for (final ps in preferredStyles) {
        if (p.styleTags.contains(ps)) hits++;
        if (p.bestFor.styles.contains(ps)) hits++;
      }
      if (hits > 0) scored.add(_PresetMatch(p, hits.toDouble()));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(limit).map((s) => s.preset).toList();
  }
}

class _PresetMatch {
  final Preset preset;
  final double score;
  _PresetMatch(this.preset, this.score);
}
