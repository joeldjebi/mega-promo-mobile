import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
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
    _NavItem('/leaderboard', Icons.leaderboard_rounded, 'Rang'),
    _NavItem('/rewards', Icons.card_giftcard_rounded, 'Gains'),
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
  bool _isBottomNavVisible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(authStateProvider).value;
    _syncMaintenanceRealtime(authUser?.id);
    final location = GoRouterState.of(context).uri.path;
    final shouldAutoHideBottomNav = location == '/home';
    if (!shouldAutoHideBottomNav && !_isBottomNavVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _isBottomNavVisible = true);
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: shouldAutoHideBottomNav
          ? NotificationListener<UserScrollNotification>(
              onNotification: _handleUserScroll,
              child: widget.child,
            )
          : widget.child,
      bottomNavigationBar: _HideableBottomNav(
        isVisible: shouldAutoHideBottomNav ? _isBottomNavVisible : true,
        animate: shouldAutoHideBottomNav,
      ),
    );
  }

  bool _handleUserScroll(UserScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical ||
        notification.metrics.maxScrollExtent <= 0) {
      return false;
    }

    final shouldShow = switch (notification.direction) {
      ScrollDirection.forward => true,
      ScrollDirection.reverse => false,
      ScrollDirection.idle => _isBottomNavVisible,
    };

    if (shouldShow != _isBottomNavVisible) {
      setState(() => _isBottomNavVisible = shouldShow);
    }

    return false;
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

class _HideableBottomNav extends StatelessWidget {
  final bool isVisible;
  final bool animate;

  const _HideableBottomNav({required this.isVisible, required this.animate});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final navHeight = 94.0 + bottomInset;

    return AnimatedContainer(
      duration: animate ? const Duration(milliseconds: 260) : Duration.zero,
      curve: Curves.easeOutCubic,
      height: isVisible ? navHeight : 0,
      child: ClipRect(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: OverflowBox(
            alignment: Alignment.bottomCenter,
            minHeight: navHeight,
            maxHeight: navHeight,
            child: SizedBox(
              height: navHeight,
              child: AnimatedSlide(
                duration: animate
                    ? const Duration(milliseconds: 260)
                    : Duration.zero,
                curve: Curves.easeOutCubic,
                offset: isVisible ? Offset.zero : const Offset(0, 1.08),
                child: AnimatedOpacity(
                  duration: animate
                      ? const Duration(milliseconds: 180)
                      : Duration.zero,
                  opacity: isVisible ? 1 : 0,
                  child: const _MainBottomNav(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MainBottomNav extends StatelessWidget {
  const _MainBottomNav();

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/subscriptions') ||
        location.startsWith('/participations/')) {
      return MainShell._items.indexWhere((item) => item.path == '/profile');
    }
    final index = MainShell._items.indexWhere(
      (item) => location.startsWith(item.path),
    );
    return index < 0 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _currentIndex(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: const Border(
          top: BorderSide(color: AppColors.surfaceBorder, width: 0.8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Container(
            height: 74,
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.surfaceBorder, width: 0.8),
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
        borderRadius: BorderRadius.circular(21),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(21),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.2)
                  : Colors.transparent,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: isSelected ? 24 : 6,
                height: 3.5,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 5.5),
              AnimatedScale(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                scale: isSelected ? 1.1 : 0.98,
                child: Icon(
                  item.icon,
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textHint.withValues(alpha: 0.78),
                  size: 23,
                ),
              ),
              const SizedBox(height: 3.5),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall.copyWith(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textHint.withValues(alpha: 0.82),
                  fontSize: 13,
                  height: 1.05,
                  letterSpacing: 0,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
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
