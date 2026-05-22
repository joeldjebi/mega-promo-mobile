import 'dart:async';

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

import '../../auth/providers/auth_provider.dart';
import '../../home/providers/user_profile_provider.dart';
import '../../live_quiz/services/live_quiz_service.dart';
import '../../rewards/services/badge_award_service.dart';
import '../../social/share_helpers.dart';
import '../models/contest.dart';
import '../providers/contest_providers.dart';
import '../widgets/contest_timer.dart';

class ContestDetailScreen extends ConsumerStatefulWidget {
  final String contestId;

  const ContestDetailScreen({super.key, required this.contestId});

  @override
  ConsumerState<ContestDetailScreen> createState() =>
      _ContestDetailScreenState();
}

class _ContestDetailScreenState extends ConsumerState<ContestDetailScreen> {
  RealtimeChannel? _refreshChannel;
  String? _currentUserId;

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(authStateProvider).value?.id;
    _syncRealtimeRefresh(userId);

    final detail = ref.watch(contestDetailProvider(widget.contestId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: detail.when(
        data: (data) => _ContestDetailBody(data: data),
        loading: () => const _ContestDetailShimmer(),
        error: (error, stackTrace) => _ContestDetailError(
          error: error,
          onRetry: () {
            clearContestDetailCache(widget.contestId);
            ref.invalidate(contestDetailProvider(widget.contestId));
          },
        ),
      ),
    );
  }

