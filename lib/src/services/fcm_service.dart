import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../firebase_options.dart';
import '../features/profile/providers/player_payment_methods_provider.dart';
import '../features/rewards/providers/rewards_provider.dart';
import 'app_telemetry_service.dart';
import 'app_logger.dart';

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
  static Timer? _winnerNavigationTimer;
  static int _syncRetryAttempt = 0;
  static String? _lastWinnerNavigationId;
  static DateTime? _lastWinnerNavigationAt;

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

    final user = Supabase.instance.client.auth.currentSession?.user;
    if (user == null) {
      debugPrint('[FCM][sync] skipped: no active authenticated session');
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
      unawaited(
        AppLogger.info(
          'push',
          'fcm_token_synced',
          'Token FCM enregistre pour le joueur.',
          metadata: {
            'platform': _platformKey(),
            'token_preview': _tokenPreview(token),
            'force': force,
          },
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('[FCM][sync] token sync failed: $error');
      debugPrint('$stackTrace');
      _scheduleSyncRetry(force: force);
      unawaited(
        AppLogger.warning(
          'push',
          'fcm_token_sync_failed',
          'Echec enregistrement token FCM.',
          metadata: {
            'platform': _platformKey(),
            'attempt': _syncRetryAttempt,
            'error': error.toString(),
          },
        ),
      );
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
      final user = Supabase.instance.client.auth.currentSession?.user;
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
        unawaited(
          AppLogger.info(
            'push',
            'fcm_token_refreshed',
            'Token FCM rafraichi pour le joueur.',
            metadata: {
              'platform': _platformKey(),
              'token_preview': _tokenPreview(token),
            },
          ),
        );
      } catch (error, stackTrace) {
        debugPrint('[FCM][refresh] refreshed token sync failed: $error');
        debugPrint('$stackTrace');
        unawaited(
          AppLogger.warning(
            'push',
            'fcm_token_refresh_failed',
            'Echec synchronisation token FCM rafraichi.',
            metadata: {
              'platform': _platformKey(),
              'error': error.toString(),
            },
          ),
        );
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

      debugPrint(
        '[FCM][message] foreground display skipped title=$title bodyLength=${body.length}',
      );
      unawaited(
        AppLogger.info(
          'push',
          'foreground_message_received',
          'Notification push recue en foreground.',
          metadata: {
            'message_id': message.messageId,
            'type': message.data['type'],
            'has_notification': notification != null,
          },
        ),
      );
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
                notification['title'] as String? ?? 'Nouveau quiz';
            final type = notification['type'] as String? ?? 'info';
            debugPrint(
              '[FCM][in-app] notification received id=${notification['id']} '
              'type=$type title=$title',
            );
            if (type == 'kyc') {
              _invalidateKycState();
            }
            unawaited(
              AppLogger.info(
                'notifications',
                'in_app_notification_received',
                'Notification in-app recue.',
                entityType: 'notification',
                entityId: notification['id'] as String?,
                metadata: {'type': type},
              ),
            );
            _openNotificationRecordTarget(notification);
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
    final type = message.data['type'] as String?;
    if (type == 'kyc') {
      _invalidateKycState();
    }
    _openDataTarget(type: type, data: message.data);
  }

  static void _invalidateKycState() {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;
    try {
      ProviderScope.containerOf(
        context,
        listen: false,
      ).invalidate(playerPaymentProfileProvider);
    } catch (_) {
      // The app may still be bootstrapping when the notification arrives.
    }
  }

  static void _invalidateRewardsState() {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      container.invalidate(rewardsProvider);
    } catch (_) {
      // The app may still be bootstrapping when the notification arrives.
    }
  }

  static void _openNotificationRecordTarget(Map<String, dynamic> notification) {
    final type = notification['type'] as String?;
    if (type != 'winner' && type != 'gain') return;

    final rawData = notification['data'];
    final data = rawData is Map
        ? rawData.cast<String, dynamic>()
        : <String, dynamic>{};
    _openDataTarget(type: type, data: data);
  }

  static void _openWinnerVictory(String winnerId) {
    final now = DateTime.now();
    final lastAt = _lastWinnerNavigationAt;
    if (_lastWinnerNavigationId == winnerId &&
        lastAt != null &&
        now.difference(lastAt) < const Duration(seconds: 3)) {
      debugPrint('[FCM][winner] duplicate navigation ignored id=$winnerId');
      return;
    }

    _lastWinnerNavigationId = winnerId;
    _lastWinnerNavigationAt = now;
    _winnerNavigationTimer?.cancel();
    _winnerNavigationTimer = Timer(const Duration(milliseconds: 180), () {
      final navigationContext = rootNavigatorKey.currentContext;
      if (navigationContext == null) return;

      final path = '/rewards/$winnerId';
      try {
        final currentPath = GoRouterState.of(navigationContext).uri.path;
        if (currentPath == path) return;
      } catch (_) {
        // If the router state is unavailable during bootstrap, navigation can
        // still safely proceed from the root context.
      }

      final navToken = DateTime.now().microsecondsSinceEpoch;
      navigationContext.go('$path?nav=$navToken');
    });
  }

  static void _openDataTarget({
    required String? type,
    required Map<String, dynamic> data,
  }) {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;

    final winnerId =
        data['winner_id'] as String? ??
        data['winnerId'] as String? ??
        data['id'] as String?;

    if ((type == 'winner' || type == 'gain') &&
        winnerId != null &&
        winnerId.isNotEmpty) {
      _invalidateRewardsState();
      _openWinnerVictory(winnerId);
      return;
    }

    switch (type) {
      case 'winner':
      case 'gain':
        _invalidateRewardsState();
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
