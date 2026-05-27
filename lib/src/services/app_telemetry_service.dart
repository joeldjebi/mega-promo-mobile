import 'dart:async';
import 'dart:io';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppTelemetryService {
  AppTelemetryService._();

  static bool _isEnabled = false;
  static final Map<String, Object> _context = <String, Object>{};

  static Future<void> initialize({required bool firebaseReady}) async {
    _isEnabled = firebaseReady && Firebase.apps.isNotEmpty;
    if (!_isEnabled) {
      debugPrint('[TELEMETRY][init] disabled: Firebase unavailable');
      return;
    }

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      unawaited(recordFlutterFatal(details));
    };

    PlatformDispatcher.instance.onError = (error, stackTrace) {
      unawaited(recordFatal(error, stackTrace, reason: 'platform_dispatcher'));
      return true;
    };

    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
      !kDebugMode,
    );
    await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);
    await setContext(<String, Object>{
      'build_mode': kReleaseMode
          ? 'release'
          : kProfileMode
          ? 'profile'
          : 'debug',
      'platform': defaultTargetPlatform.name,
    });
    debugPrint('[TELEMETRY][init] ready');
  }

  static Future<void> setUser(String? userId) async {
    if (!_isEnabled) return;
    await FirebaseCrashlytics.instance.setUserIdentifier(userId ?? '');
    await FirebaseAnalytics.instance.setUserId(id: userId);
  }

  static Future<void> setScreen(
    String screenName, {
    Map<String, Object?> parameters = const <String, Object?>{},
  }) async {
    debugPrint('[TELEMETRY][screen] $screenName $parameters');
    if (!_isEnabled) return;
    await FirebaseCrashlytics.instance.setCustomKey('screen', screenName);
    await FirebaseAnalytics.instance.logScreenView(screenName: screenName);
    await logEvent('screen_view_context', <String, Object?>{
      'screen': screenName,
      ...parameters,
    });
  }

  static Future<void> setContext(Map<String, Object?> values) async {
    final sanitized = _sanitize(values);
    _context.addAll(sanitized);
    if (!_isEnabled) return;
    for (final entry in sanitized.entries) {
      try {
        await FirebaseCrashlytics.instance.setCustomKey(entry.key, entry.value);
      } catch (telemetryError) {
        debugPrint('[TELEMETRY][context_failed] $telemetryError');
      }
    }
  }

  static Future<void> logEvent(
    String name, [
    Map<String, Object?> parameters = const <String, Object?>{},
  ]) async {
    debugPrint('[TELEMETRY][event] $name $parameters');
    if (!_isEnabled) return;
    await FirebaseAnalytics.instance.logEvent(
      name: name,
      parameters: _sanitize(parameters),
    );
  }

  static Future<void> recordFlutterFatal(FlutterErrorDetails details) async {
    if (isRetryableNetworkError(details.exception)) {
      await recordError(
        details.exception,
        details.stack,
        reason: 'flutter_retryable_network',
        context: const <String, Object?>{'fatal_downgraded': true},
      );
      return;
    }

    if (!_isEnabled) {
      debugPrint('[TELEMETRY][flutter_fatal] ${details.exceptionAsString()}');
      return;
    }
    try {
      await FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    } catch (telemetryError) {
      debugPrint('[TELEMETRY][flutter_fatal_failed] $telemetryError');
    }
  }

  static Future<void> recordFatal(
    Object error,
    StackTrace stackTrace, {
    String? reason,
    Map<String, Object?> context = const <String, Object?>{},
  }) async {
    if (isRetryableNetworkError(error)) {
      await recordError(
        error,
        stackTrace,
        reason: reason == null
            ? 'retryable_network'
            : '${reason}_retryable_network',
        context: <String, Object?>{
          ...context,
          'fatal_downgraded': true,
        },
      );
      return;
    }

    await setContext(context);
    debugPrint('[TELEMETRY][fatal] ${reason ?? 'fatal'} $error');
    if (!_isEnabled) return;
    try {
      await FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        reason: reason,
        fatal: true,
        information: _information(context),
      );
    } catch (telemetryError) {
      debugPrint('[TELEMETRY][fatal_failed] $telemetryError');
    }
  }

  static Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
    Map<String, Object?> context = const <String, Object?>{},
  }) async {
    await setContext(context);
    debugPrint('[TELEMETRY][error] ${reason ?? 'non_fatal'} $error');
    if (!_isEnabled) return;
    try {
      await FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        reason: reason,
        fatal: false,
        information: _information(context),
      );
    } catch (telemetryError) {
      debugPrint('[TELEMETRY][error_failed] $telemetryError');
    }
  }

  static String userMessageForError(
    Object error, {
    String fallback = 'Une erreur est survenue. Réessaie.',
  }) {
    final rawMessage = '$error'.toLowerCase();

    if (error is SocketException ||
        error is HttpException ||
        error is TimeoutException ||
        rawMessage.contains('socket') ||
        rawMessage.contains('httpexception') ||
        rawMessage.contains('timeout') ||
        rawMessage.contains('network') ||
        rawMessage.contains('connection refused') ||
        rawMessage.contains('connection reset') ||
        rawMessage.contains('connection closed') ||
        rawMessage.contains('connection abort') ||
        rawMessage.contains('connection aborted') ||
        rawMessage.contains('software caused connection abort') ||
        rawMessage.contains('receiving data') ||
        rawMessage.contains('failed host lookup')) {
      return 'Connexion instable. Vérifie ton internet et réessaie.';
    }

    if (error is AuthException) {
      final code = (error.code ?? '').toLowerCase();
      final message = error.message.toLowerCase();
      if (code == 'phone_provider_disabled' ||
          message.contains('unsupported phone provider')) {
        return 'Connexion par téléphone temporairement indisponible.';
      }
      if (code.contains('otp') ||
          message.contains('token') ||
          message.contains('otp') ||
          message.contains('code')) {
        return 'Code invalide ou expiré. Demande un nouveau code.';
      }
      if (message.contains('rate') || message.contains('too many')) {
        return 'Trop de tentatives. Patiente un moment puis réessaie.';
      }
      return 'Connexion impossible pour le moment. Réessaie.';
    }

    if (error is PostgrestException) {
      final message = error.message.toLowerCase();
      if (message.contains('permission denied') ||
          message.contains('row-level security') ||
          message.contains('rls')) {
        return 'Action non autorisée pour ton compte.';
      }
      if (message.contains('inscriptions sont fermees') ||
          message.contains('inscriptions sont fermées') ||
          message.contains('porte est fermee') ||
          message.contains('porte est fermée')) {
        return 'Les inscriptions sont fermées pour ce Quiz Live.';
      }
      if (message.contains('forfait')) {
        return 'Ton forfait ne permet pas cette action.';
      }
      return fallback;
    }

    if (rawMessage.contains('edge function') ||
        rawMessage.contains('function returned')) {
      return 'Service temporairement indisponible. Réessaie plus tard.';
    }

    return fallback;
  }

  static bool isRetryableNetworkError(Object error) {
    final rawMessage = '$error'.toLowerCase();
    final typeName = error.runtimeType.toString().toLowerCase();

    return error is SocketException ||
        error is HttpException ||
        error is TimeoutException ||
        typeName.contains('authretryablefetch') ||
        typeName.contains('clientexception') ||
        typeName.contains('httpexception') ||
        rawMessage.contains('authretryablefetchexception') ||
        rawMessage.contains('clientexception with socketexception') ||
        rawMessage.contains('httpexception') ||
        rawMessage.contains('socketexception') ||
        rawMessage.contains('connection refused') ||
        rawMessage.contains('connection reset') ||
        rawMessage.contains('connection closed') ||
        rawMessage.contains('receiving data') ||
        rawMessage.contains('software caused connection abort') ||
        rawMessage.contains('connection abort') ||
        rawMessage.contains('connection aborted') ||
        rawMessage.contains('errno = 103') ||
        rawMessage.contains('failed host lookup') ||
        rawMessage.contains('network is unreachable') ||
        rawMessage.contains('no address associated with hostname') ||
        rawMessage.contains('connection timed out') ||
        rawMessage.contains('statuscode: null');
  }

  static Map<String, Object> _sanitize(Map<String, Object?> values) {
    final sanitized = <String, Object>{};
    for (final entry in values.entries) {
      final key = entry.key.trim();
      final value = entry.value;
      if (key.isEmpty || value == null) continue;
      if (value is num || value is bool || value is String) {
        sanitized[key] = value is String && value.length > 96
            ? value.substring(0, 96)
            : value;
      } else {
        final text = value.toString();
        sanitized[key] = text.length > 96 ? text.substring(0, 96) : text;
      }
    }
    return sanitized;
  }

  static Iterable<Object> _information(Map<String, Object?> context) {
    return <Object>[
      if (_context.isNotEmpty) _context,
      if (context.isNotEmpty) _sanitize(context),
    ];
  }
}

class AppTelemetryNavigatorObserver extends NavigatorObserver {
  void _track(Route<dynamic>? route) {
    if (route == null) return;
    final name = route.settings.name;
    if (name == null || name.trim().isEmpty) return;
    unawaited(AppTelemetryService.setScreen(name));
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _track(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _track(newRoute);
  }
}