  void _syncRealtimeRefresh(String? userId) {
    if (_currentUserId == userId) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _currentUserId == userId) return;
      _subscribeRealtimeRefresh(userId);
    });
  }

  void _subscribeRealtimeRefresh(String? userId) {
    final supabase = ref.read(supabaseProvider);
    final previousChannel = _refreshChannel;
    if (previousChannel != null) {
      unawaited(supabase.removeChannel(previousChannel));
    }

    _refreshChannel = null;
    _currentUserId = userId;
    if (userId == null) return;

    void refreshContestState(PostgresChangePayload payload) {
      clearContestDetailCache(widget.contestId);
      ref
        ..invalidate(userProfileProvider)
        ..invalidate(contestsProvider)
        ..invalidate(contestDetailProvider(widget.contestId));
    }

    _refreshChannel = supabase
        .channel('contest-detail-refresh-${widget.contestId}-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'users',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: userId,
          ),
          callback: refreshContestState,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'participations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: refreshContestState,
        )
        .subscribe();
  }

  @override
  void dispose() {
    final channel = _refreshChannel;
    if (channel != null) {
      unawaited(Supabase.instance.client.removeChannel(channel));
    }
    super.dispose();
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

  bool get _isWaitingRoomOpen {
    final liveStartsAt = data.contest.liveStartsAt;
    if (liveStartsAt == null) return false;
    final now = DateTime.now();
    return now.isAfter(liveStartsAt.subtract(const Duration(minutes: 5))) &&
        now.isBefore(liveStartsAt);
  }

  bool get _canStartLiveQuiz {
    final liveStartsAt = data.contest.liveStartsAt;
    if (liveStartsAt == null) return false;
    final now = DateTime.now();
    return !now.isBefore(liveStartsAt) && now.isBefore(data.contest.endsAt);
  }

  String get _buttonText {
    if (_planAccessDenied) return 'Réservé ${data.contest.accessLabel}';
    if (data.contest.isLive) {
      if (data.contest.isLiveEnded) return 'Quiz Live terminé';
      if (!data.hasLiveRegistration) return 'Je m’inscris au Quiz Live';
      if (_isWaitingRoomOpen) return 'Entrer en salle d’attente';
      if (_canStartLiveQuiz) return 'Démarrer le Quiz Live';
      return 'Inscrit au Quiz Live';
    }
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

    if (data.contest.isLive) {
      if (data.contest.isLiveEnded) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ce Quiz Live est terminé.')),
        );
        return;
      }

      final supabase = Supabase.instance.client;
      try {
        if (!data.hasLiveRegistration) {
          await supabase.rpc(
            'register_live_quiz',
            params: {'p_contest_id': data.contest.id},
          );
          _refreshParticipationState(ref);
          if (!context.mounted) return;
          if (_isWaitingRoomOpen) {
            context.go('/contests/${data.contest.id}/live-waiting');
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Inscription au Quiz Live validée.')),
          );
          return;
        }

        if (_isWaitingRoomOpen) {
          await supabase.rpc(
            'join_live_quiz_waiting_room',
            params: {'p_contest_id': data.contest.id},
          );
          _refreshParticipationState(ref);
          if (!context.mounted) return;
          context.go('/contests/${data.contest.id}/live-waiting');
          return;
        }

        if (_canStartLiveQuiz) {
          final result = await startLiveQuizParticipation(data: data);
          _refreshParticipationState(ref);
          if (!context.mounted) return;
          context.go(
            '/contests/${data.contest.id}/quiz',
            extra: {'participationId': result.participationId},
          );
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reviens 5 minutes avant le début du Quiz Live.'),
          ),
        );
      } catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
      return;
    }

    if (data.contest.type == ContestType.quiz) {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      try {
        final participation = await supabase
            .from('participations')
            .insert({
              'user_id': user.id,
              'contest_id': data.contest.id,
              'score': 0,
              'answers': {
                'type': data.contest.type.name,
                'status': 'started',
                'started_at': DateTime.now().toIso8601String(),
              },
              'completed': false,
            })
            .select('id')
            .single();

        await supabase
            .from('users')
            .update({
              'participations_today': data.userProfile.participationsToday + 1,
              'last_participation_date': DateTime.now().toIso8601String().split(
                'T',
              )[0],
            })
            .eq('id', user.id);

        _refreshParticipationState(ref);
        if (!context.mounted) return;
        context.go(
          '/contests/${data.contest.id}/quiz',
          extra: {'participationId': participation['id'] as String},
        );
      } catch (_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Participation déjà enregistrée pour ce concours.'),
          ),
        );
        _refreshParticipationState(ref);
      }
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

    if (contest.isLiveEnded) {
      return _EndedLiveQuizDetail(data: data);
    }

    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              stretch: true,
              expandedHeight: 184,
              backgroundColor: AppColors.background,
              surfaceTintColor: Colors.transparent,
              leadingWidth: 62,
              leading: Padding(
                padding: const EdgeInsets.only(left: 14),
                child: _HeroActionButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Retour',
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/home');
                    }
                  },
                ),
              ),
              actions: [
                _HeroActionButton(
                  icon: Icons.refresh_rounded,
                  tooltip: 'Actualiser',
                  onPressed: () => _refreshParticipationState(ref),
                ),
                const SizedBox(width: 8),
                _HeroActionButton(
                  icon: Icons.share_rounded,
                  tooltip: 'Partager sur WhatsApp',
                  onPressed: () => _shareOnWhatsApp(context),
                ),
                const SizedBox(width: 14),
              ],
              flexibleSpace: FlexibleSpaceBar(
                stretchModes: const [
                  StretchMode.zoomBackground,
                  StretchMode.fadeTitle,
                ],
                background: _ContestHeroImage(contest: contest),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 110),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Row(
                    children: [
                      _TypeBadge(type: contest.type),
                      if (contest.allowedPlayerPlanKeys.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        _AccessBadge(label: contest.accessLabel),
                      ],
                      if (contest.brandLogoUrl?.isNotEmpty == true) ...[
                        const Spacer(),
                        Flexible(child: _ContestBrandLogoLine(contest: contest)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(contest.title, style: AppTextStyles.h1),
                  const SizedBox(height: 10),
                  Text(
                    _formatPrize(contest.prizeValue),
                    style: AppTextStyles.price,
                  ),
                  const SizedBox(height: 20),
                  AppCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _DetailStat(
                            icon: Icons.groups_rounded,
                            label: 'Participants',
                            value: '${data.participantsCount}',
                          ),
                        ),
                        const _StatDivider(),
                        Expanded(
                          child: _DetailStat(
                            icon: Icons.workspace_premium_rounded,
                            label: 'Gagnants',
                            value: '${contest.winnersCount}',
                          ),
                        ),
                        const _StatDivider(),
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
                  if (contest.isLive) ...[
                    const SizedBox(height: 14),
                    AppCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.bolt_rounded,
                            color: AppColors.accentGreen,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data.hasLiveRegistration
                                      ? 'Inscription confirmée'
                                      : 'Quiz Live',
                                  style: AppTextStyles.h3.copyWith(
                                    color: AppColors.accentGreen,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _liveQuizInfoText(contest),
                                  style: AppTextStyles.bodySecondary,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                  if (data.hasParticipated) ...[
                    const SizedBox(height: 14),
                    AppCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.accentGreen,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Déjà participé',
                                  style: AppTextStyles.h3.copyWith(
                                    color: AppColors.accentGreen,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Ta participation est enregistrée pour ce concours.',
                                  style: AppTextStyles.bodySecondary,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 26),
                  Text('Description', style: AppTextStyles.h2),
                  const SizedBox(height: 10),
                  AppCard(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      contest.description,
                      style: AppTextStyles.bodySecondary,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text('Le prix', style: AppTextStyles.h2),
                  const SizedBox(height: 10),
                  AppCard(
                    padding: const EdgeInsets.all(16),
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
          left: 20,
          right: 20,
          bottom: 18,
          child: SafeArea(
            top: false,
            child: AppButton(
              text: _buttonText,
              onPressed: _planAccessDenied ||
                      (!data.contest.isLive && _dailyLimitReached)
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

class _EndedLiveQuizDetail extends StatelessWidget {
  final ContestDetailData data;

  const _EndedLiveQuizDetail({required this.data});

  @override
  Widget build(BuildContext context) {
    final contest = data.contest;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: _HeroActionButton(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Retour',
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/home');
                  }
                },
              ),
            ),
            const Spacer(),
            Container(
              height: 170,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: AppColors.surfaceBorder),
                color: AppColors.surface,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _ContestHeroImage(contest: contest),
                    Container(color: Colors.black.withValues(alpha: 0.52)),
                    const Center(
                      child: Icon(
                        Icons.lock_clock_rounded,
                        color: AppColors.textSecondary,
                        size: 58,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Quiz Live terminé',
              textAlign: TextAlign.center,
              style: AppTextStyles.h1.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            Text(
              contest.title,
              textAlign: TextAlign.center,
              style: AppTextStyles.h3.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 18),
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    'Ce Quiz Live n’est plus accessible. Il reste visible quelques heures pour information, puis disparaîtra automatiquement de l’accueil.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySecondary,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _DetailStat(
                          icon: Icons.groups_rounded,
                          label: 'Inscrits',
                          value: '${contest.registeredCount}',
                        ),
                      ),
                      const _StatDivider(),
                      Expanded(
                        child: _DetailStat(
                          icon: Icons.workspace_premium_rounded,
                          label: 'Prix',
                          value: _formatPrize(contest.prizeValue),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Spacer(),
            AppButton(
              text: 'Retour à l’accueil',
              onPressed: () => context.go('/home'),
            ),
          ],
        ),
      ),
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
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    contest.type.color.withValues(alpha: 0.32),
                    AppColors.surface,
                    AppColors.background,
                  ],
                ),
              ),
              child: Center(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: AppColors.background.withValues(alpha: 0.42),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Icon(
                    contest.type.icon,
                    color: contest.type.color,
                    size: 48,
                  ),
                ),
              ),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.34),
                  Colors.transparent,
                  AppColors.background.withValues(alpha: 0.88),
                ],
                stops: const [0, 0.48, 1],
              ),
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
        if (_isSvg) {
          return Center(
            child: Container(
              width: (constraints.maxWidth * 0.54).clamp(140.0, 220.0),
              height: (constraints.maxHeight * 0.45).clamp(86.0, 128.0),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.surfaceBorder),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.16),
                    blurRadius: 34,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: SvgPicture.network(
                url,
                fit: BoxFit.contain,
                placeholderBuilder: (_) => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          );
        }

        return Image.network(
          url,
          fit: BoxFit.cover,
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          errorBuilder: (_, _, _) => const Center(
            child: Icon(
              Icons.image_not_supported_rounded,
              color: AppColors.textHint,
              size: 38,
            ),
          ),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          },
        );
      },
    );
  }
}

