/// Evaluation models for photo review feedback.

class DimensionScore {
  final double score;
  final String labelZh;
  final String feedbackZh;

  const DimensionScore({
    required this.score,
    this.labelZh = '',
    this.feedbackZh = '',
  });

  factory DimensionScore.fromJson(Map<String, dynamic> json) {
    return DimensionScore(
      score: (json['score'] as num?)?.toDouble() ?? 0,
      labelZh: json['label_zh'] as String? ?? '',
      feedbackZh: json['feedback_zh'] as String? ?? '',
    );
  }
}

class EvaluationResult {
  final String requestId;
  final double overallScore;
  final String grade;
  final List<DimensionScore> dimensions;
  final List<String> improvementTips;
  final String encouragement;
  final String? presetRecommendation;
  final String description;

  const EvaluationResult({
    required this.requestId,
    this.overallScore = 0,
    this.grade = 'C',
    this.dimensions = const [],
    this.improvementTips = const [],
    this.encouragement = '',
    this.presetRecommendation,
    this.description = '',
  });

  factory EvaluationResult.fromJson(Map<String, dynamic> json) {
    return EvaluationResult(
      requestId: json['request_id'] as String? ?? '',
      overallScore: (json['overall_score'] as num?)?.toDouble() ?? 0,
      grade: json['grade'] as String? ?? 'C',
      dimensions: (json['dimensions'] as List<dynamic>?)
              ?.map(
                  (d) => DimensionScore.fromJson(d as Map<String, dynamic>))
              .toList() ??
          [],
      improvementTips: (json['improvement_tips'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      encouragement: json['encouragement'] as String? ?? '',
      presetRecommendation: json['preset_recommendation'] as String?,
      description: json['description'] as String? ?? '',
    );
  }
}
