import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'network_status_service.dart';

class AppLogger {
  AppLogger._();

  static PackageInfo? _packageInfo;

  static const List<String> _sensitiveKeyFragments = <String>[
    'otp',
    'password',
    'passcode',
    'pin',
    'token',
    'access_token',
    'refresh_token',
    'authorization',
    'fcm_token',
    'service_role_key',
    'identity_document',
    'document_url',
    'document',
    'identity',
    'secret',
    'api_key',
    'apikey',
    'phone',
    'email',
    'msisdn',
    'mobile_money',
    'payment_number',
    'account_number',
  ];

  static Future<void> debug(
    String feature,
    String action,
    String message, {
    Map<String, Object?> metadata = const <String, Object?>{},
    String? entityType,
    String? entityId,
  }) {
    return log(
      level: 'debug',
      feature: feature,
      action: action,
      message: message,
      metadata: metadata,
      entityType: entityType,
      entityId: entityId,
    );
  }

  static Future<void> info(
    String feature,
    String action,
    String message, {
    Map<String, Object?> metadata = const <String, Object?>{},
    String? entityType,
    String? entityId,
  }) {
    return log(
      level: 'info',
      feature: feature,
      action: action,
      message: message,
      metadata: metadata,
      entityType: entityType,
      entityId: entityId,
    );
  }

  static Future<void> warning(
    String feature,
    String action,
    String message, {
    Map<String, Object?> metadata = const <String, Object?>{},
    String? entityType,
    String? entityId,
  }) {
    return log(
      level: 'warning',
      feature: feature,
      action: action,
      message: message,
      metadata: metadata,
      entityType: entityType,
      entityId: entityId,
    );
  }

  static Future<void> error(
    String feature,
    String action,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> metadata = const <String, Object?>{},
    String? entityType,
    String? entityId,
  }) {
    return log(
      level: 'error',
      feature: feature,
      action: action,
      message: message,
      metadata: <String, Object?>{
        ...metadata,
        if (error != null) 'error': error.toString(),
        if (stackTrace != null) 'stack': stackTrace.toString(),
      },
      entityType: entityType,
      entityId: entityId,
    );
  }

  static Future<void> log({
    required String level,
    required String feature,
    required String action,
    required String message,
    Map<String, Object?> metadata = const <String, Object?>{},
    String? entityType,
    String? entityId,
  }) async {
    if (!NetworkStatusService.instance.canAttemptNetwork) {
      debugPrint('[APP_LOGGER][offline_skip] $feature.$action $message');
      return;
    }

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      final packageInfo = await _getPackageInfo();
      final cleanedMetadata = _sanitizeMap(<String, Object?>{
        ...metadata,
        'platform': defaultTargetPlatform.name,
        'app_version': packageInfo.version,
        'build_number': packageInfo.buildNumber,
        'build_mode': kReleaseMode
            ? 'release'
            : kProfileMode
            ? 'profile'
            : 'debug',
      });

      await supabase.rpc(
        'log_system_event',
        params: <String, Object?>{
          'p_level': level,
          'p_source': 'mobile',
          'p_feature': feature,
          'p_action': action,
          'p_message': message,
          'p_user_id': user?.id,
          'p_admin_id': null,
          'p_partner_id': null,
          'p_entity_type': entityType,
          'p_entity_id': entityId,
          'p_metadata': cleanedMetadata,
          'p_ip_address': null,
          'p_user_agent':
              'MegaPromo/${packageInfo.version}+${packageInfo.buildNumber} ${defaultTargetPlatform.name}',
        },
      );
    } catch (logError, stackTrace) {
      NetworkStatusService.instance.markOfflineFromError(logError);
      if (!NetworkStatusService.instance.canAttemptNetwork ||
          _isNetworkWriteError(logError)) {
        debugPrint('[APP_LOGGER][network_skip] $logError');
        return;
      }
      debugPrint('[APP_LOGGER][write_failed] $logError');
      debugPrint('$stackTrace');
    }
  }

  static Future<PackageInfo> _getPackageInfo() async {
    final cached = _packageInfo;
    if (cached != null) return cached;
    final packageInfo = await PackageInfo.fromPlatform();
    _packageInfo = packageInfo;
    return packageInfo;
  }

  static Map<String, Object?> _sanitizeMap(Map<String, Object?> values) {
    final result = <String, Object?>{};
    for (final entry in values.entries) {
      final key = entry.key.trim();
      if (key.isEmpty || _isSensitiveKey(key)) continue;
      final value = _sanitizeValue(entry.value);
      if (value != null) result[key] = value;
    }
    return result;
  }

  static Object? _sanitizeValue(Object? value) {
    if (value == null) return null;
    if (value is String) {
      final masked = _maskEmail(_maskPhone(value));
      return masked.length > 500 ? masked.substring(0, 500) : masked;
    }
    if (value is num || value is bool) return value;
    if (value is DateTime) return value.toIso8601String();
    if (value is Iterable) {
      return value.take(30).map((item) => _sanitizeValue(item)).toList();
    }
    if (value is Map) {
      final result = <String, Object?>{};
      value.forEach((key, item) {
        final textKey = key.toString().trim();
        if (textKey.isEmpty || _isSensitiveKey(textKey)) return;
        final sanitized = _sanitizeValue(item);
        if (sanitized != null) result[textKey] = sanitized;
      });
      return result;
    }
    final text = value.toString();
    return text.length > 500 ? text.substring(0, 500) : text;
  }

  static String _maskPhone(String value) {
    final compact = value.replaceAll(RegExp(r'\s+'), '');
    if (!RegExp(r'^\+?\d{8,16}$').hasMatch(compact)) return value;
    if (compact.length <= 6) return compact;
    return '${compact.substring(0, 6)}******${compact.substring(compact.length - 2)}';
  }

  static String _maskEmail(String value) {
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) return value;
    final parts = value.split('@');
    final visibleLength = parts.first.length < 2 ? parts.first.length : 2;
    return '${parts.first.substring(0, visibleLength)}***@${parts.last}';
  }

  static bool _isSensitiveKey(String key) {
    final normalizedKey = key.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]+'),
      '_',
    );
    return _sensitiveKeyFragments.any(normalizedKey.contains);
  }

  static bool _isNetworkWriteError(Object error) {
    final rawMessage = '$error'.toLowerCase();
    final typeName = error.runtimeType.toString().toLowerCase();
    return typeName.contains('clientexception') ||
        rawMessage.contains('socketexception') ||
        rawMessage.contains('failed host lookup') ||
        rawMessage.contains('nodename nor servname') ||
        rawMessage.contains('internet connection appears to be offline') ||
        rawMessage.contains('network is unreachable') ||
        rawMessage.contains('no address associated with hostname') ||
        rawMessage.contains('connection refused') ||
        rawMessage.contains('connection reset') ||
        rawMessage.contains('connection closed') ||
        rawMessage.contains('connection timed out') ||
        rawMessage.contains('statuscode: null');
  }
}
