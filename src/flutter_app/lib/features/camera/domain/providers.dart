/// Riverpod providers for camera, pose detection, scene analysis, and recommendations.

import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/connectivity_checker.dart';
import '../../../core/tts_service.dart';
import '../domain/services/pose_detector.dart';
import '../domain/services/scene_analyzer.dart';
import '../domain/services/hybrid_scene_analyzer.dart';
import '../domain/services/camera_params_service.dart';
import '../domain/services/lighting_analyzer.dart';
import '../../ar/domain/services/alignment_scorer.dart';
import '../../recommendation/domain/services/recommendation_service.dart';
import '../../recommendation/domain/services/local_pose_loader.dart';
import '../../recommendation/domain/services/local_recommendation_engine.dart';
import '../../recommendation/domain/services/styling_service.dart';
import '../../recommendation/domain/services/photographer_guidance_service.dart';

// ── Camera ──────────────────────────────────────────────────────

/// Available cameras on the device.
final availableCamerasProvider = FutureProvider<List<CameraDescription>>((ref) async {
  return availableCameras();
});

/// The active CameraController.
final cameraControllerProvider = StateProvider<CameraController?>((ref) => null);

/// Whether the camera is initialized and ready.
final cameraInitializedProvider = Provider<bool>((ref) {
  final ctrl = ref.watch(cameraControllerProvider);
  return ctrl != null && ctrl.value.isInitialized;
});

/// Current camera lens direction (back for photographer mode, front for selfie).
final cameraLensDirectionProvider = StateProvider<CameraLensDirection>((ref) {
  return CameraLensDirection.back;
});

// ── Pose Detection ──────────────────────────────────────────────

/// The PoseDetector instance.
final poseDetectorProvider = Provider<PoseDetector>((ref) {
  return PoseDetector();
});

/// Latest detected user pose from the camera stream.
final detectedPoseProvider = StateProvider<DetectedPose?>((ref) => null);

/// Whether the pose detector is currently processing a frame.
final isPoseDetectingProvider = StateProvider<bool>((ref) => false);

// ── Scene Analysis ──────────────────────────────────────────────

/// The SceneAnalyzer instance.
final sceneAnalyzerProvider = Provider<SceneAnalyzer>((ref) {
  return SceneAnalyzer();
});

/// Latest scene analysis result.
final sceneAnalysisResultProvider = StateProvider<SceneAnalysisResult?>((ref) {
  return null;
});

/// Whether scene has changed meaningfully since last recommendation fetch.
final sceneChangedProvider = StateProvider<bool>((ref) => false);

/// Hybrid scene analyzer — TFLite when model available, rules as fallback.
final hybridSceneAnalyzerProvider = Provider<HybridSceneAnalyzer>((ref) {
  final analyzer = HybridSceneAnalyzer();
  // Fire-and-forget initialization
  analyzer.init();
  return analyzer;
});

/// Rich scene result from hybrid analysis (updated periodically).
final richSceneResultProvider = StateProvider<RichSceneResult?>((ref) => null);

// ── Camera Parameters ─────────────────────────────────────────

/// Camera parameter recommendation service.
final cameraParamsServiceProvider = Provider<CameraParamsService>((ref) {
  return CameraParamsService();
});

/// Current camera parameter recommendation (updated when pose or scene changes).
final cameraParamsRecommendationProvider = Provider<CameraParamsRecommendation?>((ref) {
  final response = ref.watch(currentRecommendationsProvider);
  final activeIndex = ref.watch(activeRecommendationIndexProvider);
  final sceneResult = ref.watch(sceneAnalysisResultProvider);
  final service = ref.watch(cameraParamsServiceProvider);

  if (response == null || response.recommendations.isEmpty) return null;
  if (activeIndex >= response.recommendations.length) return null;

  final activeRec = response.recommendations[activeIndex];
  final scene = sceneResult;

  // Determine if this is a moving pose
  final isMoving = activeRec.poseId.contains('dynamic') ||
      activeRec.poseId.contains('jump') ||
      activeRec.poseId.contains('running') ||
      activeRec.poseId.contains('action');

  // Estimate lighting from time of day
  final tod = scene?.timeOfDay ?? 'afternoon';
  final (lightIntensity, colorTemp, contrastRatio) = _estimateLighting(tod);

  final ctx = CameraParamContext(
    sceneClass: scene?.sceneClass ?? 'outdoor',
    timeOfDay: tod,
    lightIntensity: lightIntensity,
    colorTemp: colorTemp,
    contrastRatio: contrastRatio,
    subjectDistance: 2.0,
    isMovingPose: isMoving,
    poseParams: activeRec.cameraParams,
  );

  return service.recommend(ctx);
});

