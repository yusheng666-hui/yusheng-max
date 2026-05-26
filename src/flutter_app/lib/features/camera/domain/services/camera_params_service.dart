/// Camera parameter recommendation engine with embedded photography knowledge base.
///
/// Maps scene lighting conditions + pose requirements to specific camera settings.
/// Encodes classic photography rules (Sunny 16, exposure compensation heuristics, etc.)
/// with two guidance levels: beginner (mode suggestions) and advanced (specific values).

import 'dart:math' as math;
import '../../../../shared/models/recommendation.dart';

/// Maps scene class from analyzer to internal short key for EV lookup.
const _sceneKeyMap = <String, String>{
  'outdoor-nature': 'outdoor',
  'outdoor': 'outdoor',
  'urban-street': 'street',
  'street': 'street',
  'urban': 'street',
  'indoor': 'indoor',
  'indoor-cafe': 'indoor',
  'indoor-home': 'indoor',
  'beach': 'beach',
  'beach-coast': 'beach',
  'night-scene': 'night',
  'night': 'night',
  'night-neon': 'night',
};

/// Rich camera parameter recommendation combining scene context with pose-specific needs.
class CameraParamsRecommendation {
  // --- Beginner ---
  final String recommendedMode;
  final String hdrAdvice;
  final String flashAdvice;

  // --- Advanced ---
  final int iso;
  final String shutterSpeed;
  final double aperture;
  final double evCompensation;
  final int whiteBalance;
  final String meteringMode;
  final String meteringTarget;
  final String focusMode;
  final String focusPoint;
  final bool rawRecommended;
  final String colorProfile;

  // --- Meta ---
  final String rationale;
  final String sceneLightLabel;
  final double sceneBrightnessEv;

  const CameraParamsRecommendation({
    required this.recommendedMode,
    required this.hdrAdvice,
    required this.flashAdvice,
    required this.iso,
    required this.shutterSpeed,
    required this.aperture,
    required this.evCompensation,
    required this.whiteBalance,
    required this.meteringMode,
    required this.meteringTarget,
    required this.focusMode,
    required this.focusPoint,
    required this.rawRecommended,
    required this.colorProfile,
    required this.rationale,
    required this.sceneLightLabel,
    required this.sceneBrightnessEv,
  });
}

/// Context for camera parameter lookup — scene + pose combined.
class CameraParamContext {
  final String sceneClass;
  final String timeOfDay;
  final double lightIntensity;
  final double colorTemp;
  final double contrastRatio;
  final double subjectDistance;
  final bool isMovingPose;
  final CameraParams? poseParams;

  const CameraParamContext({
    required this.sceneClass,
    required this.timeOfDay,
    required this.lightIntensity,
    required this.colorTemp,
    required this.contrastRatio,
    required this.subjectDistance,
    required this.isMovingPose,
    this.poseParams,
  });
}

/// Photography knowledge base for camera parameter recommendation.
class CameraParamsService {
  // ── Exposure Value estimates by condition ──
  static const Map<String, double> _sceneBaseEv = {
    'beach': 16.0,
    'outdoor': 14.5,
    'street': 13.0,
    'indoor': 8.0,
    'night': 3.0,
  };

  static const Map<String, double> _todEvAdjust = {
    'dawn': -3.0,
    'morning': -1.0,
    'afternoon': 0.0,
    'golden-hour': -1.5,
    'dusk': -3.5,
    'night': -6.0,
  };

