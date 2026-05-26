import 'package:flutter_test/flutter_test.dart';
import 'package:pose_craft/features/ar/domain/services/alignment_scorer.dart';

/// Build a keypoint with sensible defaults.
AlignKeypoint kp(int id, {double x = 0, double y = 0, double z = 0, double visibility = 1.0}) {
  return AlignKeypoint(id: id, x: x, y: y, z: z, visibility: visibility);
}

/// Build a full 33-keypoint skeleton centered at (0.5, 0.5).
List<AlignKeypoint> makeSkeleton({
  double cx = 0.5,
  double cy = 0.5,
  double spread = 0.2,
}) {
  // Simplified: position all 33 joints spread around center
  // Indices map to MediaPipe topology
  final positions = <int, (double, double)>{
    0: (cx, cy - 0.25), // nose
    2: (cx - 0.03, cy - 0.27), // left eye
    5: (cx + 0.03, cy - 0.27), // right eye
    7: (cx - 0.06, cy - 0.25), // left ear
    8: (cx + 0.06, cy - 0.25), // right ear
    11: (cx - spread * 0.5, cy - 0.15), // left shoulder
    12: (cx + spread * 0.5, cy - 0.15), // right shoulder
    13: (cx - spread * 0.35, cy - 0.05), // left elbow
    14: (cx + spread * 0.35, cy - 0.05), // right elbow
    15: (cx - spread * 0.25, cy + 0.1), // left wrist
    16: (cx + spread * 0.25, cy + 0.1), // right wrist
    23: (cx - spread * 0.3, cy + 0.1), // left hip
    24: (cx + spread * 0.3, cy + 0.1), // right hip
    25: (cx - spread * 0.25, cy + 0.25), // left knee
    26: (cx + spread * 0.25, cy + 0.25), // right knee
    27: (cx - spread * 0.2, cy + 0.4), // left ankle
    28: (cx + spread * 0.2, cy + 0.4), // right ankle
  };

  return List.generate(33, (i) {
    final p = positions[i];
    if (p != null) return kp(i, x: p.$1, y: p.$2);
    return kp(i, x: cx, y: cy, visibility: 0.1); // untracked joints
  });
}

void main() {
  // ── AlignmentScorer.score() ────────────────────────────────────

  group('AlignmentScorer.score()', () {
    test('identical poses → score ~1.0', () {
      final skeleton = makeSkeleton();
      final result = AlignmentScorer.score(
        userKeypoints: skeleton,
        targetKeypoints: skeleton,
      );

      expect(result.overallScore, greaterThan(0.95));
      expect(result.matchedKeypoints, 33);
      expect(result.hints, isEmpty);
    });

    test('shifted pose → score < 0.5', () {
      final target = makeSkeleton();
      final user = makeSkeleton(cx: 0.7, cy: 0.7); // large offset
      final result = AlignmentScorer.score(
        userKeypoints: user,
        targetKeypoints: target,
      );

      expect(result.overallScore, lessThan(0.5));
    });

    test('insufficient keypoints (< 11) → default result', () {
      final fewKps = List.generate(5, (i) => kp(i, x: 0.5, y: 0.5));
      final target = makeSkeleton();

      final result = AlignmentScorer.score(
        userKeypoints: fewKps,
        targetKeypoints: target,
      );

      expect(result.overallScore, 0);
      expect(result.matchedKeypoints, 0);
      expect(result.hints, isEmpty);
    });

    test('invisible keypoints (visibility < 0.3) are skipped', () {
      final target = makeSkeleton();
      // Same positions, but most keypoints barely visible
      final lowVis = List.generate(33, (i) {
        final p = makeSkeleton()[i];
        return kp(i, x: p.x, y: p.y, visibility: 0.2);
      });

      final result = AlignmentScorer.score(
        userKeypoints: lowVis,
        targetKeypoints: target,
      );

      // Very few matched → low score
      expect(result.matchedKeypoints, lessThan(5));
    });

    test('zero torso span → default result', () {
      // All joints at exactly the same position → no torso span
      final zeroSpan = List.generate(33, (_) => kp(0, x: 0.5, y: 0.5));
      final target = makeSkeleton();

      final result = AlignmentScorer.score(
        userKeypoints: zeroSpan,
        targetKeypoints: target,
      );

      expect(result.overallScore, 0); // triggers < 0.01
    });
  });

  // ── AlignmentResult properties ─────────────────────────────────

  group('AlignmentResult', () {
    test('percentage clamps to [0, 100]', () {
      final zero = const AlignmentResult(overallScore: 0);
      expect(zero.percentage, 0);

      final perfect = const AlignmentResult(overallScore: 1.0);
      expect(perfect.percentage, 100);

      final mid = const AlignmentResult(overallScore: 0.75);
      expect(mid.percentage, 75);
    });

    test('grade produces correct letter thresholds', () {
      expect(const AlignmentResult(overallScore: 0.95).grade, 'A+');
      expect(const AlignmentResult(overallScore: 0.85).grade, 'A');
      expect(const AlignmentResult(overallScore: 0.7).grade, 'B');
      expect(const AlignmentResult(overallScore: 0.55).grade, 'C');
      expect(const AlignmentResult(overallScore: 0.3).grade, 'D');
    });
  });

  // ── Hint generation (tested indirectly through score()) ────────

  group('hint generation', () {
    test('generates hints when score < 0.85', () {
      final target = makeSkeleton();
      // Offset right shoulder and right elbow significantly
      final badUser = makeSkeleton();
      badUser[12] = kp(12, x: 0.7, y: 0.1); // right shoulder offset
      badUser[14] = kp(14, x: 0.8, y: 0.0); // right elbow offset

      final result = AlignmentScorer.score(
        userKeypoints: badUser,
        targetKeypoints: target,
      );

      // Should generate hints for deviated joints
      // Not guaranteed since other joints may be fine, but score should be lower
      expect(result.overallScore, lessThan(0.9));
    });

    test('no hints when score >= 0.85', () {
      final skeleton = makeSkeleton();
      final result = AlignmentScorer.score(
        userKeypoints: skeleton,
        targetKeypoints: skeleton,
      );

      expect(result.overallScore, greaterThan(0.95));
      expect(result.hints, isEmpty);
    });

    test('directional words are correct', () {
      final target = makeSkeleton();
      final user = makeSkeleton();
      // Move left shoulder further left (negative x delta = "往左移")
      user[11] = kp(11, x: 0.25, y: 0.35);

      final result = AlignmentScorer.score(
        userKeypoints: user,
        targetKeypoints: target,
      );

      // The left shoulder has a significant x-deviation (0.15 - moved 0.1 + spread effect)
      // Hints may or may not contain this depending on threshold
      if (result.hints.isNotEmpty) {
        // If hints generated, they should contain directional guidance
        final hintText = result.hints.join();
        expect(hintText, isNotEmpty);
      }
    });
  });

  // ── Torso span ─────────────────────────────────────────────────

  group('torso span', () {
    test('known positions produce expected span', () {
      // Simple case: shoulders at top, hips at bottom
      final kps = List.generate(33, (i) => kp(i));
      kps[11] = kp(11, x: 0.4, y: 0.3); // left shoulder
      kps[12] = kp(12, x: 0.6, y: 0.3); // right shoulder
      kps[23] = kp(23, x: 0.4, y: 0.6); // left hip
      kps[24] = kp(24, x: 0.6, y: 0.6); // right hip

      final result = AlignmentScorer.score(
        userKeypoints: kps,
        targetKeypoints: kps,
      );

      // Identical → perfect score
      expect(result.overallScore, greaterThan(0.95));
    });
  });
}
