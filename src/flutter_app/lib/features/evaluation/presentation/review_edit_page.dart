/// Full-screen photo review and edit page with GPU LUT preview.
///
/// Displays the captured photo with a selected preset applied via GPU shader,
/// a horizontal preset carousel for quick switching, and expandable
/// adjustment sliders for fine-tuning exposure/contrast/etc.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/providers.dart';
import '../domain/services/gpu_lut_engine.dart';
import '../domain/services/preset_loader.dart';
import '../../../shared/models/preset.dart';
import 'widgets/preset_panel.dart';
import 'widgets/adjustment_sliders.dart';

class ReviewEditPage extends ConsumerStatefulWidget {
  final String photoPath;
  final String? recommendedPresetId;

  const ReviewEditPage({
    super.key,
    required this.photoPath,
    this.recommendedPresetId,
  });

  @override
  ConsumerState<ReviewEditPage> createState() => _ReviewEditPageState();
}

class _ReviewEditPageState extends ConsumerState<ReviewEditPage> {
  ui.Image? _photoImage;
  Preset? _activePreset;
  late Map<String, double> _sliderValues;
  int _shaderVersion = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _sliderValues = _defaultSliderValues();
    _initPage();
  }

  Map<String, double> _defaultSliderValues() => {
        'exposure': 0,
        'contrast': 0,
        'highlights': 0,
        'shadows': 0,
        'saturation': 0,
        'temperature': 0,
        'vignette': 0,
        'grain': 0,
      };

  Future<void> _initPage() async {
    try {
      // Decode photo with downsampling to max 1080px for GPU texture
      final file = File(widget.photoPath);
      if (!file.existsSync()) {
        setState(() {
          _error = '照片文件不存在';
          _loading = false;
        });
        return;
      }

      final bytes = await file.readAsBytes();
      _photoImage = await _decodeImage(bytes);

      // Wait for preset loader + GPU engine
      final presetLoader = ref.read(presetLoaderProvider);
      final gpuEngine = ref.read(gpuLutEngineProvider);

      // Ensure preset loader is ready
      if (!presetLoader.isLoaded) {
        // Provider calls load() fire-and-forget, so we may need to wait slightly
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // Select recommended or first preset
      if (widget.recommendedPresetId != null) {
        _activePreset = presetLoader.getById(widget.recommendedPresetId!);
      }
      if (_activePreset == null && presetLoader.allPresets.isNotEmpty) {
        _activePreset = presetLoader.allPresets.first;
      }

      if (_activePreset != null) {
        await gpuEngine.loadPresetTexture(_activePreset!.presetId);
        _sliderValues = _presetDefaults(_activePreset!);
      }

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _error = '加载照片失败: $e';
        _loading = false;
      });
    }
  }

  Future<ui.Image?> _decodeImage(Uint8List bytes) async {
    const maxDim = 1080;
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: maxDim,
      targetHeight: maxDim,
    );
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  Map<String, double> _presetDefaults(Preset preset) {
    return {
      'exposure': preset.adjustments.exposure,
      'contrast': preset.adjustments.contrast,
      'highlights': preset.adjustments.highlights,
      'shadows': preset.adjustments.shadows,
      'saturation': preset.adjustments.saturation,
      'temperature': preset.adjustments.temperature,
      'vignette': preset.adjustments.vignette,
      'grain': preset.adjustments.grain,
    };
  }

  Future<void> _onPresetSelected(Preset preset) async {
    final gpuEngine = ref.read(gpuLutEngineProvider);
    await gpuEngine.loadPresetTexture(preset.presetId);
    setState(() {
      _activePreset = preset;
      _sliderValues = _presetDefaults(preset);
      _shaderVersion++;
    });
  }

  void _onSlidersChanged(Map<String, double> values) {
    setState(() {
      _sliderValues = values;
      _shaderVersion++;
    });
  }

  @override
  void dispose() {
    _photoImage?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final presetLoader = ref.watch(presetLoaderProvider);
    final presets = presetLoader.allPresets;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _activePreset?.name.zh ?? '编辑',
          style: const TextStyle(color: Colors.white70, fontSize: 16),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: Colors.amber),
            onPressed: () => Navigator.pop(context, widget.photoPath),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white24),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.white24),
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: Colors.white38, fontSize: 14)),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('返回', style: TextStyle(color: Colors.white54)),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Photo preview area
                    Expanded(
                      flex: 5,
                      child: _buildPreview(),
                    ),

                    // Preset carousel
                    PresetPanel(
                      presets: presets,
                      activePresetId: _activePreset?.presetId,
                      onPresetSelected: _onPresetSelected,
                    ),

                    const Divider(height: 1, color: Colors.white12),

                    // Adjustment sliders
                    AdjustmentSliders(
                      key: ValueKey(_activePreset?.presetId ?? 'none'),
                      initialValues: _activePreset != null
                          ? _presetDefaults(_activePreset!)
                          : _defaultSliderValues(),
                      onChanged: _onSlidersChanged,
                    ),
                  ],
                ),
    );
  }

  Widget _buildPreview() {
    if (_photoImage == null) return const SizedBox.shrink();

    final gpuEngine = ref.read(gpuLutEngineProvider);
    final presetId = _activePreset?.presetId;

    if (presetId == null || !gpuEngine.isTextureLoaded(presetId)) {
      // Fallback: show raw photo
      return RawImage(
        image: _photoImage,
        fit: BoxFit.contain,
        alignment: Alignment.center,
      );
    }

    return ClipRect(
      child: CustomPaint(
        painter: _ShaderPainter(
          engine: gpuEngine,
          photo: _photoImage!,
          presetId: presetId,
          sliders: _sliderValues,
          version: _shaderVersion,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _ShaderPainter extends CustomPainter {
  final GpuLutEngine engine;
  final ui.Image photo;
  final String presetId;
  final Map<String, double> sliders;
  final int version;

  _ShaderPainter({
    required this.engine,
    required this.photo,
    required this.presetId,
    required this.sliders,
    required this.version,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final shader = engine.createShader(
      inputPhoto: photo,
      presetId: presetId,
      exposure: sliders['exposure'] ?? 0,
      contrast: sliders['contrast'] ?? 0,
      saturation: sliders['saturation'] ?? 0,
      temperature: sliders['temperature'] ?? 0,
      vignette: sliders['vignette'] ?? 0,
      renderSize: size,
    );

    if (shader == null) {
      // Fallback: raw photo
      final paint = Paint();
      final src = Rect.fromLTWH(0, 0, photo.width.toDouble(), photo.height.toDouble());
      final dst = Rect.fromLTWH(0, 0, size.width, size.height);
      canvas.drawImageRect(photo, src, dst, paint);
      return;
    }

    final paint = Paint()..shader = shader;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
    shader.dispose();
  }

  @override
  bool shouldRepaint(_ShaderPainter oldDelegate) => version != oldDelegate.version;
}
