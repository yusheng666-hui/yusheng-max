import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart' hide CameraPreview;
import 'package:uuid/uuid.dart';

import 'widgets/camera_preview.dart';
import 'widgets/capture_button.dart';
import 'widgets/mode_switcher.dart';
import 'widgets/camera_params_card.dart';
import 'widgets/styling_card.dart';
import 'widgets/photographer_guide_bar.dart';
import 'widgets/movement_guide_overlay.dart';
import '../../ar/presentation/widgets/ar_overlay.dart';
import '../../recommendation/presentation/widgets/recommendation_panel.dart';
import '../domain/providers.dart';
import '../domain/services/pose_detector.dart';
import '../domain/services/scene_analyzer.dart';
import '../domain/services/hybrid_scene_analyzer.dart';
import '../domain/services/lighting_analyzer.dart';
import '../domain/services/expression_detector.dart';
import 'widgets/expression_guide_overlay.dart';
import 'widgets/person_count_selector.dart';
import '../../../core/api_client.dart';
import '../../../core/connectivity_checker.dart';
import '../../../core/tts_service.dart';
import '../../../shared/models/scene_features.dart';
import '../../recommendation/domain/services/recommendation_service.dart';
import '../../recommendation/domain/services/local_recommendation_engine.dart';
import '../../evaluation/presentation/review_edit_page.dart';
import '../../evaluation/presentation/widgets/evaluation_result_sheet.dart';
import '../../evaluation/domain/providers.dart';

final _uuid = Uuid();

/// Main camera page — the core UX of PoseCraft.
///
/// Integrates: Camera preview → Pose detection → Scene analysis →
/// API recommendation → AR skeleton overlay → Carousel panel.
class CameraPage extends ConsumerStatefulWidget {
  const CameraPage({super.key});

