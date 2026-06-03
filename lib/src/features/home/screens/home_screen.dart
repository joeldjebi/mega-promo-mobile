import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mega_promo/core/theme/app_colors.dart';
import 'package:mega_promo/core/theme/app_text_styles.dart';
import 'package:mega_promo/core/utils/currency_formatter.dart';
import 'package:mega_promo/core/widgets/app_card.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/app_store_review_mode.dart';
import '../../app_update/services/app_update_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../contests/models/contest.dart';
import '../../contests/providers/contest_providers.dart';
import '../../contests/services/contest_asset_preload_service.dart';
import '../../contests/widgets/contest_timer.dart';
import '../../../services/synced_clock_service.dart';
import '../providers/home_bootstrap_provider.dart';
import '../providers/info_message_provider.dart';
import '../providers/user_profile_provider.dart';

const _homeBackgroundColor = AppColors.primary;
const _homeOnBackgroundColor = Colors.white;
const _homeTopBackgroundHeight = 352.0;
const _homeHeaderBackgroundHeight = 24.0;
const _homeCategoryBackgroundHeight = 122.0;
const _homeContentCornerRadius = 28.0;
const _homeAppBarHeight = 70.0;

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? _selectedCategoryId;
  Timer? _liveTicker;
  String? _preloadedContestAssetsKey;
  UserProfile? _lastProfile;
  List<Contest>? _lastContests;
  Set<String>? _lastParticipatedContestIds;
  Set<String>? _lastRegisteredLiveQuizIds;

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
      _lastProfile = bootstrapData.profile;
      _lastParticipatedContestIds = bootstrapData.participatedContestIds;
      _lastRegisteredLiveQuizIds = bootstrapData.registeredLiveQuizIds;
      if (realtimeItems == null) _lastContests = bootstrapData.contests;
    }
    if (realtimeItems != null) _lastContests = realtimeItems;

    final profile = _lastProfile == null
        ? bootstrap.whenData((data) => data.profile)
        : AsyncData(_lastProfile!);
    final contests = _lastContests == null
        ? realtimeContests
        : AsyncData(_lastContests!);
    final categories = ref.watch(categoriesProvider);
    final participatedAsync = ref.watch(userParticipatedContestIdsProvider);
    final registeredAsync = ref.watch(userRegisteredLiveQuizIdsProvider);
    final participatedValue = participatedAsync.asData?.value;
    final registeredValue = registeredAsync.asData?.value;
    if (participatedValue != null) {
      _lastParticipatedContestIds = participatedValue;
    }
    if (registeredValue != null) {
      _lastRegisteredLiveQuizIds = registeredValue;
    }
    final participatedContestIds =
        _lastParticipatedContestIds ?? const <String>{};
    final registeredLiveQuizIds =
        _lastRegisteredLiveQuizIds ?? const <String>{};
    final shuffleSeed = ref.watch(contestsShuffleSeedProvider);
    final infoMessages = ref.watch(infoMessagesProvider);
    final visibleCategories = _lastContests == null
        ? const <Category>[]
        : _categoriesWithContests(
            categories.value ?? const <Category>[],
            _lastContests!,
          );
    final hasLiveQuizInCurrentView = _hasLiveQuizForCurrentView(
      _lastContests,
      categories.value ?? const <Category>[],
      _selectedCategoryId,
    );
    final topBackgroundHeight = hasLiveQuizInCurrentView
        ? _homeTopBackgroundHeight
        : visibleCategories.isNotEmpty
        ? _homeCategoryBackgroundHeight
        : _homeHeaderBackgroundHeight;
    final contentBackgroundTop = hasLiveQuizInCurrentView
        ? topBackgroundHeight - _homeContentCornerRadius
        : topBackgroundHeight;

    return Scaffold(
      backgroundColor: _homeBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: _homeBackgroundColor,
        elevation: 0,
        toolbarHeight: _homeAppBarHeight,
        titleSpacing: 16,
        title: profile.when(
          data: (user) => _HomeHeader(user: user),
          loading: () => _lastContests == null
              ? const _HomeHeaderShimmer()
              : const _HomeHeaderFallback(),
          error: (error, stackTrace) => const _HomeHeaderError(),
        ),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: _homeBackgroundColor)),
          Positioned(
            top: contentBackgroundTop,
            left: 0,
            right: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(_homeContentCornerRadius),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: RefreshIndicator(
              onRefresh: () async {
                final userId = ref.read(currentUserIdProvider);
                clearHomeBootstrapCache(userId: userId, clearStored: true);
                ref
                  ..invalidate(homeBootstrapProvider)
                  ..invalidate(contestsProvider)
                  ..invalidate(userParticipatedContestIdsProvider)
                  ..invalidate(userRegisteredLiveQuizIdsProvider)
                  ..invalidate(categoriesProvider);
                ref.read(contestsShuffleSeedProvider.notifier).refresh();
                await Future.wait([
                  ref.refresh(homeBootstrapProvider.future),
                  ref.refresh(contestsProvider.future),
                ]);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                children: [
                  contests.when(
                    data: (items) {
                      _preloadContestAssets(items);
                      final availableCategories = _categoriesWithContests(
                        categories.value ?? const <Category>[],
                        items,
                      );
                      final effectiveCategoryId =
                          availableCategories.any(
                            (category) => category.id == _selectedCategoryId,
                          )
                          ? _selectedCategoryId
                          : null;
                      final filtered = effectiveCategoryId == null
                          ? items
                          : items
                                .where(
                                  (contest) =>
                                      _contestCategoryId(contest) ==
                                      effectiveCategoryId,
                                )
                                .toList();

                      if (items.isEmpty) return const _EmptyContestsState();
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
                                return b.computedLiveEndsAt.compareTo(
                                  a.computedLiveEndsAt,
                                );
                              }
                              final aDate =
                                  a.liveStartsAt ??
                                  a.startsAt ??
                                  a.computedLiveEndsAt;
                              final bDate =
                                  b.liveStartsAt ??
                                  b.startsAt ??
                                  b.computedLiveEndsAt;
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
                          if (availableCategories.isNotEmpty) ...[
                            _HomeCategoryFilters(
                              categories: availableCategories,
                              selectedCategoryId: effectiveCategoryId,
                              onSelected: (categoryId) => setState(
                                () => _selectedCategoryId = categoryId,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (liveQuizzes.isNotEmpty) ...[
                            Text(
                              'QUIZ LIVE',
                              style: AppTextStyles.label.copyWith(
                                color: _homeOnBackgroundColor,
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 214,
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final itemWidth = liveQuizzes.length == 1
                                      ? constraints.maxWidth
                                      : 318.0;
                                  return ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    clipBehavior: Clip.none,
                                    itemCount: liveQuizzes.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(width: 10),
                                    itemBuilder: (context, index) {
                                      final contest = liveQuizzes[index];
                                      return SizedBox(
                                        width: itemWidth,
                                        child: _LiveQuizCard(
                                          contest: contest,
                                          hasParticipated:
                                              participatedContestIds.contains(
                                                contest.id,
                                              ),
                                          isRegistered: registeredLiveQuizIds
                                              .contains(contest.id),
                                        ),
                                      );
                                    },
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
                                    child: _InfoMessageCarousel(
                                      messages: messages,
                                    ),
                                  ),
                            orElse: () => const SizedBox.shrink(),
                          ),
                          if (boosted.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            const _HomeSectionLabel('EN VEDETTE'),
                            const SizedBox(height: 10),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final textScale = MediaQuery.textScalerOf(
                                  context,
                                ).scale(1);
                                final featuredHeight =
                                    248.0 +
                                    (math.max(0.0, textScale - 1) * 172.0);
                                final itemWidth = boosted.length == 1
                                    ? constraints.maxWidth
                                    : 274.0;
                                return SizedBox(
                                  height: featuredHeight,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    clipBehavior: Clip.none,
                                    itemCount: boosted.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(width: 10),
                                    itemBuilder: (context, index) {
                                      return _FeaturedContestCard(
                                        width: itemWidth,
                                        contest: boosted[index],
                                        hasParticipated: participatedContestIds
                                            .contains(boosted[index].id),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 18),
                          ],
                          const _HomeSectionLabel('TOUS LES CONCOURS'),
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
                                padding: const EdgeInsets.symmetric(
                                  vertical: 13,
                                ),
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
                      onRetry: () => ref.invalidate(homeBootstrapProvider),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _preloadContestAssets(List<Contest> contests) {
    final key = contests.take(12).map((contest) => contest.id).join('|');
    if (key.isEmpty || key == _preloadedContestAssetsKey) return;
    _preloadedContestAssetsKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ContestAssetPreloadService.preloadContestImages(context, contests);
    });
  }
}

List<Category> _categoriesWithContests(
  List<Category> categories,
  List<Contest> contests,
) {
  final contestCategoryIds = contests
      .map(_contestCategoryId)
      .whereType<String>()
      .toSet();
  return categories
      .where((category) => contestCategoryIds.contains(category.id))
      .toList(growable: false);
}

bool _hasLiveQuizForCurrentView(
  List<Contest>? contests,
  List<Category> categories,
  String? selectedCategoryId,
) {
  if (contests == null || contests.isEmpty) return false;

  final availableCategories = _categoriesWithContests(categories, contests);
  final effectiveCategoryId =
      availableCategories.any((category) => category.id == selectedCategoryId)
      ? selectedCategoryId
      : null;
  final filtered = effectiveCategoryId == null
      ? contests
      : contests
            .where(
              (contest) => _contestCategoryId(contest) == effectiveCategoryId,
            )
            .toList(growable: false);

  return filtered.any((contest) => contest.isLiveVisibleOnHome);
}

String? _contestCategoryId(Contest contest) {
  return contest.categoryId ?? contest.categoryData?.id;
}

String _contestCategoryLabel(Contest contest) {
  final category = contest.category.trim();
  if (category.isNotEmpty && category.toLowerCase() != 'général') {
    return category;
  }
  return contest.type.filterLabel;
}

class _HomeCategoryFilters extends StatelessWidget {
  final List<Category> categories;
  final String? selectedCategoryId;
  final ValueChanged<String?> onSelected;

  const _HomeCategoryFilters({
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final filters = <Category?>[null, ...categories];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CATÉGORIES',
          style: AppTextStyles.label.copyWith(color: _homeOnBackgroundColor),
        ),
        const SizedBox(height: 9),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: filters.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final category = filters[index];
              final isSelected = category == null
                  ? selectedCategoryId == null
                  : selectedCategoryId == category.id;
              final accentColor = category?.color ?? AppColors.primary;

              return InkWell(
                onTap: () => onSelected(category?.id),
                borderRadius: BorderRadius.circular(999),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.black.withValues(alpha: 0.18)
                        : Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.74)
                          : Colors.white.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (category != null) ...[
                        Icon(
                          category.icon,
                          color: _homeOnBackgroundColor,
                          size: 15,
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        category?.name ?? 'Toutes',
                        style: AppTextStyles.bodySmall.copyWith(
                          fontSize: 10.8,
                          color: _homeOnBackgroundColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _HomeSectionLabel extends StatelessWidget {
  final String text;

  const _HomeSectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.surfaceBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            text,
            style: AppTextStyles.label.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
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
  PageController? _controller;
  int _controllerMessagesCount = 0;
  int _index = 0;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  PageController _pageController() {
    final messageCount = widget.messages.length;
    final viewportFraction = messageCount == 1 ? 1.0 : 0.94;
    if (_controller != null && _controllerMessagesCount == messageCount) {
      return _controller!;
    }

    _controller?.dispose();
    _controllerMessagesCount = messageCount;
    _controller = PageController(viewportFraction: viewportFraction);
    return _controller!;
  }

  @override
  Widget build(BuildContext context) {
    final controller = _pageController();
    return Column(
      children: [
        SizedBox(
          height: 118,
          child: PageView.builder(
            controller: controller,
            padEnds: false,
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
      final opened = await AppUpdateService.openCurrentPlatformStore();
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lien de mise à jour indisponible pour ce device.'),
          ),
        );
      }
      return;
    }

    if (target.startsWith('/')) {
      context.push(target);
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
  final double width;
  final Contest contest;
  final bool hasParticipated;

  const _FeaturedContestCard({
    this.width = 274,
    required this.contest,
    required this.hasParticipated,
  });

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final buttonHeight = 36.0 + (math.max(0.0, textScale - 1) * 8.0);

    return InkWell(
      onTap: () => context.push('/contests/${contest.id}'),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: width,
        padding: const EdgeInsets.all(12),
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
        child: LayoutBuilder(
          builder: (_, _) {
            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    primary: false,
                    physics: const ClampingScrollPhysics(),
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 5,
                          runSpacing: 5,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            hasParticipated
                                ? const _ParticipatedBadge()
                                : const _SponsoredBadge(),
                            if (contest.brandLogoUrl?.isNotEmpty == true)
                              _BrandLogo(url: contest.brandLogoUrl!, size: 24),
                            Container(
                              constraints: BoxConstraints(
                                maxWidth: math.min(width - 24, 178),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
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
                                    size: 11,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: ContestTimer(
                                      endsAt: contest.computedLiveEndsAt,
                                      style: AppTextStyles.bodySmall.copyWith(
                                        fontSize: 9.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          contest.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.h2.copyWith(
                            fontSize: 15.5,
                            height: 1.12,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _formatPrize(contest.prizeValue),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.price.copyWith(fontSize: 19.5),
                        ),
                        const SizedBox(height: 7),
                        Container(height: 1, color: AppColors.separator),
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            Expanded(
                              child: _FeaturedMeta(
                                icon: Icons.visibility_rounded,
                                value: '${contest.viewsCount} vues',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: _FeaturedMeta(
                                icon: Icons.workspace_premium_rounded,
                                value: '${contest.winnersCount} gagnants',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Fin ${_shortDateTime(contest.computedLiveEndsAt)} · ${_winnerText(contest)} après la fin',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  height: buttonHeight,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: hasParticipated
                          ? AppColors.surfaceBorder
                          : AppColors.primary,
                      borderRadius: BorderRadius.circular(13),
                      border: hasParticipated
                          ? Border.all(color: AppColors.separator)
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        hasParticipated
                            ? 'Déjà joué · Voir détails'
                            : 'Participer',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.button.copyWith(
                          color: hasParticipated
                              ? AppColors.textSecondary
                              : Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

int _liveQuizHomeRank(Contest contest) {
  if (contest.isLiveActiveNow) return 0;
  if (contest.isLiveWaitingStatus) return 1;
  if (contest.isLiveEnded) return 3;
  return 2;
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
    final isWaiting = contest.isLiveWaitingStatus;
    final isQueued = contest.isLiveQueued;
    final isDisabledPreview = isEnded || isQueued;
    final statusColor = isEnded
        ? AppColors.textHint
        : isActiveNow
        ? AppColors.accentGreen
        : isWaiting
        ? AppColors.primary
        : isQueued
        ? AppColors.textHint
        : AppColors.primary;
    final statusText = isEnded
        ? 'TERMINÉ'
        : isActiveNow
        ? 'EN DIRECT'
        : isWaiting
        ? 'PROCHAIN QL'
        : isQueued
        ? 'EN ATTENTE'
        : 'À VENIR';
    final startsLabel = liveStartsAt == null
        ? 'Heure à confirmer'
        : '${liveStartsAt.hour.toString().padLeft(2, '0')}:'
              '${liveStartsAt.minute.toString().padLeft(2, '0')}';

    return InkWell(
      onTap: isEnded ? null : () => context.push('/contests/${contest.id}'),
      borderRadius: BorderRadius.circular(24),
      child: Opacity(
        opacity: isDisabledPreview ? 0.68 : 1,
        child: Container(
          decoration: BoxDecoration(
            color: isDisabledPreview
                ? AppColors.surface
                : AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDisabledPreview ? AppColors.surfaceBorder : statusColor,
              width: isDisabledPreview ? 1.5 : 3,
            ),
            boxShadow: isDisabledPreview
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
                    alpha: isDisabledPreview ? 0.025 : 0.08,
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
                          _CategoryBadge(label: _contestCategoryLabel(contest)),
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
                              color: isDisabledPreview
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
                            color: isDisabledPreview
                                ? AppColors.surfaceElevated.withValues(
                                    alpha: 0.72,
                                  )
                                : AppColors.accent,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isDisabledPreview
                                  ? AppColors.textHint.withValues(alpha: 0.18)
                                  : AppColors.primary.withValues(alpha: 0.18),
                            ),
                          ),
                          child: Icon(
                            Icons.sports_esports_rounded,
                            color: isDisabledPreview
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
                                  color: isDisabledPreview
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
                                      muted: isDisabledPreview,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  _LiveQuizMetaChip(
                                    icon: Icons.groups_rounded,
                                    label:
                                        '${contest.registeredCount} inscrit${contest.registeredCount > 1 ? 's' : ''}',
                                    muted: isDisabledPreview,
                                  ),
                                ],
                              ),
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
                        color: isDisabledPreview
                            ? AppColors.surfaceElevated.withValues(alpha: 0.70)
                            : AppColors.accent.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(17),
                        border: Border.all(
                          color: isDisabledPreview
                              ? AppColors.surfaceBorder
                              : AppColors.primary.withValues(alpha: 0.16),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isDisabledPreview
                                ? Icons.history_toggle_off_rounded
                                : Icons.timer_rounded,
                            color: isDisabledPreview
                                ? AppColors.textHint
                                : AppColors.gold,
                            size: 17,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: isEnded
                                ? Text(
                                    'Terminé',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  )
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      liveStartsAt == null
                                          ? Text(
                                              'Départ bientôt',
                                              style: AppTextStyles.bodySmall,
                                            )
                                          : _LiveQuizStartsCountdown(
                                              startsAt: liveStartsAt,
                                            ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Fin ${_shortDateTime(contest.computedLiveEndsAt)} · ${_winnerText(contest)} après',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTextStyles.bodySmall.copyWith(
                                          color: AppColors.textSecondary,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
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
                                isDisabledPreview
                                    ? 'Voir détails'
                                    : isRegistered
                                    ? 'Entrer'
                                    : 'Réserver',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: isDisabledPreview
                                      ? AppColors.textSecondary
                                      : AppColors.primaryDark,
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
    final participantsCount = contest.participantsCount;
    final hasLimit = contest.maxParticipants > 0;
    final now = SyncedClockService.now();
    final startsAt = contest.startsAt ?? now;
    final totalDuration = contest.computedLiveEndsAt
        .difference(startsAt)
        .inSeconds;
    final elapsedDuration = now.difference(startsAt).inSeconds;
    final timeProgress = totalDuration <= 0
        ? 1.0
        : (elapsedDuration / totalDuration).clamp(0.0, 1.0);
    final progress = hasLimit
        ? (participantsCount / contest.maxParticipants).clamp(0.0, 1.0)
        : timeProgress;
    final progressLabel = hasLimit
        ? '$participantsCount / ${contest.maxParticipants} joueurs'
        : '${(timeProgress * 100).round()}%';

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
                    _CategoryBadge(label: _contestCategoryLabel(contest)),
                  const SizedBox(height: 8),
                  ContestTimer(endsAt: contest.computedLiveEndsAt),
                ],
              ),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(
                child: _ScheduleLine(
                  icon: Icons.event_available_rounded,
                  text: 'Fin ${_shortDateTime(contest.computedLiveEndsAt)}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ScheduleLine(
                  icon: Icons.emoji_events_rounded,
                  text: '${_winnerText(contest)} après',
                ),
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

class _ScheduleLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ScheduleLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textHint, size: 13),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textHint,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
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
    final remaining = widget.startsAt.difference(SyncedClockService.now());
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
  if (AppStoreReviewMode.hideCashAmounts) {
    return 'Récompense partenaire';
  }
  return formatCurrencyAmount(value);
}

String _shortDateTime(DateTime date) {
  return 'le ${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')} à '
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
}

String _winnerText(Contest contest) {
  if (AppStoreReviewMode.enabled) {
    return contest.winnersCount > 1
        ? '${contest.winnersCount} récompenses'
        : '1 récompense';
  }
  return contest.winnersCount > 1
      ? '${contest.winnersCount} vainqueurs'
      : '1 vainqueur';
}

String _homeGreeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Bonjour';
  if (hour < 18) return 'Bon après-midi';
  return 'Bonsoir';
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
                _homeGreeting(),
                style: AppTextStyles.bodySecondary.copyWith(
                  color: _homeOnBackgroundColor.withValues(alpha: 0.82),
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                user.username,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.h1.copyWith(
                  color: _homeOnBackgroundColor,
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _ShimmerBlock(width: 78, height: 13),
                SizedBox(height: 7),
                _ShimmerBlock(width: 150, height: 24),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const _ShimmerBlock(width: 70, height: 38),
          const SizedBox(width: 10),
          const _ShimmerCircle(size: 39),
        ],
      ),
    );
  }
}

class _HomeHeaderFallback extends StatelessWidget {
  const _HomeHeaderFallback();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _homeGreeting(),
                style: AppTextStyles.bodySecondary.copyWith(
                  color: _homeOnBackgroundColor.withValues(alpha: 0.82),
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                'MegaPromo',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.h1.copyWith(
                  color: _homeOnBackgroundColor,
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 39,
          height: 39,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.26)),
          ),
          child: const Icon(
            Icons.person_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
      ],
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
