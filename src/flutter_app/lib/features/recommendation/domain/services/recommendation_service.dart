/// Recommendation domain service — fetches and caches pose recommendations.

import '../../../../shared/models/recommendation.dart';
import '../../../../shared/models/scene_features.dart';

/// Parsed response from the recommendation API.
class RecommendationResponse {
  final String requestId;
  final List<PoseRecommendation> recommendations;
  final String? sessionId;
  final String? sceneDetected;
  final int totalCandidates;

  const RecommendationResponse({
    required this.requestId,
    required this.recommendations,
    this.sessionId,
    this.sceneDetected,
    this.totalCandidates = 0,
  });

  factory RecommendationResponse.fromJson(Map<String, dynamic> json) {
    return RecommendationResponse(
      requestId: json['request_id'] as String? ?? '',
      recommendations: (json['recommendations'] as List<dynamic>?)
              ?.map((r) => PoseRecommendation.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [],
      sessionId: json['session_id'] as String?,
      sceneDetected: json['scene_detected'] as String?,
      totalCandidates: json['total_candidates'] as int? ?? 0,
    );
  }

  bool get isEmpty => recommendations.isEmpty;
}

/// Service that manages the recommendation state and fetching.
///
/// In Phase 1, this calls the rule-based backend API.
/// Phase 2 will add local caching and LLM-based matching.
class RecommendationService {
  RecommendationResponse? _lastResponse;
  final Map<String, dynamic> _userContext = {
    'preferred_styles': ['natural', 'fresh'],
    'preferred_difficulty': 'beginner',
    'person_count': 1,
  };

  RecommendationResponse? get lastResponse => _lastResponse;

  Map<String, dynamic> get userContext => Map.unmodifiable(_userContext);

  /// Update user style preferences.
  void setPreferredStyles(List<String> styles) {
    _userContext['preferred_styles'] = styles;
  }

  /// Set difficulty preference.
  void setPreferredDifficulty(String difficulty) {
    _userContext['preferred_difficulty'] = difficulty;
  }

  /// Set person count for multi-person modes.
  void setPersonCount(int count) {
    _userContext['person_count'] = count;
  }

  /// Store the latest recommendation response.
  void updateResponse(RecommendationResponse response) {
    _lastResponse = response;
  }

  /// Get the active (top-ranked) recommendation.
  PoseRecommendation? get activeRecommendation {
    final recs = _lastResponse?.recommendations;
    if (recs == null || recs.isEmpty) return null;
    return recs.first;
  }

  /// Get all current recommendations.
  List<PoseRecommendation> get recommendations =>
      _lastResponse?.recommendations ?? [];

  /// Select a recommendation by index (for carousel swiping).
  PoseRecommendation? selectRecommendation(int index) {
    final recs = _lastResponse?.recommendations;
    if (recs == null || index >= recs.length) return null;
    return recs[index];
  }
}
