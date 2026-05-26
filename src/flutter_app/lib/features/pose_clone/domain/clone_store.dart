/// Persists cloned poses — metadata+skeleton in SharedPreferences,
/// thumbnail images as files in the app documents directory.
///
/// Avoids OOM from storing large base64 images in SharedPreferences.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants.dart';
import '../../../shared/models/pose.dart';
import 'pose_clone_service.dart';

class ClonedPoseEntry {
  final String id;
  final String name;
  final String thumbnailPath; // file path on disk
  final Skeleton3D skeleton;
  final double confidence;
  final DateTime createdAt;

  Uint8List? _cachedThumb;

  ClonedPoseEntry({
    required this.id,
    required this.name,
    required this.thumbnailPath,
    required this.skeleton,
    required this.confidence,
    required this.createdAt,
  });

  /// Read thumbnail bytes from disk, cached after first access.
  Uint8List? get thumbBytes {
    if (_cachedThumb != null) return _cachedThumb;
    try {
      final file = File(thumbnailPath);
      if (file.existsSync()) {
        _cachedThumb = file.readAsBytesSync();
      }
    } catch (_) {
      _cachedThumb = Uint8List(0);
    }
    return _cachedThumb;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'thumbnail_path': thumbnailPath,
        'skeleton': PoseCloneService.skeletonToJson(skeleton),
        'confidence': confidence,
        'created_at': createdAt.toIso8601String(),
      };

  factory ClonedPoseEntry.fromJson(Map<String, dynamic> json) => ClonedPoseEntry(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        thumbnailPath: json['thumbnail_path'] as String? ?? '',
        skeleton: PoseCloneService.skeletonFromJson(
            json['skeleton'] as Map<String, dynamic>? ?? {}),
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
            DateTime.now(),
      );
}

class CloneStore {
  SharedPreferences? _prefs;
  final List<ClonedPoseEntry> _entries = [];
  bool _loaded = false;
  String? _thumbDir;

  List<ClonedPoseEntry> get entries => List.unmodifiable(_entries);

  Future<String> get thumbDir async {
    if (_thumbDir != null) return _thumbDir!;
    final dir = await getApplicationDocumentsDirectory();
    _thumbDir = '${dir.path}/cloned_poses';
    await Directory(_thumbDir!).create(recursive: true);
    return _thumbDir!;
  }

  Future<void> load() async {
    if (_loaded) return;
    _prefs ??= await SharedPreferences.getInstance();
    final raw = _prefs!.getString(StorageKeys.clonedPoses);
    if (raw != null) {
      try {
        final list = json.decode(raw) as List<dynamic>;
        _entries.clear();
        for (final e in list) {
          _entries.add(ClonedPoseEntry.fromJson(e as Map<String, dynamic>));
        }
      } catch (_) {
        _entries.clear();
      }
    }
    _loaded = true;
  }

  Future<void> _save() async {
    final list = _entries.map((e) => e.toJson()).toList();
    await _prefs?.setString(StorageKeys.clonedPoses, json.encode(list));
  }

  Future<void> addEntry({
    required String id,
    required String name,
    required Uint8List imageBytes,
    required Skeleton3D skeleton,
    required double confidence,
  }) async {
    final dir = await thumbDir;
    final path = '$dir/$id.jpg';
    await File(path).writeAsBytes(imageBytes);

    _entries.insert(0, ClonedPoseEntry(
      id: id,
      name: name,
      thumbnailPath: path,
      skeleton: skeleton,
      confidence: confidence,
      createdAt: DateTime.now(),
    ));
    await _save();
  }

  Future<void> deleteEntry(String id) async {
    _entries.removeWhere((e) {
      if (e.id == id) {
        // Clean up thumbnail file
        try {
          File(e.thumbnailPath).deleteSync();
        } catch (_) {}
        return true;
      }
      return false;
    });
    await _save();
  }

  ClonedPoseEntry? getById(String id) {
    try {
      return _entries.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }
}
