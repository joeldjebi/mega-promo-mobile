import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mega_promo/core/theme/app_colors.dart';
import 'package:mega_promo/core/theme/app_text_styles.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/auth_provider.dart';
import '../../contests/providers/contest_providers.dart';
import '../../home/providers/home_bootstrap_provider.dart';
import '../../home/providers/info_message_provider.dart';
import '../../home/providers/user_profile_provider.dart';
import '../../leaderboard/providers/leaderboard_provider.dart';
import '../../notifications/providers/notifications_provider.dart';
import '../../profile/providers/player_payment_methods_provider.dart';
import '../../profile/providers/profile_provider.dart';
import '../../../services/device_session_service.dart';
import '../../../services/device_telemetry_service.dart';
import '../../../services/fcm_service.dart';
import '../../../services/synced_clock_service.dart';
import '../../rewards/providers/rewards_provider.dart';
import '../../subscriptions/providers/player_subscription_provider.dart';

class MainShell extends ConsumerStatefulWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  static const List<_NavItem> _items = [
    _NavItem('/home', Icons.home_rounded, 'Accueil'),
    _NavItem('/contests', Icons.emoji_events_rounded, 'Jeux'),
    _NavItem('/leaderboard', Icons.leaderboard_rounded, 'Classement'),
    _NavItem('/rewards', Icons.card_giftcard_rounded, 'Récompenses'),
    _NavItem('/profile', Icons.person_rounded, 'Profil'),
  ];

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with WidgetsBindingObserver {
  RealtimeChannel? _maintenanceChannel;
  String? _currentUserId;
  String? _prewarmedUserId;
  DateTime? _backgroundedAt;
  Timer? _refreshDebounce;
  Timer? _foregroundSyncTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(authStateProvider).value;
    _syncMaintenanceRealtime(authUser?.id);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: widget.child,
      bottomNavigationBar: const _MainBottomNav(),
    );
  }

  void _syncMaintenanceRealtime(String? userId) {
    _prewarmHomeBootstrap(userId);
    _syncForegroundTimer(userId);
    if (_currentUserId == userId) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _currentUserId == userId) return;
      _subscribeMaintenanceRealtime(userId);
    });
  }

  void _syncForegroundTimer(String? userId) {
    if (userId == null) {
      _prewarmedUserId = null;
      _foregroundSyncTimer?.cancel();
      _foregroundSyncTimer = null;
      return;
    }

    _foregroundSyncTimer ??= Timer.periodic(const Duration(seconds: 45), (_) {
      if (mounted) _refreshPublicContestState();
    });
  }

  void _prewarmHomeBootstrap(String? userId) {
    if (userId == null || _prewarmedUserId == userId) return;
    _prewarmedUserId = userId;
    unawaited(
      Future<void>(() async {
        try {
          await ref.read(homeBootstrapProvider.future);
        } catch (_) {
          _prewarmedUserId = null;
        }
      }),
    );
  }

  void _subscribeMaintenanceRealtime(String? userId) {
    final supabase = ref.read(supabaseProvider);
    final previousChannel = _maintenanceChannel;
    if (previousChannel != null) {
      unawaited(supabase.removeChannel(previousChannel));
    }

    _maintenanceChannel = null;
    _currentUserId = userId;
    if (userId == null) return;

    void refreshAll(PostgresChangePayload payload) =>
        _scheduleRefreshAppState();

    void refreshPublicContestState(PostgresChangePayload payload) =>
        _refreshPublicContestState();

    void refreshRewardsImmediately(PostgresChangePayload payload) {
      _refreshDebounce?.cancel();
      _clearBootstrapForCurrentUser();
      ref
        ..invalidate(rewardsProvider)
        ..invalidate(homeBootstrapProvider)
        ..invalidate(notificationsProvider);
    }

    void refreshNotificationsImmediately(PostgresChangePayload payload) {
      _refreshDebounce?.cancel();
      _clearBootstrapForCurrentUser();
      ref
        ..invalidate(notificationsProvider)
        ..invalidate(homeBootstrapProvider);
    }

    void refreshUserIfMeaningful(PostgresChangePayload payload) {
      final oldRecord = payload.oldRecord;
      final newRecord = payload.newRecord;
      if (oldRecord.isNotEmpty && newRecord.isNotEmpty) {
        const ignoredKeys = {
          'active_device_session_id',
          'active_device_info',
          'active_device_seen_at',
          'device_info',
          'device_location',
          'device_last_seen_at',
          'updated_at',
          'fcm_token',
        };
        final meaningfulChange = newRecord.keys.any((key) {
          if (ignoredKeys.contains(key)) return false;
          return oldRecord[key] != newRecord[key];
        });
        if (!meaningfulChange) return;
      }

      refreshAll(payload);
    }

    _maintenanceChannel = supabase
        .channel('mobile-maintenance-refresh-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'users',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: userId,
          ),
          callback: refreshUserIfMeaningful,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'participations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: refreshAll,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'live_quiz_registrations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: refreshAll,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'winners',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: refreshRewardsImmediately,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: refreshNotificationsImmediately,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_badges',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: refreshAll,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'player_subscriptions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: refreshAll,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'contests',
          callback: refreshPublicContestState,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'questions',
          callback: refreshPublicContestState,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'categories',
          callback: refreshPublicContestState,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'contest_predictions',
          callback: refreshPublicContestState,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'contest_draw_settings',
          callback: refreshPublicContestState,
        )
        .subscribe();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshDebounce?.cancel();
    _foregroundSyncTimer?.cancel();
    final channel = _maintenanceChannel;
    if (channel != null) {
      unawaited(Supabase.instance.client.removeChannel(channel));
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _backgroundedAt = DateTime.now();
      return;
    }

    if (state != AppLifecycleState.resumed) return;

    final now = DateTime.now();
    final inactiveFor = _backgroundedAt == null
        ? Duration.zero
        : now.difference(_backgroundedAt!);
    _backgroundedAt = null;

    unawaited(SyncedClockService.initialize());
    unawaited(DeviceTelemetryService.syncForCurrentUser(force: true));
    unawaited(DeviceSessionService.claimCurrentSession(force: true));
    unawaited(FcmService.syncTokenForCurrentUser());

    if (inactiveFor >= const Duration(seconds: 20)) {
      _refreshAppState();
      _resubscribeMaintenanceRealtime();
    }
  }

  void _refreshAppState() {
    _refreshDebounce?.cancel();
    clearAllContestDetailCache();
    _clearBootstrapForCurrentUser();
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

  void _refreshPublicContestState() {
    _clearBootstrapForCurrentUser();
    clearAllContestDetailCache();
    ref
      ..invalidate(homeBootstrapProvider)
      ..invalidate(contestsProvider)
      ..invalidate(categoriesProvider)
      ..invalidate(contestParticipantsCountProvider);
  }

  void _clearBootstrapForCurrentUser() {
    clearHomeBootstrapCache(
      userId: ref.read(currentUserIdProvider),
      clearStored: true,
    );
  }

  void _scheduleRefreshAppState() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(
      const Duration(milliseconds: 700),
      _refreshAppState,
    );
  }

  void _resubscribeMaintenanceRealtime() {
    final userId = _currentUserId;
    if (userId == null) return;
    _currentUserId = null;
    _subscribeMaintenanceRealtime(userId);
  }
}

class _MainBottomNav extends StatelessWidget {
  const _MainBottomNav();

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final index = MainShell._items.indexWhere(
      (item) => location.startsWith(item.path),
    );
    return index < 0 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _currentIndex(context);

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surfaceElevated,
        border: Border(top: BorderSide(color: AppColors.surfaceBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Container(
            height: 66,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F6FA),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: Row(
              children: List.generate(MainShell._items.length, (index) {
                final item = MainShell._items[index];
                final isSelected = selectedIndex == index;

                return Expanded(
                  child: _BottomNavItem(
                    item: item,
                    isSelected: isSelected,
                    onTap: () {
                      if (!isSelected) context.go(item.path);
                    },
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final _NavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(19),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(19),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.18)
                  : Colors.transparent,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                scale: isSelected ? 1.03 : 0.94,
                child: Icon(
                  item.icon,
                  color: isSelected ? AppColors.primary : AppColors.textHint,
                  size: 22,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall.copyWith(
                  color: isSelected ? AppColors.primary : AppColors.textHint,
                  fontSize: 12,
                  height: 1.05,
                  letterSpacing: 0,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final String path;
  final IconData icon;
  final String label;

  const _NavItem(this.path, this.icon, this.label);
}
