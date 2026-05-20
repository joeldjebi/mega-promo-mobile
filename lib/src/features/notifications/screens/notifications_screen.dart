import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mega_promo/core/theme/app_colors.dart';
import 'package:mega_promo/core/theme/app_text_styles.dart';
import 'package:mega_promo/core/widgets/app_card.dart';

import '../providers/notifications_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Notifications')),
      body: SafeArea(
        child: notifications.when(
          data: (items) {
            if (items.isEmpty) return const _EmptyNotifications();

            return ListView.separated(
              padding: const EdgeInsets.all(24),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final notification = items[index];
                return AppCard(
                  showGlow: !notification.isRead,
                  onTap: () async {
                    await markNotificationAsRead(notification.id);
                    if (!context.mounted) return;
                    _openNotificationTarget(context, notification);
                  },
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _iconForType(notification.type),
                        color: notification.isRead
                            ? AppColors.textHint
                            : AppColors.primaryLight,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(notification.title, style: AppTextStyles.h3),
                            if (notification.body.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                notification.body,
                                style: AppTextStyles.bodySecondary,
                              ),
                            ],
                            const SizedBox(height: 8),
                            Text(
                              _formatDate(notification.createdAt),
                              style: AppTextStyles.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Text(
              'Impossible de charger les notifications.',
              style: AppTextStyles.bodySecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary,
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                color: AppColors.textPrimary,
                size: 42,
              ),
            ),
            const SizedBox(height: 20),
            Text('Aucune notification', style: AppTextStyles.h2),
            const SizedBox(height: 8),
            Text(
              'Tes alertes de concours, gains et annonces apparaîtront ici.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySecondary,
            ),
          ],
        ),
      ),
    );
  }
}

void _openNotificationTarget(
  BuildContext context,
  AppNotification notification,
) {
  switch (notification.type) {
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
      notification.data['contest_id'] as String? ??
      notification.data['contestId'] as String?;

  if (contestId != null && contestId.isNotEmpty) {
    context.go('/contests/$contestId');
    return;
  }
}

IconData _iconForType(String type) {
  return switch (type) {
    'winner' || 'gain' => Icons.emoji_events_rounded,
    'subscription' => Icons.workspace_premium_rounded,
    'contest_finished' => Icons.flag_rounded,
    'contest' => Icons.campaign_rounded,
    'leaderboard' => Icons.leaderboard_rounded,
    _ => Icons.notifications_rounded,
  };
}

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}
