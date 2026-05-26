/// TTS (Text-to-Speech) service wrapping flutter_tts.
///
/// Provides real-time voice guidance for pose alignment feedback.
/// Debounces to avoid spamming — won't speak more than once every 4 seconds,
/// and won't repeat the same phrase consecutively.

import 'package:flutter_tts/flutter_tts.dart';
import '../features/ar/domain/services/alignment_scorer.dart';
import '../features/camera/domain/services/lighting_analyzer.dart';
import '../shared/models/recommendation.dart';

class TtsService {
  final FlutterTts _tts = FlutterTts();

  bool _initialized = false;
  bool _muted = false;
  String? _lastText;
  DateTime _lastSpeakTime = DateTime(2000);
  bool _lastGradeWasLow = false;

  static const _minInterval = Duration(seconds: 4);

  // ── Lifecycle ──────────────────────────────────────────────────

  bool get isMuted => _muted;
  bool get isInitialized => _initialized;

  Future<void> init() async {
    if (_initialized) return;
    await _tts.setLanguage('zh-CN');
    await _tts.setSpeechRate(0.48);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
    _initialized = true;
  }

  void setMuted(bool muted) {
    _muted = muted;
    if (muted) _tts.stop();
  }

  void toggleMute() {
    setMuted(!_muted);
  }

  Future<void> dispose() async {
    await _tts.stop();
  }

  // ── Core speak with debounce ───────────────────────────────────

  Future<void> speak(String text) async {
    if (_muted || !_initialized) return;
    if (text.isEmpty) return;

    final now = DateTime.now();
    if (now.difference(_lastSpeakTime) < _minInterval) return;
    if (text == _lastText) return;

    _lastText = text;
    _lastSpeakTime = now;
    await _tts.speak(text);
  }

  // ── Pose guidance (when switching poses) ───────────────────────

  /// Speak the pose guidance for a newly selected recommendation.
  Future<void> speakPoseGuidance(PoseRecommendation rec) async {
    // Prefer voice_guidance array; fall back to guidanceText
    final lines = <String>[];

    if (rec.voiceGuidance.isNotEmpty) {
      lines.addAll(rec.voiceGuidance.take(2));
    } else if (rec.guidanceText.isNotEmpty) {
      lines.add(rec.guidanceText);
    }

    if (rec.lightingTip != null && rec.lightingTip!.isNotEmpty) {
      lines.add(rec.lightingTip!);
    }

    if (lines.isEmpty) return;

    final combined = lines.join('。');
    // Reset tracking so pose guidance always speaks on switch
    _lastText = null;
    await speak(combined);
  }

  // ── Alignment feedback ─────────────────────────────────────────

  /// Speak correction hints when alignment changes significantly.
  ///
  /// Strategy:
  /// - Score >= 85%: encouragement (only if previously low)
  /// - Score 50–84%: top 2 correction hints
  /// - Score < 50%: single most critical hint
  Future<void> speakAlignmentFeedback(AlignmentResult alignment) async {
    if (_muted || !_initialized) return;

    String? text;

    if (alignment.overallScore >= 0.80) {
      if (_lastGradeWasLow) {
        text = '很好，保持住！';
      }
      _lastGradeWasLow = false;
    } else if (alignment.overallScore >= 0.65) {
      if (alignment.hints.isNotEmpty) {
        text = alignment.hints.take(2).join('，');
      }
      _lastGradeWasLow = true;
    } else if (alignment.overallScore >= 0.4) {
      if (alignment.hints.isNotEmpty) {
        text = alignment.hints.first;
      }
      _lastGradeWasLow = true;
    } else {
      if (alignment.hints.isNotEmpty) {
        text = '差得有点远，${alignment.hints.first}';
      }
      _lastGradeWasLow = true;
    }

    if (text != null) {
      await speak(text);
    }
  }

  // ── Lighting tips ───────────────────────────────────────────────

  /// Speak lighting advice when significant conditions change.
  Future<void> speakLightingTips(LightingAnalysisResult result) async {
    if (_muted || !_initialized) return;

    String? text;

    if (result.backlight.isBacklit) {
      if (result.backlight.severity > 0.6) {
        text = '注意！你正处于严重逆光环境，建议打开闪光灯补光';
      } else {
        text = '检测到逆光，可以试试打开 HDR 或换个角度';
      }
    } else if (result.quality == LightQualityType.hard) {
      text = '光线比较硬，面部容易有阴影';
    }

    if (text != null) {
      await speak(text);
    }
  }
}
