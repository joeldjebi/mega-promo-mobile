import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'src/config/supabase_config.dart';
import 'src/config/router.dart';
import 'src/features/auth/providers/auth_provider.dart';
import 'src/features/contests/providers/contest_providers.dart';
import 'src/features/home/providers/home_bootstrap_provider.dart';
import 'src/features/home/providers/info_message_provider.dart';
import 'src/features/home/providers/user_profile_provider.dart';
import 'src/features/leaderboard/providers/leaderboard_provider.dart';
import 'src/features/notifications/providers/notifications_provider.dart';
import 'src/features/profile/providers/player_payment_methods_provider.dart';
import 'src/features/profile/providers/profile_provider.dart';
import 'src/features/rewards/providers/rewards_provider.dart';
import 'src/features/subscriptions/providers/player_subscription_provider.dart';
import 'src/services/app_telemetry_service.dart';
import 'src/services/device_session_service.dart';
import 'src/services/device_telemetry_service.dart';
import 'src/services/fcm_service.dart';
import 'src/services/live_quiz_notification_service.dart';
import 'src/services/synced_clock_service.dart';

Future<void> main() async {
  await runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      final firebaseReady = await _initializeFirebase();
      await AppTelemetryService.initialize(firebaseReady: firebaseReady);
      await Supabase.initialize(url: kSupabaseUrl, anonKey: kSupabaseAnonKey);
      unawaited(SyncedClockService.initialize());
      await LiveQuizNotificationService.initialize();
      DeviceTelemetryService.initialize();
      DeviceSessionService.initialize();
      if (firebaseReady) {
        unawaited(FcmService.initialize());
      }

      runApp(const ProviderScope(child: KonkourApp()));
    },
    (error, stackTrace) {
      unawaited(
        AppTelemetryService.recordFatal(
          error,
          stackTrace,
          reason: 'run_zoned_guarded',
        ),
      );
    },
  );
}

Future<bool> _initializeFirebase() async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    return true;
  } on FirebaseException catch (error) {
    debugPrint('Firebase disabled: ${error.code} ${error.message}');
    return false;
  } catch (error) {
    debugPrint('Firebase disabled: $error');
    return false;
  }
}

class KonkourApp extends ConsumerWidget {
  const KonkourApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    ref.listen(authStateProvider, (previous, next) {
      final previousUserId = previous?.asData?.value?.id;
      final nextUserId = next.asData?.value?.id;
      if (previousUserId != nextUserId) {
        _invalidateSessionScopedState(
          ref,
          userId: previousUserId ?? nextUserId,
        );
      }

      unawaited(AppTelemetryService.setUser(nextUserId));
      unawaited(FcmService.syncTokenForCurrentUser());
      unawaited(DeviceTelemetryService.syncForCurrentUser(force: true));
      unawaited(DeviceSessionService.claimCurrentSession(force: true));
    });

    return FcmLifecycleSync(
      child: MaterialApp.router(
        title: 'MegaPromo',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        routerConfig: router,
        scaffoldMessengerKey: scaffoldMessengerKey,
      ),
    );
  }
}

class FcmLifecycleSync extends StatefulWidget {
  final Widget child;

  const FcmLifecycleSync({super.key, required this.child});

  @override
  State<FcmLifecycleSync> createState() => _FcmLifecycleSyncState();
}

class _FcmLifecycleSyncState extends State<FcmLifecycleSync>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(FcmService.syncTokenForCurrentUser(force: true));
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

void _invalidateSessionScopedState(WidgetRef ref, {String? userId}) {
  clearAllContestDetailCache();
  clearHomeBootstrapCache(userId: userId, clearStored: true);
  ref
    ..invalidate(userProfileProvider)
    ..invalidate(homeBootstrapProvider)
    ..invalidate(profileDataProvider)
    ..invalidate(playerPaymentProfileProvider)
    ..invalidate(rewardsProvider)
    ..invalidate(playerPlansProvider)
    ..invalidate(contestsProvider)
    ..invalidate(userParticipatedContestIdsProvider)
    ..invalidate(userRegisteredLiveQuizIdsProvider)
    ..invalidate(contestsShuffleSeedProvider)
    ..invalidate(contestParticipantsCountProvider)
    ..invalidate(contestDetailProvider)
    ..invalidate(leaderboardProvider)
    ..invalidate(notificationsProvider)
    ..invalidate(infoMessagesProvider);
}
