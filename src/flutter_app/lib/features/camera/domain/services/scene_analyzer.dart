/// Scene analysis service for Phase 1 — rule-based scene classification.
///
/// Uses time of day, GPS (optional), and simple heuristics to determine
/// the most likely scene type. Phase 2 will replace this with a TFLite
/// MobileNet classifier for 20+ scene categories.

import 'dart:math';

/// Scene analysis result sent to the recommendation engine.
class SceneAnalysisResult {
  /// Internal scene key (outdoor/street/indoor/beach/night)
  final String sceneClass;

  /// Confidence score [0.0–1.0]
  final double confidence;

  /// Human-readable scene label
  final String label;

  /// Time of day classification
  final String timeOfDay;

  /// Dominant colors detected (placeholder)
  final List<String> colorPalette;

  const SceneAnalysisResult({
    required this.sceneClass,
    this.confidence = 0.8,
    this.label = '',
    this.timeOfDay = 'afternoon',
    this.colorPalette = const [],
  });
}

/// Rule-based scene analyzer for Phase 1 MVP.
///
/// Determines scene type from:
/// - Time of day (golden hour → outdoor/beach; evening/night → night)
/// - GPS / location hint (if provided)
/// - Season context
class SceneAnalyzer {
  // Default to outdoor since it's the most common use case.
  String _currentScene = 'outdoor-nature';
  final Map<String, String> _locationSceneHints = {};

  /// Set a GPS-based location hint for scene disambiguation.
  void setLocationHint(double lat, double lon) {
    // Near water (coastal) → beach
    if (lat > 18.0 && lat < 40.0 && _isNearCoastline(lat, lon)) {
      _locationSceneHints['coastal'] = 'beach';
    }
  }

  /// Analyze the current environment and return scene classification.
  ///
  /// In Phase 1, this uses rules. Phase 2 will use TFLite scene classifier.
  SceneAnalysisResult analyze({
    required DateTime now,
    double? latitude,
    double? longitude,
  }) {
    final hour = now.hour;
    final month = now.month;

    String sceneClass = 'outdoor-nature';
    String timeOfDay = 'afternoon';
    double confidence = 0.65;

    // Determine time of day
    if (hour >= 5 && hour < 7) {
      timeOfDay = 'dawn';
    } else if (hour >= 7 && hour < 10) {
      timeOfDay = 'morning';
    } else if (hour >= 10 && hour < 16) {
      timeOfDay = 'afternoon';
    } else if (hour >= 16 && hour < 18) {
      timeOfDay = 'golden-hour';
    } else if (hour >= 18 && hour < 20) {
      timeOfDay = 'dusk';
    } else {
      timeOfDay = 'night';
      sceneClass = 'night-scene';
      confidence = 0.85;
    }

    // Nighttime always → night scene
    if (timeOfDay == 'night') {
      sceneClass = 'night-scene';
      confidence = 0.9;
    }
    // Golden hour → bias toward outdoor/beach
    else if (timeOfDay == 'golden-hour') {
      sceneClass = 'outdoor-nature';
      confidence = 0.75;
    }
    // Dawn → outdoor
    else if (timeOfDay == 'dawn') {
      sceneClass = 'outdoor-nature';
      confidence = 0.7;
    }

    // GPS-based hints
    if (latitude != null && longitude != null) {
      setLocationHint(latitude, longitude);
      if (_locationSceneHints.containsKey('coastal')) {
        sceneClass = 'beach';
        confidence = 0.78;
      }
    }

    // Seasonal adjustments
    // Summer months → higher beach probability
    if (month >= 6 && month <= 8 && timeOfDay == 'afternoon') {
      // Could be beach — but don't override coastal GPS
      if (sceneClass == 'outdoor-nature' && Random().nextDouble() < 0.3) {
        sceneClass = 'beach';
        confidence = 0.55; // lower confidence since it's a guess
      }
    }

    // Apply manual override if user has set a scene
    final effectiveScene = _currentScene;
    if (effectiveScene != sceneClass) {
      // manual override takes precedence
      confidence = 1.0;
    }

    _currentScene = effectiveScene;

    return SceneAnalysisResult(
      sceneClass: effectiveScene,
      confidence: confidence,
      label: _sceneLabel(effectiveScene),
      timeOfDay: timeOfDay,
      colorPalette: _guessColors(sceneClass, timeOfDay),
    );
  }

  /// Manually set the scene (user override).
  void setScene(String sceneClass) {
    _currentScene = sceneClass;
  }

  /// Get current scene class.
  String get currentScene => _currentScene;

  /// Check if current time is golden hour (best lighting).
  bool isGoldenHour(DateTime now) {
    final h = now.hour;
    return (h >= 6 && h < 8) || (h >= 16 && h < 18);
  }

  String _sceneLabel(String key) {
    const labels = {
      'outdoor-nature': '户外自然',
      'urban-street': '城市街拍',
      'indoor': '室内',
      'beach': '海滩',
      'night-scene': '夜景',
    };
    return labels[key] ?? key;
  }

  List<String> _guessColors(String scene, String timeOfDay) {
    // Phase 1: return typical palette per scene
    const palettes = {
      'outdoor-nature': ['green', 'blue', 'brown'],
      'urban-street': ['gray', 'red', 'white'],
      'indoor': ['warm-yellow', 'brown', 'white'],
      'beach': ['blue', 'sand', 'white'],
      'night-scene': ['black', 'neon-blue', 'warm-orange'],
    };
    return palettes[scene] ?? ['green', 'blue'];
  }

  /// Simple check if coordinates are near a coastline (China coast approx).
  bool _isNearCoastline(double lat, double lon) {
    // Simplified: China's eastern/southern coastline is roughly east of 110°E
    // and south of 41°N. This is a very rough heuristic.
    return (lon > 110.0 && lon < 122.0 && lat > 18.0 && lat < 41.0);
  }
}
