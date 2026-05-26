/// Real-time skeleton alignment scorer.
///
/// Compares the user's detected pose (MediaPipe 33-keypoint) against
/// the target pose skeleton and returns a 0-100 alignment percentage.
///
/// Uses normalized keypoint distances with per-joint weighting.
/// Critical joints (shoulders, hips, knees) carry more weight than
/// extremities (fingers, toes).

import 'dart:math';

/// Single keypoint with normalized coordinates.
class AlignKeypoint {
  final double x;
  final double y;
  final double z;
  final double visibility;
  final int id;

  const AlignKeypoint({
    required this.id,
    this.x = 0,
    this.y = 0,
    this.z = 0,
    this.visibility = 1.0,
  });
}

/// Alignment result with detailed breakdown and correction hints.
class AlignmentResult {
  final double overallScore; // 0.0 - 1.0
  final double torsoScore;
  final double armsScore;
  final double legsScore;
  final double headScore;
  final int matchedKeypoints;
  final int totalKeypoints;

  /// Actionable correction hints in Chinese (top 2-3 most deviated joints).
  final List<String> hints;

  const AlignmentResult({
    this.overallScore = 0,
    this.torsoScore = 0,
    this.armsScore = 0,
    this.legsScore = 0,
    this.headScore = 0,
    this.matchedKeypoints = 0,
    this.totalKeypoints = 33,
    this.hints = const [],
  });

  /// Human-readable percentage (0-100).
  int get percentage => (overallScore * 100).round().clamp(0, 100);

  /// Letter grade.
  String get grade {
    if (overallScore >= 0.9) return 'A+';
    if (overallScore >= 0.8) return 'A';
    if (overallScore >= 0.65) return 'B';
    if (overallScore >= 0.5) return 'C';
    return 'D';
  }
}

/// Static scoring utility with correction hint generation.
class AlignmentScorer {
  /// Joint groups with their MediaPipe indices.
  static const _torsoJoints = [11, 12, 23, 24]; // shoulders, hips
  static const _armJoints = [13, 14, 15, 16]; // elbows, wrists
  static const _legJoints = [25, 26, 27, 28]; // knees, ankles
  static const _headJoints = [0, 2, 5, 7, 8]; // nose, eyes, ears

  /// Tracked joints for hint generation (subset with meaningful corrections).
  static const _trackedHintJoints = [0, 11, 12, 13, 14, 15, 16, 23, 24, 25, 26, 27, 28];

  /// Per-group weights (must sum to 1.0).
  static const _groupWeights = {
    'torso': 0.35,
    'arms': 0.25,
    'legs': 0.25,
    'head': 0.15,
  };

  /// Chinese body part names for each MediaPipe index.
  static const Map<int, String> _jointNames = {
    0: '头部',
    2: '左眼',
    5: '右眼',
    7: '左耳',
    8: '右耳',
    11: '左肩',
    12: '右肩',
    13: '左肘',
    14: '右肘',
    15: '左手',
    16: '右手',
    23: '左胯',
    24: '右胯',
    25: '左膝',
    26: '右膝',
    27: '左脚',
    28: '右脚',
  };

  /// Generate correction hints for the most deviated joints.
  ///
  /// Compares normalized distances per joint and produces actionable
  /// Chinese text for the top 2-3 most misaligned body parts.
  static List<String> _generateHints(
    Map<int, double> jointDistances,
    Map<int, ({double dx, double dy})> jointDeltas,
    double overallScore,
  ) {
    if (overallScore >= 0.85) return []; // no hints when almost perfect

    // Sort joints by deviation (largest first), only tracked ones
    final deviated = jointDistances.entries
        .where((e) => _trackedHintJoints.contains(e.key) && e.value > 0.03)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (deviated.isEmpty) return [];

    final hints = <String>[];
    for (int i = 0; i < deviated.length && hints.length < 3; i++) {
      final entry = deviated[i];
      final jointId = entry.key;
      final delta = jointDeltas[jointId];
      if (delta == null) continue;

      final name = _jointNames[jointId] ?? '身体';
      final hint = _composeHint(jointId, name, delta);
      if (hint != null) hints.add(hint);
    }

    return hints;
  }

  /// Compose a single correction hint based on joint and delta direction.
  static String? _composeHint(int jointId, String name, ({double dx, double dy}) delta) {
    final dx = delta.dx;
    final dy = delta.dy;
    const threshold = 0.015;
    if (dx.abs() < threshold && dy.abs() < threshold) return null;

    final absDx = dx.abs();
    final absDy = dy.abs();

    // Determine dominant axis
    String dir;
    if (absDx > absDy * 1.5) {
      dir = dx > 0 ? '往右移' : '往左移';
    } else if (absDy > absDx * 1.5) {
      dir = dy > 0 ? '往上移' : '往下移';
    } else {
      if (dx > 0 && dy > 0) dir = '往右上移';
      else if (dx > 0 && dy < 0) dir = '往右下移';
      else if (dx < 0 && dy > 0) dir = '往左上移';
      else dir = '往左下移';
    }

    // Use joint-specific verbs for better guidance
    final verb = _jointVerb(jointId);
    return '$name$verb$dir';
  }

