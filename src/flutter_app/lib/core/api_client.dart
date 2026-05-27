/// HTTP API client for the PoseCraft backend.
///
/// Handles recommendation requests, user profile, and evaluation endpoints.
/// Uses [Dio] for HTTP with configurable base URL and timeouts.

import 'package:dio/dio.dart';
import '../features/recommendation/domain/services/recommendation_service.dart';
import '../shared/models/scene_features.dart';
import '../shared/models/user_profile.dart';
import '../shared/models/evaluation.dart';
import 'constants.dart';

class ApiClient {
  final Dio _dio;

  ApiClient({String? baseUrl})
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl ?? ApiConstants.baseUrl,
          connectTimeout: const Duration(milliseconds: ApiConstants.connectTimeout),
          receiveTimeout: const Duration(milliseconds: ApiConstants.receiveTimeout),
          headers: {'Content-Type': 'application/json'},
        ));

  /// Request pose recommendations for the given scene and user context.
  Future<RecommendationResponse> recommendPoses({
    required String requestId,
    required SceneFeatures sceneFeatures,
    String? userId,
    String? sessionId,
    Map<String, dynamic> userContext = const {},
    int topK = 5,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.recommend,
        data: {
          'request_id': requestId,
          if (userId != null) 'user_id': userId,
          if (sessionId != null) 'session_id': sessionId,
          'scene_features': sceneFeatures.toJson(),
          'user_context': userContext,
          'top_k': topK,
        },
      );

      if (response.statusCode == 200) {
        return RecommendationResponse.fromJson(response.data);
      }
      throw ApiException('Recommendation failed: ${response.statusCode}');
    } on DioException catch (e) {
      throw ApiException('Network error: ${e.message}');
    }
  }

  /// Submit evaluation for a captured photo.
  Future<EvaluationResult> evaluatePhoto({
    required String requestId,
    required String poseId,
    String userId = 'u000000000001',
    String sceneClass = 'outdoor-nature',
    required Map<String, dynamic> photoFeatures,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.evaluate,
        data: {
          'request_id': requestId,
          'user_id': userId,
          'pose_id': poseId,
          'scene_class': sceneClass,
          'photo_features': photoFeatures,
        },
      );

      if (response.statusCode == 200) {
        return EvaluationResult.fromJson(response.data);
      }
      throw ApiException('Evaluation failed: ${response.statusCode}');
    } on DioException catch (e) {
      throw ApiException('Network error: ${e.message}');
    }
  }

  /// Register a new user or set up a profile for the first time.
  Future<UserProfile> registerUser({
    required Map<String, dynamic> profile,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.registerUser,
        data: profile,
      );
      if (response.statusCode == 200) {
        return UserProfile.fromJson(response.data);
      }
      throw ApiException('Registration failed: ${response.statusCode}');
    } on DioException catch (e) {
      throw ApiException('Network error: ${e.message}');
    }
  }

  /// Fetch the current user profile.
  Future<UserProfile> getUserProfile({String userId = 'u000000000001'}) async {
    try {
      final response = await _dio.get(
        ApiConstants.userProfile,
        queryParameters: {'user_id': userId},
      );
      if (response.statusCode == 200) {
        return UserProfile.fromJson(response.data);
      }
      throw ApiException('Profile fetch failed: ${response.statusCode}');
    } on DioException catch (e) {
      throw ApiException('Network error: ${e.message}');
    }
  }

  /// Update user style/difficulty preferences.
  Future<UserProfile> updatePreferences({
    String userId = 'u000000000001',
    List<String>? preferredStyles,
    String? preferredDifficulty,
  }) async {
    try {
      final response = await _dio.patch(
        ApiConstants.updatePreferences,
        data: {
          if (preferredStyles != null) 'preferred_styles': preferredStyles,
          if (preferredDifficulty != null)
            'preferred_difficulty': preferredDifficulty,
        },
        queryParameters: {'user_id': userId},
      );
      if (response.statusCode == 200) {
        return UserProfile.fromJson(response.data);
      }
      throw ApiException('Preference update failed: ${response.statusCode}');
    } on DioException catch (e) {
      throw ApiException('Network error: ${e.message}');
    }
  }

  void dispose() {
    _dio.close();
  }
}

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => 'ApiException: $message';
}
