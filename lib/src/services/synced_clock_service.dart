import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SyncedClockService {
  SyncedClockService._();

  static Duration _serverOffset = Duration.zero;
  static DateTime? _lastSyncedAt;
  static Timer? _syncTimer;
  static Future<void>? _syncFuture;

  static DateTime now() => DateTime.now().add(_serverOffset);

  static int get currentServerSecond => now().millisecondsSinceEpoch ~/ 1000;

  static Future<void> initialize() async {
    await sync();
    _syncTimer ??= Timer.periodic(
      const Duration(minutes: 2),
      (_) => unawaited(sync(force: true)),
    );
  }

  static Future<void> sync({bool force = false}) {
    final runningSync = _syncFuture;
    if (runningSync != null) return runningSync;

    _syncFuture = _sync(force: force).whenComplete(() => _syncFuture = null);
    return _syncFuture!;
  }

  static Future<void> _sync({required bool force}) async {
    final previousSync = _lastSyncedAt;
    if (!force &&
        previousSync != null &&
        DateTime.now().difference(previousSync) < const Duration(seconds: 20)) {
      return;
    }

    try {
      final localBefore = DateTime.now();
      final response = await Supabase.instance.client.rpc('server_now');
      final localAfter = DateTime.now();
      final serverNow = DateTime.tryParse(response.toString());
      if (serverNow == null) return;

      final localMidpoint = localBefore.add(
        Duration(
          microseconds: localAfter.difference(localBefore).inMicroseconds ~/ 2,
        ),
      );
      _serverOffset = serverNow.difference(localMidpoint);
      _lastSyncedAt = localAfter;
    } catch (error) {
      debugPrint('[CLOCK][sync] skipped: $error');
    }
  }
}
