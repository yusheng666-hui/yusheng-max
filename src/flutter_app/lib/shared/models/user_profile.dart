/// User profile model matching the backend UserOut schema.

class UserProfile {
  final String userId;
  final String username;
  final String displayName;
  final String gender;
  final String ageRange;
  final double heightCm;
  final String bodyType;
  final String faceShape;
  final String skinTone;
  final List<String> preferredStyles;
  final String preferredDifficulty;
  final String photographyLevel;
  final double qualityScore;
  final int totalSessions;
  final int totalPhotos;
  final String createdAt;
  final String updatedAt;

  const UserProfile({
    required this.userId,
    this.username = '',
    this.displayName = '',
    this.gender = 'unspecified',
    this.ageRange = '18-25',
    this.heightCm = 165.0,
    this.bodyType = 'average',
    this.faceShape = 'oval',
    this.skinTone = 'medium',
    this.preferredStyles = const ['natural', 'fresh'],
    this.preferredDifficulty = 'beginner',
    this.photographyLevel = 'beginner',
    this.qualityScore = 5.0,
    this.totalSessions = 0,
    this.totalPhotos = 0,
    this.createdAt = '',
    this.updatedAt = '',
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: json['user_id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      gender: json['gender'] as String? ?? 'unspecified',
      ageRange: json['age_range'] as String? ?? '18-25',
      heightCm: (json['height_cm'] as num?)?.toDouble() ?? 165.0,
      bodyType: json['body_type'] as String? ?? 'average',
      faceShape: json['face_shape'] as String? ?? 'oval',
      skinTone: json['skin_tone'] as String? ?? 'medium',
      preferredStyles: (json['preferred_styles'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          ['natural', 'fresh'],
      preferredDifficulty:
          json['preferred_difficulty'] as String? ?? 'beginner',
      photographyLevel:
          json['photography_level'] as String? ?? 'beginner',
      qualityScore: (json['quality_score'] as num?)?.toDouble() ?? 5.0,
      totalSessions: json['total_sessions'] as int? ?? 0,
      totalPhotos: json['total_photos'] as int? ?? 0,
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'username': username,
      'display_name': displayName,
      'gender': gender,
      'age_range': ageRange,
      'height_cm': heightCm,
      'body_type': bodyType,
      'face_shape': faceShape,
      'skin_tone': skinTone,
      'preferred_styles': preferredStyles,
      'preferred_difficulty': preferredDifficulty,
      'photography_level': photographyLevel,
      'quality_score': qualityScore,
      'total_sessions': totalSessions,
      'total_photos': totalPhotos,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}
