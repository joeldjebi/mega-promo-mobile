import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
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

  static Future<void> initialize() async {
    if (Firebase.apps.isEmpty) return;
    if (_isInitialized) return;
    _isInitialized = true;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _requestPermission();
    await _configureForegroundPresentation();
    await syncTokenForCurrentUser();
    _listenTokenRefresh();
    _listenForegroundMessages();
    _listenNotificationTaps();
    await _handleInitialMessage();
  }

  static Future<void> syncTokenForCurrentUser() async {
    if (Firebase.apps.isEmpty) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      await _stopInAppNotifications();
      return;
    }

    _listenInAppNotificationsForCurrentUser(user.id);

    try {
      final token = await _messaging.getToken();
      if (token == null) {
        debugPrint('[FCM] token unavailable');
        return;
      }

      await Supabase.instance.client
          .from('users')
          .update({'fcm_token': token})
          .eq('id', user.id);
      debugPrint('[FCM] token synced');
    } catch (error, stackTrace) {
      debugPrint('[FCM] token sync failed: $error');
      debugPrint('$stackTrace');
    }
  }

  static Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('[FCM] permission: ${settings.authorizationStatus.name}');
  }

  static Future<void> _configureForegroundPresentation() async {
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: true,
      sound: true,
    );
  }

  static void _listenTokenRefresh() {
    _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((token) async {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      try {
        await Supabase.instance.client
            .from('users')
            .update({'fcm_token': token})
            .eq('id', user.id);
        debugPrint('[FCM] refreshed token synced');
      } catch (error, stackTrace) {
        debugPrint('[FCM] refreshed token sync failed: $error');
        debugPrint('$stackTrace');
      }
    });
  }

  static void _listenForegroundMessages() {
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      final title =
          notification?.title ??
          message.data['title'] as String? ??
          'MegaPromo';
      final body = notification?.body ?? message.data['body'] as String? ?? '';

      scaffoldMessengerKey.currentState?.showMaterialBanner(
        MaterialBanner(
          elevation: 0,
          backgroundColor: AppColors.surface,
          content: Column(
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
          leading: const Icon(
            Icons.notifications_active_rounded,
            color: AppColors.primaryLight,
          ),
          actions: [
            TextButton(
              onPressed: () {
                scaffoldMessengerKey.currentState?.hideCurrentMaterialBanner();
                _openMessageTarget(message);
              },
              child: const Text('Ouvrir'),
            ),
            TextButton(
              onPressed: () {
                scaffoldMessengerKey.currentState?.hideCurrentMaterialBanner();
              },
              child: const Text('Fermer'),
            ),
          ],
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
            final data =
                notification['data'] as Map<String, dynamic>? ?? const {};
            final type = notification['type'] as String? ?? 'info';

            _showInAppBanner(
              title: title,
              body: body,
              type: type,
              data: data,
            );
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

  static void _showInAppBanner({
    required String title,
    required String body,
    required String type,
    required Map<String, dynamic> data,
  }) {
    scaffoldMessengerKey.currentState?.hideCurrentMaterialBanner();
    scaffoldMessengerKey.currentState?.showMaterialBanner(
      MaterialBanner(
        elevation: 0,
        backgroundColor: AppColors.surface,
        content: Column(
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
        leading: const Icon(
          Icons.notifications_active_rounded,
          color: AppColors.primaryLight,
        ),
        actions: [
          TextButton(
            onPressed: () {
              scaffoldMessengerKey.currentState?.hideCurrentMaterialBanner();
              _openDataTarget(type: type, data: data);
            },
            child: const Text('Ouvrir'),
          ),
          TextButton(
            onPressed: () {
              scaffoldMessengerKey.currentState?.hideCurrentMaterialBanner();
            },
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  static void _listenNotificationTaps() {
    FirebaseMessaging.onMessageOpenedApp.listen(_openMessageTarget);
  }

  static Future<void> _handleInitialMessage() async {
    final message = await _messaging.getInitialMessage();
    if (message != null) {
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
}