  /// Core recommendation engine.
  CameraParamsRecommendation recommend(CameraParamContext ctx) {
    final poseParams = ctx.poseParams;

    // ── Estimate scene brightness (EV) ──
    final sceneKey = _sceneKeyMap[ctx.sceneClass] ?? 'outdoor';
    final baseEv = _sceneBaseEv[sceneKey] ?? 13.0;
    final todAdj = _todEvAdjust[ctx.timeOfDay] ?? 0.0;
    final intensityFactor = ctx.lightIntensity.clamp(0.1, 2.0);
    final sceneEv = (baseEv + todAdj) * intensityFactor;

    // ── Pose-driven overrides ──
    final isMoving = ctx.isMovingPose;
    final subjectDist = ctx.subjectDistance.clamp(0.3, 10.0);

    // ── Beginner recommendations ──
    String mode = 'photo';
    String hdr = 'auto';
    String flash = 'off';

    // Mode selection
    if (ctx.sceneClass == 'night' || sceneEv < 5.0) {
      mode = 'night';
      hdr = 'off';
    } else if (ctx.contrastRatio > 4.0) {
      mode = 'hdr';
      hdr = 'on';
    } else if (subjectDist < 2.0 && !isMoving) {
      mode = 'portrait';
    }

    // Flash guidance
    if (sceneEv < 4.0 && subjectDist < 3.0) {
      flash = 'on';
    } else if (ctx.contrastRatio > 5.0 && ctx.lightIntensity > 0.6) {
      flash = 'fill';
    }

    final beginnerMode = poseParams?.beginner['mode'] as String? ?? mode;
    final beginnerHdr = poseParams?.beginner['hdr'] as String? ?? hdr;
    final beginnerFlash = poseParams?.beginner['flash'] as String? ?? flash;

    // ── Advanced recommendations ──
    // Sunny 16 base: EV 15 → f/16, ISO 100, 1/125s
    double aperture;
    int iso;
    String shutter;
    double evComp = 0.0;
    int wb;
    String metering;
    String meteringTarget;
    String focusModeStr;
    String focusPoint;
    bool raw = false;
    String colorProfile;

    if (isMoving) {
      // Fast shutter priority for action/motion poses
      shutter = _evToShutter(sceneEv, apertureHint: 2.8, minSpeed: 0.002); // >= 1/500
      aperture = _evToAperture(sceneEv, shutterSpeedHint: 0.002);
      iso = _evToIso(sceneEv, aperture, 0.002);
    } else if (subjectDist < 2.0) {
      // Wide aperture priority for portraits (background blur)
      aperture = 2.0;
      shutter = _evToShutter(sceneEv, apertureHint: aperture);
      iso = _evToIso(sceneEv, aperture, _shutterFractionToSec(shutter));
    } else {
      // Balanced for general / landscape
      aperture = 5.6;
      shutter = _evToShutter(sceneEv, apertureHint: aperture);
      iso = _evToIso(sceneEv, aperture, _shutterFractionToSec(shutter));
    }

    // Pose-specific overrides from DB
    if (poseParams != null) {
      final adv = poseParams.advanced;
      if (adv['iso'] is int) iso = adv['iso'] as int;
      if (adv['shutter_speed'] is String) shutter = adv['shutter_speed'] as String;
      if (adv['aperture'] is num) aperture = (adv['aperture'] as num).toDouble();
    }

    // Exposure compensation by scene type
    if ((ctx.sceneClass == 'beach' || ctx.sceneClass == 'beach-coast' || sceneKey == 'outdoor') && ctx.contrastRatio > 3.0) {
      evComp = 0.7; // bright scenes trick meters
    } else if (ctx.sceneClass == 'night') {
      evComp = -1.0; // preserve shadows
    } else if (ctx.contrastRatio > 5.0) {
      evComp = -0.3; // protect highlights
    }
    if (poseParams?.advanced['ev_compensation'] is num) {
      evComp = (poseParams!.advanced['ev_compensation'] as num).toDouble();
    }

    // White balance
    if (ctx.colorTemp > 5500) {
      wb = 5500; // cool light → warm it slightly
    } else if (ctx.colorTemp < 3500) {
      wb = 4500; // warm light → cool it slightly
    } else {
      wb = ctx.colorTemp.round();
    }
    if (poseParams?.advanced['white_balance'] is int) {
      wb = poseParams!.advanced['white_balance'] as int;
    }

    // Golden hour override — keep warm tones
    if (ctx.timeOfDay == 'golden-hour') {
      wb = 5200;
      colorProfile = 'warm';
    } else if (ctx.sceneClass == 'night') {
      colorProfile = 'vivid';
    } else if (ctx.contrastRatio < 2.0) {
      colorProfile = 'flat';
    } else {
      colorProfile = 'standard';
    }

    // Metering
    if (ctx.contrastRatio > 4.0) {
      metering = 'spot';
      meteringTarget = 'face';
    } else if (ctx.sceneClass == 'night') {
      metering = 'center';
      meteringTarget = 'subject';
    } else {
      metering = 'matrix';
      meteringTarget = 'scene';
    }
    if (poseParams?.advanced['metering_mode'] is String) {
      metering = poseParams!.advanced['metering_mode'] as String;
    }
    if (poseParams?.advanced['metering_target'] is String) {
      meteringTarget = poseParams!.advanced['metering_target'] as String;
    }

    // Focus
    focusModeStr = isMoving ? 'af-c' : 'af-s';
    focusPoint = subjectDist < 2.0 ? 'eye' : 'face';
    if (poseParams?.advanced['focus_mode'] is String) {
      focusModeStr = poseParams!.advanced['focus_mode'] as String;
    }
    if (poseParams?.advanced['focus_point'] is String) {
      focusPoint = poseParams!.advanced['focus_point'] as String;
    }

    // RAW for high-contrast or night
    raw = ctx.contrastRatio > 4.0 || ctx.sceneClass == 'night';
    if (poseParams?.advanced['raw'] is bool) {
      raw = poseParams!.advanced['raw'] as bool;
    }

    // ── Rationale ──
    final rationale = _buildRationale(ctx, sceneEv, isMoving, subjectDist);

    return CameraParamsRecommendation(
      recommendedMode: beginnerMode,
      hdrAdvice: beginnerHdr,
      flashAdvice: beginnerFlash,
      iso: iso,
      shutterSpeed: shutter,
      aperture: aperture,
      evCompensation: double.parse(evComp.toStringAsFixed(1)),
      whiteBalance: wb,
      meteringMode: metering,
      meteringTarget: meteringTarget,
      focusMode: focusModeStr,
      focusPoint: focusPoint,
      rawRecommended: raw,
      colorProfile: colorProfile,
      rationale: rationale,
      sceneLightLabel: _lightLabel(sceneEv),
      sceneBrightnessEv: double.parse(sceneEv.toStringAsFixed(1)),
    );
  }

