import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mega_promo/core/theme/app_colors.dart';
import 'package:mega_promo/core/theme/app_text_styles.dart';
import 'package:mega_promo/core/widgets/app_card.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../home/screens/home_screen.dart';
import '../providers/leaderboard_provider.dart';

class LeaderboardScreen extends ConsumerWidget {
  final String? contestId;

  const LeaderboardScreen({super.key, this.contestId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboard = ref.watch(leaderboardProvider(contestId));
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: leaderboard.when(
          data: (users) {
            final currentUserIndex = users.indexWhere(
              (user) => user.id == currentUserId,
            );
            final shouldPinCurrentUser = currentUserIndex >= 10;

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
              children: [
                _Header(hasContest: contestId != null),
                if (contestId != null) ...[
                  const SizedBox(height: 14),
                  const _ContestScopeBanner(),
                ],
                const SizedBox(height: 20),
                _Podium(
                  users: users.take(3).toList(),
                  currentUserId: currentUserId,
                ),
                const SizedBox(height: 22),
                Text('AUTRES JOUEURS', style: AppTextStyles.label),
                const SizedBox(height: 12),
                if (users.length <= 3)
                  const _EmptyLeaderboardState()
                else
                  ...users.skip(3).take(97).toList().asMap().entries.map((
                    entry,
                  ) {
                    final rank = entry.key + 4;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _RankCard(
                        rank: rank,
                        user: entry.value,
                        isCurrentUser: entry.value.id == currentUserId,
                      ),
                    );
                  }),
                if (shouldPinCurrentUser) ...[
                  const SizedBox(height: 4),
                  Text('MON RANG', style: AppTextStyles.label),
                  const SizedBox(height: 12),
                  _RankCard(
                    rank: currentUserIndex + 1,
                    user: users[currentUserIndex],
                    isCurrentUser: true,
                  ),
                ],
              ],
            );
          },
          loading: () => const _LeaderboardShimmer(),
          error: (error, stackTrace) => const _LeaderboardErrorState(),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final bool hasContest;

  const _Header({required this.hasContest});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Classement', style: AppTextStyles.h1),
              const SizedBox(height: 5),
              Text(
                hasContest
                    ? 'Les meilleurs joueurs de ce concours'
                    : 'Les meilleurs joueurs MegaPromo',
                style: AppTextStyles.bodySecondary,
              ),
            ],
          ),
        ),
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: AppColors.surfaceBorder),
          ),
          child: const Icon(
            Icons.leaderboard_rounded,
            color: AppColors.primary,
            size: 22,
          ),
        ),
      ],
    );
  }
}

class _ContestScopeBanner extends StatelessWidget {
  const _ContestScopeBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              color: AppColors.primary,
              size: 17,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Classement de ce concours',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          TextButton(
            onPressed: () => context.go('/leaderboard'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 30),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Voir général',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  final List<LeaderboardUser> users;
  final String? currentUserId;

