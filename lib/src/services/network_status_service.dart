import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../config/supabase_config.dart';

class NetworkStatusService {
  NetworkStatusService._();

  static final NetworkStatusService instance = NetworkStatusService._();

  final ValueNotifier<bool> isOffline = ValueNotifier<bool>(false);
  Timer? _timer;
  bool _isChecking = false;
  DateTime? _lastCheckAt;

  static const String offlineActionMessage =
      'Connexion internet indisponible. Réessaie quand le réseau revient.';

  bool get canAttemptNetwork => !isOffline.value;

  void start() {
    _timer?.cancel();
    unawaited(checkNow());
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      unawaited(checkNow());
    });
  }

  void pause() {
    _timer?.cancel();
  }

  Future<bool> ensureOnline() async {
    if (isOffline.value) return checkNow(force: true);
    unawaited(checkNow());
    return true;
  }

  void markOffline() {
    _lastCheckAt = DateTime.now();
    if (!isOffline.value) {
      isOffline.value = true;
    }
  }

  void markOfflineFromError(Object error) {
    if (_looksLikeNetworkError(error)) markOffline();
  }

  Future<bool> checkNow({bool force = false}) async {
    if (_isChecking) return !isOffline.value;
    final lastCheckAt = _lastCheckAt;
    if (!force &&
        lastCheckAt != null &&
        DateTime.now().difference(lastCheckAt) < const Duration(seconds: 4)) {
      return !isOffline.value;
    }

    _isChecking = true;
    try {
      _lastCheckAt = DateTime.now();
      final online = await _canReachSupabase();
      if (isOffline.value == online) {
        isOffline.value = !online;
      }
      return online;
    } finally {
      _isChecking = false;
    }
  }

  Future<bool> _canReachSupabase() async {
    final host = Uri.tryParse(kSupabaseUrl)?.host;
    if (host == null || host.isEmpty) return false;

    try {
      final addresses = await InternetAddress.lookup(
        host,
      ).timeout(const Duration(milliseconds: 1200));
      return addresses.isNotEmpty;
    } on Object {
      return false;
    }
  }

  bool _looksLikeNetworkError(Object error) {
    final rawMessage = '$error'.toLowerCase();
    final typeName = error.runtimeType.toString().toLowerCase();
    return error is SocketException ||
        error is HttpException ||
        error is TimeoutException ||
        typeName.contains('clientexception') ||
        typeName.contains('authretryablefetch') ||
        rawMessage.contains('socketexception') ||
        rawMessage.contains('clientexception') ||
        rawMessage.contains('failed host lookup') ||
        rawMessage.contains('nodename nor servname') ||
        rawMessage.contains('no address associated with hostname') ||
        rawMessage.contains('network is unreachable') ||
        rawMessage.contains('internet connection appears to be offline') ||
        rawMessage.contains('connection refused') ||
        rawMessage.contains('connection reset') ||
        rawMessage.contains('connection closed') ||
        rawMessage.contains('connection timed out') ||
        rawMessage.contains('software caused connection abort') ||
        rawMessage.contains('statuscode: null');
  }
}
