import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mega_promo/core/theme/app_colors.dart';
import 'package:mega_promo/core/theme/app_text_styles.dart';
import 'package:mega_promo/core/utils/currency_formatter.dart';
import 'package:mega_promo/core/widgets/app_card.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/auth_provider.dart';
import '../../home/providers/home_bootstrap_provider.dart';
import '../../notifications/providers/notifications_provider.dart';
import '../../../services/network_status_service.dart';
import '../providers/rewards_provider.dart';

enum _RewardsTab { contests, liveQuiz }

const _rewardsCardBackground = Color(0xFFF0EDFF);

class RewardsScreen extends ConsumerStatefulWidget {
  const RewardsScreen({super.key});

  @override
  ConsumerState<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends ConsumerState<RewardsScreen> {
  _RewardsTab _selectedTab = _RewardsTab.contests;
  RealtimeChannel? _rewardsChannel;
  String? _subscribedUserId;
  Timer? _refreshThrottle;
  List<RewardPrize>? _lastRewards;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncRealtimeSubscription();
    });
  }

  @override
  void dispose() {
    _refreshThrottle?.cancel();
    final channel = _rewardsChannel;
    if (channel != null) {
      unawaited(Supabase.instance.client.removeChannel(channel));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(authStateProvider).value;
    if (authUser?.id != _subscribedUserId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncRealtimeSubscription();
      });
    }

    final watchedRewards = ref.watch(rewardsProvider);
    final latestRewards = watchedRewards.asData?.value;
    if (latestRewards != null) _lastRewards = latestRewards;
    final rewards = _lastRewards == null
        ? watchedRewards
        : AsyncData(_lastRewards!);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'RÉCOMPENSES',
          style: AppTextStyles.label.copyWith(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(rewardsProvider);
            await ref.read(rewardsProvider.future);
          },
          child: rewards.when(
            data: (items) {
              final contestItems = items
                  .where((reward) => !reward.isLiveQuiz)
                  .toList(growable: false);
              final liveQuizItems = items
                  .where((reward) => reward.isLiveQuiz)
                  .toList(growable: false);
              final visibleItems = _selectedTab == _RewardsTab.liveQuiz
                  ? liveQuizItems
                  : contestItems;

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                children: [
                  _RewardsSummary(items: items),
                  const SizedBox(height: 14),
                  _RewardsTabBar(
                    selectedTab: _selectedTab,
                    contestCount: contestItems.length,
                    liveQuizCount: liveQuizItems.length,
                    onChanged: (tab) => setState(() => _selectedTab = tab),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _selectedTab == _RewardsTab.liveQuiz
                        ? 'RÉCOMPENSES QUIZ LIVE'
                        : 'RÉCOMPENSES QUIZ',
                    style: AppTextStyles.label,
                  ),
                  const SizedBox(height: 10),
                  if (visibleItems.isEmpty)
                    _EmptyRewardsState(tab: _selectedTab)
                  else
                    ...visibleItems.map(
                      (reward) => Padding(
                        padding: const EdgeInsets.only(bottom: 9),
                        child: _RewardCard(
                          reward: reward,
                          onTap: () => _openRewardDetail(reward),
                        ),
                      ),
                    ),
                ],
              );
            },
            loading: () => const _RewardsShimmer(),
            error: (error, stackTrace) => ListView(
              padding: const EdgeInsets.fromLTRB(24, 120, 24, 24),
              children: [
                AppCard(
                  backgroundColor: _rewardsCardBackground,
                  child: Column(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: AppColors.accentRed,
                        size: 34,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Impossible de charger tes récompenses.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodySecondary,
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () => ref.invalidate(rewardsProvider),
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _syncRealtimeSubscription() {
    final supabase = ref.read(supabaseProvider);
    final userId = supabase.auth.currentUser?.id;
    if (userId == _subscribedUserId) return;

    final previousChannel = _rewardsChannel;
    if (previousChannel != null) {
      unawaited(supabase.removeChannel(previousChannel));
    }

    _rewardsChannel = null;
    _subscribedUserId = userId;
    if (userId == null) return;

    void refresh(PostgresChangePayload payload) => _refreshRewardsNow();

    _rewardsChannel = supabase
        .channel('rewards-screen-refresh-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'winners',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: refresh,
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
          callback: refresh,
        )
        .subscribe();
  }

  void _refreshRewardsNow() {
    if (!mounted) return;
    _refreshThrottle?.cancel();
    _refreshThrottle = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      ref
        ..invalidate(rewardsProvider)
        ..invalidate(notificationsProvider)
        ..invalidate(homeBootstrapProvider);
    });
  }

  Future<void> _openRewardDetail(RewardPrize reward) async {
    if (!await NetworkStatusService.instance.ensureOnline()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(NetworkStatusService.offlineActionMessage),
        ),
      );
      return;
    }

    if (!mounted) return;
    context.go('/rewards/${reward.id}');
  }
}

