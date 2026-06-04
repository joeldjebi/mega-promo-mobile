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
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.primary,
        elevation: 0,
        toolbarHeight: 76,
        titleSpacing: 20,
        title: _Header(
          hasContest: hasContest,
          hasLiveQuizScope: _scope == LeaderboardScope.liveQuiz,
          onPrimary: true,
        ),
      ),
      body: SafeArea(
        top: false,
        child: leaderboard.when(
          data: (data) {
            final users = data.users;
            final currentUserIndex = users.indexWhere(
              (user) => user.id == currentUserId,
            );
            final podiumUsers = users.take(3).toList();
            final otherUsers = users.skip(3).take(10).toList();
            final currentUser =
                data.currentUser ??
                (currentUserIndex >= 0 ? users[currentUserIndex] : null);
            final currentUserRank =
                data.currentUserRank ??
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
                (rank: currentUserRank, user: currentUser),
            ];

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              children: [
                if (!hasContest) ...[
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
                _Podium(users: podiumUsers, currentUserId: currentUserId),
                if (otherRows.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  Text('CLASSEMENT', style: AppTextStyles.label),
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
  final bool onPrimary;

  const _Header({
    required this.hasContest,
    required this.hasLiveQuizScope,
    this.onPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = onPrimary ? Colors.white : AppColors.textPrimary;
    final subtitleColor = onPrimary
        ? Colors.white.withValues(alpha: 0.78)
        : AppColors.textSecondary;
    final iconBackground = onPrimary
        ? Colors.white.withValues(alpha: 0.16)
        : AppColors.surface;
    final iconBorder = onPrimary
        ? Colors.white.withValues(alpha: 0.24)
        : AppColors.surfaceBorder;
    final iconColor = onPrimary ? Colors.white : AppColors.primary;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Classement',
                style: AppTextStyles.h1.copyWith(color: titleColor),
              ),
              const SizedBox(height: 5),
              Text(
                hasContest
                    ? 'Les meilleurs joueurs de ce quiz'
                    : hasLiveQuizScope
                    ? 'Les meilleurs joueurs Quiz Live'
                    : 'Les meilleurs joueurs MegaPromo',
                style: AppTextStyles.bodySecondary.copyWith(
                  color: subtitleColor,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: iconBackground,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: iconBorder),
          ),
          child: Icon(Icons.leaderboard_rounded, color: iconColor, size: 22),
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

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        clipBehavior: Clip.antiAlias,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        decoration: BoxDecoration(
          color: const Color(0xFF6557D9),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDark.withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 296,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final sideWidth = (width * 0.29).clamp(82.0, 108.0);
                  final centerWidth = (width * 0.33).clamp(96.0, 126.0);
                  final sideInset = (width * 0.06).clamp(14.0, 24.0);

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: CustomPaint(painter: _PodiumArenaLinesPainter()),
                      ),
                      Positioned(
                        top: 0,
                        left: 0,
                        child: Row(
                          children: [
                            const Icon(
                              Icons.workspace_premium_rounded,
                              color: Colors.white,
                              size: 17,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'TOP 3',
                              style: AppTextStyles.label.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        left: sideInset,
                        bottom: 0,
                        width: sideWidth,
                        child: _PodiumPlace(
                          rank: 2,
                          user: second,
                          height: 92,
                          avatarSize: 54,
                          color: const Color(0xFF8FD3FF),
                          isCurrentUser: second?.id == currentUserId,
                          animationDelay: 120,
                        ),
                      ),
                      Positioned(
                        right: sideInset,
                        bottom: 0,
                        width: sideWidth,
                        child: _PodiumPlace(
                          rank: 3,
                          user: third,
                          height: 76,
                          avatarSize: 52,
                          color: const Color(0xFFFFB17A),
                          isCurrentUser: third?.id == currentUserId,
                          animationDelay: 190,
                        ),
                      ),
                      Positioned(
                        left: (width - centerWidth) / 2,
                        bottom: 0,
                        width: centerWidth,
                        child: _PodiumPlace(
                          rank: 1,
                          user: first,
                          height: 138,
                          avatarSize: 68,
                          color: const Color(0xFFD7C7FF),
                          isCurrentUser: first?.id == currentUserId,
                          animationDelay: 40,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
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
  final int animationDelay;

  const _PodiumPlace({
    required this.rank,
    required this.user,
    required this.height,
    required this.avatarSize,
    required this.color,
    required this.isCurrentUser,
    required this.animationDelay,
  });

  @override
  Widget build(BuildContext context) {
    final avatar = avatarForId(user?.avatarUrl);
    final username = user?.username ?? 'En attente';
    final points = user?.points ?? 0;
    final avatarBackground = rank == 1
        ? const Color(0xFFBDF4F0)
        : rank == 2
        ? const Color(0xFFD7F0FF)
        : const Color(0xFFFFE0C7);
    final avatarForeground = rank == 1
        ? const Color(0xFF7C4A16)
        : rank == 2
        ? const Color(0xFF285C7A)
        : const Color(0xFF8D4D21);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 420 + animationDelay),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        final settled = value.clamp(0.0, 1.0);
        return Opacity(
          opacity: settled,
          child: Transform.translate(
            offset: Offset(0, 22 * (1 - settled)),
            child: Transform.scale(
              scale: 0.94 + (settled * 0.06),
              child: child,
            ),
          ),
        );
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            width: avatarSize,
            height: avatarSize,
            decoration: BoxDecoration(
              color: avatarBackground,
              shape: BoxShape.circle,
              border: Border.all(
                color: isCurrentUser
                    ? AppColors.accentGreen
                    : Colors.white.withValues(alpha: 0.84),
                width: isCurrentUser ? 2.4 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: rank == 1 ? 0.26 : 0.16),
                  blurRadius: rank == 1 ? 18 : 12,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              avatar.icon,
              color: avatarForeground,
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
              color: Colors.white,
              fontSize: rank == 1 ? 15 : 13,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _formatLeaderboardPoints(points),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall.copyWith(
              color: color.withValues(alpha: 0.96),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          _PodiumBlock3D(rank: rank, height: height, color: color),
        ],
      ),
    );
  }
}

class _PodiumBlock3D extends StatelessWidget {
  final int rank;
  final double height;
  final Color color;

  const _PodiumBlock3D({
    required this.rank,
    required this.height,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final depth = 18.0;
    final horizontalInset = rank == 1 ? 4.0 : 6.0;

    return SizedBox(
      height: height + depth,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return Stack(
            alignment: Alignment.bottomCenter,
            children: [
              SizedBox(
                width: width - (horizontalInset * 2),
                height: height + depth,
                child: CustomPaint(
                  size: Size(width - (horizontalInset * 2), height + depth),
                  painter: _PodiumBlockPainter(color: color, depth: depth),
                ),
              ),
              Positioned(
                left: horizontalInset,
                top: depth,
                width: width - (horizontalInset * 2),
                height: height,
                child: Center(
                  child: Text(
                    '$rank',
                    style: AppTextStyles.h2.copyWith(
                      color: rank == 1 ? const Color(0xFF3A2A00) : Colors.white,
                      fontSize: rank == 1 ? 54 : 42,
                      height: 1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PodiumBlockPainter extends CustomPainter {
  final Color color;
  final double depth;

  const _PodiumBlockPainter({required this.color, required this.depth});

  @override
  void paint(Canvas canvas, Size size) {
    final frontPaint = Paint()..color = color.withValues(alpha: 0.94);
    final topPaint = Paint()..color = Colors.white.withValues(alpha: 0.26);
    final innerTopPaint = Paint()..color = color.withValues(alpha: 0.62);
    final strokePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final front = RRect.fromRectAndCorners(
      Rect.fromLTWH(0, depth, size.width, size.height - depth),
      topLeft: const Radius.circular(3),
      topRight: const Radius.circular(3),
      bottomLeft: const Radius.circular(2),
      bottomRight: const Radius.circular(2),
    );

    final top = Path()
      ..moveTo(16, depth)
      ..lineTo(32, 0)
      ..lineTo(size.width - 32, 0)
      ..lineTo(size.width - 16, depth)
      ..close();

    canvas.drawShadow(
      Path()..addRRect(front),
      Colors.black.withValues(alpha: 0.22),
      8,
      false,
    );
    canvas.drawRRect(front, frontPaint);
    canvas.drawPath(top, topPaint);
    canvas.drawPath(
      Path()
        ..moveTo(23, depth - 1)
        ..lineTo(35, 5)
        ..lineTo(size.width - 35, 5)
        ..lineTo(size.width - 23, depth - 1)
        ..close(),
      innerTopPaint,
    );
    canvas.drawPath(top, strokePaint);
    canvas.drawRRect(front, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _PodiumBlockPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.depth != depth;
  }
}

class _PodiumArenaLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final path1 = Path()
      ..moveTo(-20, size.height * 0.62)
      ..quadraticBezierTo(
        size.width * 0.34,
        size.height * 0.12,
        size.width + 26,
        size.height * 0.3,
      );
    final path2 = Path()
      ..moveTo(size.width * 0.08, size.height * 0.08)
      ..quadraticBezierTo(
        size.width * 0.48,
        -18,
        size.width * 0.94,
        size.height * 0.42,
      );

    canvas.drawPath(path1, paint);
    canvas.drawPath(path2, paint);
  }

  @override
  bool shouldRepaint(covariant _PodiumArenaLinesPainter oldDelegate) => false;
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

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + (rank.clamp(4, 12) * 18)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(18 * (1 - value), 0),
            child: child,
          ),
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.fromLTRB(8, 9, 12, 9),
        decoration: BoxDecoration(
          color: isCurrentUser
              ? AppColors.primary.withValues(alpha: 0.12)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isCurrentUser
                ? AppColors.primary.withValues(alpha: 0.52)
                : AppColors.surfaceBorder,
            width: isCurrentUser ? 1.3 : 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: isCurrentUser
                  ? AppColors.primary.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: isCurrentUser ? 18 : 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 3,
              height: 42,
              decoration: BoxDecoration(
                color: isCurrentUser ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isCurrentUser
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isCurrentUser
                      ? AppColors.primary.withValues(alpha: 0.26)
                      : AppColors.surfaceBorder,
                ),
              ),
              child: Text(
                '$rank',
                style: AppTextStyles.bodySmall.copyWith(
                  color: isCurrentUser ? AppColors.primary : AppColors.textHint,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: avatar.color.withValues(alpha: 0.14),
                shape: BoxShape.circle,
                border: Border.all(color: avatar.color.withValues(alpha: 0.2)),
              ),
              child: Icon(avatar.icon, color: avatar.color, size: 19),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Row(
                children: [
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
                  if (isCurrentUser) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'MOI',
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.primary,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            _ScorePill(points: user.points, highlighted: isCurrentUser),
          ],
        ),
      ),
    );
  }
}

class _ScorePill extends StatelessWidget {
  final int points;
  final bool highlighted;

  const _ScorePill({required this.points, required this.highlighted});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: highlighted
            ? AppColors.primary.withValues(alpha: 0.12)
            : AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: highlighted
              ? AppColors.primary.withValues(alpha: 0.22)
              : AppColors.surfaceBorder,
        ),
      ),
      child: Text(
        _formatLeaderboardPoints(points),
        style: AppTextStyles.bodySmall.copyWith(
          color: highlighted ? AppColors.primaryDark : AppColors.textSecondary,
          fontWeight: FontWeight.w900,
        ),
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

String _formatLeaderboardPoints(int points) {
  if (points >= 1000000) return '${(points / 1000000).toStringAsFixed(1)}M pts';
  if (points >= 1000) return '${(points / 1000).toStringAsFixed(1)}K pts';
  return '$points pts';
}
