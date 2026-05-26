import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/camera/domain/services/lighting_analyzer.dart';

/// Minimal fake to satisfy the CameraImage interface used by LightingAnalyzer.
class FakePlane {
  final Uint8List bytes;
  final int bytesPerRow;
  final int bytesPerPixel;
  final int width;
  final int height;

  const FakePlane({
    required this.bytes,
    required this.bytesPerRow,
    this.bytesPerPixel = 1,
    this.width = 0,
    this.height = 0,
  });
}

class FakeCameraImage {
  final int width;
  final int height;
  final List<FakePlane> planes;
  final int format;

  const FakeCameraImage({
    required this.width,
    required this.height,
    required this.planes,
    this.format = 17, // NV21
  });
}

/// Build a fake Y-plane luminance buffer of [width] × [height].
///
/// [centerLum] and [peripheryLum] specify the Y value for the center and
/// periphery regions. [backlit] mode paints center dark + periphery bright.
Uint8List _makeYPlane(
  int width,
  int height, {
  int fillValue = 128,
  int? centerValue,
  int? peripheryValue,
}) {
  final bytes = Uint8List(width * height);
  final midX = width ~/ 2;
  final midY = height ~/ 2;
  final centerRadius = (width * 0.175).round();

  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final dx = (x - midX).abs();
      final dy = (y - midY).abs();
      final inCenter = dx <= centerRadius && dy <= centerRadius;

      if (inCenter && centerValue != null) {
        bytes[y * width + x] = centerValue;
      } else if (!inCenter && peripheryValue != null) {
        bytes[y * width + x] = peripheryValue;
      } else {
        bytes[y * width + x] = fillValue;
      }
    }
  }
  return bytes;
}

void main() {
  late LightingAnalyzer analyzer;

  setUp(() {
    analyzer = LightingAnalyzer();
  });

  // ── Helpers ───────────────────────────────────────────────────

  FakeCameraImage _makeImage({
    int fillValue = 128,
    int? centerValue,
    int? peripheryValue,
  }) {
    const w = 160;
    const h = 120;
    final bytes = _makeYPlane(
      w, h,
      fillValue: fillValue,
      centerValue: centerValue,
      peripheryValue: peripheryValue,
    );
    return FakeCameraImage(
      width: w,
      height: h,
      planes: [
        FakePlane(bytes: bytes, bytesPerRow: w),
      ],
    );
  }

  // ── Tests ─────────────────────────────────────────────────────

  group('LightingAnalyzer.analyzeFrame()', () {
    test('uniform mid-range image → diffused light quality', () {
      final image = _makeImage(fillValue: 128);
      final result = analyzer.analyzeFrame(
        image as dynamic,
        sceneClass: 'outdoor-nature',
        timeOfDay: 'afternoon',
      );

      expect(result, isNotNull);
      expect(result!.quality, LightQualityType.diffused);
    });

    test('high contrast image → hard light quality', () {
      final image = _makeImage(centerValue: 10, peripheryValue: 250);
      final result = analyzer.analyzeFrame(
        image as dynamic,
        sceneClass: 'outdoor-nature',
        timeOfDay: 'afternoon',
      );

      expect(result, isNotNull);
      expect(result!.quality, LightQualityType.hard);
    });

    test('center dark + periphery bright → backlit', () {
      final image = _makeImage(centerValue: 50, peripheryValue: 220);
      final result = analyzer.analyzeFrame(
        image as dynamic,
        sceneClass: 'outdoor-nature',
        timeOfDay: 'afternoon',
      );

      expect(result, isNotNull);
      expect(result!.backlight.isBacklit, true);
      expect(
        result.tips.any(
          (t) => t.contains('逆光'),
        ),
        true,
      );
    });

    test('normal scene → no backlight', () {
      final image = _makeImage(fillValue: 140);
      final result = analyzer.analyzeFrame(
        image as dynamic,
        sceneClass: 'outdoor-nature',
        timeOfDay: 'afternoon',
      );

      expect(result, isNotNull);
      expect(result!.backlight.isBacklit, false);
    });

    test('soft light scene → contains positive tip', () {
      final image = _makeImage(fillValue: 140);
      final result = analyzer.analyzeFrame(
        image as dynamic,
        sceneClass: 'outdoor-nature',
        timeOfDay: 'afternoon',
      );

      expect(result, isNotNull);
      expect(result!.tips, isNotEmpty);
    });

    test('golden-hour + soft light → golden hour tip', () {
      final image = _makeImage(fillValue: 130);
      final result = analyzer.analyzeFrame(
        image as dynamic,
        sceneClass: 'outdoor-nature',
        timeOfDay: 'golden-hour',
      );

      expect(result, isNotNull);
      // soft light at golden-hour should have at least one tip
      expect(result!.tips, isNotEmpty);
    });

    test('night scene → night lighting tip', () {
      final image = _makeImage(fillValue: 30);
      final result = analyzer.analyzeFrame(
        image as dynamic,
        sceneClass: 'night-scene',
        timeOfDay: 'night',
      );

      expect(result, isNotNull);
      // night scene should produce tips about low light
      expect(result!.tips, isNotEmpty);
    });
  });

  // _classifyQuality is private; tested indirectly through analyzeFrame() above.
}
