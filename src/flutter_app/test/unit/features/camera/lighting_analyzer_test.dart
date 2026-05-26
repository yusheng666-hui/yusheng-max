import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_craft/features/camera/domain/services/lighting_analyzer.dart';

/// Build a fake Y-plane luminance buffer of [width] × [height].
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

  FrameLuminanceData _makeFrame({
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
    return FrameLuminanceData(
      yPlaneBytes: bytes,
      width: w,
      height: h,
      bytesPerRow: w,
    );
  }

  group('LightingAnalyzer.analyzeFrame()', () {
    test('uniform mid-range image → diffused light quality', () {
      final frame = _makeFrame(fillValue: 128);
      final result = analyzer.analyzeFrame(
        frame,
        sceneClass: 'outdoor-nature',
        timeOfDay: 'afternoon',
      );

      expect(result, isNotNull);
      expect(result!.quality, LightQualityType.diffused);
    });

    test('high contrast image → hard light quality', () {
      final frame = _makeFrame(centerValue: 10, peripheryValue: 250);
      final result = analyzer.analyzeFrame(
        frame,
        sceneClass: 'outdoor-nature',
        timeOfDay: 'afternoon',
      );

      expect(result, isNotNull);
      expect(result!.quality, LightQualityType.hard);
    });

    test('center dark + periphery bright → backlit', () {
      final frame = _makeFrame(centerValue: 50, peripheryValue: 220);
      final result = analyzer.analyzeFrame(
        frame,
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
      final frame = _makeFrame(fillValue: 140);
      final result = analyzer.analyzeFrame(
        frame,
        sceneClass: 'outdoor-nature',
        timeOfDay: 'afternoon',
      );

      expect(result, isNotNull);
      expect(result!.backlight.isBacklit, false);
    });

    test('soft light scene → contains positive tip', () {
      final frame = _makeFrame(fillValue: 140);
      final result = analyzer.analyzeFrame(
        frame,
        sceneClass: 'outdoor-nature',
        timeOfDay: 'afternoon',
      );

      expect(result, isNotNull);
      expect(result!.tips, isNotEmpty);
    });

    test('golden-hour + soft light → golden hour tip', () {
      final frame = _makeFrame(fillValue: 130);
      final result = analyzer.analyzeFrame(
        frame,
        sceneClass: 'outdoor-nature',
        timeOfDay: 'golden-hour',
      );

      expect(result, isNotNull);
      expect(result!.tips, isNotEmpty);
    });

    test('night scene → night lighting tip', () {
      final frame = _makeFrame(fillValue: 30);
      final result = analyzer.analyzeFrame(
        frame,
        sceneClass: 'night-scene',
        timeOfDay: 'night',
      );

      expect(result, isNotNull);
      expect(result!.tips, isNotEmpty);
    });
  });
}
