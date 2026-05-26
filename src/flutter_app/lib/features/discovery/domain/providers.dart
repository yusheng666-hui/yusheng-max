/// Providers for POI Discovery feature.
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'poi_loader.dart';
import '../../../shared/models/photo_spot.dart';

/// Singleton loader — loads china_pois.json from assets.
final poiLoaderProvider = FutureProvider<PoiLoader>((ref) async {
  final loader = PoiLoader();
  await loader.load();
  return loader;
});

/// All loaded POIs.
final allPoisProvider = Provider<List<PhotoSpot>>((ref) {
  final loader = ref.watch(poiLoaderProvider).valueOrNull;
  return loader?.allPois ?? [];
});

/// Distinct region names for filter tabs.
final poiRegionsProvider = Provider<List<String>>((ref) {
  final loader = ref.watch(poiLoaderProvider).valueOrNull;
  return loader?.regions ?? [];
});

/// Currently selected region filter (null = show all).
final poiRegionFilterProvider = StateProvider<String?>((ref) => null);

/// POIs filtered by selected region.
final filteredPoisProvider = Provider<List<PhotoSpot>>((ref) {
  final all = ref.watch(allPoisProvider);
  final region = ref.watch(poiRegionFilterProvider);
  if (region == null) return all;
  return all.where((p) => p.region == region).toList();
});

/// POIs near a given coordinate, sorted by distance.
final nearbyPoisProvider =
    Provider.family<List<PhotoSpot>, ({double lat, double lon})>(
        (ref, coord) {
  final loader = ref.watch(poiLoaderProvider).valueOrNull;
  if (loader == null) return [];
  return loader.getNearby(coord.lat, coord.lon);
});

/// Selected POI for detail view.
final selectedPoiProvider = StateProvider<PhotoSpot?>((ref) => null);

// ── Map Discovery / Nearby ──────────────────────────────────────

/// Toggle between region-browse mode and GPS-nearby mode.
final nearbyModeProvider = StateProvider<bool>((ref) => false);

/// Whether GPS location is being fetched.
final isLocatingProvider = StateProvider<bool>((ref) => false);

/// User's current GPS position.
final userPositionProvider =
    StateProvider<({double lat, double lon})?>((ref) => null);

/// Error message if location fails.
final locationErrorProvider = StateProvider<String?>(() => null);

/// Fetch GPS position and update state.
Future<void> fetchUserLocation(Ref ref) async {
  ref.read(isLocatingProvider.notifier).state = true;
  ref.read(locationErrorProvider.notifier).state = null;

  try {
    final hasPermission = await Geolocator.checkPermission();
    if (hasPermission == LocationPermission.denied) {
      final result = await Geolocator.requestPermission();
      if (result != LocationPermission.whileInUse &&
          result != LocationPermission.always) {
        ref.read(locationErrorProvider.notifier).state = '位置权限被拒绝';
        return;
      }
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ref.read(locationErrorProvider.notifier).state = '请开启GPS定位服务';
      return;
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      ),
    );

    ref.read(userPositionProvider.notifier).state = (
      lat: position.latitude,
      lon: position.longitude,
    );
  } catch (e) {
    ref.read(locationErrorProvider.notifier).state = '定位失败';
  } finally {
    ref.read(isLocatingProvider.notifier).state = false;
  }
}

/// POIs near user's current position, within 100km.
final userNearbyPoisProvider = Provider<List<PhotoSpot>>((ref) {
  final pos = ref.watch(userPositionProvider);
  if (pos == null) return [];
  final loader = ref.watch(poiLoaderProvider).valueOrNull;
  if (loader == null) return [];
  return loader.getNearby(pos.lat, pos.lon, radiusKm: 100);
});

/// Calculate bearing from one coordinate to another (0=North, 90=East).
double bearingTo(double fromLat, double fromLon, double toLat, double toLon) {
  final dLon = (toLon - fromLon) * pi / 180;
  final rLat1 = fromLat * pi / 180;
  final rLat2 = toLat * pi / 180;
  final y = sin(dLon) * cos(rLat2);
  final x = cos(rLat1) * sin(rLat2) -
      sin(rLat1) * cos(rLat2) * cos(dLon);
  return (atan2(y, x) * 180 / pi + 360) % 360;
}

/// Convert bearing degrees to a compass arrow character.
String bearingToArrow(double deg) {
  if (deg < 22.5 || deg >= 337.5) return '↑';
  if (deg < 67.5) return '↗';
  if (deg < 112.5) return '→';
  if (deg < 157.5) return '↘';
  if (deg < 202.5) return '↓';
  if (deg < 247.5) return '↙';
  if (deg < 292.5) return '←';
  return '↖';
}