  const _Podium({required this.users, required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) return const _EmptyLeaderboardState();

    final first = users.isNotEmpty ? users[0] : null;
    final second = users.length > 1 ? users[1] : null;
    final third = users.length > 2 ? users[2] : null;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      borderRadius: 26,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TOP 3', style: AppTextStyles.label),
          const SizedBox(height: 14),
          SizedBox(
            height: 224,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: _PodiumPlace(
                    rank: 2,
                    user: second,
                    height: 64,
                    avatarSize: 52,
                    color: const Color(0xFF9CA3B8),
                    isCurrentUser: second?.id == currentUserId,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PodiumPlace(
                    rank: 1,
                    user: first,
                    height: 82,
                    avatarSize: 60,
                    color: AppColors.gold,
                    isCurrentUser: first?.id == currentUserId,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PodiumPlace(
                    rank: 3,
                    user: third,
                    height: 56,
                    avatarSize: 50,
                    color: const Color(0xFFB98252),
                    isCurrentUser: third?.id == currentUserId,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PodiumPlace extends StatelessWidget {
  final int rank;
  final LeaderboardUser? user;
  final double height;
  final double avatarSize;
  final Color color;
  final bool isCurrentUser;

  const _PodiumPlace({
    required this.rank,
    required this.user,
    required this.height,
    required this.avatarSize,
    required this.color,
    required this.isCurrentUser,
  });

  @override
  Widget build(BuildContext context) {
    final avatar = avatarForId(user?.avatarUrl);
    final username = user?.username ?? 'En attente';
    final points = user?.points ?? 0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: avatarSize,
          height: avatarSize,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(
              color: isCurrentUser ? AppColors.primary : color,
              width: isCurrentUser ? 2.2 : 1.4,
            ),
          ),
          child: Icon(
            avatar.icon,
            color: avatar.color,
            size: avatarSize * 0.45,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          username,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: AppTextStyles.h3.copyWith(
            color: isCurrentUser
                ? AppColors.primaryDark
                : AppColors.textPrimary,
            fontSize: rank == 1 ? 15 : 13,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$points pts',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodySmall.copyWith(
            color: rank == 1 ? AppColors.gold : AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 7),
        Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border.all(color: color.withValues(alpha: 0.28)),
          ),
          child: Center(
            child: Text(
              '$rank',
              style: AppTextStyles.h2.copyWith(color: color),
            ),
          ),
        ),
      ],
    );
  }
}

class _RankCard extends StatelessWidget {
  final int rank;
  final LeaderboardUser user;
  final bool isCurrentUser;

  const _RankCard({
    required this.rank,
    required this.user,
    required this.isCurrentUser,
  });

  @override
  Widget build(BuildContext context) {
    final avatar = avatarForId(user.avatarUrl);

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      borderRadius: 24,
      showGlow: isCurrentUser,
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$rank',
              style: AppTextStyles.h3.copyWith(
                color: isCurrentUser ? AppColors.primary : AppColors.textHint,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: avatar.color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
              border: Border.all(color: avatar.color.withValues(alpha: 0.20)),
            ),
            child: Icon(avatar.icon, color: avatar.color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              user.username,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.h3.copyWith(
                color: isCurrentUser
                    ? AppColors.primaryDark
                    : AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${user.points} pts',
            style: AppTextStyles.bodySecondary.copyWith(
              color: isCurrentUser ? AppColors.primaryDark : AppColors.textHint,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyLeaderboardState extends StatelessWidget {
  const _EmptyLeaderboardState();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      borderRadius: 24,
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: const Icon(
              Icons.leaderboard_rounded,
              color: AppColors.primary,
              size: 30,
            ),
          ),
          const SizedBox(height: 14),
          Text('Aucun score pour l’instant', style: AppTextStyles.h2),
          const SizedBox(height: 6),
          Text(
            'Les premiers joueurs apparaîtront ici.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySecondary,
          ),
        ],
      ),
    );
  }
}

class _LeaderboardShimmer extends StatelessWidget {
  const _LeaderboardShimmer();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surface,
      highlightColor: AppColors.surfaceElevated,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 26, 20, 24),
        children: const [
          _ShimmerBlock(width: 180, height: 34),
          SizedBox(height: 20),
          _ShimmerBlock(width: double.infinity, height: 44),
          SizedBox(height: 20),
          _ShimmerBlock(width: double.infinity, height: 276),
          SizedBox(height: 22),
          _ShimmerBlock(width: 140, height: 14),
          SizedBox(height: 12),
          _ShimmerBlock(width: double.infinity, height: 74),
          SizedBox(height: 12),
          _ShimmerBlock(width: double.infinity, height: 74),
          SizedBox(height: 12),
          _ShimmerBlock(width: double.infinity, height: 74),
        ],
      ),
    );
  }
}

class _ShimmerBlock extends StatelessWidget {
  final double width;
  final double height;

  const _ShimmerBlock({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
      ),
    );
  }
}

class _LeaderboardErrorState extends StatelessWidget {
  const _LeaderboardErrorState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Classement indisponible',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySecondary,
        ),
      ),
    );
  }
}