  @override
  ConsumerState<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends ConsumerState<CameraPage>
    with WidgetsBindingObserver {
  CameraController? _controller;
  PoseDetector? _poseDetector;
  ConnectivityChecker? _connectivityChecker;
  StreamSubscription<bool>? _connectivitySub;
  Timer? _analysisTimer;
  SceneAnalysisResult? _lastScene;
  DateTime? _lastFetchTime;
  int _frameSkipCounter = 0;
  int _lightingFrameCounter = 0;
  static const int _frameProcessInterval = 6; // process every 6th frame (~5 fps at 30fps)
  static const int _lightingFrameInterval = 30; // analyze lighting every 30th frame (~1 fps)
  static const Duration _analysisInterval = Duration(seconds: 3);
  static const Duration _fetchDebounce = Duration(seconds: 10);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initPipeline();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _analysisTimer?.cancel();
    _connectivitySub?.cancel();
    _connectivityChecker?.stop();
    _poseDetector?.dispose();
    _controller?.dispose();
    ref.read(expressionDetectorProvider).dispose();
    ref.read(ttsServiceProvider).dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _analysisTimer?.cancel();
      _controller?.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed) {
      _initPipeline();
    }
  }

  /// Initialize the full camera + detection + recommendation pipeline.
  Future<void> _initPipeline() async {
    await _initCamera();
    if (_controller == null) return;

    await _initPoseDetector();
    _initConnectivity();
    _startSceneAnalysisLoop();
    _fetchRecommendations(); // initial fetch

    // Load preferences + sync to recommendation service
    final prefs = ref.read(userPreferenceStoreProvider);
    await prefs.load();
    ref.read(recommendationServiceProvider)
      ..setPreferredStyles(prefs.preferredStyles)
      ..setPreferredDifficulty(prefs.preferredDifficulty);
    prefs.recordSession();

    // Initialize TTS
    final tts = ref.read(ttsServiceProvider);
    tts.init();

    // Initialize expression detection
    final expressionDetector = ref.read(expressionDetectorProvider);
    expressionDetector.initialize();
  }

  /// Initialize the rear camera with image stream for ML processing.
  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        backCamera,
        ResolutionPreset.medium, // balance quality vs frame processing speed
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      await _controller!.initialize();

      // Start image stream for real-time pose detection
      await _controller!.startImageStream(_onFrameAvailable);

      ref.read(cameraControllerProvider.notifier).state = _controller;
    } catch (e) {
      debugPrint('Camera init failed: $e');
    }
  }

  /// Initialize the ML Kit pose detector.
  Future<void> _initPoseDetector() async {
    _poseDetector = ref.read(poseDetectorProvider);
    await _poseDetector!.initialize();
    _poseDetector!.onPosesDetected = _onPosesDetected;
  }

  /// Start connectivity monitoring for online/offline mode switching.
  void _initConnectivity() {
    _connectivityChecker = ref.read(connectivityCheckerProvider);
    _connectivityChecker!.start();
    _connectivitySub = _connectivityChecker!.onStatusChange.listen((online) {
      ref.read(isOnlineProvider.notifier).state = online;
    });
    // Run initial check
    _connectivityChecker!.checkNow().then((online) {
      ref.read(isOnlineProvider.notifier).state = online;
    });
  }

  /// Called on every camera frame from the image stream.
  ///
  /// Skips frames to maintain ~5 fps detection rate, avoiding
  /// overwhelming the ML Kit pipeline.
  void _onFrameAvailable(CameraImage image) {
    _frameSkipCounter++;
    _lightingFrameCounter++;

    // Pose detection at ~5 fps
    if (_frameSkipCounter >= _frameProcessInterval) {
      _frameSkipCounter = 0;
      if (_poseDetector != null) {
        _poseDetector!.processFrame(image);
      }
    }

    // Lighting analysis at ~1 fps (lighting doesn't change rapidly)
    if (_lightingFrameCounter >= _lightingFrameInterval) {
      _lightingFrameCounter = 0;
      final scene = _lastScene;
      final sceneClass = scene?.sceneClass ?? 'outdoor-nature';
      final timeOfDay = scene?.timeOfDay ?? _timeOfDayFromHour(DateTime.now().hour);

      final analyzer = ref.read(lightingAnalyzerProvider);
      final result = analyzer.analyzeFrame(
        image,
        sceneClass: sceneClass,
        timeOfDay: timeOfDay,
      );
      if (result != null) {
        ref.read(lightingAnalysisResultProvider.notifier).state = result;
      }

      // Expression detection — piggyback on lighting interval (~1 fps)
      final expressionDetector = ref.read(expressionDetectorProvider);
      expressionDetector.processFrame(image).then((expr) {
        if (expr != null) {
          ref.read(expressionResultProvider.notifier).state = expr;
        }
      });
    }
  }

  /// Called when the pose detector finds poses in a frame.
  void _onPosesDetected(List<DetectedPose> poses) {
    ref.read(detectedPosesProvider.notifier).state = poses;
  }

  /// Periodic scene analysis and recommendation refresh.
  void _startSceneAnalysisLoop() {
    _analysisTimer?.cancel();
    _analysisTimer = Timer.periodic(_analysisInterval, (_) => _onAnalysisTick());
  }

  void _onAnalysisTick() {
    final hybrid = ref.read(hybridSceneAnalyzerProvider);
    final now = DateTime.now();

    // Use hybrid analyzer — TFLite if model loaded, else rules
    final richResult = hybrid.analyzeFromRules(now: now);
    ref.read(richSceneResultProvider.notifier).state = richResult;

    // Also update the legacy scene analysis provider for backward compat
    final result = SceneAnalysisResult(
      sceneClass: richResult.sceneClass,
      fineSceneId: richResult.fineSceneId,
      confidence: richResult.sceneConfidence,
      label: richResult.label,
      timeOfDay: richResult.timeOfDay,
      colorPalette: richResult.colorPalette,
    );

    // Check if scene changed meaningfully
    final changed = _lastScene == null || _lastScene!.sceneClass != result.sceneClass;
    _lastScene = result;
    ref.read(sceneAnalysisResultProvider.notifier).state = result;

    if (changed) {
      ref.read(sceneChangedProvider.notifier).state = true;
    }

    // Fetch recommendations if scene changed and enough time has passed
    if (changed &&
        (_lastFetchTime == null ||
         now.difference(_lastFetchTime!) > _fetchDebounce)) {
      _fetchRecommendations();
    }
  }

  /// Fetch recommendations — cloud API when online, local engine when offline.
  Future<void> _fetchRecommendations() async {
    if (ref.read(isFetchingRecommendationsProvider)) return;
    ref.read(isFetchingRecommendationsProvider.notifier).state = true;

    try {
      final isOnline = ref.read(isOnlineProvider);
      final scene = _lastScene;
      final sceneClass = scene?.sceneClass ?? 'outdoor-nature';
      final sceneLabel = scene?.label;

      if (isOnline) {
        await _fetchFromCloud(scene, sceneClass);
      } else {
        await _fetchFromLocal(sceneClass, sceneLabel: sceneLabel);
      }
    } finally {
      _lastFetchTime = DateTime.now();
      ref.read(isFetchingRecommendationsProvider.notifier).state = false;
    }
  }

  /// Fetch from the cloud recommendation API.
  Future<void> _fetchFromCloud(SceneAnalysisResult? scene, String sceneClass) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final service = ref.read(recommendationServiceProvider);
      // Sync person count for cloud recommendation
      final mode = ref.read(personCountModeProvider);
      final personCount = ref.read(detectedPersonCountProvider);
      service.setPersonCount(personCount > 0 ? personCount : _modeToMinCount(mode));
      final richResult = ref.read(richSceneResultProvider);
      final timeOfDay = scene?.timeOfDay ?? _timeOfDayFromHour(DateTime.now().hour);

      // Prefer frame-based lighting analysis, fall back to rich scene rules
      final frameLighting = ref.read(lightingAnalysisResultProvider);
      final lighting = frameLighting?.baseInfo ??
          richResult?.lighting ??
          LightingInfo(
            direction: [0.5, 0.3, 0.8],
            intensity: timeOfDay == 'night' ? 0.2 : 0.65,
            colorTemp: timeOfDay == 'golden-hour' ? 3500.0 : 5500.0,
            contrastRatio: timeOfDay == 'night' ? 4.0 : 2.5,
          );

      final spatial = richResult?.spatial ?? const SpatialInfo(
        dominantPlanes: [],
        depthRange: [0.5, 20.0],
      );

      final features = SceneFeatures(
        sceneClass: sceneClass,
        sceneConfidence: scene?.confidence ?? 0.7,
        lighting: lighting,
        spatial: spatial,
        colorPalette: scene?.colorPalette ?? ['green', 'blue'],
        timeOfDay: timeOfDay,
        weather: 'clear',
        crowdDensity: 0.2,
      );

      final response = await apiClient.recommendPoses(
        requestId: _uuid.v4(),
        sceneFeatures: features,
        userContext: service.userContext,
        topK: 5,
      );

      service.updateResponse(response);
      ref.read(currentRecommendationsProvider.notifier).state = response;
      ref.read(sceneChangedProvider.notifier).state = false;
    } on ApiException catch (e) {
      debugPrint('Cloud fetch failed, falling back to local: $e');
      await _fetchFromLocal(sceneClass);
    }
  }

  /// Fetch from the local recommendation engine.
  Future<void> _fetchFromLocal(String sceneClass, {String? sceneLabel}) async {
    try {
      final engine = ref.read(localEngineProvider);
      final service = ref.read(recommendationServiceProvider);
      final store = ref.read(userPreferenceStoreProvider);
      final mode = ref.read(personCountModeProvider);
      // Map mode to category — null for solo (shows all solo/expression/advanced_solo)
      final category = mode == PersonCountMode.solo ? null : mode.name;

      // Merge style affinity into preferred styles for personalization
      final baseStyles = store.preferredStyles;
      final boostedStyles = <String>[...baseStyles];
      for (final style in store.styleAffinity.keys) {
        if (store.affinityFor(style) >= 3 && !boostedStyles.contains(style)) {
          boostedStyles.add(style);
        }
      }

      final response = engine.recommend(
        sceneClass: sceneClass,
        preferredStyles: boostedStyles,
        preferredDifficulty: store.preferredDifficulty,
        category: category,
        likedPoseIds: store.likedPoseIds,
        skipPoseIds: store.skippedPoseIds,
      );

      // Override sceneDetected with fine-grained label if available
      final displayResponse = sceneLabel != null
          ? RecommendationResponse(
              requestId: response.requestId,
              recommendations: response.recommendations,
              sessionId: response.sessionId,
              sceneDetected: sceneLabel,
              totalCandidates: response.totalCandidates,
            )
          : response;

      service.updateResponse(displayResponse);
      ref.read(currentRecommendationsProvider.notifier).state = displayResponse;
      ref.read(sceneChangedProvider.notifier).state = false;
    } catch (e) {
      debugPrint('Local engine failed: $e');
    }
  }

  /// Handle photo capture with evaluation flow.
  Future<void> _onCapture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      // Stop stream briefly for full-res capture
      await _controller!.stopImageStream();
      final photo = await _controller!.takePicture();

      // Snapshot evaluation data at capture moment
      final alignment = ref.read(alignmentResultProvider);
      final lighting = ref.read(lightingAnalysisResultProvider);
      final sceneResult = ref.read(sceneAnalysisResultProvider);
      final sceneClass = sceneResult?.sceneClass ?? 'outdoor-nature';
      final timeOfDay = sceneResult?.timeOfDay ?? 'afternoon';

      // Restart stream immediately — don't wait for navigation
      await _controller!.startImageStream(_onFrameAvailable);

      // Determine recommended presets using intelligent matching
      final recService = ref.read(presetRecommendationServiceProvider);
      final userPrefs = ref.read(userPreferenceStoreProvider);
      final recommendations = recService.recommend(
        sceneClass: sceneClass,
        lighting: lighting,
        preferredStyles: userPrefs.preferredStyles,
        timeOfDay: timeOfDay,
        limit: 3,
      );
      ref.read(currentPresetRecommendationsProvider.notifier).state =
          recommendations;

      // Record photo capture for personalization
      final activeRec = ref.read(currentRecommendationsProvider)?.recommendations
          .elementAtOrNull(ref.read(activeRecommendationIndexProvider));
      if (activeRec != null) {
        final loader = ref.read(localPoseLoaderProvider).valueOrNull;
        final localPose = loader?.getPoseById(activeRec.poseId);
        ref.read(userPreferenceStoreProvider).recordPhotoTaken(
          activeRec.poseId,
          localPose?.style ?? [],
        );
      }

      // Snapshot current expression
      final expression = ref.read(expressionResultProvider);

      // Generate local evaluation
      final evalEngine = ref.read(localEvaluationEngineProvider);
      final result = evalEngine.evaluate(
        alignment: alignment,
        lighting: lighting,
        sceneClass: sceneClass,
        timeOfDay: timeOfDay,
        expression: expression,
      );

      if (!mounted) return;

      // Show evaluation sheet first, then navigate to edit page if user wants
      await EvaluationResultSheet.show(
        context,
        result,
        onApplyPreset: (presetId) {
          Navigator.pop(context); // dismiss sheet
          _navigateToEdit(photo.path, presetId);
        },
        onRetake: () {
          Navigator.pop(context); // just dismiss, stay on camera
        },
      );
    } catch (e) {
      debugPrint('Capture failed: $e');
      // Ensure stream is restarted
      if (_controller != null && !_controller!.value.isStreamingImages) {
        _controller!.startImageStream(_onFrameAvailable);
      }
    }
  }

  Future<void> _navigateToEdit(String photoPath, String? recommendedPresetId) async {
    if (!mounted) return;
    final savedPath = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => ReviewEditPage(
          photoPath: photoPath,
          recommendedPresetId: recommendedPresetId,
        ),
      ),
    );
    if (savedPath != null) {
      debugPrint('Photo saved: $savedPath');
    }
  }

  /// Toggle between front and rear camera.
  Future<void> _switchCamera() async {
    final currentLens = ref.read(cameraLensDirectionProvider);
    final targetLens = currentLens == CameraLensDirection.back
        ? CameraLensDirection.front
        : CameraLensDirection.back;

    try {
      final cameras = await availableCameras();
      final target = cameras.firstWhere(
        (c) => c.lensDirection == targetLens,
        orElse: () => cameras.first,
      );

      await _controller?.stopImageStream();
      await _controller?.dispose();

      _controller = CameraController(
        target,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      await _controller!.initialize();
      await _controller!.startImageStream(_onFrameAvailable);

      ref.read(cameraControllerProvider.notifier).state = _controller;
      ref.read(cameraLensDirectionProvider.notifier).state = targetLens;
      ref.read(isSelfieModeProvider.notifier).state =
          targetLens == CameraLensDirection.front;
    } catch (e) {
      debugPrint('Camera switch failed: $e');
    }
  }

  /// Minimum person count fallback when no one is detected yet.
  int _modeToMinCount(PersonCountMode mode) {
    switch (mode) {
      case PersonCountMode.couple: return 2;
      case PersonCountMode.friends: return 2;
      case PersonCountMode.family: return 3;
      case PersonCountMode.solo: return 1;
    }
  }

  String _timeOfDayFromHour(int hour) {
    if (hour >= 5 && hour < 7) return 'dawn';
    if (hour >= 7 && hour < 10) return 'morning';
    if (hour >= 10 && hour < 16) return 'afternoon';
    if (hour >= 16 && hour < 18) return 'golden-hour';
    if (hour >= 18 && hour < 20) return 'dusk';
    return 'night';
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(cameraControllerProvider);
    final recommendations = ref.watch(currentRecommendationsProvider);
    final isFetching = ref.watch(isFetchingRecommendationsProvider);
    final scene = ref.watch(sceneAnalysisResultProvider);
    final isOnline = ref.watch(isOnlineProvider);
    final ttsMuted = ref.watch(ttsMutedProvider);
    final isInitialized = controller != null && controller.value.isInitialized;

    // TTS: speak correction hints when alignment changes
    ref.listen(alignmentResultProvider, (prev, next) {
      if (next != null) {
        ref.read(ttsServiceProvider).speakAlignmentFeedback(next);
      }
    });

    // TTS: speak pose guidance when user switches pose
    ref.listen(activeRecommendationIndexProvider, (prev, next) {
      final recs = ref.read(currentRecommendationsProvider);
      if (recs != null && next < recs.recommendations.length) {
        ref.read(ttsServiceProvider).speakPoseGuidance(recs.recommendations[next]);
      }
    });

    // Sync TTS mute state
    ref.listen(ttsMutedProvider, (prev, next) {
      ref.read(ttsServiceProvider).setMuted(next);
    });

    // Re-fetch recommendations when person-count mode changes
    ref.listen(personCountModeProvider, (prev, next) {
      if (prev != next) {
        _fetchRecommendations();
      }
    });

    // Re-fetch when recommendation panel requests refresh (like/skip)
    ref.listen(recommendationRefreshTriggerProvider, (prev, next) {
      if (prev != next) {
        _fetchRecommendations();
      }
    });

    // TTS: speak lighting tips when conditions change significantly
    ref.listen(lightingAnalysisResultProvider, (prev, next) {
      if (next != null &&
          (prev == null ||
              prev.backlight.isBacklit != next.backlight.isBacklit ||
              prev.quality != next.quality)) {
        ref.read(ttsServiceProvider).speakLightingTips(next);
      }
    });

    // TTS: speak expression hints when expression type changes
    ref.listen(expressionResultProvider, (prev, next) {
      if (next != null &&
          (prev == null || prev.expression != next.expression)) {
        ref.read(ttsServiceProvider).speakExpressionGuidance(next);
      }
    });

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Live camera preview
          if (isInitialized) CameraPreview(controller: controller!),

          // AR skeleton overlay
          const ArOverlay(),

          // Expression guide chip
          const ExpressionGuideOverlay(),

          // Wardrobe + prop styling card (left side)
          const Positioned(
            left: 12,
            top: 110,
            child: StylingCard(),
          ),

          // Camera parameter recommendation card (right side)
          const Positioned(
            right: 12,
            top: 110,
            child: CameraParamsCard(),
          ),

          // Top bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 12,
            right: 12,
            child: Row(
              children: [
                // Scene label
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.landscape, size: 14, color: Colors.white.withOpacity(0.7)),
                      const SizedBox(width: 6),
                      Text(
                        scene?.label ?? 'PoseCraft',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isOnline)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_off, size: 12, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          '离线',
                          style: TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                const Spacer(),
                // TTS mute toggle
                _IconButton(
                  icon: ttsMuted ? Icons.volume_off : Icons.volume_up,
                  onTap: () {
                    ref.read(ttsMutedProvider.notifier).state = !ttsMuted;
                  },
                ),
                const SizedBox(width: 8),
                // Flash toggle
                _IconButton(
                  icon: Icons.flash_off,
                  onTap: () {
                    ref.read(flashEnabledProvider.notifier).state =
                        !ref.read(flashEnabledProvider);
                  },
                ),
                const SizedBox(width: 8),
                // Refresh recommendations
                _IconButton(
                  icon: Icons.refresh,
                  onTap: isFetching ? null : _fetchRecommendations,
                ),
              ],
            ),
          ),

          // Person-count mode selector
          Positioned(
            top: MediaQuery.of(context).padding.top + 56,
            left: 0,
            right: 0,
            child: const Center(child: PersonCountSelector()),
          ),

          // Loading indicator
          if (isFetching)
            const Positioned(
              top: 80,
              left: 0,
              right: 0,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white54,
                  ),
                ),
              ),
            ),

          // No recommendations yet placeholder
          if (!isFetching && recommendations == null && isInitialized)
            Positioned(
              top: MediaQuery.of(context).size.height * 0.35,
              left: 0,
              right: 0,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, size: 36, color: Colors.white.withOpacity(0.4)),
                    const SizedBox(height: 8),
                    Text(
                      '正在分析环境...',
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),

          // Movement guide overlay
          const MovementGuideOverlay(),

          // Photographer guidance bar
          const Positioned(
            bottom: 180,
            left: 0,
            right: 0,
            child: PhotographerGuideBar(),
          ),

          // Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pose recommendation carousel
                const RecommendationPanel(),
                const SizedBox(height: 8),
                // Capture + mode controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ModeSwitcher(onSwitch: _switchCamera),
                    GestureDetector(
                      onTap: _onCapture,
                      child: const CaptureButton(),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
                SizedBox(height: MediaQuery.of(context).padding.bottom + 20 + ref.watch(bottomNavInsetProvider)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact icon button for the top bar.
class _IconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _IconButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, size: 18, color: Colors.white70),
      ),
    );
  }
}