class _RewardsTabBar extends StatelessWidget {
  final _RewardsTab selectedTab;
  final int contestCount;
  final int liveQuizCount;
  final ValueChanged<_RewardsTab> onChanged;

  const _RewardsTabBar({
    required this.selectedTab,
    required this.contestCount,
    required this.liveQuizCount,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.separator),
      ),
      child: Row(
        children: [
          Expanded(
            child: _RewardsTabButton(
              label: 'Quiz',
              count: contestCount,
              isSelected: selectedTab == _RewardsTab.contests,
              onTap: () => onChanged(_RewardsTab.contests),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _RewardsTabButton(
              label: 'Quiz Live',
              count: liveQuizCount,
              isSelected: selectedTab == _RewardsTab.liveQuiz,
              onTap: () => onChanged(_RewardsTab.liveQuiz),
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardsTabButton extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _RewardsTabButton({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppColors.textPrimary : AppColors.textSecondary;

    return Material(
      color: isSelected ? AppColors.surfaceElevated : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.14)
                      : AppColors.separator.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isSelected ? AppColors.primary : AppColors.textHint,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RewardsSummary extends StatelessWidget {
  final List<RewardPrize> items;

  const _RewardsSummary({required this.items});

  @override
  Widget build(BuildContext context) {
    final paid = items.where((item) => item.isPaid).length;
    final pending = items
        .where((item) => !item.isPaid && !item.isRejected)
        .length;
    final totalValue = items.fold<num>(0, (sum, item) => sum + item.value);

    return AppCard(
      backgroundColor: _rewardsCardBackground,
      showGlow: true,
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.goldSoft,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.26),
                  ),
                ),
                child: const Icon(
                  Icons.card_giftcard_rounded,
                  color: AppColors.gold,
                  size: 23,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Valeur totale',
                      style: AppTextStyles.bodySecondary.copyWith(fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatAmount(totalValue),
                      style: AppTextStyles.price.copyWith(fontSize: 23),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: AppColors.separator),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SummaryStat(
                  label: 'Récompenses',
                  value: '${items.length}',
                ),
              ),
              Container(width: 1, height: 34, color: AppColors.separator),
              Expanded(
                child: _SummaryStat(label: 'Remises', value: '$paid'),
              ),
              Container(width: 1, height: 34, color: AppColors.separator),
              Expanded(
                child: _SummaryStat(label: 'En attente', value: '$pending'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: AppTextStyles.h3.copyWith(fontSize: 15)),
        const SizedBox(height: 2),
        Text(label, style: AppTextStyles.bodySmall.copyWith(fontSize: 10)),
      ],
    );
  }
}

class _RewardCard extends StatelessWidget {
  final RewardPrize reward;
  final VoidCallback onTap;

  const _RewardCard({required this.reward, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = _statusData(reward);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AppCard(
          backgroundColor: _rewardsCardBackground,
          padding: const EdgeInsets.all(12),
          borderRadius: 18,
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: status.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: status.color.withValues(alpha: 0.22),
                  ),
                ),
                child: Icon(
                  _rewardTypeIcon(reward.rewardType, fallback: status.icon),
                  color: status.color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            reward.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.h3.copyWith(
                              fontSize: 13.5,
                              height: 1.25,
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        _StatusPill(status: status),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 7,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          _formatAmount(reward.value),
                          style: AppTextStyles.price.copyWith(fontSize: 15),
                        ),
                        _RewardTypePill(label: _rewardTypeLabel(reward)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _rewardMeta(reward),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textHint,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RewardTypePill extends StatelessWidget {
  final String label;

  const _RewardTypePill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Text(
        label,
        style: AppTextStyles.bodySmall.copyWith(
          fontSize: 10,
          color: AppColors.primaryDark,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final _RewardStatus status;

  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: status.color.withValues(alpha: 0.24)),
      ),
      child: Text(
        status.label,
        style: AppTextStyles.bodySmall.copyWith(
          fontSize: 10,
          color: status.color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmptyRewardsState extends StatelessWidget {
  final _RewardsTab tab;

  const _EmptyRewardsState({required this.tab});

  @override
  Widget build(BuildContext context) {
    final isLiveQuiz = tab == _RewardsTab.liveQuiz;

    return AppCard(
      backgroundColor: _rewardsCardBackground,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 26),
      borderRadius: 20,
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppColors.goldSoft,
              borderRadius: BorderRadius.circular(19),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.26)),
            ),
            child: const Icon(
              Icons.card_giftcard_rounded,
              color: AppColors.gold,
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            isLiveQuiz
                ? 'Aucune récompense Quiz Live pour le moment'
                : 'Aucune récompense quiz pour le moment',
            style: AppTextStyles.h2.copyWith(fontSize: 17),
          ),
          const SizedBox(height: 6),
          Text(
            isLiveQuiz
                ? 'Participe aux Quiz Live pour découvrir tes prochaines récompenses.'
                : 'Participe aux quiz actifs pour découvrir tes prochaines récompenses.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySecondary.copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _RewardsShimmer extends StatelessWidget {
  const _RewardsShimmer();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surface,
      highlightColor: AppColors.surfaceElevated,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
        children: const [
          _ShimmerBlock(height: 16, width: 80),
          SizedBox(height: 14),
          _ShimmerBlock(height: 134, width: double.infinity),
          SizedBox(height: 18),
          _ShimmerBlock(height: 12, width: 120),
          SizedBox(height: 10),
          _ShimmerBlock(height: 82, width: double.infinity),
          SizedBox(height: 9),
          _ShimmerBlock(height: 82, width: double.infinity),
        ],
      ),
    );
  }
}

class _ShimmerBlock extends StatelessWidget {
  final double height;
  final double width;

  const _ShimmerBlock({required this.height, required this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
      ),
    );
  }
}

class _RewardStatus {
  final String label;
  final Color color;
  final IconData icon;

  const _RewardStatus({
    required this.label,
    required this.color,
    required this.icon,
  });
}

_RewardStatus _statusData(RewardPrize reward) {
  final claimStatus = reward.rewardClaimStatus.toLowerCase();

  if (reward.isPaid) {
    return const _RewardStatus(
      label: 'Envoyé',
      color: AppColors.accentGreen,
      icon: Icons.verified_rounded,
    );
  }

  if (reward.isRejected) {
    return const _RewardStatus(
      label: 'Annulé',
      color: AppColors.accentRed,
      icon: Icons.close_rounded,
    );
  }

  if (claimStatus == 'ready') {
    return const _RewardStatus(
      label: 'Prêt',
      color: AppColors.accentBlue,
      icon: Icons.inventory_2_rounded,
    );
  }

  if (claimStatus == 'sent' ||
      claimStatus == 'claimed' ||
      claimStatus == 'used') {
    return const _RewardStatus(
      label: 'Disponible',
      color: AppColors.accentGreen,
      icon: Icons.verified_rounded,
    );
  }

  if (claimStatus == 'expired' || claimStatus == 'cancelled') {
    return const _RewardStatus(
      label: 'Expiré',
      color: AppColors.accentRed,
      icon: Icons.close_rounded,
    );
  }

  return const _RewardStatus(
    label: 'En attente',
    color: AppColors.gold,
    icon: Icons.hourglass_top_rounded,
  );
}

String _formatAmount(num value) {
  return formatCurrencyAmount(value);
}

String _rewardMeta(RewardPrize reward) {
  final date = reward.sentAt ?? reward.createdAt;
  final payment = reward.paymentMethod?.trim();
  final code = reward.rewardCode?.trim();
  final parts = <String>[
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
    _rewardTypeLabel(reward),
    if (code != null && code.isNotEmpty) 'Code: $code',
    if (payment != null && payment.isNotEmpty) payment,
  ];
  return parts.join(' - ');
}

String _rewardTypeLabel(RewardPrize reward) {
  switch (reward.rewardType.toLowerCase()) {
    case 'discount_code':
      return 'Code réduction';
    case 'voucher':
      return 'Bon';
    case 'concert_ticket':
      return 'Invitation concert';
    case 'physical_item':
      return 'Lot physique';
    case 'manual':
      return 'Lot manuel';
    case 'mobile_money':
    default:
      return 'Récompense partenaire';
  }
}

IconData _rewardTypeIcon(String rewardType, {required IconData fallback}) {
  switch (rewardType.toLowerCase()) {
    case 'discount_code':
      return Icons.confirmation_number_rounded;
    case 'voucher':
      return Icons.local_offer_rounded;
    case 'concert_ticket':
      return Icons.event_seat_rounded;
    case 'physical_item':
      return Icons.redeem_rounded;
    case 'manual':
      return Icons.card_giftcard_rounded;
    case 'mobile_money':
      return Icons.account_balance_wallet_rounded;
    default:
      return fallback;
  }
}
