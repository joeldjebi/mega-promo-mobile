import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mega_promo/core/theme/app_colors.dart';
import 'package:mega_promo/core/theme/app_text_styles.dart';
import 'package:mega_promo/core/widgets/app_button.dart';
import 'package:mega_promo/core/widgets/app_card.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../home/providers/user_profile_provider.dart';
import '../../rewards/services/badge_award_service.dart';
import '../../social/share_helpers.dart';
import '../models/contest.dart';
import '../providers/contest_providers.dart';
import '../widgets/contest_timer.dart';

class ContestDetailScreen extends ConsumerWidget {
  final String contestId;

  const ContestDetailScreen({super.key, required this.contestId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(contestDetailProvider(contestId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: detail.when(
        data: (data) => _ContestDetailBody(data: data),
        loading: () => const _ContestDetailShimmer(),
        error: (error, stackTrace) => _ContestDetailError(
          error: error,
          onRetry: () {
            clearContestDetailCache(contestId);
            ref.invalidate(contestDetailProvider(contestId));
          },
        ),
      ),
    );
  }
}

class _ContestDetailBody extends ConsumerWidget {
  final ContestDetailData data;

  const _ContestDetailBody({required this.data});

  bool get _dailyLimitReached =>
      data.userProfile.participationsToday >=
      data.userProfile.dailyParticipationLimit;

  bool get _planAccessDenied =>
      !data.contest.isAccessibleForPlan(data.userProfile.planKey);

  String get _buttonText {
    if (_planAccessDenied) return 'Réservé ${data.contest.accessLabel}';
    if (data.hasParticipated) return 'Déjà participé · Actualiser';
    if (_dailyLimitReached) {
      return 'Limite ${data.userProfile.dailyParticipationLimit}/jour atteinte';
    }
    return 'Participer';
  }

  void _refreshParticipationState(WidgetRef ref) {
    clearContestDetailCache(data.contest.id);
    ref.invalidate(userProfileProvider);
    ref.invalidate(contestDetailProvider(data.contest.id));
  }

  Future<void> _shareOnWhatsApp(BuildContext context) async {
    try {
      await shareContest(
        contest: data.contest,
        participantsCount: data.participantsCount,
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d’ouvrir le partage.')),
      );
    }
  }

  Future<void> _participate(BuildContext context, WidgetRef ref) async {
    if (_planAccessDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ce concours est réservé aux joueurs ${data.contest.accessLabel}.',
          ),
        ),
      );
      return;
    }

    if (data.contest.type == ContestType.quiz) {
      context.go('/contests/${data.contest.id}/quiz');
      return;
    }

    if (data.contest.type == ContestType.pronostic) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (context) =>
            _PredictionParticipationSheet(data: data, ref: ref),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _DrawParticipationSheet(data: data, ref: ref),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contest = data.contest;

    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 132,
              backgroundColor: AppColors.background,
              leading: IconButton(
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/home');
                  }
                },
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              actions: [
                IconButton(
                  onPressed: () => _refreshParticipationState(ref),
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Actualiser',
                ),
                IconButton(
                  onPressed: () => _shareOnWhatsApp(context),
                  icon: const Icon(Icons.share_rounded),
                  tooltip: 'Partager sur WhatsApp',
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: _ContestHeroImage(contest: contest),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 110),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _TypeBadge(type: contest.type),
                  if (contest.brandLogoUrl?.isNotEmpty == true) ...[
                    const SizedBox(height: 12),
                    _ContestBrandLogoLine(contest: contest),
                  ],
                  const SizedBox(height: 16),
                  Text(contest.title, style: AppTextStyles.h1),
                  const SizedBox(height: 10),
                  Text(
                    _formatPrize(contest.prizeValue),
                    style: AppTextStyles.price,
                  ),
                  const SizedBox(height: 24),
                  AppCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _DetailStat(
                            icon: Icons.groups_rounded,
                            label: 'Participants',
                            value: '${data.participantsCount}',
                          ),
                        ),
                        Expanded(
                          child: _DetailStat(
                            icon: Icons.workspace_premium_rounded,
                            label: 'Gagnants',
                            value: '${contest.winnersCount}',
                          ),
                        ),
                        Expanded(
                          child: _DetailStat(
                            icon: Icons.schedule_rounded,
                            label: 'Temps',
                            child: ContestTimer(endsAt: contest.endsAt),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_planAccessDenied) ...[
                    const SizedBox(height: 14),
                    AppCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.lock_rounded, color: AppColors.gold),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Ce concours est réservé aux joueurs ${contest.accessLabel}. Ton forfait actuel est ${data.userProfile.planName}.',
                              style: AppTextStyles.bodySecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 26),
                  Text('Description', style: AppTextStyles.h2),
                  const SizedBox(height: 10),
                  Text(contest.description, style: AppTextStyles.bodySecondary),
                  const SizedBox(height: 26),
                  Text('Le prix', style: AppTextStyles.h2),
                  const SizedBox(height: 10),
                  AppCard(
                    child: Text(
                      contest.prizeDescription.isEmpty
                          ? 'Prix surprise offert par la marque partenaire.'
                          : contest.prizeDescription,
                      style: AppTextStyles.body,
                    ),
                  ),
                  const SizedBox(height: 30),
                ]),
              ),
            ),
          ],
        ),
        Positioned(
          left: 24,
          right: 24,
          bottom: 18,
          child: SafeArea(
            top: false,
            child: AppButton(
              text: _buttonText,
              onPressed: _planAccessDenied || _dailyLimitReached
                  ? null
                  : data.hasParticipated
                  ? () => _refreshParticipationState(ref)
                  : () => _participate(context, ref),
            ),
          ),
        ),
      ],
    );
  }
}

