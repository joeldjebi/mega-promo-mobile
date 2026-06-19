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
import 'src/features/quiz/services/quiz_result_sync_service.dart';
import 'src/features/rewards/providers/rewards_provider.dart';
import 'src/features/subscriptions/providers/player_subscription_provider.dart';
import 'src/services/app_telemetry_service.dart';
import 'src/services/device_session_service.dart';
import 'src/services/device_telemetry_service.dart';
import 'src/services/fcm_service.dart';
import 'src/services/live_quiz_notification_service.dart';
import 'src/services/network_status_service.dart';
import 'src/services/synced_clock_service.dart';
import 'src/widgets/network_status_banner.dart';

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
      unawaited(QuizResultSyncService.syncPending());
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
        builder: (context, child) {
          return AccountStatusGuard(
            child: NetworkStatusBanner(child: child ?? const SizedBox.shrink()),
          );
        },
        routerConfig: router,
        scaffoldMessengerKey: scaffoldMessengerKey,
      ),
    );
  }
}

class AccountStatusGuard extends ConsumerStatefulWidget {
  final Widget child;

  const AccountStatusGuard({super.key, required this.child});

  @override
  ConsumerState<AccountStatusGuard> createState() => _AccountStatusGuardState();
}

class _AccountStatusGuardState extends ConsumerState<AccountStatusGuard>
    with WidgetsBindingObserver {
  RealtimeChannel? _channel;
  String? _watchedUserId;
  bool _isSigningOut = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _removeChannel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_checkCurrentAccountStatus());
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider);
    if (userId != _watchedUserId) {
      _watchedUserId = userId;
      _subscribeToUser(userId);
      unawaited(_checkCurrentAccountStatus());
    }

    return widget.child;
  }

  void _subscribeToUser(String? userId) {
    _removeChannel();
    if (userId == null) return;

    final supabase = Supabase.instance.client;
    _channel = supabase
        .channel('mobile-account-status-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'users',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: userId,
          ),
          callback: (payload) {
            final row = payload.newRecord.isNotEmpty
                ? payload.newRecord
                : payload.oldRecord;
            unawaited(
              _handleAccountRow(
                row,
                forceDisconnect: payload.eventType == PostgresChangeEvent.delete,
              ),
            );
          },
        )
        .subscribe();
  }

  void _removeChannel() {
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      unawaited(Supabase.instance.client.removeChannel(channel));
    }
  }

  Future<void> _checkCurrentAccountStatus() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || _isSigningOut) return;
    if (!NetworkStatusService.instance.canAttemptNetwork) return;

    try {
      final row = await Supabase.instance.client
          .from('users')
          .select('id, is_active, account_status')
          .eq('id', userId)
          .maybeSingle();
      await _handleAccountRow(row);
    } catch (error, stackTrace) {
      NetworkStatusService.instance.markOfflineFromError(error);
      if (AppTelemetryService.isRetryableNetworkError(error)) return;
      unawaited(
        AppTelemetryService.recordError(
          error,
          stackTrace,
          reason: 'account_status_guard_check_failed',
        ),
      );
    }
  }

  Future<void> _handleAccountRow(
    Map<String, dynamic>? row, {
    bool forceDisconnect = false,
  }) async {
    if (_isSigningOut || Supabase.instance.client.auth.currentUser == null) {
      return;
    }

    if (!forceDisconnect && !_shouldDisconnectForAccountRow(row)) return;

    _isSigningOut = true;
    try {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        _invalidateSessionScopedState(ref, userId: _watchedUserId);
      }
      scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('Ton compte a été désactivé. Connexion fermée.'),
        ),
      );
    } catch (error, stackTrace) {
      unawaited(
        AppTelemetryService.recordError(
          error,
          stackTrace,
          reason: 'account_status_guard_signout_failed',
        ),
      );
    } finally {
      _isSigningOut = false;
    }
  }

  bool _shouldDisconnectForAccountRow(Map<String, dynamic>? row) {
    if (row == null || row.isEmpty) return false;
    final status = (row['account_status'] as String? ?? '').toLowerCase();
    final isActive = row['is_active'] as bool? ?? true;
    if (status == 'deleted') return true;
    if (status == 'pending_deletion') return true;
    if (!isActive) return true;
    return false;
  }
}

class FcmLifecycleSync extends ConsumerStatefulWidget {
  final Widget child;

  const FcmLifecycleSync({super.key, required this.child});

  @override
  ConsumerState<FcmLifecycleSync> createState() => _FcmLifecycleSyncState();
}

class _FcmLifecycleSyncState extends ConsumerState<FcmLifecycleSync>
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
      unawaited(QuizResultSyncService.syncPending());
      ref.invalidate(playerPaymentProfileProvider);
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
