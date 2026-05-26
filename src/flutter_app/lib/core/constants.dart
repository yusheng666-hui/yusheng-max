/// Core network constants shared across app modules.
class ApiConstants {
  ApiConstants._();

  /// Base URL for the cloud backend.
  /// Override via environment variable or build flavor.
  static const String baseUrl = 'https://api.posecraft.example.com';

  /// API version prefix.
  static const String apiPrefix = '/api/v1';

  // Endpoint paths
  static const String recommend = '$apiPrefix/recommend';
  static const String recommendHealth = '$apiPrefix/recommend/health';
  static const String evaluate = '$apiPrefix/evaluate';
  static const String feedback = '$apiPrefix/feedback';
  static const String poses = '$apiPrefix/poses';
  static const String userProfile = '$apiPrefix/users/me';
  static const String registerUser = '$apiPrefix/users/register';
  static const String updatePreferences = '$apiPrefix/users/me/preferences';

  /// Timeout durations (milliseconds).
  static const int connectTimeout = 5000;
  static const int receiveTimeout = 8000;
}

/// ML model file names stored in assets/models/.
class MlModels {
  MlModels._();

  static const String sceneClassifier = 'scene_classifier.tflite';
  static const String depthEstimation = 'depth_estimation.tflite';
  static const String lightingAnalyzer = 'lighting_analyzer.tflite';
  static const String sceneLabels = 'scene_labels.txt';
}

/// Local storage keys.
class StorageKeys {
  StorageKeys._();

  static const String userProfile = 'user_profile';
  static const String stylePreferences = 'style_preferences';
  static const String localPoseDb = 'local_pose_db';
  static const String onboardingComplete = 'onboarding_complete';
  static const String poseSquareVotes = 'pose_square_votes';
  static const String poseSquareCollections = 'pose_square_collections';
  static const String clonedPoses = 'cloned_poses';
}
