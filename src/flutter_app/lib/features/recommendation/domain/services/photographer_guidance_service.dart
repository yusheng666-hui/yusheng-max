/// Photographer guidance engine — camera angle and composition recommendations.
///
/// Maps pose type + scene context → optimal camera angles (pitch, yaw, height)
/// and composition strategies (rule of thirds, leading lines, framing, etc.).

import '../../../../shared/models/recommendation.dart';

/// Camera angle guidance for the photographer.
class AngleGuidance {
  /// Camera pitch in degrees (-90 = overhead, 0 = eye-level, +90 = worm's-eye)
  final double pitch;

  /// Camera yaw offset in degrees (0 = straight-on, ±30 = side angle)
  final double yaw;

  /// Camera height relative to subject: 'low'/'eye'/'high'
  final String height;

  /// Human-readable angle instruction
  final String instruction;

  /// Why this angle works for the pose
  final String rationale;

  const AngleGuidance({
    required this.pitch,
    required this.yaw,
    required this.height,
    required this.instruction,
    required this.rationale,
  });

  PhotographerAngle toPhotographerAngle() => PhotographerAngle(
        pitch: pitch,
        yaw: yaw,
        height: height,
      );
}

/// Composition guidance for framing the shot.
class CompositionGuidance {
  /// Whether to show rule of thirds grid
  final bool showGrid;

  /// Subject placement: 'center' / 'left-third' / 'right-third'
  final String subjectPlacement;

  /// Composition technique to use
  final String technique;

  /// Leading lines direction or null
  final String? leadingLines;

  /// Framing suggestion
  final String? framing;

  /// Human-readable composition instruction
  final String instruction;

  /// Why this composition works
  final String rationale;

  const CompositionGuidance({
    required this.showGrid,
    required this.subjectPlacement,
    required this.technique,
    required this.leadingLines,
    required this.framing,
    required this.instruction,
    required this.rationale,
  });

  CompositionHints toCompositionHints() => CompositionHints(
        ruleOfThirdsGrid: showGrid,
        alignment: subjectPlacement,
      );
}

/// Combined photographer guidance for the current pose + scene.
class PhotographerGuidance {
  final AngleGuidance angle;
  final CompositionGuidance composition;

  const PhotographerGuidance({
    required this.angle,
    required this.composition,
  });
}

/// Maps pose characteristics + scene → optimal photographer position and framing.
class PhotographerGuidanceService {
  // ── Pose category → default angle ──

  static const _poseAngleDefaults = <String, _AnglePreset>{
    'solo': _AnglePreset(pitch: 0, yaw: 0, height: 'eye', rationale: '单人照眼平角度最自然，与观者建立连接'),
    'couple': _AnglePreset(pitch: 0, yaw: 0, height: 'eye', rationale: '双人照保持眼平，避免透视变形导致身高差失真'),
    'friends': _AnglePreset(pitch: -5, yaw: 0, height: 'high', rationale: '多人合照略高角度能拍到所有人脸'),
    'family': _AnglePreset(pitch: -5, yaw: 0, height: 'high', rationale: '家庭照稍高角度包容不同身高'),
    'expression': _AnglePreset(pitch: 0, yaw: 0, height: 'eye', rationale: '表情特写眼平角度最传神'),
    'advanced_solo': _AnglePreset(pitch: -10, yaw: 15, height: 'low', rationale: '进阶姿势用低角度增加张力和视觉冲击'),
  };

  // ── Pose tag → angle overrides ──