/// Estimate lighting conditions from time of day.
(double lightIntensity, double colorTemp, double contrastRatio) _estimateLighting(String timeOfDay) {
  switch (timeOfDay) {
    case 'dawn':
      return (0.35, 3500.0, 2.0);
    case 'morning':
      return (0.65, 5000.0, 2.5);
    case 'afternoon':
      return (1.0, 5500.0, 3.0);
    case 'golden-hour':
      return (0.6, 3200.0, 2.0);
    case 'dusk':
      return (0.25, 3800.0, 3.5);
    case 'night':
      return (0.1, 4500.0, 4.0);
    default:
      return (1.0, 5500.0, 2.5);
  }
}

// ── Styling (Wardrobe + Props) ─────────────────────────────────

/// Styling service for wardrobe and prop recommendations.
final stylingServiceProvider = Provider<StylingService>((ref) {
  return StylingService();
});

/// Current styling recommendation (updated when scene changes).
final stylingRecommendationProvider = Provider<StylingRecommendation?>((ref) {
  final sceneResult = ref.watch(sceneAnalysisResultProvider);
  final response = ref.watch(currentRecommendationsProvider);
  final service = ref.watch(stylingServiceProvider);

  if (sceneResult == null) return null;

  return service.recommend(
    sceneClass: sceneResult.sceneClass,
    timeOfDay: sceneResult.timeOfDay,
    month: DateTime.now().month,
  );
});

// ── Photographer Guidance ──────────────────────────────────────

/// Photographer guidance service.
final photographerGuidanceServiceProvider = Provider<PhotographerGuidanceService>((ref) {
  return PhotographerGuidanceService();
});

/// Current photographer guidance (updated when pose or scene changes).
final photographerGuidanceProvider = Provider<PhotographerGuidance?>((ref) {
  final response = ref.watch(currentRecommendationsProvider);
  final activeIndex = ref.watch(activeRecommendationIndexProvider);
  final sceneResult = ref.watch(sceneAnalysisResultProvider);
  final service = ref.watch(photographerGuidanceServiceProvider);

  if (response == null || response.recommendations.isEmpty) return null;
  if (activeIndex >= response.recommendations.length) return null;
  if (sceneResult == null) return null;

  final activeRec = response.recommendations[activeIndex];
  // Infer pose tags from pose ID using word-boundary matching
  final tags = <String>[];
  final pid = activeRec.poseId.toLowerCase();
  if (pid.contains('-sit') || pid.contains('sit-') || pid.contains('sitting')) tags.add('sitting');
  if (pid.contains('-lying') || pid.contains('lying-') || pid.contains('-lay') || pid.contains('lay-')) tags.add('lying');
  if (pid.contains('-jump') || pid.contains('jump-') || pid.contains('-dynamic') || pid.contains('dynamic-')) tags.add('jumping');
  if (pid.contains('-look-up') || pid.contains('look-up-')) tags.add('looking-up');
  if (pid.contains('-look-down') || pid.contains('look-down-')) tags.add('looking-down');
  if (pid.contains('-back') || pid.contains('back-') || pid.contains('backview')) tags.add('back-view');
  if (pid.contains('-side') || pid.contains('side-') || pid.contains('-profile') || pid.contains('profile-')) tags.add('side-profile');

  // Determine category from pose ID prefix
  String category = 'solo';
  for (final cat in ['couple', 'friends', 'family', 'expression', 'advanced_solo']) {
    if (pid.startsWith(cat)) {
      category = cat;
      break;
    }
  }

  return service.recommend(
    sceneClass: sceneResult.sceneClass,
    category: category,
    poseTags: tags,
  );
});

// ── API & Recommendations ───────────────────────────────────────

/// API client for backend communication.
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(baseUrl: 'http://10.0.2.2:8080');
});

