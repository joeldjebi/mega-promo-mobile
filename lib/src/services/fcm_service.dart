import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../firebase_options.dart';
import 'app_telemetry_service.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (_) {
    return;
  }
  // Firebase Messaging displays system notifications automatically when the
  // payload contains a notification block. Data-only background handling can be
  // added here later if needed.
}

class FcmService {
  FcmService._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static bool _isInitialized = false;
  static StreamSubscription<String>? _tokenRefreshSubscription;
  static RealtimeChannel? _notificationsChannel;
  static String? _notificationsUserId;
  static Timer? _syncRetryTimer;
  static int _syncRetryAttempt = 0;

  static Future<void> initialize() async {
    if (Firebase.apps.isEmpty) {
      debugPrint('[FCM][init] skipped: Firebase is not initialized');
      return;
    }
    if (_isInitialized) {
      debugPrint('[FCM][init] skipped: already initialized');
      return;
    }
    _isInitialized = true;
    debugPrint('[FCM][init] starting on ${defaultTargetPlatform.name}');

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _requestPermission();
    await _configureForegroundPresentation();
    await syncTokenForCurrentUser(force: true);
    _listenTokenRefresh();
    _listenForegroundMessages();
    _listenNotificationTaps();
    await _handleInitialMessage();
  }

  static Future<void> syncTokenForCurrentUser({bool force = false}) async {
    if (Firebase.apps.isEmpty) {
      debugPrint('[FCM][sync] skipped: Firebase is not initialized');
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      debugPrint('[FCM][sync] skipped: no authenticated user');
      _cancelSyncRetry();
      await _stopInAppNotifications();
      return;
    }

    _listenInAppNotificationsForCurrentUser(user.id);
    debugPrint('[FCM][sync] starting for user=${_idPreview(user.id)}');

    try {
      if (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        final apnsToken = await _waitForApplePushToken();
        if (apnsToken == null) {
          debugPrint('[FCM][sync] APNs token unavailable after retries');
          _scheduleSyncRetry(force: force);
          return;
        }
        debugPrint('[FCM][sync] APNs token ready ${_tokenPreview(apnsToken)}');
      }

      final token = await _messaging.getToken();
      if (token == null) {
        debugPrint('[FCM][sync] FCM token unavailable');
        _scheduleSyncRetry(force: force);
        return;
      }
      debugPrint('[FCM][sync] FCM token ready ${_tokenPreview(token)}');
      debugPrint('[FCM][sync] user=${user.id} full_fcm_token=$token');

      await Supabase.instance.client
          .from('users')
          .update({
            'fcm_token': token,
            'fcm_token_platform': _platformKey(),
            'fcm_token_updated_at': DateTime.now().toIso8601String(),
            'fcm_token_last_error': null,
            'fcm_token_last_error_at': null,
          })
          .eq('id', user.id);
      _cancelSyncRetry();
      debugPrint('[FCM][sync] token synced for user=${_idPreview(user.id)}');
    } catch (error, stackTrace) {
      debugPrint('[FCM][sync] token sync failed: $error');
      debugPrint('$stackTrace');
      _scheduleSyncRetry(force: force);
      unawaited(
        AppTelemetryService.recordError(
          error,
          stackTrace,
          reason: 'fcm_token_sync_failed',
          context: {'platform': defaultTargetPlatform.name},
        ),
      );
    }
  }

  static Future<void> stopForCurrentUser() async {
    _cancelSyncRetry();
    await _stopInAppNotifications();
  }

  static void _scheduleSyncRetry({bool force = false}) {
    if (_syncRetryTimer?.isActive == true) return;
    if (!force && _syncRetryAttempt >= 12) return;

    _syncRetryAttempt += 1;
    final delay = Duration(seconds: _syncRetryAttempt <= 3 ? 2 : 10);
    debugPrint(
      '[FCM][sync] retry #$_syncRetryAttempt scheduled in ${delay.inSeconds}s',
    );

    _syncRetryTimer = Timer(delay, () {
      _syncRetryTimer = null;
      unawaited(syncTokenForCurrentUser());
    });
  }

  static void _cancelSyncRetry() {
    _syncRetryTimer?.cancel();
    _syncRetryTimer = null;
    _syncRetryAttempt = 0;
  }

