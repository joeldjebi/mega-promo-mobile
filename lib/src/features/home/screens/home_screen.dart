import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mega_promo/core/theme/app_colors.dart';
import 'package:mega_promo/core/theme/app_text_styles.dart';
import 'package:mega_promo/core/widgets/app_card.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_update/services/app_update_service.dart';
import '../../contests/models/contest.dart';
import '../../contests/providers/contest_providers.dart';
import '../../contests/widgets/contest_timer.dart';
import '../providers/info_message_provider.dart';
import '../providers/user_profile_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  ContestType? _selectedType;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider);
    final contests = ref.watch(contestsProvider);
    final participatedContestIds =
        ref.watch(userParticipatedContestIdsProvider).value ?? const <String>{};
    final registeredLiveQuizIds =
        ref.watch(userRegisteredLiveQuizIdsProvider).value ?? const <String>{};
    final shuffleSeed = ref.watch(contestsShuffleSeedProvider);
    final infoMessages = ref.watch(infoMessagesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(userProfileProvider);
            ref.invalidate(userParticipatedContestIdsProvider);
            ref.invalidate(userRegisteredLiveQuizIdsProvider);
            ref.read(contestsShuffleSeedProvider.notifier).refresh();
            final refreshedContests = ref.refresh(contestsProvider.future);
            await refreshedContests;
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            children: [
              profile.when(
                data: (user) => _HomeHeader(user: user),
                loading: () => const _HomeHeaderShimmer(),
                error: (error, stackTrace) => const _HomeHeaderError(),
              ),
              const SizedBox(height: 16),
              _ContestFilters(
                selectedType: _selectedType,
                onSelected: (type) => setState(() => _selectedType = type),
              ),
              const SizedBox(height: 14),
              contests.when(
                data: (items) {
                  final filtered = _selectedType == null
                      ? items
                      : items
                            .where((contest) => contest.type == _selectedType)
                            .toList();
                  if (filtered.isEmpty) return const _EmptyContestsState();

                  final liveQuizzes =
                      filtered
                          .where((contest) => contest.isLiveVisibleOnHome)
                          .toList()
                        ..sort((a, b) {
                          final rankCompare = _liveQuizHomeRank(
                            a,
                          ).compareTo(_liveQuizHomeRank(b));
                          if (rankCompare != 0) return rankCompare;
                          if (a.isLiveEnded && b.isLiveEnded) {
                            return b.endsAt.compareTo(a.endsAt);
                          }
                          final aDate =
                              a.liveStartsAt ?? a.startsAt ?? a.endsAt;
                          final bDate =
                              b.liveStartsAt ?? b.startsAt ?? b.endsAt;
                          return aDate.compareTo(bDate);
                        });
                  final boosted = shuffleContestsForSession(
                    filtered.where(
                      (contest) => contest.isBoosted && !contest.isLive,
                    ),
                    shuffleSeed,
                  ).take(5).toList();
                  final allContests = shuffleContestsForSession(
                    filtered.where((contest) => !contest.isLive),
                    shuffleSeed,
                  );

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (liveQuizzes.isNotEmpty) ...[
                        Text('QUIZ LIVE', style: AppTextStyles.label),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 214,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            clipBehavior: Clip.none,
                            itemCount: liveQuizzes.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 10),
                            itemBuilder: (context, index) {
                              final contest = liveQuizzes[index];
                              return SizedBox(
                                width: 318,
                                child: _LiveQuizCard(
                                  contest: contest,
                                  hasParticipated: participatedContestIds
                                      .contains(contest.id),
                                  isRegistered: registeredLiveQuizIds.contains(
                                    contest.id,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      infoMessages.maybeWhen(
                        data: (messages) => messages.isEmpty
                            ? const SizedBox.shrink()
                            : Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: _InfoMessageCarousel(messages: messages),
                              ),
                        orElse: () => const SizedBox.shrink(),
                      ),
                      if (boosted.isNotEmpty) ...[
                        Text('EN VEDETTE', style: AppTextStyles.label),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 228,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            clipBehavior: Clip.none,
                            itemCount: boosted.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 10),
                            itemBuilder: (context, index) {
                              return _FeaturedContestCard(
                                contest: boosted[index],
                                hasParticipated: participatedContestIds
                                    .contains(boosted[index].id),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],
                      Text('TOUS LES CONCOURS', style: AppTextStyles.label),
                      const SizedBox(height: 10),
                      ...allContests
                          .take(10)
                          .map(
                            (contest) => Padding(
                              padding: const EdgeInsets.only(bottom: 9),
                              child: _CompactContestCard(
                                contest: contest,
                                hasParticipated: participatedContestIds
                                    .contains(contest.id),
                              ),
                            ),
                          ),
                      if (allContests.length > 10) ...[
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () => context.go('/contests'),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.surfaceBorder,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'Voir tout',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
                loading: () => const _ContestListShimmer(),
                error: (error, stackTrace) => _ContestErrorState(
                  onRetry: () => ref.invalidate(contestsProvider),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContestFilters extends StatelessWidget {
  final ContestType? selectedType;
  final ValueChanged<ContestType?> onSelected;

  const _ContestFilters({required this.selectedType, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final filters = <({String label, ContestType? type})>[
      (label: 'Tous', type: null),
      (label: 'Quiz', type: ContestType.quiz),
      (label: 'Tirage', type: ContestType.tirage),
      (label: 'Pronostic', type: ContestType.pronostic),
    ];

    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = selectedType == filter.type;

          return InkWell(
            onTap: () => onSelected(filter.type),
            borderRadius: BorderRadius.circular(999),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primaryLight
                      : AppColors.surfaceBorder,
                ),
              ),
              child: Center(
                child: Text(
                  filter.label,
                  style: AppTextStyles.bodySmall.copyWith(
                    fontSize: 10.5,
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _InfoMessageCarousel extends ConsumerStatefulWidget {
  final List<InfoMessage> messages;

  const _InfoMessageCarousel({required this.messages});

  @override
  ConsumerState<_InfoMessageCarousel> createState() =>
      _InfoMessageCarouselState();
}

class _InfoMessageCarouselState extends ConsumerState<_InfoMessageCarousel> {
  final PageController _controller = PageController(viewportFraction: 0.94);
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 118,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.messages.length,
            onPageChanged: (index) => setState(() => _index = index),
            itemBuilder: (context, index) {
              final message = widget.messages[index];
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _InfoMessageCard(message: message),
              );
            },
          ),
        ),
        if (widget.messages.length > 1) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.messages.length, (index) {
              final active = index == _index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: active ? 18 : 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.primaryLight
                      : AppColors.surfaceBorder,
                  borderRadius: BorderRadius.circular(999),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

class _InfoMessageCard extends ConsumerWidget {
  final InfoMessage message;

  const _InfoMessageCard({required this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final background = _parseColor(
      message.backgroundColor,
      const Color(0xFFF7C4AD),
    );
    final foreground = _parseColor(message.textColor, const Color(0xFF4B1609));

    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: background.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: 18,
            bottom: 14,
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.44),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.campaign_rounded,
                color: foreground.withValues(alpha: 0.78),
                size: 28,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 46, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.h2.copyWith(
                    color: foreground,
                    fontSize: 17,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  message.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                    color: foreground.withValues(alpha: 0.9),
                    fontSize: 12,
                    height: 1.2,
                  ),
                ),
                const Spacer(),
                if (message.ctaLabel.isNotEmpty)
                  InkWell(
                    onTap: () =>
                        unawaited(_openInfoMessageTarget(context, message)),
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.26),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.34),
                        ),
                      ),
                      child: Text(
                        message.ctaLabel,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: foreground,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              tooltip: 'Masquer',
              onPressed: () => dismissInfoMessage(ref, message.id),
              icon: Icon(Icons.close_rounded, color: foreground, size: 21),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openInfoMessageTarget(
    BuildContext context,
    InfoMessage message,
  ) async {
    final target = message.ctaUrl.trim();
    if (target == 'app-update://store') {
      await AppUpdateService.openCurrentPlatformStore();
      return;
    }

    if (target.startsWith('/')) {
      context.go(target);
      return;
    }

    final uri = Uri.tryParse(target);
    if (uri != null && uri.hasScheme) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

Color _parseColor(String value, Color fallback) {
  final normalized = value.trim().replaceFirst('#', '');
  if (normalized.length != 6) return fallback;
  final colorValue = int.tryParse('FF$normalized', radix: 16);
  return colorValue == null ? fallback : Color(colorValue);
}

class _FeaturedContestCard extends StatelessWidget {
  final Contest contest;
  final bool hasParticipated;

  const _FeaturedContestCard({
    required this.contest,
    required this.hasParticipated,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/contests/${contest.id}'),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 274,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.20),
            width: 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: AppColors.subtleShadow,
              blurRadius: 14,
              offset: Offset(0, 7),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (hasParticipated)
                  const _ParticipatedBadge()
                else
                  const _SponsoredBadge(),
                const SizedBox(width: 6),
                if (contest.brandLogoUrl?.isNotEmpty == true) ...[
                  _BrandLogo(url: contest.brandLogoUrl!, size: 26),
                  const SizedBox(width: 5),
                ],
                Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.schedule_rounded,
                            color: AppColors.gold,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: ContestTimer(
                              endsAt: contest.endsAt,
                              style: AppTextStyles.bodySmall.copyWith(
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              contest.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.h2.copyWith(fontSize: 16.5, height: 1.13),
            ),
            const SizedBox(height: 4),
            Text(
              _formatPrize(contest.prizeValue),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.price.copyWith(fontSize: 21),
            ),
            const SizedBox(height: 8),
            Container(height: 1, color: AppColors.separator),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _FeaturedMeta(
                    icon: Icons.visibility_rounded,
                    value: '${contest.viewsCount} vues',
                  ),
                ),
                const SizedBox(width: 8),
                _FeaturedMeta(
                  icon: Icons.workspace_premium_rounded,
                  value: '${contest.winnersCount} gagnants',
                ),
              ],
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 38,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    hasParticipated ? 'Déjà joué' : 'Participer',
                    style: AppTextStyles.button.copyWith(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

int _liveQuizHomeRank(Contest contest) {
  if (contest.isLiveActiveNow) return 0;
  if (contest.isLiveEnded) return 2;
  return 1;
}

class _LiveQuizCard extends StatelessWidget {
  final Contest contest;
  final bool hasParticipated;
  final bool isRegistered;

  const _LiveQuizCard({
    required this.contest,
    required this.hasParticipated,
    required this.isRegistered,
  });

  @override
  Widget build(BuildContext context) {
    final liveStartsAt = contest.liveStartsAt;
    final isEnded = contest.isLiveEnded;
    final isActiveNow = contest.isLiveActiveNow;
    final statusColor = isEnded
        ? AppColors.textHint
        : isActiveNow
        ? AppColors.accentGreen
        : AppColors.primary;
    final statusText = isEnded
        ? 'TERMINÉ'
        : isActiveNow
        ? 'EN DIRECT'
        : 'À VENIR';
    final startsLabel = liveStartsAt == null
        ? 'Heure à confirmer'
        : '${liveStartsAt.hour.toString().padLeft(2, '0')}:'
              '${liveStartsAt.minute.toString().padLeft(2, '0')}';

    return InkWell(
      onTap: isEnded ? null : () => context.push('/contests/${contest.id}'),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          color: isEnded ? AppColors.surface : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isEnded ? AppColors.textHint : statusColor,
            width: 3,
          ),
          boxShadow: isEnded
              ? const []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.07),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    blurRadius: 26,
                    offset: const Offset(0, 14),
                  ),
                ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: 14,
              top: 62,
              child: Icon(
                Icons.grid_4x4_rounded,
                color: AppColors.primary.withValues(
                  alpha: isEnded ? 0.04 : 0.08,
                ),
                size: 72,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.26),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              statusText,
                              style: AppTextStyles.label.copyWith(
                                color: statusColor,
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (isRegistered)
                        const _LiveRegisteredBadge()
                      else if (hasParticipated)
                        const _ParticipatedBadge(compact: true)
                      else
                        _CategoryBadge(label: contest.type.filterLabel),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.surfaceBorder),
                        ),
                        child: Text(
                          startsLabel,
                          style: AppTextStyles.h3.copyWith(
                            color: isEnded
                                ? AppColors.textSecondary
                                : AppColors.primaryDark,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: isEnded
                              ? AppColors.surfaceElevated.withValues(
                                  alpha: 0.72,
                                )
                              : AppColors.accent,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isEnded
                                ? AppColors.textHint.withValues(alpha: 0.18)
                                : AppColors.primary.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Icon(
                          Icons.sports_esports_rounded,
                          color: isEnded
                              ? AppColors.textHint
                              : AppColors.primaryDark,
                          size: 27,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              contest.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.h2.copyWith(
                                color: isEnded
                                    ? AppColors.textSecondary
                                    : AppColors.textPrimary,
                                fontSize: 17,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Flexible(
                                  child: _LiveQuizMetaChip(
                                    icon: Icons.workspace_premium_rounded,
                                    label: _formatPrize(contest.prizeValue),
                                    muted: isEnded,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                _LiveQuizMetaChip(
                                  icon: Icons.groups_rounded,
                                  label: '${contest.registeredCount}',
                                  muted: isEnded,
                                ),
                              ],
                            ),
                            if (isEnded) ...[
                              const SizedBox(height: 5),
                              Text(
                                'Terminé · visible aujourd’hui',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: isEnded
                          ? AppColors.surfaceElevated.withValues(alpha: 0.70)
                          : AppColors.accent.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(
                        color: isEnded
                            ? AppColors.surfaceBorder
                            : AppColors.primary.withValues(alpha: 0.16),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isEnded
                              ? Icons.history_toggle_off_rounded
                              : Icons.timer_rounded,
                          color: isEnded ? AppColors.textHint : AppColors.gold,
                          size: 17,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: isEnded
                              ? Text(
                                  'Terminé · visible aujourd’hui',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                )
                              : liveStartsAt == null
                              ? Text(
                                  'Départ bientôt',
                                  style: AppTextStyles.bodySmall,
                                )
                              : _LiveQuizStartsCountdown(
                                  startsAt: liveStartsAt,
                                ),
                        ),
                        if (!isEnded) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: AppColors.primary.withValues(
                                  alpha: 0.16,
                                ),
                              ),
                            ),
                            child: Text(
                              isRegistered ? 'Entrer' : 'Réserver',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveQuizMetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool muted;

  const _LiveQuizMetaChip({
    required this.icon,
    required this.label,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    final color = muted ? AppColors.textHint : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: muted ? 0.58 : 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySmall.copyWith(
                color: color,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveRegisteredBadge extends StatelessWidget {
  const _LiveRegisteredBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.accentGreen.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.accentGreen.withValues(alpha: 0.34),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: AppColors.accentGreen,
            size: 13,
          ),
          const SizedBox(width: 5),
          Text(
            'Inscrit',
            style: AppTextStyles.label.copyWith(
              color: AppColors.accentGreen,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturedMeta extends StatelessWidget {
  final IconData icon;
  final String value;

  const _FeaturedMeta({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.textHint, size: 15),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySecondary.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _BrandLogo extends StatelessWidget {
  final String url;
  final double size;

  const _BrandLogo({required this.url, required this.size});

  bool get _isSvg => url.split('?').first.toLowerCase().endsWith('.svg');

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size <= 32 ? 4 : 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size <= 32 ? 10 : 14),
        border: Border.all(color: AppColors.surfaceBorder, width: 0.8),
      ),
      clipBehavior: Clip.antiAlias,
      child: _isSvg
          ? SvgPicture.network(url, fit: BoxFit.contain)
          : Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Icon(
                Icons.business_rounded,
                color: AppColors.textHint,
                size: size * 0.45,
              ),
            ),
    );
  }
}

class _CompactContestCard extends ConsumerWidget {
  final Contest contest;
  final bool hasParticipated;

  const _CompactContestCard({
    required this.contest,
    required this.hasParticipated,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final participantsCount =
        ref.watch(contestParticipantsCountProvider(contest.id)).value ?? 0;
    final hasLimit = contest.maxParticipants > 0;
    final now = DateTime.now();
    final startsAt = contest.startsAt ?? now;
    final totalDuration = contest.endsAt.difference(startsAt).inSeconds;
    final elapsedDuration = now.difference(startsAt).inSeconds;
    final timeProgress = totalDuration <= 0
        ? 1.0
        : (elapsedDuration / totalDuration).clamp(0.0, 1.0);
    final progress = hasLimit
        ? (participantsCount / contest.maxParticipants).clamp(0.0, 1.0)
        : timeProgress;
    final progressLabel = hasLimit
        ? '$participantsCount / ${contest.maxParticipants} joueurs'
        : '$participantsCount participant${participantsCount > 1 ? 's' : ''}';

    return AppCard(
      onTap: () => context.push('/contests/${contest.id}'),
      padding: const EdgeInsets.all(13),
      borderRadius: 18,
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: contest.type.color.withValues(alpha: 0.22),
                  ),
                ),
                child: contest.brandLogoUrl?.isNotEmpty == true
                    ? _BrandLogo(url: contest.brandLogoUrl!, size: 42)
                    : Icon(
                        contest.type.icon,
                        color: contest.type.color,
                        size: 20,
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contest.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.h2.copyWith(fontSize: 14.8),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatPrize(contest.prizeValue),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.price.copyWith(fontSize: 13.5),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${contest.viewsCount} vues',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        fontSize: 10.5,
                        color: AppColors.textHint,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (hasParticipated)
                    const _ParticipatedBadge(compact: true)
                  else
                    _CategoryBadge(label: contest.type.filterLabel),
                  const SizedBox(height: 8),
                  ContestTimer(endsAt: contest.endsAt),
                ],
              ),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: Text(
                  hasLimit ? 'Places prises' : 'Temps écoulé',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textHint,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                progressLabel,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 3,
              backgroundColor: AppColors.separator,
              valueColor: AlwaysStoppedAnimation<Color>(contest.type.color),
            ),
          ),
        ],
      ),
    );
  }
}

class _SponsoredBadge extends StatelessWidget {
  const _SponsoredBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.28),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt_rounded, color: AppColors.primary, size: 12),
          const SizedBox(width: 4),
          Text(
            'Sponsorisé',
            style: AppTextStyles.bodySmall.copyWith(
              fontSize: 10.5,
              color: AppColors.primaryLight,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveQuizStartsCountdown extends StatefulWidget {
  final DateTime startsAt;

  const _LiveQuizStartsCountdown({required this.startsAt});

  @override
  State<_LiveQuizStartsCountdown> createState() =>
      _LiveQuizStartsCountdownState();
}

class _LiveQuizStartsCountdownState extends State<_LiveQuizStartsCountdown> {
  Timer? _timer;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = _calculateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remaining = _calculateRemaining());
    });
  }

  @override
  void didUpdateWidget(covariant _LiveQuizStartsCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startsAt != widget.startsAt) {
      setState(() => _remaining = _calculateRemaining());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Duration _calculateRemaining() {
    final remaining = widget.startsAt.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  String _formatRemaining() {
    if (_remaining == Duration.zero) return 'Commence maintenant';

    final totalHours = _remaining.inHours;
    final minutes = _remaining.inMinutes.remainder(60);
    final seconds = _remaining.inSeconds.remainder(60);

    return 'Commence dans $totalHours:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isUrgent =
        _remaining > Duration.zero && _remaining < const Duration(minutes: 5);

    return Text(
      _formatRemaining(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyles.bodySmall.copyWith(
        color: isUrgent ? AppColors.accentRed : AppColors.textPrimary,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _ParticipatedBadge extends StatelessWidget {
  final bool compact;

  const _ParticipatedBadge({this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 8,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: AppColors.accentGreen.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.accentGreen.withValues(alpha: 0.32),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_rounded,
            color: AppColors.accentGreen,
            size: compact ? 11 : 12,
          ),
          const SizedBox(width: 4),
          Text(
            'Déjà joué',
            style: AppTextStyles.bodySmall.copyWith(
              fontSize: compact ? 10 : 10.5,
              color: AppColors.accentGreen,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  final String label;

  const _CategoryBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 86),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.surfaceBorder, width: 0.8),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.bodySmall.copyWith(
          fontSize: 10.5,
          color: AppColors.primaryLight,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ContestListShimmer extends StatelessWidget {
  const _ContestListShimmer();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceElevated,
      highlightColor: AppColors.surfaceBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _ShimmerBlock(width: 92, height: 14),
          SizedBox(height: 14),
          _ShimmerBlock(width: double.infinity, height: 174),
          SizedBox(height: 22),
          _ShimmerBlock(width: 138, height: 14),
          SizedBox(height: 14),
          _ShimmerBlock(width: double.infinity, height: 76),
          SizedBox(height: 10),
          _ShimmerBlock(width: double.infinity, height: 76),
          SizedBox(height: 10),
          _ShimmerBlock(width: double.infinity, height: 76),
        ],
      ),
    );
  }
}

class _EmptyContestsState extends StatelessWidget {
  const _EmptyContestsState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 44),
      child: Column(
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              color: AppColors.gold,
              size: 44,
            ),
          ),
          const SizedBox(height: 22),
          Text('Aucun concours actif', style: AppTextStyles.h2),
          const SizedBox(height: 8),
          Text(
            'Reviens bientôt pour découvrir les prochains défis.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySecondary,
          ),
        ],
      ),
    );
  }
}

class _ContestErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _ContestErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          Text(
            'Impossible de charger les concours.',
            style: AppTextStyles.bodySecondary,
          ),
          const SizedBox(height: 10),
          TextButton(onPressed: onRetry, child: const Text('Réessayer')),
        ],
      ),
    );
  }
}

String _formatPrize(num value) {
  final rounded = value.round();
  if (rounded <= 0) return 'Prix surprise';
  return '$rounded FCFA';
}

class _HomeHeader extends StatelessWidget {
  final UserProfile user;

  const _HomeHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bonjour',
                style: AppTextStyles.bodySecondary.copyWith(fontSize: 12.5),
              ),
              const SizedBox(height: 1),
              Text(
                user.username,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.h1.copyWith(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.surfaceBorder),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.star_border_rounded,
                color: AppColors.gold,
                size: 18,
              ),
              const SizedBox(width: 5),
              Text(
                '${user.pointsTotal}',
                style: AppTextStyles.h3.copyWith(fontSize: 15),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        _UserAvatar(avatarUrl: user.avatarUrl),
      ],
    );
  }
}

class _UserAvatar extends StatelessWidget {
  final String? avatarUrl;

  const _UserAvatar({required this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    final avatar = avatarForId(avatarUrl);

    return Container(
      width: 39,
      height: 39,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: avatar.color.withValues(alpha: 0.18),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Icon(avatar.icon, color: avatar.color, size: 20),
    );
  }
}

class _HomeHeaderShimmer extends StatelessWidget {
  const _HomeHeaderShimmer();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceElevated,
      highlightColor: AppColors.surfaceBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    _ShimmerBlock(width: 196, height: 24),
                    SizedBox(height: 10),
                    _ShimmerBlock(width: 170, height: 14),
                  ],
                ),
              ),
              _ShimmerCircle(size: 48),
            ],
          ),
          const SizedBox(height: 20),
          const _ShimmerBlock(width: double.infinity, height: 84),
        ],
      ),
    );
  }
}

