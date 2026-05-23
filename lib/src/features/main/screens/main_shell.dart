import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mega_promo/core/theme/app_colors.dart';
import 'package:mega_promo/core/theme/app_text_styles.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/auth_provider.dart';
import '../../contests/providers/contest_providers.dart';
import '../../home/providers/user_profile_provider.dart';
import '../../notifications/providers/notifications_provider.dart';
import '../../profile/providers/profile_provider.dart';
import '../../rewards/providers/rewards_provider.dart';
import '../../subscriptions/providers/player_subscription_provider.dart';

class MainShell extends ConsumerStatefulWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  static const List<_NavItem> _items = [
    _NavItem('/home', Icons.home_rounded, 'Accueil'),
    _NavItem('/contests', Icons.emoji_events_rounded, 'Jeux'),
    _NavItem('/leaderboard', Icons.leaderboard_rounded, 'Classement'),
    _NavItem('/rewards', Icons.card_giftcard_rounded, 'Gains'),
    _NavItem('/profile', Icons.person_rounded, 'Profil'),
  ];

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  RealtimeChannel? _maintenanceChannel;
  String? _currentUserId;

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
    if (_currentUserId == userId) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _currentUserId == userId) return;
      _subscribeMaintenanceRealtime(userId);
    });
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

    void refreshAll(PostgresChangePayload payload) {
      clearAllContestDetailCache();
      ref
        ..invalidate(userProfileProvider)
        ..invalidate(profileDataProvider)
        ..invalidate(rewardsProvider)
        ..invalidate(playerPlansProvider)
        ..invalidate(contestsProvider)
        ..invalidate(contestParticipantsCountProvider)
        ..invalidate(contestDetailProvider)
        ..invalidate(notificationsProvider);
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
          table: 'winners',
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
        .subscribe();
  }

  @override
  void dispose() {
    final channel = _maintenanceChannel;
    if (channel != null) {
      unawaited(Supabase.instance.client.removeChannel(channel));
    }
    super.dispose();
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
