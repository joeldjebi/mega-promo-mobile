import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mega_promo/core/theme/app_colors.dart';
import 'package:mega_promo/core/theme/app_text_styles.dart';
import 'package:mega_promo/core/widgets/app_card.dart';
import 'package:shimmer/shimmer.dart';

import '../providers/rewards_provider.dart';

class RewardsScreen extends ConsumerWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rewards = ref.watch(rewardsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(rewardsProvider);
            await ref.read(rewardsProvider.future);
          },
          child: rewards.when(
            data: (items) => ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
              children: [
                Center(
                  child: Text(
                    'GAINS',
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.textHint,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _RewardsSummary(items: items),
                const SizedBox(height: 18),
                Text('MES RÉCOMPENSES', style: AppTextStyles.label),
                const SizedBox(height: 10),
                if (items.isEmpty)
                  const _EmptyRewardsState()
                else
                  ...items.map(
                    (reward) => Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: _RewardCard(reward: reward),
                    ),
                  ),
              ],
            ),
            loading: () => const _RewardsShimmer(),
            error: (error, stackTrace) => ListView(
              padding: const EdgeInsets.fromLTRB(24, 120, 24, 24),
              children: [
                AppCard(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: AppColors.accentRed,
                        size: 34,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Impossible de charger tes gains.',
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
}

class _RewardsSummary extends StatelessWidget {
  final List<RewardPrize> items;

  const _RewardsSummary({required this.items});

  @override
  Widget build(BuildContext context) {
    final received = items.where((item) => item.isReceived).length;
    final pending = items
        .where((item) => !item.isReceived && !item.isRejected)
        .length;
    final totalValue = items.fold<num>(0, (sum, item) => sum + item.value);

    return AppCard(
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
                child: _SummaryStat(label: 'Gains', value: '${items.length}'),
              ),
              Container(width: 1, height: 34, color: AppColors.separator),
              Expanded(
                child: _SummaryStat(label: 'Reçus', value: '$received'),
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

  const _RewardCard({required this.reward});

  @override
  Widget build(BuildContext context) {
    final status = _statusData(reward);

    return AppCard(
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
              border: Border.all(color: status.color.withValues(alpha: 0.22)),
            ),
            child: Icon(status.icon, color: status.color, size: 22),
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
                Text(
                  _formatAmount(reward.value),
                  style: AppTextStyles.price.copyWith(fontSize: 15),
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
        ],
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
  const _EmptyRewardsState();

  @override
  Widget build(BuildContext context) {
    return AppCard(
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
            'Aucun gain pour le moment',
            style: AppTextStyles.h2.copyWith(fontSize: 17),
          ),
          const SizedBox(height: 6),
          Text(
            'Participe aux concours actifs pour débloquer tes prochains lots.',
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
  if (reward.isReceived) {
    return const _RewardStatus(
      label: 'Reçu',
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

  return const _RewardStatus(
    label: 'En attente',
    color: AppColors.gold,
    icon: Icons.hourglass_top_rounded,
  );
}

String _formatAmount(num value) {
  final rounded = value.round();
  if (rounded <= 0) return 'Prix surprise';
  return '$rounded FCFA';
}

String _rewardMeta(RewardPrize reward) {
  final date = reward.sentAt ?? reward.createdAt;
  final payment = reward.paymentMethod?.trim();
  final parts = <String>[
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
    if (payment != null && payment.isNotEmpty) payment,
  ];
  return parts.join(' - ');
}