  static const _poseTagAngles = <String, _AnglePreset>{
    'sitting': _AnglePreset(pitch: -5, yaw: 0, height: 'low', rationale: '坐姿用低角度拉长腿部线条'),
    'lying': _AnglePreset(pitch: -20, yaw: 0, height: 'high', rationale: '躺姿用高角度俯拍展现全身'),
    'jumping': _AnglePreset(pitch: -15, yaw: 0, height: 'low', rationale: '跳跃用低角度仰拍增加腾空感'),
    'looking-up': _AnglePreset(pitch: -10, yaw: 0, height: 'low', rationale: '仰头姿势配合低角度强化向上的视线'),
    'looking-down': _AnglePreset(pitch: 10, yaw: 0, height: 'high', rationale: '低头姿势配合高角度捕捉睫毛和下颌线'),
    'back-view': _AnglePreset(pitch: 0, yaw: 0, height: 'eye', rationale: '背影照眼平角度最佳，让背景成为主角'),
    'side-profile': _AnglePreset(pitch: 0, yaw: 15, height: 'eye', rationale: '侧脸用微侧角度突出轮廓线'),
  };

  // ── Composition strategies by pose type ──

  static const _poseCompositions = <String, _CompositionPreset>{
    'solo': _CompositionPreset(
      placement: 'right-third',
      technique: 'rule-of-thirds',
      leadingLines: null,
      framing: null,
      rationale: '单人放三分线让视线有延伸空间',
    ),
    'couple': _CompositionPreset(
      placement: 'center',
      technique: 'centered',
      leadingLines: null,
      framing: 'arch',
      rationale: '双人中置构图强调对称与亲密感',
    ),
    'friends': _CompositionPreset(
      placement: 'center',
      technique: 'centered',
      leadingLines: null,
      framing: null,
      rationale: '多人合照居中构图确保所有人入镜',
    ),
    'family': _CompositionPreset(
      placement: 'center',
      technique: 'centered',
      leadingLines: null,
      framing: 'door-frame',
      rationale: '家庭照居中构图+门框取景增加温馨感',
    ),
    'expression': _CompositionPreset(
      placement: 'center',
      technique: 'centered',
      leadingLines: null,
      framing: null,
      rationale: '表情特写居中聚焦面部',
    ),
    'advanced_solo': _CompositionPreset(
      placement: 'left-third',
      technique: 'rule-of-thirds',
      leadingLines: 'diagonal',
      framing: null,
      rationale: '进阶构图用斜线引导增加画面动感',
    ),
  };

  // ── Scene → composition modifier ──

  static const _sceneCompositionMods = <String, _CompositionMod>{
    'beach': _CompositionMod(leadingLines: 'shoreline', framing: 'horizon'),
    'street': _CompositionMod(leadingLines: 'road-lines', framing: 'architecture'),
    'indoor': _CompositionMod(leadingLines: null, framing: 'window'),
    'outdoor': _CompositionMod(leadingLines: 'path', framing: 'trees'),
    'night': _CompositionMod(leadingLines: 'light-trail', framing: 'neon'),
  };

  // ── Scene → angle modifier ──

  static const _sceneAngleMods = <String, _AnglePreset>{
    'beach': _AnglePreset(pitch: -5, yaw: 0, height: 'low', rationale: '低角度纳入更多天空，减少杂乱沙滩'),
    'street': _AnglePreset(pitch: 0, yaw: 5, height: 'eye', rationale: '街拍保持自然视角，微侧角利用建筑线条'),
    'indoor': _AnglePreset(pitch: 0, yaw: 0, height: 'eye', rationale: '室内空间有限，眼平角度最稳妥'),
    'outdoor': _AnglePreset(pitch: -3, yaw: 0, height: 'eye', rationale: '户外略低角度纳入树冠和天空'),
    'night': _AnglePreset(pitch: 0, yaw: 10, height: 'eye', rationale: '夜景微侧角度捕捉霓虹灯光'),
  };

  // ── Scene key mapping ──