class _DrawParticipationSheet extends ConsumerStatefulWidget {
  final ContestDetailData data;
  final WidgetRef ref;

  const _DrawParticipationSheet({required this.data, required this.ref});

  @override
  ConsumerState<_DrawParticipationSheet> createState() =>
      _DrawParticipationSheetState();
}

class _DrawParticipationSheetState
    extends ConsumerState<_DrawParticipationSheet> {
  bool _isSaving = false;
  bool _isDone = false;

  Future<void> _confirm() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);
    try {
      final tickets = _drawTickets(widget.data);
      await supabase.from('participations').insert({
        'user_id': user.id,
        'contest_id': widget.data.contest.id,
        'score': 0,
        'answers': {'type': widget.data.contest.type.name, 'tickets': tickets},
        'completed': true,
      });

      await supabase
          .from('users')
          .update({
            'participations_today':
                widget.data.userProfile.participationsToday + 1,
            'last_participation_date': DateTime.now().toIso8601String().split(
              'T',
            )[0],
          })
          .eq('id', user.id);

      await awardBadgesAfterParticipation(
        supabase: supabase,
        profile: widget.data.userProfile,
        nextParticipationsToday:
            widget.data.userProfile.participationsToday + 1,
        nextPointsTotal: widget.data.userProfile.pointsTotal,
      );

      widget.ref.invalidate(userProfileProvider);
      clearContestDetailCache(widget.data.contest.id);
      widget.ref.invalidate(contestDetailProvider(widget.data.contest.id));

      if (mounted) setState(() => _isDone = true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Participation impossible. Réessaie.')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tickets = _drawTickets(widget.data);
    final confirmationMessage =
        widget.data.drawSettings?.confirmationMessage ??
        'Les gagnants seront annoncés le ${_shortDate(widget.data.contest.endsAt)}.';
    final winnerDate =
        widget.data.drawSettings?.winnerAnnouncementAt ??
        widget.data.contest.endsAt;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isDone ? AppColors.primary : AppColors.gold,
              ),
              child: Icon(
                _isDone
                    ? Icons.auto_awesome_rounded
                    : Icons.card_giftcard_rounded,
                color: AppColors.textPrimary,
                size: 42,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              _isDone ? 'Tu participes !' : 'Participer au tirage',
              style: AppTextStyles.h2,
            ),
            const SizedBox(height: 10),
            Text(
              _isDone
                  ? confirmationMessage
                  : widget.data.contest.prizeDescription,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySecondary,
            ),
            if (!_isDone && widget.data.drawSettings?.rules.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  widget.data.drawSettings!.rules,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall,
                ),
              ),
            const SizedBox(height: 18),
            AppCard(
              child: Text(
                'Tu auras $tickets ticket${tickets > 1 ? 's' : ''}',
                textAlign: TextAlign.center,
                style: AppTextStyles.h3,
              ),
            ),
            if (!_isDone)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'Annonce prévue le ${_shortDate(winnerDate)}',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall,
                ),
              ),
            const SizedBox(height: 18),
            if (!_isDone)
              AppButton(
                text: 'Confirmer ma participation',
                isLoading: _isSaving,
                onPressed: _isSaving ? null : _confirm,
              )
            else
              AppButton(text: 'Fermer', onPressed: () => context.pop()),
          ],
        ),
      ),
    );
  }
}

int _drawTickets(ContestDetailData data) {
  final baseTickets = data.drawSettings?.standardTickets ?? 1;
  return baseTickets + data.userProfile.bonusTickets;
}

class _PredictionParticipationSheet extends ConsumerStatefulWidget {
  final ContestDetailData data;
  final WidgetRef ref;

