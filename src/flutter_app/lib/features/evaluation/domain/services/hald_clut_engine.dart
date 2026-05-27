/// CPU-based Hald CLUT application engine.
///
/// Applies a Hald CLUT (level 8, 64×64 PNG) to an image for real-time
/// preset preview. For full-resolution output, use the .cube LUT via
/// a GPU shader (Phase 2). Phase 1 uses CPU for thumbnail previews (< 200ms).

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/services.dart' show rootBundle;

class HaldClutEngine {
  /// Level of the Hald CLUT (8 = 512 samples per channel).
  static const int level = 8;

  /// Cached Hald CLUT textures keyed by preset ID.
  final Map<String, _HaldTexture> _cache = {};

  /// Load a Hald CLUT PNG from assets into a usable texture.
  Future<void> loadPreset(String presetId) async {
    if (_cache.containsKey(presetId)) return;

    final bytes = await rootBundle.load('assets/presets/${presetId}_hald.png');
    final codec = await ui.instantiateImageCodec(
      bytes.buffer.asUint8List(),
      targetWidth: level * level,
      targetHeight: level * level,
    );
    final frame = await codec.getNextFrame();
    final image = frame.image;

    // Read pixel data
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) return;

    _cache[presetId] = _HaldTexture(
      data: byteData,
      width: image.width,
      height: image.height,
    );

    image.dispose();
  }

  /// Apply the loaded Hald CLUT to an image and return the result.
  ///
  /// [srcImage] is the input photo. Returns a new [ui.Image] with the
  /// LUT applied. Input is downscaled to max 256px for performance.
  Future<ui.Image?> apply(ui.Image srcImage, String presetId) async {
    final hald = _cache[presetId];
    if (hald == null) return null;

    // Downscale input for performance (max 256px wide)
    int outW = srcImage.width;
    int outH = srcImage.height;
    if (outW > 256) {
      final ratio = 256.0 / outW;
      outW = 256;
      outH = (srcImage.height * ratio).round();
    }

    // Read source pixels
    final srcBytes = await _readPixels(srcImage, outW, outH);
    if (srcBytes == null) return null;

    // Apply LUT pixel by pixel
    final resultBytes = Uint8List(outW * outH * 4);
    final haldData = hald.data;
    final haldW = hald.width;

    for (int y = 0; y < outH; y++) {
      for (int x = 0; x < outW; x++) {
        final offset = (y * outW + x) * 4;
        final r = srcBytes.getUint8(offset);
        final g = srcBytes.getUint8(offset + 1);
        final b = srcBytes.getUint8(offset + 2);
        final a = srcBytes.getUint8(offset + 3);

        // Map RGB to Hald CLUT coordinate
        // Each color channel has `level` samples (0..7)
        final rf = r / 255.0 * (level - 1);
        final gf = g / 255.0 * (level - 1);
        final bf = b / 255.0 * (level - 1);

        final r0 = rf.floor();
        final g0 = gf.floor();
        final b0 = bf.floor();
        final r1 = (r0 + 1).clamp(0, level - 1);
        final g1 = (g0 + 1).clamp(0, level - 1);
        final b1 = (b0 + 1).clamp(0, level - 1);

        final dr = rf - r0;
        final dg = gf - g0;
        final db = bf - b0;

        // Trilinear interpolation across 8 corner samples
        double outR = 0, outG = 0, outB = 0;
        for (final ri in [r0, r1]) {
          for (final gi in [g0, g1]) {
            for (final bi in [b0, b1]) {
              final weight = (ri == r0 ? 1.0 - dr : dr) *
                  (gi == g0 ? 1.0 - dg : dg) *
                  (bi == b0 ? 1.0 - db : db);

              // Hald layout: idx = r*lvl² + g*lvl + b → x = g*lvl + b, y = r
              final hx = (gi * level + bi).clamp(0, haldW - 1);
              final hy = ri.clamp(0, hald.height - 1);
              final hOffset = (hy * haldW + hx) * 4;

              outR += haldData.getUint8(hOffset) * weight;
              outG += haldData.getUint8(hOffset + 1) * weight;
              outB += haldData.getUint8(hOffset + 2) * weight;
            }
          }
        }

        resultBytes[offset] = outR.round().clamp(0, 255);
        resultBytes[offset + 1] = outG.round().clamp(0, 255);
        resultBytes[offset + 2] = outB.round().clamp(0, 255);
        resultBytes[offset + 3] = a;
      }
    }

    // Encode back to ui.Image
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      resultBytes,
      outW,
      outH,
      ui.PixelFormat.rgba8888,
      (img) => completer.complete(img),
    );
    return completer.future;
  }

  /// Read pixel data from a ui.Image, optionally resizing.
  Future<ByteData?> _readPixels(ui.Image image, int targetW, int targetH) async {
    // If same size, read directly
    if (image.width == targetW && image.height == targetH) {
      return image.toByteData(format: ui.ImageByteFormat.rawRgba);
    }

    // Resize by re-decoding
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (bytes == null) return null;

    final codec = await ui.instantiateImageCodec(
      bytes.buffer.asUint8List(),
      targetWidth: targetW,
      targetHeight: targetH,
    );
    final frame = await codec.getNextFrame();
    final resized = frame.image;
    final result = await resized.toByteData(format: ui.ImageByteFormat.rawRgba);
    resized.dispose();
    return result;
  }

  /// Check if a preset is loaded.
  bool isLoaded(String presetId) => _cache.containsKey(presetId);

  void dispose() {
    _disposed = true;
    _cache.clear();
  }
}

class _HaldTexture {
  final ByteData data;
  final int width;
  final int height;

  _HaldTexture({required this.data, required this.width, required this.height});
}