  // ── Exposure triangle helpers ──

  /// Convert EV to ISO given aperture and shutter.
  /// EV = log2(N²/t) - log2(ISO/100)
  /// → ISO = 100 * N² / (t * 2^EV)
  static int _evToIso(double ev, double aperture, double shutterSec) {
    final twoPowEv = math.pow(2, ev);
    var iso = 100 * aperture * aperture / (shutterSec * twoPowEv);
    iso = iso.clamp(50, 6400);
    return _snapIso(iso.round());
  }

  /// Convert EV to shutter speed string given aperture.
  /// EV = log2(N²/t) - log2(ISO/100), ISO assumed 100.
  /// → t = N² / (2^EV)
  static String _evToShutter(double ev, {double apertureHint = 5.6, double minSpeed = 0.0}) {
    final twoPowEv = math.pow(2, ev);
    var sec = apertureHint * apertureHint / twoPowEv;
    if (minSpeed > 0 && sec > minSpeed) sec = minSpeed;
    sec = sec.clamp(0.0005, 2.0);
    return _snapShutter(sec);
  }

  /// Convert EV to aperture given shutter speed.
  /// EV = log2(N²/t), ISO assumed 100.
  /// → N = sqrt(t * 2^EV)
  static double _evToAperture(double ev, {double shutterSpeedHint = 0.008}) {
    final twoPowEv = math.pow(2, ev);
    var n = math.sqrt(shutterSpeedHint * twoPowEv);
    n = n.clamp(1.0, 16.0);
    return _snapAperture(n);
  }

  static double _shutterFractionToSec(String fraction) {
    final parts = fraction.split('/');
    if (parts.length == 2) {
      final num = double.tryParse(parts[0]) ?? 1;
      final den = double.tryParse(parts[1]) ?? 125;
      return num / den;
    }
    return 1.0 / 125;
  }

  static int _snapIso(int iso) {
    const stops = [50, 64, 80, 100, 125, 160, 200, 250, 320, 400, 500, 640, 800, 1000, 1250, 1600, 2000, 2500, 3200, 4000, 5000, 6400];
    return stops.reduce((a, b) => (a - iso).abs() < (b - iso).abs() ? a : b);
  }

  static String _snapShutter(double sec) {
    if (sec >= 1.0) return '${sec.round()}s';
    final denom = (1.0 / sec).round();
    const denominators = [2, 4, 8, 15, 30, 60, 125, 250, 500, 1000, 2000, 4000];
    final snapped = denominators.reduce((a, b) => (a - denom).abs() < (b - denom).abs() ? a : b);
    return '1/$snapped';
  }

  static double _snapAperture(double n) {
    const stops = [1.4, 2.0, 2.8, 4.0, 5.6, 8.0, 11.0, 16.0];
    final snapped = stops.reduce((a, b) => (a - n).abs() < (b - n).abs() ? a : b);
    return snapped;
  }

  // ── Labels ──

  static String _lightLabel(double ev) {
    if (ev >= 15) return 'bright-sun';
    if (ev >= 12) return 'daylight';
    if (ev >= 9) return 'overcast';
    if (ev >= 6) return 'indoor-bright';
    if (ev >= 3) return 'indoor-dim';
    return 'night';
  }

  static String _buildRationale(CameraParamContext ctx, double ev, bool moving, double dist) {
    final buf = StringBuffer();

    if (moving) {
      buf.write('动态姿势需高速快门冻结动作；');
    }
    if (dist < 1.5) {
      buf.write('近距离拍摄用大光圈虚化背景；');
    }
    if (ctx.sceneClass == 'night') {
      buf.write('夜景场景提高ISO并建议三脚架；');
    } else if (ctx.sceneClass == 'beach') {
      buf.write('明亮沙滩场景需正曝光补偿避免偏暗；');
    } else if (ctx.sceneClass == 'indoor') {
      buf.write('室内光线有限，提高ISO保证安全快门；');
    }
    if (ctx.contrastRatio > 4.0) {
      buf.write('高对比度场景用点测光锁定主体；');
    }
    if (ctx.timeOfDay == 'golden-hour') {
      buf.write('黄金时刻保留暖色调；');
    }

    if (buf.isEmpty) {
      buf.write('标准日间人像参数组合。');
    }

    return buf.toString();
  }
}
