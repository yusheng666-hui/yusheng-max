/// Loads the china_pois.json scenic-spot database from app assets.
///
/// Indexes 52 POIs by region and provides GPS-based nearby search
/// using the Haversine formula from PhotoSpot.distanceKm().

import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../../../shared/models/photo_spot.dart';

class PoiLoader {
  List<PhotoSpot>? _allPois;
  Map<String, List<PhotoSpot>>? _byRegion;
  bool _loaded = false;

  bool get isLoaded => _loaded;
  int get totalPois => _allPois?.length ?? 0;
  List<PhotoSpot> get allPois => List.unmodifiable(_allPois ?? []);
  Map<String, List<PhotoSpot>> get byRegion =>
      Map.unmodifiable(_byRegion ?? {});

  Future<void> load() async {
    if (_loaded) return;

    try {
      final jsonStr =
          await rootBundle.loadString('assets/pois/china_pois.json');
      final data = json.decode(jsonStr) as Map<String, dynamic>;
      final poiList = data['pois'] as List<dynamic>? ?? [];

      _allPois = [];
      _byRegion = {};

      for (final p in poiList) {
        final poi = PhotoSpot.fromJson(p as Map<String, dynamic>);
        _allPois!.add(poi);
        _byRegion!.putIfAbsent(poi.region, () => []).add(poi);
      }

      _loaded = true;
      print(
          'PoiLoader: loaded ${_allPois!.length} POIs across ${_byRegion!.length} regions');
    } catch (e) {
      print('PoiLoader: failed to load POI DB — $e');
      _allPois = [];
      _byRegion = {};
      _loaded = true;
    }
  }

  /// Find POIs within [radiusKm] of a GPS coordinate, sorted by distance.
  List<PhotoSpot> getNearby(double lat, double lon, {double radiusKm = 50}) {
    if (_allPois == null) return [];
    final results = _allPois!
        .where((p) => p.distanceKm(lat, lon) <= radiusKm)
        .toList();
    results.sort((a, b) {
      final da = a.distanceKm(lat, lon);
      final db = b.distanceKm(lat, lon);
      return da.compareTo(db);
    });
    return results;
  }

  /// All distinct regions, sorted.
  List<String> get regions {
    final keys = (_byRegion?.keys.toList() ?? []);
    keys.sort();
    return keys;
  }

  /// Get POIs for a specific region.
  List<PhotoSpot> poisForRegion(String region) {
    return _byRegion?[region] ?? [];
  }

  /// Find POIs whose best_pose_ids contain the given pose ID.
  List<PhotoSpot> poisForPoseId(String poseId) {
    if (_allPois == null) return [];
    return _allPois!
        .where((p) => p.bestPoseIds.contains(poseId))
        .toList();
  }
}