class _HeroActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _HeroActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: AppColors.background.withValues(alpha: 0.72),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Tooltip(
            message: tooltip,
            child: SizedBox(
              width: 42,
              height: 42,
              child: Icon(icon, color: AppColors.textPrimary, size: 22),
            ),
          ),
        ),
      ),
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

class _AccessBadge extends StatelessWidget {
  final String label;

  const _AccessBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.34)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_rounded, color: AppColors.gold, size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTextStyles.label.copyWith(
              color: AppColors.gold,
              fontSize: 11,
            ),
          ),
        ],
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

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 46,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: AppColors.surfaceBorder,
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
          _ShimmerBox(height: 184),
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

String _liveQuizInfoText(Contest contest) {
  final liveStartsAt = contest.liveStartsAt;
  if (liveStartsAt == null) {
    return 'L’heure de départ sera confirmée bientôt.';
  }

  final date =
      '${liveStartsAt.day.toString().padLeft(2, '0')}/'
      '${liveStartsAt.month.toString().padLeft(2, '0')}/${liveStartsAt.year}';
  final time =
      '${liveStartsAt.hour.toString().padLeft(2, '0')}:'
      '${liveStartsAt.minute.toString().padLeft(2, '0')}';

  return 'Départ le $date à $time. Salle d’attente ouverte 5 minutes avant. '
      '${contest.registeredCount} joueur(s) inscrit(s).';
}
