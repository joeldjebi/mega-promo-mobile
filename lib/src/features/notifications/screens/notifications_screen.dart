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
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Retour',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
              return;
            }
            context.go('/home');
          },
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Notifications'),
        actions: [
          notifications.maybeWhen(
            data: (items) => items.isEmpty
                ? const SizedBox.shrink()
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (items.any((item) => !item.isRead))
                        IconButton(
                          tooltip: 'Tout marquer comme lu',
                          onPressed: () async {
                            await _runNotificationAction(
                              context,
                              action: markAllNotificationsAsRead,
                              successMessage:
                                  'Toutes les notifications sont lues.',
                            );
                          },
                          icon: const Icon(Icons.done_all_rounded),
                        ),
                      IconButton(
                        tooltip: 'Tout supprimer',
                        onPressed: () async {
                          final deleted = await _confirmDeleteAllNotifications(
                            context,
                            items.length,
                          );
                          if (!deleted || !context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Notifications supprimées.'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.delete_sweep_rounded),
                      ),
                    ],
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
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
                return _NotificationTile(notification: notification);
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

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDeleteNotification(context, notification),
      onDismissed: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification supprimée.')),
        );
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          color: AppColors.accentRed.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Icon(Icons.delete_rounded, color: AppColors.accentRed),
      ),
      child: AppCard(
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: AppTextStyles.h3,
                        ),
                      ),
                      if (!notification.isRead) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(top: 6),
                          decoration: const BoxDecoration(
                            color: AppColors.primaryLight,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (notification.body.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(notification.body, style: AppTextStyles.bodySecondary),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    _formatDate(notification.createdAt),
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            PopupMenuButton<_NotificationAction>(
              tooltip: 'Options',
              color: AppColors.surface,
              icon: const Icon(
                Icons.more_vert_rounded,
                color: AppColors.textSecondary,
              ),
              onSelected: (action) async {
                switch (action) {
                  case _NotificationAction.markAsRead:
                    await _runNotificationAction(
                      context,
                      action: () => markNotificationAsRead(notification.id),
                      successMessage: 'Notification marquée lue.',
                    );
                    return;
                  case _NotificationAction.delete:
                    final deleted = await _confirmDeleteNotification(
                      context,
                      notification,
                    );
                    if (!deleted || !context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Notification supprimée.')),
                    );
                    return;
                }
              },
              itemBuilder: (context) => [
                if (!notification.isRead)
                  const PopupMenuItem(
                    value: _NotificationAction.markAsRead,
                    child: Row(
                      children: [
                        Icon(Icons.done_rounded, size: 18),
                        SizedBox(width: 10),
                        Text('Marquer lu'),
                      ],
                    ),
                  ),
                const PopupMenuItem(
                  value: _NotificationAction.delete,
                  child: Row(
                    children: [
                      Icon(Icons.delete_rounded, size: 18),
                      SizedBox(width: 10),
                      Text('Supprimer'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _NotificationAction { markAsRead, delete }

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
              'Tes alertes de quiz, récompenses et annonces apparaîtront ici.',
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
      final winnerId =
          notification.data['winner_id'] as String? ??
          notification.data['winnerId'] as String?;
      if (winnerId != null && winnerId.isNotEmpty) {
        context.go('/rewards/$winnerId');
        return;
      }
      context.go('/rewards');
      return;
    case 'subscription':
      context.go('/subscriptions');
      return;
    case 'leaderboard':
      context.go('/leaderboard');
      return;
    case 'quiz_replay_approved':
      final contestId =
          notification.data['contest_id'] as String? ??
          notification.data['contestId'] as String?;
      if (contestId != null && contestId.isNotEmpty) {
        context.go('/contests/$contestId');
        return;
      }
      context.go('/contests');
      return;
    case 'profile':
      context.go('/profile');
      return;
  }

  final contestId =
      notification.data['contest_id'] as String? ??
      notification.data['contestId'] as String?;

  if (contestId != null && contestId.isNotEmpty) {
    if (notification.type == 'live_quiz_waiting' ||
        notification.type == 'live_quiz_reminder') {
      context.go('/contests/$contestId/live-waiting');
      return;
    }
    context.go('/contests/$contestId');
    return;
  }
}

Future<void> _runNotificationAction(
  BuildContext context, {
  required Future<void> Function() action,
  required String successMessage,
}) async {
  try {
    await action();
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(successMessage)));
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Action impossible. Réessaie.')),
    );
  }
}

Future<bool> _confirmDeleteNotification(
  BuildContext context,
  AppNotification notification,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Supprimer la notification ?'),
      content: Text(notification.title, style: AppTextStyles.bodySecondary),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Supprimer'),
        ),
      ],
    ),
  );

  if (confirmed != true) return false;

  try {
    await deleteNotification(notification.id);
    return true;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Suppression impossible. Réessaie.')),
      );
    }
    return false;
  }
}

Future<bool> _confirmDeleteAllNotifications(
  BuildContext context,
  int count,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Tout supprimer ?'),
      content: Text(
        '$count notification${count > 1 ? 's' : ''} seront supprimée${count > 1 ? 's' : ''}.',
        style: AppTextStyles.bodySecondary,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Tout supprimer'),
        ),
      ],
    ),
  );

  if (confirmed != true) return false;

  try {
    await deleteAllNotifications();
    return true;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Suppression impossible. Réessaie.')),
      );
    }
    return false;
  }
}

IconData _iconForType(String type) {
  return switch (type) {
    'winner' || 'gain' => Icons.emoji_events_rounded,
    'subscription' => Icons.workspace_premium_rounded,
    'contest_finished' => Icons.flag_rounded,
    'contest' => Icons.campaign_rounded,
    'live_quiz_waiting' || 'live_quiz_reminder' => Icons.bolt_rounded,
    'quiz_replay_approved' => Icons.replay_rounded,
    'leaderboard' => Icons.leaderboard_rounded,
    _ => Icons.notifications_rounded,
  };
}

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year} à '
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
}