  static const _sceneKeyMap = <String, String>{
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

  // ── Public API ──

  /// Generate photographer guidance for the current pose + scene.
  PhotographerGuidance recommend({
    required String sceneClass,
    required String category,
    List<String> poseTags = const [],
  }) {
    final sceneKey = _sceneKeyMap[sceneClass] ?? 'outdoor';

    // Determine angle — pose tags override category, then scene modifies
    _AnglePreset anglePreset = _poseAngleDefaults[category] ?? _poseAngleDefaults['solo']!;

    for (final tag in poseTags) {
      if (_poseTagAngles.containsKey(tag)) {
        anglePreset = _poseTagAngles[tag]!;
        break;
      }
    }

    final sceneAngle = _sceneAngleMods[sceneKey];
    final finalPitch = anglePreset.pitch + (sceneAngle?.pitch ?? 0);
    final finalYaw = anglePreset.yaw + (sceneAngle?.yaw ?? 0);
    final finalHeight = sceneAngle?.height ?? anglePreset.height;

    final rationaleParts = <String>[anglePreset.rationale];
    if (sceneAngle?.rationale != null && sceneAngle!.rationale.isNotEmpty) {
      rationaleParts.add(sceneAngle.rationale);
    }

    final angle = AngleGuidance(
      pitch: finalPitch.clamp(-30.0, 30.0).toDouble(),
      yaw: finalYaw.clamp(-45.0, 45.0).toDouble(),
      height: finalHeight,
      instruction: _angleInstruction(finalPitch, finalYaw, finalHeight),
      rationale: rationaleParts.join('。'),
    );

    // Determine composition — pose category + scene modifiers
    final compPreset = _poseCompositions[category] ?? _poseCompositions['solo']!;
    final sceneComp = _sceneCompositionMods[sceneKey];

    final composition = CompositionGuidance(
      showGrid: compPreset.technique == 'rule-of-thirds',
      subjectPlacement: compPreset.placement,
      technique: compPreset.technique,
      leadingLines: sceneComp?.leadingLines ?? compPreset.leadingLines,
      framing: sceneComp?.framing ?? compPreset.framing,
      instruction: _compositionInstruction(compPreset, sceneComp),
      rationale: compPreset.rationale,
    );

    return PhotographerGuidance(
      angle: angle,
      composition: composition,
    );
  }

  // ── Instruction formatters ──

  String _angleInstruction(double pitch, double yaw, String height) {
    final heightStr = switch (height) {
      'low' => '蹲下或放低手机',
      'high' => '举高手机或踩台阶',
      _ => '保持手机与眼睛同高',
    };
    final pitchStr = pitch < -5 ? '微微仰拍' : (pitch > 5 ? '微微俯拍' : '平视拍摄');
    final yawStr = yaw.abs() > 5
        ? '向${yaw > 0 ? "右" : "左"}偏${yaw.abs().round()}度'
        : '';
    return '$heightStr，$pitchStr${yawStr.isNotEmpty ? "，$yawStr" : ""}';
  }

  String _compositionInstruction(_CompositionPreset preset, _CompositionMod? scene) {
    final buf = StringBuffer();
    if (preset.technique == 'rule-of-thirds') {
      buf.write('将人物放在${preset.placement == 'left-third' ? '左' : '右'}三分线上');
    } else {
      buf.write('将人物置于画面中央');
    }
    final lead = scene?.leadingLines ?? preset.leadingLines;
    if (lead != null) {
      final leadStr = switch (lead) {
        'shoreline' => '，利用海岸线做引导线',
        'road-lines' => '，利用道路标线做引导线',
        'path' => '，利用小路做引导线',
        'light-trail' => '，利用车灯光轨做引导线',
        'diagonal' => '，利用对角线增加动感',
        _ => '',
      };
      buf.write(leadStr);
    }
    buf.write('。');
    return buf.toString();
  }
}

// ── Internal presets ──

class _AnglePreset {
  final double pitch;
  final double yaw;
  final String height;
  final String rationale;
  const _AnglePreset({
    required this.pitch,
    required this.yaw,
    required this.height,
    required this.rationale,
  });
}

class _CompositionPreset {
  final String placement;
  final String technique;
  final String? leadingLines;
  final String? framing;
  final String rationale;
  const _CompositionPreset({
    required this.placement,
    required this.technique,
    this.leadingLines,
    this.framing,
    required this.rationale,
  });
}

class _CompositionMod {
  final String? leadingLines;
  final String? framing;
  const _CompositionMod({this.leadingLines, this.framing});
}