  const _PredictionParticipationSheet({required this.data, required this.ref});

  @override
  ConsumerState<_PredictionParticipationSheet> createState() =>
      _PredictionParticipationSheetState();
}

class _PredictionParticipationSheetState
    extends ConsumerState<_PredictionParticipationSheet> {
  final _homeScoreController = TextEditingController();
  final _awayScoreController = TextEditingController();
  bool _isSaving = false;
  bool _isDone = false;

  @override
  void dispose() {
    _homeScoreController.dispose();
    _awayScoreController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final prediction = widget.data.prediction;
    final homeScore = int.tryParse(_homeScoreController.text.trim());
    final awayScore = int.tryParse(_awayScoreController.text.trim());

    if (prediction == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ce pronostic n’est pas encore configuré.'),
        ),
      );
      return;
    }

    if (!prediction.isOpen) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ce pronostic est fermé.')));
      return;
    }

    if (homeScore == null ||
        awayScore == null ||
        homeScore < 0 ||
        awayScore < 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Entre un score valide.')));
      return;
    }

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);
    try {
      await supabase.from('participations').insert({
        'user_id': user.id,
        'contest_id': widget.data.contest.id,
        'score': 0,
        'answers': {
          'type': 'pronostic',
          'match': prediction.matchLabel,
          'home_team': prediction.homeTeam,
          'away_team': prediction.awayTeam,
          'predicted_home_score': homeScore,
          'predicted_away_score': awayScore,
          'predicted_score': '$homeScore-$awayScore',
        },
        'completed': true,
      });

      await supabase
          .from('users')
          .update({
            'participations_today':
                widget.data.userProfile.participationsToday + 1,
            'last_participation_date': DateTime.now().toIso8601String().split(
              'T',
            )[0],
          })
          .eq('id', user.id);

      await awardBadgesAfterParticipation(
        supabase: supabase,
        profile: widget.data.userProfile,
        nextParticipationsToday:
            widget.data.userProfile.participationsToday + 1,
        nextPointsTotal: widget.data.userProfile.pointsTotal,
      );

      widget.ref.invalidate(userProfileProvider);
      clearContestDetailCache(widget.data.contest.id);
      widget.ref.invalidate(contestDetailProvider(widget.data.contest.id));

      if (mounted) setState(() => _isDone = true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pronostic impossible. Réessaie.')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prediction = widget.data.prediction;
    final homeTeam = prediction?.homeTeam ?? 'Equipe 1';
    final awayTeam = prediction?.awayTeam ?? 'Equipe 2';
    final isConfigured = prediction != null;
    final isOpen = prediction?.isOpen ?? false;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.of(context).viewInsets.bottom + 18,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 76,
                height: 76,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _isDone
                      ? AppColors.accentGreen.withValues(alpha: 0.16)
                      : AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: Icon(
                  _isDone ? Icons.check_rounded : Icons.sports_soccer_rounded,
                  color: _isDone ? AppColors.accentGreen : AppColors.primary,
                  size: 34,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _isDone ? 'Pronostic enregistré !' : 'Ton pronostic',
                textAlign: TextAlign.center,
                style: AppTextStyles.h2,
              ),
              const SizedBox(height: 8),
              Text(
                prediction?.matchLabel.isNotEmpty == true
                    ? prediction!.matchLabel
                    : widget.data.contest.title,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySecondary,
              ),
              if (prediction?.matchDate != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Match le ${_shortDate(prediction!.matchDate!)}',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySmall,
                  ),
                ),
              const SizedBox(height: 18),
              AppCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        homeTeam,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.h3,
                      ),
                    ),
                    Text('vs', style: AppTextStyles.bodySecondary),
                    Expanded(
                      child: Text(
                        awayTeam,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.h3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (!_isDone) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _homeScoreController,
                        enabled: isConfigured && isOpen,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(labelText: homeTeam),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _awayScoreController,
                        enabled: isConfigured && isOpen,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(labelText: awayTeam),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  isConfigured
                      ? isOpen
                            ? 'Score exact : ${prediction.pointsExactScore} pts · Bon résultat : ${prediction.pointsCorrectResult} pts'
                            : 'Ce pronostic est actuellement fermé.'
                      : 'Ce jeu n’est pas encore configuré par MegaPromo.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: 18),
                AppButton(
                  text: 'Valider mon pronostic',
                  isLoading: _isSaving,
                  onPressed: isConfigured && isOpen && !_isSaving
                      ? _confirm
                      : null,
                ),
              ] else ...[
                Text(
                  'Tu as joué $homeTeam ${_homeScoreController.text}-${_awayScoreController.text} $awayTeam.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body,
                ),
                const SizedBox(height: 18),
                AppButton(text: 'Fermer', onPressed: () => context.pop()),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ContestHeroImage extends StatelessWidget {
  final Contest contest;

  const _ContestHeroImage({required this.contest});

  @override
  Widget build(BuildContext context) {
    final hasImage = contest.imageUrl != null && contest.imageUrl!.isNotEmpty;
    final imageUrl = contest.imageUrl ?? '';

    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.surface),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasImage)
            _NetworkPromoImage(url: imageUrl)
          else
            Center(
              child: Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: Icon(
                  contest.type.icon,
                  color: AppColors.primary,
                  size: 42,
                ),
              ),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
        ],
      ),
    );
  }
}

