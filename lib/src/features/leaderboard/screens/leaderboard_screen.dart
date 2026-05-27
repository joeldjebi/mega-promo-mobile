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

class LeaderboardScreen extends ConsumerStatefulWidget {
  final String? contestId;

  const LeaderboardScreen({super.key, this.contestId});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  LeaderboardScope _scope = LeaderboardScope.system;
  final Map<LeaderboardRequest, LeaderboardData> _lastLeaderboardData = {};

  @override
  Widget build(BuildContext context) {
    final request = widget.contestId == null
        ? (_scope == LeaderboardScope.liveQuiz
              ? const LeaderboardRequest.liveQuiz()
              : const LeaderboardRequest.system())
        : LeaderboardRequest.contest(widget.contestId!);
    final watchedLeaderboard = ref.watch(leaderboardProvider(request));
    final latestLeaderboard = watchedLeaderboard.asData?.value;
    if (latestLeaderboard != null) {
      _lastLeaderboardData[request] = latestLeaderboard;
    }
    final cachedLeaderboard = _lastLeaderboardData[request];
    final leaderboard = cachedLeaderboard == null
        ? watchedLeaderboard
        : AsyncData(cachedLeaderboard);
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final hasContest = widget.contestId != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: leaderboard.when(
          data: (data) {
            final users = data.users;
            final currentUserIndex = users.indexWhere(
              (user) => user.id == currentUserId,
            );
            final podiumUsers = users.take(3).toList();
            final otherUsers = users.skip(3).take(5).toList();
            final currentUser = data.currentUser ??
                (currentUserIndex >= 0 ? users[currentUserIndex] : null);
            final currentUserRank = data.currentUserRank ??
                currentUser?.rank ??
                (currentUserIndex >= 0 ? currentUserIndex + 1 : null);
            final currentUserIsOnPodium = podiumUsers.any(
              (user) => user.id == currentUserId,
            );
            final currentUserIsInOtherUsers = otherUsers.any(
              (user) => user.id == currentUserId,
            );
            final shouldAppendCurrentUser =
                currentUser != null &&
                currentUserRank != null &&
                !currentUserIsOnPodium &&
                !currentUserIsInOtherUsers;
            final otherRows = <({int rank, LeaderboardUser user})>[
              ...otherUsers.asMap().entries.map(
                    (entry) => (
                      rank: entry.value.rank ?? entry.key + 4,
                      user: entry.value,
                    ),
                  ),
              if (shouldAppendCurrentUser)
                (rank: currentUserRank!, user: currentUser!),
            ];

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
              children: [
                _Header(
                  hasContest: hasContest,
                  hasLiveQuizScope: data.hasLiveQuizScope,
                ),
                if (!hasContest) ...[
                  const SizedBox(height: 14),
                  _LeaderboardScopeTabs(
                    selectedScope: _scope,
                    onChanged: (scope) => setState(() => _scope = scope),
                  ),
                ],
                if (hasContest) ...[
                  const SizedBox(height: 14),
                  const _ContestScopeBanner(),
                ],
                const SizedBox(height: 20),
                _Podium(
                  users: podiumUsers,
                  currentUserId: currentUserId,
                ),
                if (otherRows.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  Text('AUTRES JOUEURS', style: AppTextStyles.label),
                  const SizedBox(height: 12),
                  ...otherRows.map((row) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _RankCard(
                        rank: row.rank,
                        user: row.user,
                        isCurrentUser: row.user.id == currentUserId,
                      ),
                    );
                  }),
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
  final bool hasLiveQuizScope;

  const _Header({required this.hasContest, required this.hasLiveQuizScope});

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
                    ? 'Les meilleurs joueurs de ce quiz'
                    : hasLiveQuizScope
                    ? 'Les meilleurs joueurs Quiz Live'
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

class _LeaderboardScopeTabs extends StatelessWidget {
  final LeaderboardScope selectedScope;
  final ValueChanged<LeaderboardScope> onChanged;

  const _LeaderboardScopeTabs({
    required this.selectedScope,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(4),
      borderRadius: 18,
      child: Row(
        children: [
          Expanded(
            child: _ScopeTabButton(
              label: 'Général',
              selected: selectedScope == LeaderboardScope.system,
              onTap: () => onChanged(LeaderboardScope.system),
            ),
          ),
          Expanded(
            child: _ScopeTabButton(
              label: 'Quiz Live',
              selected: selectedScope == LeaderboardScope.liveQuiz,
              onTap: () => onChanged(LeaderboardScope.liveQuiz),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScopeTabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ScopeTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: selected ? null : onTap,
      style: TextButton.styleFrom(
        backgroundColor: selected ? AppColors.primary : Colors.transparent,
        foregroundColor: selected ? Colors.white : AppColors.textSecondary,
        disabledBackgroundColor: AppColors.primary,
        disabledForegroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(
        label,
        style: AppTextStyles.bodySmall.copyWith(
          color: selected ? Colors.white : AppColors.textSecondary,
          fontWeight: FontWeight.w800,
        ),
      ),
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
              'Classement de ce quiz',
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? AppColors.primary.withValues(alpha: 0.12)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCurrentUser
              ? AppColors.primary.withValues(alpha: 0.48)
              : AppColors.surfaceBorder,
          width: isCurrentUser ? 1.2 : 0.8,
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.subtleShadow,
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '$rank',
              style: AppTextStyles.bodySecondary.copyWith(
                color: isCurrentUser ? AppColors.primary : AppColors.textHint,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: avatar.color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
              border: Border.all(color: avatar.color.withValues(alpha: 0.20)),
            ),
            child: Icon(avatar.icon, color: avatar.color, size: 19),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              user.username,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySecondary.copyWith(
                color: isCurrentUser
                    ? AppColors.primaryDark
                    : AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${user.points} pts',
            style: AppTextStyles.bodySmall.copyWith(
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
            'Joue à un quiz pour marquer tes premiers points.',
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