class _HomeHeaderError extends StatelessWidget {
  const _HomeHeaderError();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Text(
        'Impossible de charger ton profil.',
        style: AppTextStyles.bodySecondary,
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
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

class _ShimmerCircle extends StatelessWidget {
  final double size;

  const _ShimmerCircle({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.surfaceElevated,
        shape: BoxShape.circle,
      ),
    );
  }
}

class AvatarDisplayData {
  final IconData icon;
  final Color color;

  const AvatarDisplayData({required this.icon, required this.color});
}

AvatarDisplayData avatarForId(String? id) {
  return _avatarDisplayMap[id] ??
      const AvatarDisplayData(
        icon: Icons.person_rounded,
        color: AppColors.primaryLight,
      );
}

const Map<String, AvatarDisplayData> _avatarDisplayMap = {
  'avatar_1': AvatarDisplayData(
    icon: Icons.emoji_events_rounded,
    color: AppColors.gold,
  ),
  'avatar_2': AvatarDisplayData(
    icon: Icons.bolt_rounded,
    color: AppColors.primaryLight,
  ),
  'avatar_3': AvatarDisplayData(
    icon: Icons.star_rounded,
    color: AppColors.accent,
  ),
  'avatar_4': AvatarDisplayData(
    icon: Icons.workspace_premium_rounded,
    color: AppColors.accentGreen,
  ),
  'avatar_5': AvatarDisplayData(
    icon: Icons.local_fire_department_rounded,
    color: Color(0xFFFF8A4C),
  ),
  'avatar_6': AvatarDisplayData(
    icon: Icons.diamond_rounded,
    color: Color(0xFF38BDF8),
  ),
  'avatar_7': AvatarDisplayData(
    icon: Icons.sports_esports_rounded,
    color: Color(0xFFF472B6),
  ),
  'avatar_8': AvatarDisplayData(
    icon: Icons.rocket_launch_rounded,
    color: Color(0xFFA3E635),
  ),
  'avatar_9': AvatarDisplayData(
    icon: Icons.campaign_rounded,
    color: Color(0xFFFACC15),
  ),
  'avatar_10': AvatarDisplayData(
    icon: Icons.shield_rounded,
    color: Color(0xFF60A5FA),
  ),
  'avatar_11': AvatarDisplayData(
    icon: Icons.favorite_rounded,
    color: Color(0xFFFB7185),
  ),
  'avatar_12': AvatarDisplayData(
    icon: Icons.auto_awesome_rounded,
    color: Color(0xFFC084FC),
  ),
};
