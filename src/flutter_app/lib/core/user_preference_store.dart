/// Local persistence for user preferences and interaction history.
///
/// Stores preferred styles, difficulty, liked/skipped poses, and style affinity
/// scores to shared_preferences. Used by the recommendation engine to
/// personalize pose rankings without a cloud backend.
///
/// All writes are fire-and-forget (async but not awaited at call sites) since
/// losing a preference update on crash is acceptable.

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class UserPreferenceStore {
  static const _keyStyles = 'pref_styles';
  static const _keyDifficulty = 'pref_difficulty';
  static const _keyLikedPoses = 'liked_poses';
  static const _keySkippedPoses = 'skipped_poses';
  static const _keyStyleAffinity = 'style_affinity';
  static const _keySessions = 'total_sessions';
  static const _keyPhotos = 'total_photos';

  SharedPreferences? _prefs;

  // ── In-memory state (initialized from prefs) ──

  List<String> preferredStyles = ['natural', 'fresh'];
  String preferredDifficulty = 'beginner';
  final Set<String> likedPoseIds = {};
  final Set<String> skippedPoseIds = {};
  final Map<String, int> styleAffinity = {};
  int totalSessions = 0;
  int totalPhotos = 0;

  bool _loaded = false;
  bool get isLoaded => _loaded;

  // ── Init ─────────────────────────────────────────────────────

  Future<void> load() async {
    if (_loaded) return;
    _prefs = await SharedPreferences.getInstance();

    preferredStyles = _prefs!.getStringList(_keyStyles) ?? ['natural', 'fresh'];
    preferredDifficulty = _prefs!.getString(_keyDifficulty) ?? 'beginner';

    _decodeSet(_keyLikedPoses).forEach(likedPoseIds.add);
    _decodeSet(_keySkippedPoses).forEach(skippedPoseIds.add);

    final affStr = _prefs!.getString(_keyStyleAffinity);
    if (affStr != null) {
      final map = json.decode(affStr) as Map<String, dynamic>;
      map.forEach((k, v) => styleAffinity[k] = v as int);
    }

    totalSessions = _prefs!.getInt(_keySessions) ?? 0;
    totalPhotos = _prefs!.getInt(_keyPhotos) ?? 0;
    _loaded = true;
  }

  // ── Setters (auto-persist) ───────────────────────────────────

  void setPreferredStyles(List<String> styles) {
    preferredStyles = styles;
    _prefs?.setStringList(_keyStyles, styles);
  }

  void setPreferredDifficulty(String difficulty) {
    preferredDifficulty = difficulty;
    _prefs?.setString(_keyDifficulty, difficulty);
  }

  void likePose(String poseId, List<String> styles) {
    likedPoseIds.add(poseId);
    for (final s in styles) {
      styleAffinity[s] = (styleAffinity[s] ?? 0) + 2;
    }
    _persistSet(_keyLikedPoses, likedPoseIds);
    _persistAffinity();
  }

  void skipPose(String poseId, List<String> styles) {
    skippedPoseIds.add(poseId);
    for (final s in styles) {
      styleAffinity[s] = (styleAffinity[s] ?? 0) - 1;
    }
    _persistSet(_keySkippedPoses, skippedPoseIds);
    _persistAffinity();
  }

  void recordPhotoTaken(String poseId, List<String> styles) {
    totalPhotos++;
    for (final s in styles) {
      styleAffinity[s] = (styleAffinity[s] ?? 0) + 3;
    }
    if (!likedPoseIds.contains(poseId)) {
      likedPoseIds.add(poseId);
    }
    _prefs?.setInt(_keyPhotos, totalPhotos);
    _persistSet(_keyLikedPoses, likedPoseIds);
    _persistAffinity();
  }

  void recordSession() {
    totalSessions++;
    _prefs?.setInt(_keySessions, totalSessions);
  }

  /// Reset per-session skip list (keep affinity and likes).
  void clearSessionSkips() {
    skippedPoseIds.clear();
    _persistSet(_keySkippedPoses, skippedPoseIds);
  }

  /// Affinity score for a style, normalized to a -5..+15 range.
  double affinityFor(String style) {
    final raw = (styleAffinity[style] ?? 0).toDouble();
    return raw.clamp(-5.0, 15.0);
  }

  // ── Helpers ──────────────────────────────────────────────────

  Set<String> _decodeSet(String key) {
    final s = _prefs?.getString(key);
    if (s == null || s.isEmpty) return {};
    try {
      return (json.decode(s) as List<dynamic>).map((e) => e.toString()).toSet();
    } catch (_) {
      return {};
    }
  }

  void _persistSet(String key, Set<String> value) {
    _prefs?.setString(key, json.encode(value.toList()));
  }

  void _persistAffinity() {
    _prefs?.setString(_keyStyleAffinity, json.encode(styleAffinity));
  }
}
