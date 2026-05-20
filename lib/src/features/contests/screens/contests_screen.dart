import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:mega_promo/core/theme/app_colors.dart';
import 'package:mega_promo/core/theme/app_text_styles.dart';
import 'package:mega_promo/core/widgets/app_card.dart';

import '../models/contest.dart';
import '../providers/contest_providers.dart';
import '../widgets/contest_timer.dart';

enum _ContestViewMode { list, grid }

class ContestsScreen extends ConsumerStatefulWidget {
  const ContestsScreen({super.key});

  @override
  ConsumerState<ContestsScreen> createState() => _ContestsScreenState();
}

class _ContestsScreenState extends ConsumerState<ContestsScreen> {
  ContestType? _selectedType;
  String? _selectedCategory;
  _ContestViewMode _viewMode = _ContestViewMode.list;

  @override
  Widget build(BuildContext context) {
    final contests = ref.watch(contestsProvider);
    final shuffleSeed = ref.watch(contestsShuffleSeedProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Concours'),
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
            ref.read(contestsShuffleSeedProvider.notifier).refresh();
            final refreshed = ref.refresh(contestsProvider.future);
            await refreshed;
          },
          child: contests.when(
            data: (items) {
              final categories = _categoryNames(items);
              final filtered = shuffleContestsForSession(
                _filterContests(items),
                shuffleSeed,
              );

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                children: [
                  Text(
                    'Tous les concours actifs',
                    style: AppTextStyles.h2.copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${filtered.length} concours disponible${filtered.length > 1 ? 's' : ''}',
                    style: AppTextStyles.bodySecondary.copyWith(fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  _TypeFilters(
                    selectedType: _selectedType,
                    onSelected: (type) => setState(() => _selectedType = type),
                  ),
                  if (categories.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _CategoryFilters(
                      categories: categories,
                      selectedCategory: _selectedCategory,
                      onSelected: (category) => setState(
                        () => _selectedCategory = category,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (filtered.isEmpty)
                    const _EmptyContestList()
                  else if (_viewMode == _ContestViewMode.grid)
                    _ContestGrid(contests: filtered)
                  else
                    _ContestList(contests: filtered),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => _ContestLoadError(
              onRetry: () => ref.invalidate(contestsProvider),
            ),
          ),
        ),
      ),
    );
  }

  List<Contest> _filterContests(List<Contest> contests) {
    return contests.where((contest) {
      final typeMatches = _selectedType == null || contest.type == _selectedType;
      final categoryMatches =
          _selectedCategory == null || contest.category == _selectedCategory;
      return typeMatches && categoryMatches;
    }).toList();
  }

  List<String> _categoryNames(List<Contest> contests) {
    final names = contests
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

class _TypeFilters extends StatelessWidget {
  final ContestType? selectedType;
  final ValueChanged<ContestType?> onSelected;

  const _TypeFilters({required this.selectedType, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final filters = <({String label, ContestType? type})>[
      (label: 'Tous', type: null),
      (label: 'Quiz', type: ContestType.quiz),
      (label: 'Tirage', type: ContestType.tirage),
      (label: 'Pronostic', type: ContestType.pronostic),
    ];

    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = selectedType == filter.type;
          return _FilterChipButton(
            label: filter.label,
            isSelected: isSelected,
            onTap: () => onSelected(filter.type),
          );
        },
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
            color: isSelected ? AppColors.primaryLight : AppColors.surfaceBorder,
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

class _ContestList extends StatelessWidget {
  final List<Contest> contests;

  const _ContestList({required this.contests});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: contests
          .map(
            (contest) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ListContestCard(contest: contest),
            ),
          )
          .toList(),
    );
  }
}

class _ContestGrid extends StatelessWidget {
  final List<Contest> contests;

  const _ContestGrid({required this.contests});

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
      itemBuilder: (context, index) => _GridContestCard(contest: contests[index]),
    );
  }
}

class _ListContestCard extends StatelessWidget {
  final Contest contest;

  const _ListContestCard({required this.contest});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.push('/contests/${contest.id}'),
      padding: const EdgeInsets.all(13),
      borderRadius: 18,
      child: Row(
        children: [
          _ContestIcon(contest: contest, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contest.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.h3.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatPrize(contest.prizeValue),
                  style: AppTextStyles.price.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _SmallBadge(label: contest.type.filterLabel),
                    const SizedBox(width: 8),
                    _InlineMeta(
                      icon: Icons.visibility_rounded,
                      label: '${contest.viewsCount}',
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: ContestTimer(endsAt: contest.endsAt)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GridContestCard extends StatelessWidget {
  final Contest contest;

  const _GridContestCard({required this.contest});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.push('/contests/${contest.id}'),
      padding: const EdgeInsets.all(12),
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ContestIcon(contest: contest, size: 40),
              const Spacer(),
              Icon(
                contest.type.icon,
                size: 17,
                color: contest.type.color,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            contest.title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.h3.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 6),
          Text(
            _formatPrize(contest.prizeValue),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.price.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 4),
          _InlineMeta(
            icon: Icons.visibility_rounded,
            label: '${contest.viewsCount} vues',
          ),
          const Spacer(),
          _SmallBadge(label: contest.type.filterLabel),
          const SizedBox(height: 8),
          ContestTimer(
            endsAt: contest.endsAt,
            style: AppTextStyles.bodySmall.copyWith(fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}

class _ContestIcon extends StatelessWidget {
  final Contest contest;
  final double size;

  const _ContestIcon({required this.contest, required this.size});

  @override
  Widget build(BuildContext context) {
    final logoUrl = contest.brandLogoUrl;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(logoUrl?.isNotEmpty == true ? 6 : 0),
      decoration: BoxDecoration(
        color: logoUrl?.isNotEmpty == true
            ? Colors.white
            : contest.type.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.surfaceBorder, width: 0.8),
      ),
      clipBehavior: Clip.antiAlias,
      child: logoUrl?.isNotEmpty == true
          ? _NetworkLogo(url: logoUrl!)
          : Icon(contest.type.icon, color: contest.type.color, size: size * 0.5),
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

  const _SmallBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
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
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
        ),
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
        'Aucun concours ne correspond à ces filtres.',
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
                'Impossible de charger les concours.',
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
  final rounded = value.round();
  if (rounded <= 0) return 'Prix surprise';
  return '$rounded FCFA';
}