  /// Get a joint-appropriate verb for the correction hint.
  static String _jointVerb(int jointId) {
    switch (jointId) {
      case 0: return '';
      case 11:
      case 12: return '沉肩';
      case 13:
      case 14: return '曲肘';
      case 15:
      case 16: return '';
      case 23:
      case 24: return '摆胯';
      case 25:
      case 26: return '屈膝';
      case 27:
      case 28: return '移步';
      default: return '';
    }
  }

  /// Compute the alignment score between a user pose and target pose.
  ///
  /// Both are lists of keypoints with normalized (0-1) coordinates.
  /// [userKeypoints] from ML Kit detection. [targetKeypoints] from pose DB.
  static AlignmentResult score({
    required List<AlignKeypoint> userKeypoints,
    required List<AlignKeypoint> targetKeypoints,
  }) {
    if (userKeypoints.length < 11 || targetKeypoints.length < 11) {
      return const AlignmentResult();
    }

    // Normalize both to torso scale (shoulder-to-hip distance)
    final userScale = _torsoSpan(userKeypoints);
    final targetScale = _torsoSpan(targetKeypoints);

    if (userScale <= 0 || targetScale <= 0) {
      return const AlignmentResult();
    }

    final scaleRatio = targetScale / userScale;

    int matched = 0;
    double torsoDist = 0, armsDist = 0, legsDist = 0, headDist = 0;
    final jointDistances = <int, double>{};
    final jointDeltas = <int, ({double dx, double dy})>{};

    for (int i = 0; i < min(userKeypoints.length, targetKeypoints.length); i++) {
      final uk = userKeypoints[i];
      final tk = targetKeypoints[i];
      if (uk.visibility < 0.3) continue;

      matched++;

      // Signed deltas for direction analysis
      final sdx = uk.x - tk.x * scaleRatio;
      final sdy = uk.y - tk.y * scaleRatio;
      final d = sqrt(sdx * sdx + sdy * sdy);

      jointDistances[i] = d;
      jointDeltas[i] = (dx: sdx, dy: sdy);

      if (_torsoJoints.contains(i)) {
        torsoDist += d;
      } else if (_armJoints.contains(i)) {
        armsDist += d;
      } else if (_legJoints.contains(i)) {
        legsDist += d;
      } else if (_headJoints.contains(i)) {
        headDist += d;
      }
    }

    // Average distances per group, convert to 0-1 scores
    // Max expected distance ~0.3 after normalization, so divide by 0.3 and clamp
    double _distToScore(double d, int count) {
      if (count == 0) return 0.5; // neutral for missing group
      final avgDist = d / count;
      return (1.0 - (avgDist / 0.30)).clamp(0.0, 1.0);
    }

    final torsoCount = _torsoJoints.where((j) => j < userKeypoints.length && userKeypoints[j].visibility >= 0.3).length;
    final armsCount = _armJoints.where((j) => j < userKeypoints.length && userKeypoints[j].visibility >= 0.3).length;
    final legsCount = _legJoints.where((j) => j < userKeypoints.length && userKeypoints[j].visibility >= 0.3).length;
    final headCount = _headJoints.where((j) => j < userKeypoints.length && userKeypoints[j].visibility >= 0.3).length;

    final tScore = _distToScore(torsoDist, torsoCount);
    final aScore = _distToScore(armsDist, armsCount);
    final lScore = _distToScore(legsDist, legsCount);
    final hScore = _distToScore(headDist, headCount);

    final overall = tScore * _groupWeights['torso']! +
        aScore * _groupWeights['arms']! +
        lScore * _groupWeights['legs']! +
        hScore * _groupWeights['head']!;

    final clampedOverall = overall.clamp(0.0, 1.0);

    return AlignmentResult(
      overallScore: clampedOverall,
      torsoScore: tScore,
      armsScore: aScore,
      legsScore: lScore,
      headScore: hScore,
      matchedKeypoints: matched,
      totalKeypoints: userKeypoints.length,
      hints: _generateHints(jointDistances, jointDeltas, clampedOverall),
    );
  }

  /// Compute the torso span (shoulder midpoint to hip midpoint distance).
  static double _torsoSpan(List<AlignKeypoint> kps) {
    if (kps.length < 25) return 1.0;

    double sx = 0, sy = 0, hx = 0, hy = 0;
    int sCount = 0, hCount = 0;

    for (final j in _torsoJoints) {
      if (j < kps.length && kps[j].visibility >= 0.3) {
        if (j == 11 || j == 12) {
          sx += kps[j].x; sy += kps[j].y; sCount++;
        } else {
          hx += kps[j].x; hy += kps[j].y; hCount++;
        }
      }
    }

    if (sCount == 0 || hCount == 0) return 1.0;
    sx /= sCount; sy /= sCount;
    hx /= hCount; hy /= hCount;
    return sqrt((sx - hx) * (sx - hx) + (sy - hy) * (sy - hy));
  }
}
