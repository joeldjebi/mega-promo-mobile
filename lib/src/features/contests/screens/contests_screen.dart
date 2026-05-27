import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:mega_promo/core/theme/app_colors.dart';
import 'package:mega_promo/core/theme/app_text_styles.dart';
import 'package:mega_promo/core/utils/currency_formatter.dart';
import 'package:mega_promo/core/widgets/app_card.dart';

import '../models/contest.dart';
import '../providers/contest_providers.dart';
import '../services/contest_asset_preload_service.dart';
import '../widgets/contest_timer.dart';
import '../../auth/providers/auth_provider.dart';
import '../../home/providers/home_bootstrap_provider.dart';

enum _ContestViewMode { list, grid }

class ContestsScreen extends ConsumerStatefulWidget {
  const ContestsScreen({super.key});

  @override
  ConsumerState<ContestsScreen> createState() => _ContestsScreenState();
}

class _ContestsScreenState extends ConsumerState<ContestsScreen> {
  String? _selectedCategory;
  _ContestViewMode _viewMode = _ContestViewMode.list;
  Timer? _liveTicker;
  String? _preloadedContestAssetsKey;
  List<Contest>? _lastContests;
  Set<String>? _lastParticipatedContestIds;

  @override
  void initState() {
    super.initState();
    _liveTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _liveTicker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bootstrap = ref.watch(homeBootstrapProvider);
    final bootstrapData = bootstrap.asData?.value;
    final realtimeContests = ref.watch(contestsProvider);
    final realtimeItems = realtimeContests.asData?.value;
    if (bootstrapData != null) {
      _lastParticipatedContestIds = bootstrapData.participatedContestIds;
      if (realtimeItems == null) _lastContests = bootstrapData.contests;
    }
    if (realtimeItems != null) _lastContests = realtimeItems;
    final contests = _lastContests == null
        ? realtimeContests
        : AsyncData(_lastContests!);
    final participatedAsync = ref.watch(userParticipatedContestIdsProvider);
    final participatedValue = participatedAsync.asData?.value;
    if (participatedValue != null) {
      _lastParticipatedContestIds = participatedValue;
    }
    final participatedContestIds =
        _lastParticipatedContestIds ?? const <String>{};
    final shuffleSeed = ref.watch(contestsShuffleSeedProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Quiz promotionnels'),
        actions: [
          _ViewToggleButton(
            icon: Icons.view_agenda_rounded,
            isSelected: _viewMode == _ContestViewMode.list,
            onTap: () => setState(() => _viewMode = _ContestViewMode.list),
          ),
          _ViewToggleButton(
            icon: Icons.grid_view_rounded,
            isSelected: _viewMode == _ContestViewMode.grid,
            onTap: () => setState(() => _viewMode = _ContestViewMode.grid),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () async {
            clearHomeBootstrapCache(
              userId: ref.read(currentUserIdProvider),
              clearStored: true,
            );
            ref.invalidate(homeBootstrapProvider);
            ref.invalidate(userParticipatedContestIdsProvider);
            ref.invalidate(userRegisteredLiveQuizIdsProvider);
            ref.invalidate(categoriesProvider);
            ref.read(contestsShuffleSeedProvider.notifier).refresh();
            final refreshedBootstrap = ref.refresh(
              homeBootstrapProvider.future,
            );
            await refreshedBootstrap;
            final refreshed = ref.refresh(contestsProvider.future);
            await refreshed;
          },
          child: contests.when(
            data: (items) {
              _preloadContestAssets(items);
              final categories = _categoryNames(items);
              final effectiveCategory = categories.contains(_selectedCategory)
                  ? _selectedCategory
                  : null;
              final filtered = shuffleContestsForSession(
                _filterContestsByCategory(items, effectiveCategory),
                shuffleSeed,
              );

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                children: [
                  Text(
                    'Tous les quiz promotionnels actifs',
                    style: AppTextStyles.h2.copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${filtered.length} quiz disponible${filtered.length > 1 ? 's' : ''}',
                    style: AppTextStyles.bodySecondary.copyWith(fontSize: 12),
                  ),
                  if (categories.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _CategoryFilters(
                      categories: categories,
                      selectedCategory: effectiveCategory,
                      onSelected: (category) =>
                          setState(() => _selectedCategory = category),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (filtered.isEmpty)
                    const _EmptyContestList()
                  else if (_viewMode == _ContestViewMode.grid)
                    _ContestGrid(
                      contests: filtered,
                      participatedContestIds: participatedContestIds,
                    )
                  else
                    _ContestList(
                      contests: filtered,
                      participatedContestIds: participatedContestIds,
                    ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => _ContestLoadError(
              onRetry: () {
                clearHomeBootstrapCache(
                  userId: ref.read(currentUserIdProvider),
                  clearStored: true,
                );
                ref
                  ..invalidate(homeBootstrapProvider)
                  ..invalidate(contestsProvider);
              },
            ),
          ),
        ),
      ),
    );
  }

  void _preloadContestAssets(List<Contest> contests) {
    final key = contests.take(16).map((contest) => contest.id).join('|');
    if (key.isEmpty || key == _preloadedContestAssetsKey) return;
    _preloadedContestAssetsKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ContestAssetPreloadService.preloadContestImages(
        context,
        contests,
        limit: 16,
      );
    });
  }

  List<Contest> _filterContestsByCategory(
    List<Contest> contests,
    String? selectedCategory,
  ) {
    if (selectedCategory == null) return contests;
    return contests
        .where((contest) => contest.category == selectedCategory)
        .toList();
  }

  List<String> _categoryNames(List<Contest> contests) {
    final names =
        contests
            .map((contest) => contest.category.trim())
            .where((category) => category.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return names;
  }
}

class _ViewToggleButton extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ViewToggleButton({
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon),
      color: isSelected ? AppColors.primary : AppColors.textHint,
      style: IconButton.styleFrom(
        backgroundColor: isSelected
            ? AppColors.primary.withValues(alpha: 0.12)
            : Colors.transparent,
      ),
    );
  }
}

class _CategoryFilters extends StatelessWidget {
  final List<String> categories;
  final String? selectedCategory;
  final ValueChanged<String?> onSelected;

  const _CategoryFilters({
    required this.categories,
    required this.selectedCategory,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = index == 0 ? null : categories[index - 1];
          final label = category ?? 'Toutes catégories';
          return _FilterChipButton(
            label: label,
            isSelected: selectedCategory == category,
            onTap: () => onSelected(category),
          );
        },
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChipButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
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
        alignment: Alignment.center,
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodySmall.copyWith(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

String _contestBadgeLabel(Contest contest) {
  if (contest.isLiveActiveNow) return 'En direct';
  if (contest.isLive) return 'À venir';
  return _contestCategoryLabel(contest);
}

String _contestCategoryLabel(Contest contest) {
  final category = contest.category.trim();
  if (category.isNotEmpty && category.toLowerCase() != 'général') {
    return category;
  }
  return contest.type.filterLabel;
}

String _contestAudienceLabel(Contest contest) {
  if (contest.isLive) {
    return '${contest.registeredCount} inscrit${contest.registeredCount > 1 ? 's' : ''}';
  }
  return '${contest.viewsCount} vue${contest.viewsCount > 1 ? 's' : ''}';
}

DateTime _contestCountdownTarget(Contest contest) {
  if (contest.isLive &&
      !contest.isLiveActiveNow &&
      !contest.isLiveEnded &&
      contest.liveStartsAt != null) {
    return contest.liveStartsAt!;
  }
  return contest.computedLiveEndsAt;
}

class _ContestList extends StatelessWidget {
  final List<Contest> contests;
  final Set<String> participatedContestIds;

  const _ContestList({
    required this.contests,
    required this.participatedContestIds,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: contests
          .map(
            (contest) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ListContestCard(
                contest: contest,
                hasParticipated: participatedContestIds.contains(contest.id),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _ContestGrid extends StatelessWidget {
  final List<Contest> contests;
  final Set<String> participatedContestIds;

  const _ContestGrid({
    required this.contests,
    required this.participatedContestIds,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: contests.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.78,
      ),
      itemBuilder: (context, index) => _GridContestCard(
        contest: contests[index],
        hasParticipated: participatedContestIds.contains(contests[index].id),
      ),
    );
  }
}

class _ListContestCard extends StatelessWidget {
  final Contest contest;
  final bool hasParticipated;

  const _ListContestCard({
    required this.contest,
    required this.hasParticipated,
  });

  @override
  Widget build(BuildContext context) {
    final isEndedLive = contest.isLiveEnded;
    return Opacity(
      opacity: isEndedLive ? 0.58 : 1,
      child: AppCard(
        onTap: isEndedLive
            ? null
            : () {
                clearContestDetailCache(contest.id);
                context.push('/contests/${contest.id}');
              },
        padding: const EdgeInsets.all(13),
        borderRadius: 18,
        child: Row(
          children: [
            _ContestIcon(contest: contest, size: 44, muted: isEndedLive),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contest.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.h3.copyWith(
                      color: isEndedLive
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatPrize(contest.prizeValue),
                    style: AppTextStyles.price.copyWith(
                      color: isEndedLive ? AppColors.textHint : AppColors.gold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (isEndedLive)
                        const _EndedLiveBadge()
                      else if (hasParticipated)
                        const _ParticipatedBadge()
                      else
                        _SmallBadge(label: _contestBadgeLabel(contest)),
                      const SizedBox(width: 8),
                      _InlineMeta(
                        icon: contest.isLive
                            ? Icons.groups_rounded
                            : Icons.visibility_rounded,
                        label: _contestAudienceLabel(contest),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: isEndedLive
                            ? Text(
                                'Terminé',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textHint,
                                  fontWeight: FontWeight.w800,
                                ),
                              )
                            : ContestTimer(
                                endsAt: _contestCountdownTarget(contest),
                              ),
                      ),
                    ],
                  ),
                  if (!isEndedLive) ...[
                    const SizedBox(height: 5),
                    Text(
                      'Fin ${_shortDateTime(contest.computedLiveEndsAt)} · ${_winnerText(contest)} après la fin',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textHint,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridContestCard extends StatelessWidget {
  final Contest contest;
  final bool hasParticipated;

  const _GridContestCard({
    required this.contest,
    required this.hasParticipated,
  });

  @override
  Widget build(BuildContext context) {
    final isEndedLive = contest.isLiveEnded;
    return Opacity(
      opacity: isEndedLive ? 0.58 : 1,
      child: AppCard(
        onTap: isEndedLive
            ? null
            : () {
                clearContestDetailCache(contest.id);
                context.push('/contests/${contest.id}');
              },
        padding: const EdgeInsets.all(12),
        borderRadius: 18,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _ContestIcon(contest: contest, size: 40, muted: isEndedLive),
                const Spacer(),
                if (isEndedLive)
                  const _EndedLiveBadge(compact: true)
                else if (hasParticipated)
                  const _ParticipatedBadge(compact: true)
                else
                  _SmallBadge(
                    label: _contestBadgeLabel(contest),
                    compact: true,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              contest.title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.h3.copyWith(
                color: isEndedLive
                    ? AppColors.textSecondary
                    : AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _formatPrize(contest.prizeValue),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.price.copyWith(
                color: isEndedLive ? AppColors.textHint : AppColors.gold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            _InlineMeta(
              icon: contest.isLive
                  ? Icons.groups_rounded
                  : Icons.visibility_rounded,
              label: _contestAudienceLabel(contest),
            ),
            if (!isEndedLive) ...[
              const SizedBox(height: 4),
              _InlineMeta(
                icon: Icons.event_available_rounded,
                label: 'Fin ${_shortDateTime(contest.computedLiveEndsAt)}',
              ),
              const SizedBox(height: 3),
              _InlineMeta(
                icon: Icons.emoji_events_rounded,
                label: '${_winnerText(contest)} après la fin',
              ),
            ],
            const Spacer(),
            if (isEndedLive)
              const _EndedLiveBadge()
            else if (hasParticipated)
              const _ParticipatedBadge()
            else
              _SmallBadge(label: _contestBadgeLabel(contest)),
            const SizedBox(height: 8),
            if (isEndedLive)
              Text(
                'Terminé',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textHint,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              )
            else
              ContestTimer(
                endsAt: _contestCountdownTarget(contest),
                style: AppTextStyles.bodySmall.copyWith(fontSize: 10.5),
              ),
          ],
        ),
      ),
    );
  }
}

class _ContestIcon extends StatelessWidget {
  final Contest contest;
  final double size;
  final bool muted;

  const _ContestIcon({
    required this.contest,
    required this.size,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    final logoUrl = contest.brandLogoUrl;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(logoUrl?.isNotEmpty == true ? 6 : 0),
      decoration: BoxDecoration(
        color: muted
            ? AppColors.surfaceElevated
            : logoUrl?.isNotEmpty == true
            ? Colors.white
            : contest.type.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.surfaceBorder, width: 0.8),
      ),
      clipBehavior: Clip.antiAlias,
      child: logoUrl?.isNotEmpty == true
          ? _NetworkLogo(url: logoUrl!)
          : Icon(
              contest.type.icon,
              color: muted ? AppColors.textHint : contest.type.color,
              size: size * 0.5,
            ),
    );
  }
}

class _NetworkLogo extends StatelessWidget {
  final String url;

  const _NetworkLogo({required this.url});

  bool get _isSvg => url.split('?').first.toLowerCase().endsWith('.svg');

  @override
  Widget build(BuildContext context) {
    if (_isSvg) return SvgPicture.network(url, fit: BoxFit.contain);

    return Image.network(
      url,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => const Icon(
        Icons.business_rounded,
        color: AppColors.textHint,
        size: 18,
      ),
    );
  }
}

class _SmallBadge extends StatelessWidget {
  final String label;
  final bool compact;

  const _SmallBadge({required this.label, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 7,
        vertical: compact ? 3 : 4,
      ),
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
          fontSize: compact ? 9.5 : 10.5,
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
        ),
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
        horizontal: compact ? 6 : 7,
        vertical: compact ? 3 : 4,
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
            size: compact ? 10 : 11,
          ),
          const SizedBox(width: 4),
          Text(
            'Déjà joué',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall.copyWith(
              fontSize: compact ? 9.5 : 10.5,
              color: AppColors.accentGreen,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _EndedLiveBadge extends StatelessWidget {
  final bool compact;

  const _EndedLiveBadge({this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 7,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.surfaceBorder, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.history_toggle_off_rounded,
            color: AppColors.textHint,
            size: compact ? 10 : 11,
          ),
          const SizedBox(width: 4),
          Text(
            'Terminé',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall.copyWith(
              fontSize: compact ? 9.5 : 10.5,
              color: AppColors.textHint,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineMeta extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InlineMeta({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.textHint, size: 13),
        const SizedBox(width: 4),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodySmall.copyWith(
            fontSize: 10.5,
            color: AppColors.textHint,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _EmptyContestList extends StatelessWidget {
  const _EmptyContestList();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Text(
        'Aucun quiz ne correspond à ces filtres.',
        textAlign: TextAlign.center,
        style: AppTextStyles.bodySecondary,
      ),
    );
  }
}

class _ContestLoadError extends StatelessWidget {
  final VoidCallback onRetry;

  const _ContestLoadError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: AppCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Impossible de charger les quiz promotionnels.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySecondary,
              ),
              const SizedBox(height: 10),
              TextButton(onPressed: onRetry, child: const Text('Réessayer')),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatPrize(num value) {
  return formatCurrencyAmount(value);
}

String _shortDateTime(DateTime date) {
  return 'le ${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')} à '
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
}

String _winnerText(Contest contest) {
  return contest.winnersCount > 1
      ? '${contest.winnersCount} lauréats'
      : '1 lauréat';
}
