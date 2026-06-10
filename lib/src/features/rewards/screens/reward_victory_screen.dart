import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mega_promo/core/theme/app_colors.dart';
import 'package:mega_promo/core/theme/app_text_styles.dart';
import 'package:mega_promo/core/utils/currency_formatter.dart';
import 'package:mega_promo/core/widgets/app_button.dart';
import 'package:mega_promo/core/widgets/app_card.dart';
import 'package:shimmer/shimmer.dart';

import '../../auth/providers/auth_provider.dart';
import '../providers/rewards_provider.dart';

class RewardVictoryScreen extends ConsumerStatefulWidget {
  final String winnerId;

  const RewardVictoryScreen({super.key, required this.winnerId});

  @override
  ConsumerState<RewardVictoryScreen> createState() =>
      _RewardVictoryScreenState();
}

class _RewardVictoryScreenState extends ConsumerState<RewardVictoryScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
    unawaited(HapticFeedback.heavyImpact());
    unawaited(SystemSound.play(SystemSoundType.alert));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goBackToRewards() {
    ref.invalidate(rewardsProvider);
    context.go('/rewards');
  }

  Future<void> _openParticipationResult(WinnerVictoryDetail detail) async {
    final supabase = ref.read(supabaseProvider);
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final row = await supabase
          .from('participations')
          .select('id')
          .eq('user_id', user.id)
          .eq('contest_id', detail.contest.id)
          .order('score', ascending: false)
          .order('participated_at', ascending: true)
          .limit(1)
          .maybeSingle();
      final participationId = row?['id'] as String?;
      if (!mounted || participationId == null || participationId.isEmpty) {
        return;
      }
      context.go('/participations/$participationId/result');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Résultat indisponible pour le moment.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(winnerVictoryDetailProvider(widget.winnerId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: detail.when(
          data: (data) => _VictoryContent(
            detail: data,
            animation: _controller,
            onBack: _goBackToRewards,
            onViewResult: () => _openParticipationResult(data),
          ),
          loading: () => const _VictoryLoading(),
          error: (error, stackTrace) => ListView(
            padding: const EdgeInsets.fromLTRB(18, 24, 18, 18),
            children: [
              _TopBar(onBack: _goBackToRewards),
              const SizedBox(height: 80),
              AppCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.accentRed,
                      size: 36,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Impossible de charger cette victoire.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySecondary,
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => ref.invalidate(
                        winnerVictoryDetailProvider(widget.winnerId),
                      ),
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VictoryContent extends StatelessWidget {
  final WinnerVictoryDetail detail;
  final Animation<double> animation;
  final VoidCallback onBack;
  final VoidCallback onViewResult;

  const _VictoryContent({
    required this.detail,
    required this.animation,
    required this.onBack,
    required this.onViewResult,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      children: [
        _TopBar(onBack: onBack),
        const SizedBox(height: 12),
        _VictoryHero(detail: detail, animation: animation),
        const SizedBox(height: 14),
        _PerformanceGrid(performance: detail.performance),
        const SizedBox(height: 14),
        _PodiumCard(
          players: detail.topThree,
          currentRank: detail.performance.rank,
        ),
        const SizedBox(height: 14),
        _RewardDetailsCard(reward: detail.reward),
        const SizedBox(height: 18),
        AppButton(
          text: 'Voir le résultat de mes réponses',
          icon: Icons.fact_check_rounded,
          onPressed: onViewResult,
        ),
        const SizedBox(height: 10),
        AppButton(
          text: 'Retour aux récompenses',
          icon: Icons.card_giftcard_rounded,
          onPressed: onBack,
          color: AppColors.gold,
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback onBack;

  const _TopBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Retour',
        ),
        Expanded(
          child: Text(
            'DÉTAIL DU GAIN',
            textAlign: TextAlign.center,
            style: AppTextStyles.label.copyWith(
              color: AppColors.textHint,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }
}

class _VictoryHero extends StatelessWidget {
  final WinnerVictoryDetail detail;
  final Animation<double> animation;

  const _VictoryHero({required this.detail, required this.animation});

  @override
  Widget build(BuildContext context) {
    final rank = detail.performance.rank;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Container(
          height: 258,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2A2210), Color(0xFF9B7A18), Color(0xFFFFF0B3)],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.gold.withValues(alpha: 0.24),
                blurRadius: 34,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _VictoryConfettiPainter(animation.value),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(
                        math.sin(animation.value * math.pi * 2) * 0.25,
                        -0.25,
                      ),
                      radius: 0.95,
                      colors: [
                        Colors.white.withValues(alpha: 0.24),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.28),
                            ),
                          ),
                          child: Text(
                            detail.contest.isLiveQuiz ? 'QUIZ LIVE' : 'QUIZ',
                            style: AppTextStyles.label.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.auto_awesome_rounded,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Transform.scale(
                      scale:
                          1 + math.sin(animation.value * math.pi * 2) * 0.035,
                      child: Container(
                        width: 82,
                        height: 82,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.34),
                              blurRadius: 24,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            rank > 0 ? '#$rank' : '★',
                            style: AppTextStyles.h1.copyWith(
                              color: AppColors.gold,
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Victoire confirmée',
                      style: AppTextStyles.h1.copyWith(
                        color: Colors.white,
                        fontSize: 27,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      detail.contest.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySecondary.copyWith(
                        color: Colors.white.withValues(alpha: 0.86),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PerformanceGrid extends StatelessWidget {
  final VictoryPerformance performance;

  const _PerformanceGrid({required this.performance});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            label: 'Score',
            value: '${performance.score}',
            icon: Icons.bolt_rounded,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _MetricCard(
            label: 'Temps',
            value: _formatDurationMs(performance.durationMs),
            icon: Icons.timer_rounded,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _MetricCard(
            label: 'Réponses',
            value: performance.totalAnswers > 0
                ? '${performance.correctAnswers}/${performance.totalAnswers}'
                : '-',
            icon: Icons.check_circle_rounded,
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
      borderRadius: 18,
      child: Column(
        children: [
          Icon(icon, color: AppColors.gold, size: 21),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.h3.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.bodySmall.copyWith(fontSize: 10)),
        ],
      ),
    );
  }
}

class _PodiumCard extends StatelessWidget {
  final List<VictoryPodiumPlayer> players;
  final int currentRank;

  const _PodiumCard({required this.players, required this.currentRank});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.workspace_premium_rounded,
                color: AppColors.gold,
              ),
              const SizedBox(width: 8),
              Text(
                currentRank > 3 ? 'Top 3 final + toi' : 'Top 3 final',
                style: AppTextStyles.h3,
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (players.isEmpty)
            Text(
              'Le podium sera disponible bientôt.',
              style: AppTextStyles.bodySecondary,
            )
          else
            ...players.map(
              (player) => Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: _PodiumRow(player: player),
              ),
            ),
        ],
      ),
    );
  }
}

class _PodiumRow extends StatelessWidget {
  final VictoryPodiumPlayer player;

  const _PodiumRow({required this.player});

  @override
  Widget build(BuildContext context) {
    final color = switch (player.rank) {
      1 => AppColors.gold,
      2 => AppColors.textSecondary,
      3 => const Color(0xFFB46B3C),
      _ => AppColors.primary,
    };
    final rowColor = player.isCurrentUser ? AppColors.primary : color;

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: rowColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: rowColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: rowColor, shape: BoxShape.circle),
            child: Center(
              child: Text(
                '${player.rank}',
                style: AppTextStyles.h3.copyWith(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        player.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.h3.copyWith(fontSize: 14),
                      ),
                    ),
                    if (player.isCurrentUser) ...[
                      const SizedBox(width: 8),
                      Text(
                        'Toi',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  '${player.score} pts · ${_formatDurationMs(player.durationMs)}',
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

class _RewardDetailsCard extends StatelessWidget {
  final RewardPrize reward;

  const _RewardDetailsCard({required this.reward});

  @override
  Widget build(BuildContext context) {
    final code = reward.rewardCode?.trim();
    final instructions = reward.rewardDeliveryInstructions?.trim();

    return AppCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 22,
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.goldSoft,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.25),
                  ),
                ),
                child: Icon(
                  _rewardTypeIcon(reward.rewardType),
                  color: AppColors.gold,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reward.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.h3.copyWith(fontSize: 14),
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          _formatAmount(reward.value),
                          style: AppTextStyles.price.copyWith(fontSize: 18),
                        ),
                        _RewardTypePill(label: _rewardTypeLabel(reward)),
                      ],
                    ),
                  ],
                ),
              ),
              _MiniStatus(reward: reward),
            ],
          ),
          if (code != null && code.isNotEmpty) ...[
            const SizedBox(height: 14),
            _RewardInfoRow(
              icon: Icons.confirmation_number_rounded,
              label: 'Code',
              value: code,
            ),
          ],
          if (instructions != null && instructions.isNotEmpty) ...[
            const SizedBox(height: 10),
            _RewardInfoRow(
              icon: Icons.info_outline_rounded,
              label: 'Instructions',
              value: instructions,
            ),
          ],
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Text(
        label,
        style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.primaryDark,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _RewardInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _RewardInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primaryDark),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textHint,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(value, style: AppTextStyles.bodySecondary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStatus extends StatelessWidget {
  final RewardPrize reward;

  const _MiniStatus({required this.reward});

  @override
  Widget build(BuildContext context) {
    final claimStatus = reward.rewardClaimStatus.toLowerCase();
    final isReady = claimStatus == 'ready';
    final isAvailable =
        claimStatus == 'sent' ||
        claimStatus == 'claimed' ||
        claimStatus == 'used';
    final isExpired = claimStatus == 'expired' || claimStatus == 'cancelled';
    final label = reward.isPaid
        ? 'Envoyé'
        : reward.isRejected || isExpired
        ? 'Annulé'
        : isReady
        ? 'Prêt'
        : isAvailable
        ? 'Disponible'
        : 'En attente';
    final color = reward.isPaid || isAvailable
        ? AppColors.accentGreen
        : reward.isRejected || isExpired
        ? AppColors.accentRed
        : isReady
        ? AppColors.accentBlue
        : AppColors.gold;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTextStyles.bodySmall.copyWith(
          color: color,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _VictoryLoading extends StatelessWidget {
  const _VictoryLoading();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surface,
      highlightColor: AppColors.surfaceElevated,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        children: const [
          _ShimmerBlock(height: 44),
          SizedBox(height: 14),
          _ShimmerBlock(height: 258),
          SizedBox(height: 14),
          _ShimmerBlock(height: 88),
          SizedBox(height: 14),
          _ShimmerBlock(height: 210),
        ],
      ),
    );
  }
}

class _ShimmerBlock extends StatelessWidget {
  final double height;

  const _ShimmerBlock({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
    );
  }
}

class _VictoryConfettiPainter extends CustomPainter {
  final double progress;

  const _VictoryConfettiPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final colors = [
      Colors.white,
      AppColors.goldLight,
      AppColors.goldSoft,
      AppColors.primaryLight,
    ];
    for (var index = 0; index < 32; index++) {
      final seed = index * 37.0;
      final x =
          ((seed * 11) % size.width) + math.sin(progress * 6.28 + index) * 8;
      final y =
          ((progress * size.height * 1.35 + seed) % (size.height + 40)) - 20;
      final paint = Paint()
        ..color = colors[index % colors.length].withValues(alpha: 0.72)
        ..style = PaintingStyle.fill;
      final rect = Rect.fromCenter(
        center: Offset(x, y),
        width: 4 + (index % 3) * 2,
        height: 8 + (index % 4) * 2,
      );
      canvas.save();
      canvas.translate(rect.center.dx, rect.center.dy);
      canvas.rotate(progress * math.pi * 2 + index);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: rect.width,
            height: rect.height,
          ),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _VictoryConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

String _formatDurationMs(int value) {
  if (value <= 0 || value >= 2147483647) return '-';
  return '${(value / 1000).toStringAsFixed(2)}s';
}

String _formatAmount(num value) {
  return formatCurrencyAmount(value);
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

IconData _rewardTypeIcon(String rewardType) {
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
      return Icons.card_giftcard_rounded;
  }
}