class _NetworkPromoImage extends StatelessWidget {
  final String url;

  const _NetworkPromoImage({required this.url});

  bool get _isSvg {
    final cleanUrl = url.split('?').first.toLowerCase();
    return cleanUrl.endsWith('.svg');
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxImageWidth = (constraints.maxWidth * 0.5)
            .clamp(104.0, 180.0)
            .toDouble();
        final maxImageHeight = (constraints.maxHeight * 0.56)
            .clamp(60.0, 94.0)
            .toDouble();

        return Center(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: maxImageWidth,
              maxHeight: maxImageHeight,
            ),
            padding: EdgeInsets.all(_isSvg ? 12 : 0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            clipBehavior: Clip.antiAlias,
            child: _isSvg
                ? SvgPicture.network(
                    url,
                    fit: BoxFit.contain,
                    placeholderBuilder: (_) => const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Center(
                      child: Icon(
                        Icons.image_not_supported_rounded,
                        color: AppColors.textHint,
                        size: 34,
                      ),
                    ),
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      );
                    },
                  ),
          ),
        );
      },
    );
  }
}

class _ContestBrandLogoLine extends StatelessWidget {
  final Contest contest;

  const _ContestBrandLogoLine({required this.contest});

  @override
  Widget build(BuildContext context) {
    final logoUrl = contest.brandLogoUrl;
    if (logoUrl == null || logoUrl.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _BrandLogoImage(url: logoUrl, size: 38),
        if (contest.brandName?.trim().isNotEmpty == true) ...[
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              contest.brandName!.trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _BrandLogoImage extends StatelessWidget {
  final String url;
  final double size;

  const _BrandLogoImage({required this.url, required this.size});

  bool get _isSvg => url.split('?').first.toLowerCase().endsWith('.svg');

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.surfaceBorder, width: 0.8),
      ),
      clipBehavior: Clip.antiAlias,
      child: _isSvg
          ? SvgPicture.network(url, fit: BoxFit.contain)
          : Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Icon(
                Icons.business_rounded,
                color: AppColors.textHint,
                size: 18,
              ),
            ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final ContestType type;

  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: type.color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: type.color.withValues(alpha: 0.38)),
        ),
        child: Text(
          type.label,
          style: AppTextStyles.label.copyWith(color: type.color),
        ),
      ),
    );
  }
}

class _DetailStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final Widget? child;

  const _DetailStat({
    required this.icon,
    required this.label,
    this.value,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primaryLight, size: 20),
        const SizedBox(height: 8),
        Text(label, style: AppTextStyles.bodySmall),
        const SizedBox(height: 4),
        child ?? Text(value ?? '-', style: AppTextStyles.h3),
      ],
    );
  }
}

class _ContestDetailShimmer extends StatelessWidget {
  const _ContestDetailShimmer();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceElevated,
      highlightColor: AppColors.surfaceBorder,
      child: ListView(
        padding: EdgeInsets.zero,
        children: const [
          _ShimmerBox(height: 180),
          Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ShimmerBox(width: 92, height: 30),
                SizedBox(height: 16),
                _ShimmerBox(width: double.infinity, height: 34),
                SizedBox(height: 14),
                _ShimmerBox(width: 130, height: 28),
                SizedBox(height: 24),
                _ShimmerBox(width: double.infinity, height: 96),
                SizedBox(height: 24),
                _ShimmerBox(width: double.infinity, height: 120),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContestDetailError extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _ContestDetailError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: AppCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Impossible de charger ce concours.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySecondary,
                ),
                const SizedBox(height: 8),
                Text(
                  '$error',
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: 12),
                TextButton(onPressed: onRetry, child: const Text('Réessayer')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  final double? width;
  final double height;

  const _ShimmerBox({this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

String _formatPrize(num value) {
  final rounded = value.round();
  if (rounded <= 0) return 'Prix surprise';
  return '$rounded FCFA';
}

String _shortDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}
