import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_telemetry_service.dart';
import 'device_telemetry_service.dart';
import 'fcm_service.dart';

class DeviceSessionService {
  DeviceSessionService._();

  static const _sessionKey = 'megapromo_device_session_id';
  static final _observer = _DeviceSessionLifecycleObserver();
  static bool _initialized = false;
  static String? _sessionId;
  static bool _isChecking = false;

  static void initialize() {
    if (_initialized) return;
    _initialized = true;
    WidgetsBinding.instance.addObserver(_observer);
    Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(validateCurrentSession()),
    );
  }

  static Future<void> claimCurrentSession({bool force = false}) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentSession?.user;
    if (user == null) return;

    try {
      final sessionId = await _getSessionId();
      await supabase.rpc(
        'claim_player_device_session',
        params: {
          'p_session_id': sessionId,
          'p_device_info': await DeviceTelemetryService.collectDeviceInfo(),
        },
      );
      if (force) await validateCurrentSession();
    } catch (error, stackTrace) {
      debugPrint('Device session claim failed: $error');
      unawaited(
        AppTelemetryService.recordError(
          error,
          stackTrace,
          reason: 'device_session_claim_failed',
        ),
      );
    }
  }

  static Future<void> validateCurrentSession() async {
    if (_isChecking) return;
    _isChecking = true;
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentSession?.user;
      if (user == null) return;

      final sessionId = await _getSessionId();
      final response = await supabase.rpc(
        'validate_player_device_session',
        params: {'p_session_id': sessionId},
      );
      final active = response is Map && response['active'] == true;
      if (!active) {
        await AppTelemetryService.logEvent('device_session_replaced');
        await FcmService.stopForCurrentUser();
        await supabase.auth.signOut();
        final context = rootNavigatorKey.currentContext;
        if (context != null && context.mounted) {
          scaffoldMessengerKey.currentState?.showSnackBar(
            const SnackBar(
              content: Text(
                'Ton compte est connecté sur un autre appareil. Cette session a été fermée.',
              ),
            ),
          );
          context.go('/login');
        }
      }
    } catch (error, stackTrace) {
      debugPrint('Device session validation failed: $error');
      unawaited(
        AppTelemetryService.recordError(
          error,
          stackTrace,
          reason: 'device_session_validation_failed',
        ),
      );
    } finally {
      _isChecking = false;
    }
  }

  static Future<String> _getSessionId() async {
    if (_sessionId != null) return _sessionId!;
    final preferences = await SharedPreferences.getInstance();
    final existing = preferences.getString(_sessionKey);
    if (existing != null && existing.isNotEmpty) {
      _sessionId = existing;
      return existing;
    }

    final random = Random.secure().nextInt(1 << 32);
    final generated = 'mobile-${DateTime.now().microsecondsSinceEpoch}-$random';
    await preferences.setString(_sessionKey, generated);
    _sessionId = generated;
    return generated;
  }
}

class _DeviceSessionLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(DeviceSessionService.validateCurrentSession());
    }
  }
}
