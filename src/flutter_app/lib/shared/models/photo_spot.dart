import 'dart:math';

/// A scenic photo spot with pose recommendations and shooting guidance.
class PhotoSpot {
  final String id;
  final String nameZh;
  final String city;
  final String region;
  final double latitude;
  final double longitude;
  final String sceneType;
  final List<String> bestPoseIds;
  final String bestTime;
  final List<String> bestAngles;
  final String description;
  final String photoTip;
  final double popularity;
  final List<String> tags;

  const PhotoSpot({
    required this.id,
    required this.nameZh,
    this.city = '',
    this.region = '',
    required this.latitude,
    required this.longitude,
    required this.sceneType,
    this.bestPoseIds = const [],
    this.bestTime = '',
    this.bestAngles = const [],
    this.description = '',
    this.photoTip = '',
    this.popularity = 5.0,
    this.tags = const [],
  });

  factory PhotoSpot.fromJson(Map<String, dynamic> json) {
    return PhotoSpot(
      id: json['id'] as String? ?? '',
      nameZh: json['name_zh'] as String? ?? '',
      city: json['city'] as String? ?? '',
      region: json['region'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      sceneType: json['scene_type'] as String? ?? 'outdoor',
      bestPoseIds: (json['best_pose_ids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      bestTime: json['best_time'] as String? ?? '',
      bestAngles: (json['best_angles'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      description: json['description'] as String? ?? '',
      photoTip: json['photo_tip'] as String? ?? '',
      popularity: (json['popularity'] as num?)?.toDouble() ?? 5.0,
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  /// Distance in km from a given coordinate.
  double distanceKm(double lat, double lon) {
    const r = 6371;
    final dLat = _degToRad(lat - latitude);
    final dLon = _degToRad(lon - longitude);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(latitude)) * cos(_degToRad(lat)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  static double _degToRad(double deg) => deg * pi / 180;
}
