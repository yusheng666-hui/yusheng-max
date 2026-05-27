/// GPU-accelerated Hald CLUT engine using Flutter FragmentProgram.
///
/// Loads a 64×64 Hald CLUT PNG as a GPU texture and applies it to the
/// captured photo via a custom fragment shader. The shader also handles
/// exposure, contrast, saturation, temperature, and vignette adjustments
/// in a single GPU pass.
///
/// For full-resolution export, use the .cube LUT via CPU — this engine
/// targets real-time preview at up to 1080px.

import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/services.dart' show rootBundle;

class GpuLutEngine {
  ui.FragmentProgram? _program;
  final Map<String, ui.Image> _haldTextures = {};
  bool _isReady = false;

  bool get isReady => _isReady;

  /// Load the fragment program from assets. Fire-and-forget at startup.
  Future<void> init() async {
    try {
      _program = await ui.FragmentProgram.fromAsset('shaders/hald_clut.frag');
      _isReady = true;
    } catch (_) {
      _isReady = false;
    }
  }

  /// Load a preset's Hald CLUT PNG as a GPU-samplable texture.
  Future<void> loadPresetTexture(String presetId) async {
    if (_haldTextures.containsKey(presetId)) return;

    try {
      final bytes =
          await rootBundle.load('assets/presets/${presetId}_hald.png');
      final codec = await ui.instantiateImageCodec(
        bytes.buffer.asUint8List(),
        targetWidth: 64,
        targetHeight: 64,
      );
      final frame = await codec.getNextFrame();
      _haldTextures[presetId] = frame.image.clone();
      frame.image.dispose();
    } catch (_) {
      // Texture load failed — shader will render without LUT if configured
    }
  }

  /// Create a configured FragmentShader for a photo + preset + adjustments.
  ///
  /// Returns null if the shader program isn't loaded or the Hald texture
  /// for the preset hasn't been loaded.
  ///
  /// The caller must dispose the returned [ui.FragmentShader].
  ui.FragmentShader? createShader({
    required ui.Image inputPhoto,
    required String presetId,
    required double exposure,
    required double contrast,
    required double saturation,
    required double temperature,
    required double vignette,
    required ui.Size renderSize,
  }) {
    if (!_isReady || _program == null) return null;

    final haldImage = _haldTextures[presetId];
    if (haldImage == null) return null;

    final shader = _program!.fragmentShader();

    // Samplers — order matches shader declaration
    shader.setImageSampler(0, inputPhoto);
    shader.setImageSampler(1, haldImage);

    // Float uniforms — indexed in declaration order
    shader.setFloat(0, exposure);
    shader.setFloat(1, contrast);
    shader.setFloat(2, saturation);
    shader.setFloat(3, temperature);
    shader.setFloat(4, vignette);

    // vec2 uInputSize — two consecutive float indices
    shader.setFloat(5, renderSize.width);
    shader.setFloat(6, renderSize.height);

    return shader;
  }

  /// Check whether a preset's Hald texture is loaded.
  bool isTextureLoaded(String presetId) =>
      _haldTextures.containsKey(presetId);

  /// Preload the next preset texture for smooth switching.
  Future<void> preload(String presetId) => loadPresetTexture(presetId);

  void dispose() {
    for (final img in _haldTextures.values) {
      img.dispose();
    }
    _haldTextures.clear();
    _isReady = false;
    _program = null;
  }
}
