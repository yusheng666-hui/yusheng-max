/// Local persistence for Pose Square votes and collections.
///
/// Follows the same pattern as [UserPreferenceStore]: shared_preferences
/// with JSON-encoded maps/sets, fire-and-forget writes.

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants.dart';

class PoseSquareStore {
  SharedPreferences? _prefs;

  final Map<String, int> _votes = {};
  final Set<String> _collections = {};

  bool _loaded = false;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    _prefs = await SharedPreferences.getInstance();

    final votesStr = _prefs!.getString(StorageKeys.poseSquareVotes);
    if (votesStr != null) {
      try {
        final map = json.decode(votesStr) as Map<String, dynamic>;
        map.forEach((k, v) => _votes[k] = v as int);
      } catch (_) {}
    }

    final collStr = _prefs!.getString(StorageKeys.poseSquareCollections);
    if (collStr != null) {
      try {
        final list = json.decode(collStr) as List<dynamic>;
        for (final e in list) {
          _collections.add(e.toString());
        }
      } catch (_) {}
    }

    _loaded = true;
  }

  void upvotePose(String poseId) {
    _votes[poseId] = 1;
    _persistVotes();
  }

  void downvotePose(String poseId) {
    _votes[poseId] = -1;
    _persistVotes();
  }

  void removeVote(String poseId) {
    _votes.remove(poseId);
    _persistVotes();
  }

  int voteFor(String poseId) => _votes[poseId] ?? 0;

  void toggleCollection(String poseId) {
    if (_collections.contains(poseId)) {
      _collections.remove(poseId);
    } else {
      _collections.add(poseId);
    }
    _persistCollections();
  }

  bool isCollected(String poseId) => _collections.contains(poseId);
  List<String> get collectedPoseIds => _collections.toList();

  void _persistVotes() {
    _prefs?.setString(StorageKeys.poseSquareVotes, json.encode(_votes));
  }

  void _persistCollections() {
    _prefs?.setString(
      StorageKeys.poseSquareCollections,
      json.encode(_collections.toList()),
    );
  }
}