  static Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint(
      '[FCM][permission] status=${settings.authorizationStatus.name} '
      'alert=${settings.alert.name} badge=${settings.badge.name} '
      'sound=${settings.sound.name} announcement=${settings.announcement.name}',
    );
  }

  static Future<void> _configureForegroundPresentation() async {
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint(
      '[FCM][foreground] presentation alert=true badge=true sound=true',
    );
  }

  static Future<String?> _waitForApplePushToken() async {
    String? token = await _messaging.getAPNSToken();
    if (token != null) {
      debugPrint('[FCM][apns] token available immediately');
      return token;
    }

    for (var attempt = 0; attempt < 10; attempt += 1) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      token = await _messaging.getAPNSToken();
      if (token != null) {
        debugPrint('[FCM][apns] token available after ${attempt + 1} retry');
        return token;
      }
    }

    return null;
  }

  static void _listenTokenRefresh() {
    _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((token) async {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      try {
        debugPrint('[FCM][refresh] token refreshed ${_tokenPreview(token)}');
        debugPrint('[FCM][refresh] user=${user.id} full_fcm_token=$token');
        await Supabase.instance.client
            .from('users')
            .update({
              'fcm_token': token,
              'fcm_token_platform': _platformKey(),
              'fcm_token_updated_at': DateTime.now().toIso8601String(),
              'fcm_token_last_error': null,
              'fcm_token_last_error_at': null,
            })
            .eq('id', user.id);
        debugPrint('[FCM][refresh] refreshed token synced');
      } catch (error, stackTrace) {
        debugPrint('[FCM][refresh] refreshed token sync failed: $error');
        debugPrint('$stackTrace');
        unawaited(
          AppTelemetryService.recordError(
            error,
            stackTrace,
            reason: 'fcm_token_refresh_sync_failed',
          ),
        );
      }
    });
  }

  static void _listenForegroundMessages() {
    FirebaseMessaging.onMessage.listen((message) {
      debugPrint(
        '[FCM][message] foreground id=${message.messageId} '
        'type=${message.data['type']} data=${message.data}',
      );
      final notification = message.notification;
      final title =
          notification?.title ??
          message.data['title'] as String? ??
          'MegaPromo';
      final body = notification?.body ?? message.data['body'] as String? ?? '';

      _showPlainNotification(title: title, body: body);
    });
  }

  static void _listenInAppNotificationsForCurrentUser(String userId) {
    if (_notificationsUserId == userId && _notificationsChannel != null) {
      return;
    }

    unawaited(_stopInAppNotifications());
    _notificationsUserId = userId;

    final supabase = Supabase.instance.client;
    debugPrint('[FCM][in-app] subscribing user=${_idPreview(userId)}');
    _notificationsChannel = supabase
        .channel('mobile-notifications-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            final notification = payload.newRecord;
            final title =
                notification['title'] as String? ?? 'Nouveau concours';
            final body = notification['body'] as String? ?? '';
            final type = notification['type'] as String? ?? 'info';
            debugPrint(
              '[FCM][in-app] notification received id=${notification['id']} '
              'type=$type title=$title',
            );

            _showPlainNotification(title: title, body: body);
          },
        )
        .subscribe();
  }

  static Future<void> _stopInAppNotifications() async {
    final channel = _notificationsChannel;
    _notificationsChannel = null;
    _notificationsUserId = null;
    if (channel == null) return;

    try {
      await Supabase.instance.client.removeChannel(channel);
    } catch (_) {
      // The channel may already be closed after a session reset.
    }
  }

  static void _showPlainNotification({
    required String title,
    required String body,
  }) {
    scaffoldMessengerKey.currentState
      ?..hideCurrentMaterialBanner()
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.surface,
          elevation: 8,
          content: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.notifications_active_rounded,
                color: AppColors.primaryLight,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: AppTextStyles.h3),
                    if (body.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(body, style: AppTextStyles.bodySecondary),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
  }

  static void _listenNotificationTaps() {
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint(
        '[FCM][tap] opened id=${message.messageId} type=${message.data['type']}',
      );
      _openMessageTarget(message);
    });
  }

  static Future<void> _handleInitialMessage() async {
    final message = await _messaging.getInitialMessage();
    if (message != null) {
      debugPrint(
        '[FCM][initial] opened id=${message.messageId} type=${message.data['type']}',
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openMessageTarget(message);
      });
    }
  }

  static void _openMessageTarget(RemoteMessage message) {
    _openDataTarget(type: message.data['type'] as String?, data: message.data);
  }

  static void _openDataTarget({
    required String? type,
    required Map<String, dynamic> data,
  }) {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;

    switch (type) {
      case 'winner':
      case 'gain':
        context.go('/rewards');
        return;
      case 'subscription':
        context.go('/subscriptions');
        return;
      case 'leaderboard':
        context.go('/leaderboard');
        return;
      case 'profile':
        context.go('/profile');
        return;
    }

    final contestId =
        data['contest_id'] as String? ?? data['contestId'] as String?;

    if (contestId != null && contestId.isNotEmpty) {
      if (type == 'live_quiz_waiting' || type == 'live_quiz_reminder') {
        context.go('/contests/$contestId/live-waiting');
        return;
      }
      context.go('/contests/$contestId');
      return;
    }

    context.go('/notifications');
  }

  static String _tokenPreview(String token) {
    if (token.length <= 16) return token;
    return '${token.substring(0, 8)}...${token.substring(token.length - 6)}';
  }

  static String _platformKey() {
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'ios',
      TargetPlatform.android => 'android',
      _ => 'unknown',
    };
  }

  static String _idPreview(String id) {
    if (id.length <= 12) return id;
    return '${id.substring(0, 8)}...';
  }
}