/// Recommendation service — manages fetched recommendations and user preferences.
final recommendationServiceProvider = Provider<RecommendationService>((ref) {
  return RecommendationService();
});

/// The current recommendation response (null = not yet fetched).
final currentRecommendationsProvider = StateProvider<RecommendationResponse?>((ref) => null);

/// Index of the active recommendation in the carousel.
final activeRecommendationIndexProvider = StateProvider<int>((ref) => 0);

/// Whether recommendations are currently being fetched.
final isFetchingRecommendationsProvider = StateProvider<bool>((ref) => false);

/// Last time recommendations were fetched.
final lastFetchTimeProvider = StateProvider<DateTime?>((ref) => null);

// ── Camera Mode ─────────────────────────────────────────────────

/// Whether in selfie mode (front camera) vs photographer mode (rear camera).
final isSelfieModeProvider = StateProvider<bool>((ref) => false);

/// Whether flash is enabled.
final flashEnabledProvider = StateProvider<bool>((ref) => false);

/// Whether grid overlay is shown.
final gridOverlayEnabledProvider = StateProvider<bool>((ref) => true);

// ── TTS ─────────────────────────────────────────────────────────

/// TTS service for real-time voice guidance.
final ttsServiceProvider = Provider<TtsService>((ref) {
  return TtsService();
});

/// Whether TTS voice is muted.
final ttsMutedProvider = StateProvider<bool>((ref) => false);

// ── Lighting Analysis ───────────────────────────────────────────

/// Lighting analyzer for on-device light quality and backlight detection.
final lightingAnalyzerProvider = Provider<LightingAnalyzer>((ref) {
  return LightingAnalyzer();
});

/// Latest lighting analysis result from camera frames.
final lightingAnalysisResultProvider = StateProvider<LightingAnalysisResult?>((ref) => null);

/// Current skeleton alignment between user pose and active recommendation.
final alignmentResultProvider = Provider<AlignmentResult?>((ref) {
  final detectedPose = ref.watch(detectedPoseProvider);
  final recommendations = ref.watch(currentRecommendationsProvider);
  final activeIndex = ref.watch(activeRecommendationIndexProvider);

  if (detectedPose == null ||
      recommendations == null ||
      recommendations.recommendations.isEmpty) {
    return null;
  }
  if (activeIndex >= recommendations.recommendations.length) return null;

  final target = recommendations.recommendations[activeIndex];

  final userKps = <AlignKeypoint>[];
  final keypoints = detectedPose.keypoints;

  for (int i = 0; i < keypoints.length && i < 33; i++) {
    final k = keypoints[i];
    userKps.add(AlignKeypoint(
      id: i,
      x: k.x,
      y: k.y,
      z: k.z,
      visibility: k.likelihood,
    ));
  }

  final targetKps = <AlignKeypoint>[];
  for (int i = 0; i < target.skeleton.keypoints.length && i < 33; i++) {
    final k = target.skeleton.keypoints[i];
    targetKps.add(AlignKeypoint(
      id: i,
      x: k.x,
      y: k.y,
      z: k.z,
      visibility: k.visibility,
    ));
  }

  return AlignmentScorer.score(
    userKeypoints: userKps,
    targetKeypoints: targetKps,
  );
});

// ── Connectivity & Offline ───────────────────────────────────────

/// Network connectivity checker — periodically pings the backend.
final connectivityCheckerProvider = Provider<ConnectivityChecker>((ref) {
  return ConnectivityChecker();
});

/// Whether the device is currently online (backend reachable).
final isOnlineProvider = StateProvider<bool>((ref) => true);

/// Local pose loader for offline fallback — loads the 300-pose DB from assets.
final localPoseLoaderProvider = FutureProvider<LocalPoseLoader>((ref) async {
  final loader = LocalPoseLoader();
  await loader.load();
  return loader;
});

/// Local recommendation engine — mirrors the cloud algorithm in Dart.
final localEngineProvider = Provider<LocalRecommendationEngine>((ref) {
  final loader = ref.watch(localPoseLoaderProvider).valueOrNull;
  if (loader == null) {
    throw StateError('LocalPoseLoader not yet loaded');
  }
  return LocalRecommendationEngine(loader);
});
