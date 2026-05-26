/// Monitors network connectivity for online/offline mode switching.
///
/// Uses a combination of socket-level checks and periodic backend health
/// pings to determine if the cloud recommendation API is reachable.

import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'constants.dart';

class ConnectivityChecker {
  final Dio _dio;
  bool _isOnline = true;
  Timer? _pingTimer;

  final _statusController = StreamController<bool>.broadcast();

  ConnectivityChecker({String? baseUrl})
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl ?? ApiConstants.baseUrl,
          connectTimeout: const Duration(seconds: 3),
          receiveTimeout: const Duration(seconds: 3),
        ));

  bool get isOnline => _isOnline;

  Stream<bool> get onStatusChange => _statusController.stream;

  /// Start periodic connectivity checks.
  void start({Duration interval = const Duration(seconds: 15)}) {
    _pingTimer?.cancel();
    _checkNow();
    _pingTimer = Timer.periodic(interval, (_) => _checkNow());
  }

  /// Stop periodic checks.
  void stop() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  /// Run a single connectivity check.
  Future<bool> checkNow() => _checkNow();

  Future<bool> _checkNow() async {
    try {
      // First check: can we resolve DNS at all?
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 2));
      if (result.isEmpty || result[0].rawAddress.isEmpty) {
        _setOnline(false);
        return false;
      }

      // Second check: is our backend reachable?
      final response = await _dio.get(
        ApiConstants.recommendHealth,
      );
      final online = response.statusCode == 200;
      _setOnline(online);
      return online;
    } on SocketException {
      _setOnline(false);
      return false;
    } on TimeoutException {
      _setOnline(false);
      return false;
    } on DioException {
      _setOnline(false);
      return false;
    } catch (_) {
      _setOnline(false);
      return false;
    }
  }

  void _setOnline(bool value) {
    if (_isOnline != value) {
      _isOnline = value;
      _statusController.add(value);
    }
  }

  void dispose() {
    stop();
    _statusController.close();
    _dio.close();
  }
}
