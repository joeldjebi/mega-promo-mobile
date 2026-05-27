import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'live_quiz_live_activity_service.dart';

class LiveQuizNotificationService {
  LiveQuizNotificationService._();

  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    try {
      await _notifications.initialize(settings);
      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          'mega_promo_push',
          'MegaPromo Push',
          description: 'Notifications push distantes MegaPromo',
          importance: Importance.high,
        ),
      );
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          'live_quiz_waiting',
          'Quiz Live',
          description: 'Salle d’attente et rappels Quiz Live MegaPromo',
          importance: Importance.max,
        ),
      );
      await androidPlugin?.requestNotificationsPermission();
      _initialized = true;
    } catch (error, stackTrace) {
      debugPrint('[LiveQuizNotification] init failed: $error');
      debugPrint('$stackTrace');
    }
  }

  static Future<void> showWaitingNotification({
    required String contestId,
    required String title,
    required DateTime startsAt,
    String prizeLabel = 'Récompense surprise',
    int registeredCount = 0,
    int connectedCount = 0,
    bool showClassicNotification = true,
  }) async {
    await initialize();
    await LiveQuizLiveActivityService.startOrUpdateWaiting(
      contestId: contestId,
      title: title,
      startsAt: startsAt,
      prizeLabel: prizeLabel,
      registeredCount: registeredCount,
      connectedCount: connectedCount,
    );

    if (!showClassicNotification) return;
    if (!_initialized) return;

    final time =
        '${startsAt.hour.toString().padLeft(2, '0')}:'
        '${startsAt.minute.toString().padLeft(2, '0')}';

    const androidDetails = AndroidNotificationDetails(
      'live_quiz_waiting',
      'Quiz Live',
      channelDescription: 'Salle d’attente et rappels Quiz Live MegaPromo',
      importance: Importance.max,
      priority: Priority.high,
      ongoing: true,
      autoCancel: false,
      showWhen: true,
      category: AndroidNotificationCategory.event,
      visibility: NotificationVisibility.public,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    await _notifications.show(
      _notificationId(contestId),
      'Quiz Live en attente',
      '$title démarre à $time. Reste prêt, le jeu se lance automatiquement.',
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: contestId,
    );
  }

  static Future<void> cancelWaitingNotification(String contestId) async {
    await LiveQuizLiveActivityService.end(contestId);
    if (!_initialized) return;
    await _notifications.cancel(_notificationId(contestId));
  }

  static int _notificationId(String contestId) {
    return contestId.hashCode & 0x7fffffff;
  }
}
