import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mega_promo/core/theme/app_colors.dart';
import 'package:mega_promo/core/theme/app_text_styles.dart';
import 'package:mega_promo/core/utils/currency_formatter.dart';
import 'package:mega_promo/core/widgets/app_button.dart';
import 'package:mega_promo/core/widgets/app_card.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/app_store_review_mode.dart';
import '../../auth/providers/auth_provider.dart';
import '../../home/providers/home_bootstrap_provider.dart';
import '../../home/providers/user_profile_provider.dart';
import '../../live_quiz/services/live_quiz_service.dart';
import '../../rewards/services/badge_award_service.dart';
import '../../../services/app_telemetry_service.dart';
import '../../../services/app_logger.dart';
import '../../../services/live_quiz_notification_service.dart';
import '../../../services/device_session_service.dart';
import '../../../services/network_status_service.dart';
import '../../../services/synced_clock_service.dart';
import '../../settings/providers/app_feature_flags_provider.dart';
import '../../social/share_helpers.dart';
import '../models/contest.dart';
import '../providers/contest_providers.dart';
import '../services/contest_asset_preload_service.dart';
import '../widgets/contest_timer.dart';

class ContestDetailScreen extends ConsumerStatefulWidget {
  final String contestId;

  const ContestDetailScreen({super.key, required this.contestId});

  @override
  ConsumerState<ContestDetailScreen> createState() =>
      _ContestDetailScreenState();
}

class _ContestDetailScreenState extends ConsumerState<ContestDetailScreen>
    with WidgetsBindingObserver {
  RealtimeChannel? _refreshChannel;
  String? _currentUserId;
  Timer? _liveTicker;
  DateTime? _backgroundedAt;
  late final DateTime _openedAt;
  String? _preloadedContestAssetId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _openedAt = DateTime.now();
    unawaited(
      AppTelemetryService.setScreen(
        'ContestDetailScreen',
        parameters: {'contest_id': widget.contestId},
      ),
    );
    unawaited(AppTelemetryService.setContext({'contest_id': widget.contestId}));
    _liveTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(appFeatureFlagsProvider);
    final userId = ref.watch(authStateProvider).value?.id;
    _syncRealtimeRefresh(userId);

    final detail = ref.watch(contestDetailProvider(widget.contestId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: detail.when(
        data: (data) {
          if (_isHiddenForAppStoreReview(data.contest)) {
            return const _CampaignUnavailableForStore();
          }
          _preloadContestAssets(data.contest);
          return _ContestDetailBody(data: data);
        },
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

  void _preloadContestAssets(Contest contest) {
    if (_preloadedContestAssetId == contest.id) return;
    _preloadedContestAssetId = contest.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ContestAssetPreloadService.preloadContestImage(context, contest);
    });
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
      clearHomeBootstrapCache(
        userId: ref.read(currentUserIdProvider),
        clearStored: true,
      );
      ref
        ..invalidate(userProfileProvider)
        ..invalidate(homeBootstrapProvider)
        ..invalidate(contestsProvider)
        ..invalidate(userParticipatedContestIdsProvider)
        ..invalidate(userRegisteredLiveQuizIdsProvider)
        ..invalidate(contestDetailProvider(widget.contestId));
    }

    void refreshUserIfMeaningful(PostgresChangePayload payload) {
      const ignoredKeys = {
        'active_device_session_id',
        'active_device_info',
        'active_device_seen_at',
        'device_info',
        'device_location',
        'device_last_seen_at',
        'updated_at',
        'fcm_token',
      };
      if (!_hasMeaningfulRealtimeChange(payload, ignoredKeys: ignoredKeys)) {
        return;
      }
      refreshContestState(payload);
    }

    void refreshContestIfMeaningful(PostgresChangePayload payload) {
      if (DateTime.now().difference(_openedAt) < const Duration(seconds: 3)) {
        return;
      }
      const ignoredKeys = {'views_count', 'unique_views_count', 'updated_at'};
      if (!_hasMeaningfulRealtimeChange(payload, ignoredKeys: ignoredKeys)) {
        return;
      }
      refreshContestState(payload);
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
          callback: refreshUserIfMeaningful,
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
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'contests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.contestId,
          ),
          callback: refreshContestIfMeaningful,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'live_quiz_registrations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'contest_id',
            value: widget.contestId,
          ),
          callback: refreshContestState,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'live_sessions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'contest_id',
            value: widget.contestId,
          ),
          callback: refreshContestState,
        )
        .subscribe();
  }

  bool _hasMeaningfulRealtimeChange(
    PostgresChangePayload payload, {
    required Set<String> ignoredKeys,
  }) {
    final oldRecord = payload.oldRecord;
    final newRecord = payload.newRecord;
    if (oldRecord.isEmpty || newRecord.isEmpty) return true;

    return newRecord.keys.any((key) {
      if (ignoredKeys.contains(key)) return false;
      return oldRecord[key] != newRecord[key];
    });
  }

  void _refreshDetailState() {
    clearContestDetailCache(widget.contestId);
    clearHomeBootstrapCache(
      userId: ref.read(currentUserIdProvider),
      clearStored: true,
    );
    ref
      ..invalidate(userProfileProvider)
      ..invalidate(homeBootstrapProvider)
      ..invalidate(contestsProvider)
      ..invalidate(userParticipatedContestIdsProvider)
      ..invalidate(userRegisteredLiveQuizIdsProvider)
      ..invalidate(contestDetailProvider(widget.contestId));
  }

  void _resubscribeRealtimeRefresh() {
    final userId = _currentUserId;
    if (userId == null) return;
    _currentUserId = null;
    _subscribeRealtimeRefresh(userId);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _backgroundedAt = DateTime.now();
      return;
    }

    if (state != AppLifecycleState.resumed) return;

    final inactiveFor = _backgroundedAt == null
        ? Duration.zero
        : DateTime.now().difference(_backgroundedAt!);
    _backgroundedAt = null;

    if (inactiveFor >= const Duration(seconds: 20)) {
      unawaited(SyncedClockService.initialize());
      _refreshDetailState();
      _resubscribeRealtimeRefresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _liveTicker?.cancel();
    final channel = _refreshChannel;
    if (channel != null) {
      unawaited(Supabase.instance.client.removeChannel(channel));
    }
    super.dispose();
  }
}

bool _isHiddenForAppStoreReview(Contest contest) {
  if (!AppStoreReviewMode.hideRandomOrPredictionCampaigns) return false;
  return contest.type == ContestType.tirage ||
      contest.type == ContestType.pronostic;
}

class _CampaignUnavailableForStore extends StatelessWidget {
  const _CampaignUnavailableForStore();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.campaign_rounded,
                  color: AppColors.primary,
                  size: 44,
                ),
                const SizedBox(height: 14),
                Text(
                  'Campagne indisponible',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.h2.copyWith(fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  'Cette campagne promotionnelle n’est pas disponible dans cette version.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySecondary,
                ),
                const SizedBox(height: 16),
                AppButton(
                  text: 'Retour',
                  isOutlined: true,
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/home');
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ContestDetailBody extends ConsumerStatefulWidget {
  final ContestDetailData data;

  const _ContestDetailBody({required this.data});

  @override
  ConsumerState<_ContestDetailBody> createState() => _ContestDetailBodyState();
}

class _ContestDetailBodyState extends ConsumerState<_ContestDetailBody> {
  bool _isActionRunning = false;
  bool _isSubscriptionNavigationRunning = false;

  ContestDetailData get data => widget.data;

  bool get _dailyLimitReached =>
      data.userProfile.participationsToday >=
      data.userProfile.dailyParticipationLimit;

  bool get _planAccessDenied =>
      !data.contest.isAccessibleForPlan(data.userProfile.planKey);

  bool get _hasPaidPlanRequirement {
    return data.contest.allowedPlayerPlanKeys.any((key) {
      final normalizedKey = key.trim().toLowerCase();
      return normalizedKey.isNotEmpty &&
          normalizedKey != 'free' &&
          normalizedKey != 'standard';
    });
  }

  String get _planAccessTitle {
    if (!_planAccessDenied) return 'Forfait requis validé';
    if (data.contest.isLive) return 'Quiz Live réservé';
    if (data.contest.type == ContestType.quiz) return 'JCQ réservé';
    return 'Accès réservé';
  }

  String get _planAccessMessage {
    final requiredPlan = data.contest.accessLabel;
    final currentPlan = data.userProfile.planName.trim().isEmpty
        ? 'Standard'
        : data.userProfile.planName.trim();
    if (!_planAccessDenied) {
      return 'Ton forfait actuel ($currentPlan) te donne accès à ce concours.';
    }
    return 'Ton forfait actuel ($currentPlan) ne permet pas encore de participer. '
        'Ce concours est réservé aux joueurs $requiredPlan.';
  }

  bool get _isWaitingRoomOpen {
    if (!data.contest.isLiveReservationOpen) return false;
    final liveStartsAt = data.contest.liveStartsAt;
    if (liveStartsAt == null) return false;
    return SyncedClockService.now().isBefore(liveStartsAt);
  }

  bool get _canStartLiveQuiz {
    if (data.contest.isLiveActiveNow) return true;
    final liveStartsAt = data.contest.liveStartsAt;
    return data.contest.isLiveWaitingStatus &&
        liveStartsAt != null &&
        !SyncedClockService.now().isBefore(liveStartsAt);
  }

  bool get _isLiveRegisteredAndWaiting =>
      data.contest.isLive &&
      data.hasLiveRegistration &&
      !_isWaitingRoomOpen &&
      !_canStartLiveQuiz &&
      !data.contest.isLiveEnded;

  bool get _isClassicQuizEnded {
    if (data.contest.isLive || data.contest.type != ContestType.quiz) {
      return false;
    }
    final status = data.contest.status.toLowerCase().trim();
    return status == 'ended' ||
        status == 'completed' ||
        status == 'finished' ||
        !data.contest.endsAt.isAfter(SyncedClockService.now());
  }

  bool get _isActionDisabled =>
      (data.contest.isLive && !data.contest.isLiveReady) ||
      (data.contest.isLive && !data.contest.isLiveReservationOpen) ||
      data.contest.isLiveEnded ||
      _isLiveRegisteredAndWaiting;

  String get _buttonText {
    if (_planAccessDenied) return 'Voir les offres';
    if (data.contest.isLive) {
      if (!data.contest.isLiveReady) return 'Arène en préparation';
      if (data.contest.isLiveEnded) return 'Quiz Live terminé';
      if (!data.contest.isLiveReservationOpen) {
        return data.contest.isLiveQueued
            ? 'En attente du QL précédent'
            : 'Quiz Live programmé';
      }
      if (!data.hasLiveRegistration) return 'Réserver ma place';
      if (_isWaitingRoomOpen) return 'Entrer en salle d’attente';
      if (_canStartLiveQuiz) return 'Démarrer le Quiz Live';
      return 'Place réservée';
    }
    if (data.hasParticipated && data.contest.type == ContestType.quiz) {
      return _isClassicQuizEnded
          ? 'Voir mon résultat'
          : 'Participation enregistrée';
    }
    if (data.hasParticipated) return 'Déjà joué · Voir détails';
    if (_dailyLimitReached) {
      return 'Voir les options';
    }
    return 'Participer';
  }

  void _refreshParticipationState(WidgetRef ref) {
    clearContestDetailCache(data.contest.id);
    clearHomeBootstrapCache(
      userId: ref.read(currentUserIdProvider),
      clearStored: true,
    );
    ref.invalidate(userProfileProvider);
    ref.invalidate(homeBootstrapProvider);
    ref.invalidate(userParticipatedContestIdsProvider);
    ref.invalidate(userRegisteredLiveQuizIdsProvider);
    ref.invalidate(contestDetailProvider(data.contest.id));
  }

  void _openMyQuizResult(BuildContext context) {
    final participationId = data.participationId?.trim() ?? '';
    if (participationId.isNotEmpty) {
      context.go('/participations/$participationId/result');
      return;
    }

    context.go(
      '/contests/${data.contest.id}/quiz/result',
      extra: {
        'participationId': data.participationId ?? '',
        'questions': const [],
        'answers': const [],
      },
    );
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

  void _openSubscriptions(BuildContext context) {
    if (_isSubscriptionNavigationRunning) return;
    _isSubscriptionNavigationRunning = true;
    final contestId = data.contest.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      context.go('/subscriptions?fromContest=$contestId');
    });
  }

  Future<void> _participate(BuildContext context) async {
    if (_isActionRunning) return;
    setState(() => _isActionRunning = true);

    Future<void> stopLoading() async {
      if (mounted) setState(() => _isActionRunning = false);
    }

    if (_planAccessDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ce quiz est réservé aux joueurs ${data.contest.accessLabel}.',
          ),
        ),
      );
      await stopLoading();
      return;
    }

    if (data.contest.isLive) {
      if (!data.contest.isLiveReady) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('L’arène du Quiz Live se prépare. Reviens vite.'),
          ),
        );
        await stopLoading();
        return;
      }

      if (data.contest.isLiveEnded) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ce Quiz Live est terminé.')),
        );
        await stopLoading();
        return;
      }

      if (!data.contest.isLiveReservationOpen) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data.contest.isLiveQueued
                  ? 'Ce Quiz Live est programmé. Il sera activé automatiquement quand son tour arrivera.'
                  : 'Ce Quiz Live n’est pas encore ouvert.',
            ),
          ),
        );
        await stopLoading();
        return;
      }

      final messenger = ScaffoldMessenger.of(context);
      if (!await NetworkStatusService.instance.ensureOnline()) {
        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text(NetworkStatusService.offlineActionMessage),
            ),
          );
        }
        await stopLoading();
        return;
      }

      final supabase = Supabase.instance.client;
      try {
        if (!data.hasLiveRegistration) {
          await supabase.rpc(
            'register_live_quiz',
            params: {'p_contest_id': data.contest.id},
          );
          unawaited(
            AppLogger.info(
              'live_quiz',
              'register',
              'Joueur inscrit au Quiz Live.',
              entityType: 'contest',
              entityId: data.contest.id,
              metadata: {
                'contest_title': data.contest.title,
                'live_starts_at': data.contest.liveStartsAt?.toIso8601String(),
                'registered_count': data.contest.registeredCount + 1,
              },
            ),
          );
          await supabase.rpc(
            'join_live_quiz_waiting_room',
            params: {'p_contest_id': data.contest.id},
          );
          final startsAt = data.contest.liveStartsAt;
          if (startsAt != null) {
            unawaited(
              LiveQuizNotificationService.showWaitingNotification(
                contestId: data.contest.id,
                title: data.contest.title,
                startsAt: startsAt,
                prizeLabel: _formatPrize(data.contest.prizeValue),
                registeredCount: data.contest.registeredCount + 1,
                connectedCount: data.contest.connectedCount,
                showClassicNotification: false,
              ),
            );
          }
          _refreshParticipationState(ref);
          if (!context.mounted) return;
          context.go('/contests/${data.contest.id}/live-waiting');
          return;
        }

        if (_isWaitingRoomOpen) {
          await supabase.rpc(
            'join_live_quiz_waiting_room',
            params: {'p_contest_id': data.contest.id},
          );
          unawaited(
            AppLogger.info(
              'live_quiz',
              'open_waiting_room',
              'Joueur ouvre la salle attente QL depuis le detail.',
              entityType: 'contest',
              entityId: data.contest.id,
              metadata: {'contest_title': data.contest.title},
            ),
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

        messenger.showSnackBar(
          const SnackBar(
            content: Text('La salle d’attente est disponible avant le départ.'),
          ),
        );
      } catch (error, stackTrace) {
        unawaited(
          AppLogger.warning(
            'live_quiz',
            'action_failed',
            'Action Quiz Live impossible depuis le detail.',
            entityType: 'contest',
            entityId: data.contest.id,
            metadata: {
              'contest_title': data.contest.title,
              'retryable_network': AppTelemetryService.isRetryableNetworkError(
                error,
              ),
              'error': error.toString(),
            },
          ),
        );
        unawaited(
          AppTelemetryService.recordError(
            error,
            stackTrace,
            reason: 'live_quiz_action_failed',
            context: {'contest_id': data.contest.id},
          ),
        );
        if (!context.mounted) return;
        final message = _formatLiveQuizError(error);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      } finally {
        await stopLoading();
      }
      return;
    }

    if (data.contest.type == ContestType.quiz) {
      if (!await NetworkStatusService.instance.ensureOnline()) {
        if (mounted) {
          ScaffoldMessenger.of(this.context).showSnackBar(
            const SnackBar(
              content: Text(NetworkStatusService.offlineActionMessage),
            ),
          );
        }
        await stopLoading();
        return;
      }

      final supabase = Supabase.instance.client;
      try {
        final deviceSessionId = await DeviceSessionService.currentSessionId();
        final result = await supabase.rpc(
          'start_quiz_contest',
          params: {
            'p_contest_id': data.contest.id,
            'p_device_session_id': deviceSessionId,
          },
        );
        final participationId = result is Map
            ? result['participation_id'] as String?
            : null;
        if (participationId == null || participationId.isEmpty) {
          throw StateError('Participation introuvable après démarrage quiz.');
        }

        unawaited(
          AppLogger.info(
            'contests',
            'start_quiz_contest',
            'Joueur demarre un quiz concours.',
            entityType: 'contest',
            entityId: data.contest.id,
            metadata: {
              'contest_title': data.contest.title,
              'participation_id': participationId,
              if (result is Map) 'questions_count': result['questions_count'],
            },
          ),
        );

        _refreshParticipationState(ref);
        if (!context.mounted) return;
        context.go(
          '/contests/${data.contest.id}/quiz',
          extra: {'participationId': participationId},
        );
      } catch (error, stackTrace) {
        unawaited(
          AppLogger.error(
            'contests',
            'start_quiz_contest_failed',
            'Echec demarrage quiz concours.',
            entityType: 'contest',
            entityId: data.contest.id,
            error: error,
            stackTrace: stackTrace,
          ),
        );
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Participation déjà enregistrée pour ce quiz.'),
          ),
        );
        _refreshParticipationState(ref);
      } finally {
        await stopLoading();
      }
      return;
    }

    if (data.contest.type == ContestType.pronostic) {
      await showModalBottomSheet<void>(
        context: this.context,
        isScrollControlled: true,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (context) =>
            _PredictionParticipationSheet(data: data, ref: ref),
      );
      await stopLoading();
      return;
    }

    await showModalBottomSheet<void>(
      context: this.context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _DrawParticipationSheet(data: data, ref: ref),
    );
    await stopLoading();
  }

  @override
  Widget build(BuildContext context) {
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
                  Text(
                    contest.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.h2.copyWith(
                      fontSize: 21,
                      height: 1.12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _ContestArenaSummary(data: data),
                  if (contest.isLive) ...[
                    const SizedBox(height: 14),
                    _LiveQuizArenaCard(data: data),
                  ],
                  if (_hasPaidPlanRequirement) ...[
                    const SizedBox(height: 14),
                    _AccessRequirementCard(
                      icon: _planAccessDenied
                          ? Icons.lock_rounded
                          : Icons.verified_rounded,
                      title: _planAccessTitle,
                      body: _planAccessMessage,
                      badge: 'Requis: ${contest.accessLabel}',
                      isUnlocked: !_planAccessDenied,
                    ),
                  ],
                  if (!contest.isLive &&
                      _dailyLimitReached &&
                      !data.hasParticipated) ...[
                    const SizedBox(height: 14),
                    _StatusNoticeCard(
                      icon: Icons.workspace_premium_rounded,
                      label:
                          'Limite ${data.userProfile.participationsToday}/${data.userProfile.dailyParticipationLimit}',
                      color: AppColors.gold,
                    ),
                  ],
                  if (data.hasParticipated) ...[
                    const SizedBox(height: 14),
                    const _StatusNoticeCard(
                      icon: Icons.check_circle_rounded,
                      label: 'Participation enregistrée',
                      color: AppColors.accentGreen,
                    ),
                  ],
                  if (data.userRanking != null) ...[
                    const SizedBox(height: 14),
                    _ContestUserRankingCard(
                      contestId: contest.id,
                      ranking: data.userRanking!,
                    ),
                  ],
                  const SizedBox(height: 22),
                  _PremiumInfoCard(
                    icon: Icons.article_rounded,
                    title: 'Description',
                    body: contest.description,
                    collapsible: true,
                  ),
                  const SizedBox(height: 14),
                  _PremiumInfoCard(
                    icon: Icons.workspace_premium_rounded,
                    title: 'À gagner',
                    body: contest.prizeDescription.isEmpty
                        ? 'Récompense surprise offerte par la marque partenaire.'
                        : contest.prizeDescription,
                    accentColor: AppColors.gold,
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
              isLoading: _isActionRunning,
              color:
                  data.hasParticipated &&
                      !contest.isLive &&
                      !(contest.type == ContestType.quiz && _isClassicQuizEnded)
                  ? AppColors.surfaceBorder
                  : null,
              foregroundColor:
                  data.hasParticipated &&
                      !contest.isLive &&
                      !(contest.type == ContestType.quiz && _isClassicQuizEnded)
                  ? AppColors.textSecondary
                  : null,
              onPressed: _isActionDisabled || _isActionRunning
                  ? null
                  : _planAccessDenied
                  ? () => _openSubscriptions(context)
                  : data.hasParticipated
                  ? data.contest.type == ContestType.quiz
                        ? () => _openMyQuizResult(context)
                        : () => _refreshParticipationState(ref)
                  : (!contest.isLive && _dailyLimitReached)
                  ? () => _openSubscriptions(context)
                  : () => _participate(context),
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
                    'Ce Quiz Live n’est plus accessible. Retourne à l’accueil pour voir les quiz disponibles.',
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
                          label: 'Récompense',
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

class _ContestArenaSummary extends StatelessWidget {
  final ContestDetailData data;

  const _ContestArenaSummary({required this.data});

  @override
  Widget build(BuildContext context) {
    final contest = data.contest;
    final isLive = contest.isLive;
    final accentColor = isLive ? AppColors.accentGreen : contest.type.color;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isLive ? const Color(0xFF17113F) : AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isLive
              ? accentColor.withValues(alpha: 0.46)
              : contest.type.color.withValues(alpha: 0.22),
          width: isLive ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (isLive ? AppColors.primaryDark : Colors.black).withValues(
              alpha: isLive ? 0.18 : 0.05,
            ),
            blurRadius: isLive ? 22 : 14,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: isLive ? 0.18 : 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.34),
                  ),
                ),
                child: Icon(
                  isLive ? Icons.bolt_rounded : contest.type.icon,
                  color: isLive ? Colors.white : accentColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isLive ? 'Arena' : 'JCQ',
                      style: AppTextStyles.h3.copyWith(
                        color: isLive ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isLive
                          ? _liveQuizStatusLabel(contest)
                          : 'Tirage aléatoire',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isLive
                            ? Colors.white.withValues(alpha: 0.72)
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _ArenaTimePill(contest: contest, inverted: isLive),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ArenaChip(
                icon: Icons.groups_rounded,
                label: '${data.participantsCount} joueurs',
                color: accentColor,
                inverted: isLive,
              ),
              _ArenaChip(
                icon: Icons.workspace_premium_rounded,
                label: _winnerText(contest),
                color: AppColors.gold,
                inverted: isLive,
              ),
              _ArenaChip(
                icon: Icons.payments_rounded,
                label: _formatPrize(contest.prizeValue),
                color: AppColors.gold,
                inverted: isLive,
              ),
              if (isLive)
                _ArenaChip(
                  icon: Icons.how_to_reg_rounded,
                  label: '${contest.registeredCount} inscrits',
                  color: AppColors.accentGreen,
                  inverted: true,
                )
              else
                _ArenaChip(
                  icon: Icons.shuffle_rounded,
                  label: 'Aléatoire',
                  color: AppColors.primary,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LiveQuizArenaCard extends StatelessWidget {
  final ContestDetailData data;

  const _LiveQuizArenaCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final contest = data.contest;
    final isRegistered = data.hasLiveRegistration;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.accentGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.accentGreen.withValues(alpha: 0.28),
                  ),
                ),
                child: const Icon(
                  Icons.sports_esports_rounded,
                  color: AppColors.accentGreen,
                  size: 21,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  isRegistered ? 'Réservé' : 'Arena',
                  style: AppTextStyles.h3.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (isRegistered)
                const Icon(
                  Icons.verified_rounded,
                  color: AppColors.accentGreen,
                  size: 22,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ArenaChip(
                icon: Icons.quiz_rounded,
                label: '5 Q',
                color: AppColors.primary,
              ),
              _ArenaChip(
                icon: Icons.timer_rounded,
                label: '20 sec',
                color: AppColors.primary,
              ),
              _ArenaChip(
                icon: Icons.speed_rounded,
                label: 'Vitesse',
                color: AppColors.accentGreen,
              ),
              _ArenaChip(
                icon: Icons.emoji_events_rounded,
                label: _winnerText(contest),
                color: AppColors.gold,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PremiumInfoCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String body;
  final Color accentColor;
  final bool collapsible;

  const _PremiumInfoCard({
    required this.icon,
    required this.title,
    required this.body,
    this.accentColor = AppColors.primary,
    this.collapsible = false,
  });

  @override
  State<_PremiumInfoCard> createState() => _PremiumInfoCardState();
}

class _PremiumInfoCardState extends State<_PremiumInfoCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final canCollapse = widget.collapsible && widget.body.length > 180;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: widget.accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: widget.accentColor.withValues(alpha: 0.24),
              ),
            ),
            child: Icon(widget.icon, color: widget.accentColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.title, style: AppTextStyles.h3),
                const SizedBox(height: 5),
                Text(
                  widget.body,
                  maxLines: canCollapse && !_isExpanded ? 5 : null,
                  overflow: canCollapse && !_isExpanded
                      ? TextOverflow.ellipsis
                      : TextOverflow.visible,
                  style: AppTextStyles.bodySecondary.copyWith(height: 1.35),
                ),
                if (canCollapse) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () =>
                          setState(() => _isExpanded = !_isExpanded),
                      child: Text(_isExpanded ? 'Voir moins' : 'Voir plus'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusNoticeCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatusNoticeCard({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccessRequirementCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String badge;
  final bool isUnlocked;

  const _AccessRequirementCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.badge,
    this.isUnlocked = false,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = isUnlocked ? AppColors.accentGreen : AppColors.gold;
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accentColor.withValues(alpha: 0.28)),
            ),
            child: Icon(icon, color: accentColor, size: 20),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: AppTextStyles.h3.copyWith(fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.24),
                        ),
                      ),
                      child: Text(
                        badge,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: accentColor,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: AppTextStyles.bodySecondary.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ArenaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool inverted;

  const _ArenaChip({
    required this.icon,
    required this.label,
    required this.color,
    this.inverted = false,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = inverted ? Colors.white : color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: inverted
            ? Colors.white.withValues(alpha: 0.1)
            : color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: inverted
              ? Colors.white.withValues(alpha: 0.18)
              : color.withValues(alpha: 0.24),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: foreground, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: foreground,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ArenaTimePill extends StatelessWidget {
  final Contest contest;
  final bool inverted;

  const _ArenaTimePill({required this.contest, required this.inverted});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: inverted
            ? Colors.white.withValues(alpha: 0.12)
            : AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: inverted
              ? Colors.white.withValues(alpha: 0.22)
              : AppColors.surfaceBorder,
        ),
      ),
      child: contest.isLive
          ? _LiveQuizDetailTime(contest: contest, inverted: inverted)
          : ContestTimer(endsAt: contest.computedLiveEndsAt),
    );
  }
}

class _ContestUserRankingCard extends StatelessWidget {
  final String contestId;
  final ContestUserRanking ranking;

  const _ContestUserRankingCard({
    required this.contestId,
    required this.ranking,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.leaderboard_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ton classement', style: AppTextStyles.h3),
                    const SizedBox(height: 3),
                    Text(
                      '${ranking.score} point${ranking.score > 1 ? 's' : ''}',
                      style: AppTextStyles.bodySecondary,
                    ),
                  ],
                ),
              ),
              Text(
                '#${ranking.rank}',
                style: AppTextStyles.price.copyWith(fontSize: 22),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Tu es ${ranking.rank}${ranking.rank == 1 ? 'er' : 'e'} sur ${ranking.totalParticipants} participant${ranking.totalParticipants > 1 ? 's' : ''}.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: () =>
                    context.go('/leaderboard?contestId=$contestId'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Voir tout',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ],
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
    if (!await NetworkStatusService.instance.ensureOnline()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(NetworkStatusService.offlineActionMessage),
        ),
      );
      return;
    }

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
      clearHomeBootstrapCache(
        userId: widget.ref.read(currentUserIdProvider),
        clearStored: true,
      );
      widget.ref.invalidate(homeBootstrapProvider);
      widget.ref.invalidate(userParticipatedContestIdsProvider);
      widget.ref.invalidate(userRegisteredLiveQuizIdsProvider);
      clearContestDetailCache(widget.data.contest.id);
      widget.ref.invalidate(contestDetailProvider(widget.data.contest.id));

      unawaited(
        AppLogger.info(
          'contests',
          'draw_participation',
          'Participation tirage enregistree.',
          entityType: 'contest',
          entityId: widget.data.contest.id,
          metadata: {
            'contest_title': widget.data.contest.title,
            'tickets': tickets,
          },
        ),
      );

      if (mounted) setState(() => _isDone = true);
    } catch (error, stackTrace) {
      unawaited(
        AppLogger.error(
          'contests',
          'draw_participation_failed',
          'Echec participation tirage.',
          entityType: 'contest',
          entityId: widget.data.contest.id,
          error: error,
          stackTrace: stackTrace,
        ),
      );
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
        'Les vainqueurs seront annoncés ${_shortDateTime(widget.data.contest.computedLiveEndsAt)}.';
    final winnerDate =
        widget.data.drawSettings?.winnerAnnouncementAt ??
        widget.data.contest.computedLiveEndsAt;

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
              _isDone ? 'Participation validée !' : 'Valider ma participation',
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
                tickets > 1
                    ? 'Ta participation est enregistrée avec $tickets participations bonus.'
                    : 'Ta participation est enregistrée.',
                textAlign: TextAlign.center,
                style: AppTextStyles.h3,
              ),
            ),
            if (!_isDone)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'Annonce prévue ${_shortDateTime(winnerDate)}',
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
  return (baseTickets + data.userProfile.bonusTickets).toInt();
}

String _formatLiveQuizError(Object error) {
  final safeMessage = AppTelemetryService.userMessageForError(
    error,
    fallback: 'Action impossible pour le moment. Réessaie.',
  );
  if (safeMessage != 'Action impossible pour le moment. Réessaie.') {
    return safeMessage;
  }

  final message = '$error';
  if (message.contains('Les inscriptions sont fermees') ||
      message.contains('La porte est fermee')) {
    return 'Les inscriptions sont fermées pour ce Quiz Live.';
  }
  if (message.contains('salle d') || message.contains('Inscription requise')) {
    return 'La salle d’attente n’est pas encore ouverte ou ton inscription doit être actualisée.';
  }
  if (message.contains('forfait')) {
    return 'Ton forfait ne permet pas de participer à ce Quiz Live.';
  }
  return 'Action impossible pour le moment. Réessaie.';
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
  final _otherPlayerController = TextEditingController();
  final _customTextController = TextEditingController();
  final Set<String> _selectedPlayers = <String>{};
  String? _selectedPlayer;
  String _doneSummary = '';
  bool _isSaving = false;
  bool _isDone = false;

  @override
  void dispose() {
    _homeScoreController.dispose();
    _awayScoreController.dispose();
    _otherPlayerController.dispose();
    _customTextController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final prediction = widget.data.prediction;

    if (prediction == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ce quiz sport n’est pas encore configuré.'),
        ),
      );
      return;
    }

    if (!prediction.isOpen) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ce quiz sport est fermé.')));
      return;
    }

    final predictionAnswer = _buildPredictionAnswer(prediction);
    if (predictionAnswer == null) {
      return;
    }

    if (!await NetworkStatusService.instance.ensureOnline()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(NetworkStatusService.offlineActionMessage),
        ),
      );
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
          'prediction_type': prediction.kind.storageKey,
          'match': prediction.matchLabel,
          'home_team': prediction.homeTeam,
          'away_team': prediction.awayTeam,
          ...predictionAnswer.answers,
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
      clearHomeBootstrapCache(
        userId: widget.ref.read(currentUserIdProvider),
        clearStored: true,
      );
      widget.ref.invalidate(homeBootstrapProvider);
      widget.ref.invalidate(userParticipatedContestIdsProvider);
      widget.ref.invalidate(userRegisteredLiveQuizIdsProvider);
      clearContestDetailCache(widget.data.contest.id);
      widget.ref.invalidate(contestDetailProvider(widget.data.contest.id));

      unawaited(
        AppLogger.info(
          'contests',
          'prediction_participation',
          'Participation pronostic enregistree.',
          entityType: 'contest',
          entityId: widget.data.contest.id,
          metadata: {
            'contest_title': widget.data.contest.title,
            'prediction_type': prediction.kind.storageKey,
            'match': prediction.matchLabel,
          },
        ),
      );

      if (mounted) {
        setState(() {
          _doneSummary = predictionAnswer.summary;
          _isDone = true;
        });
      }
    } catch (error, stackTrace) {
      unawaited(
        AppLogger.error(
          'contests',
          'prediction_participation_failed',
          'Echec participation pronostic.',
          entityType: 'contest',
          entityId: widget.data.contest.id,
          error: error,
          stackTrace: stackTrace,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Réponse impossible. Réessaie.')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  _PredictionAnswer? _buildPredictionAnswer(ContestPrediction prediction) {
    switch (prediction.kind) {
      case FootballPredictionKind.scoreExact:
        final homeScore = int.tryParse(_homeScoreController.text.trim());
        final awayScore = int.tryParse(_awayScoreController.text.trim());
        if (homeScore == null ||
            awayScore == null ||
            homeScore < 0 ||
            awayScore < 0) {
          _showValidationMessage('Entre un score valide.');
          return null;
        }
        return _PredictionAnswer(
          summary:
              'Tu as joué ${prediction.homeTeam} $homeScore-$awayScore ${prediction.awayTeam}.',
          answers: {
            'predicted_home_score': homeScore,
            'predicted_away_score': awayScore,
            'predicted_score': '$homeScore-$awayScore',
          },
        );
      case FootballPredictionKind.firstScorer:
      case FootballPredictionKind.assistProvider:
        final player = _selectedSinglePlayer(prediction);
        if (player == null) return null;
        final answerKey = prediction.kind == FootballPredictionKind.firstScorer
            ? 'predicted_first_scorer'
            : 'predicted_assist_provider';
        return _PredictionAnswer(
          summary: '${prediction.prompt} $player',
          answers: {answerKey: player, 'selected_player': player},
        );
      case FootballPredictionKind.startingEleven:
        final requiredCount = prediction.maxSelections;
        if (_selectedPlayers.length < prediction.minSelections ||
            _selectedPlayers.length > requiredCount) {
          _showValidationMessage(
            'Selectionne ${prediction.maxSelections} joueurs pour valider ton XI.',
          );
          return null;
        }
        final players = _selectedPlayers.toList(growable: false);
        return _PredictionAnswer(
          summary:
              'Ton XI titulaire est enregistre (${players.length}/$requiredCount).',
          answers: {
            'predicted_starting_eleven': players,
            'selected_players': players,
          },
        );
      case FootballPredictionKind.customText:
        final text = _customTextController.text.trim();
        if (text.length < 2) {
          _showValidationMessage('Entre ta réponse.');
          return null;
        }
        return _PredictionAnswer(
          summary: 'Ta réponse: $text',
          answers: {'prediction_text': text},
        );
    }
  }

  String? _selectedSinglePlayer(ContestPrediction prediction) {
    final selected = _selectedPlayer;
    if (selected == null || selected.isEmpty) {
      _showValidationMessage('Choisis un joueur pour valider.');
      return null;
    }
    if (selected == '__none__') {
      return prediction.kind == FootballPredictionKind.firstScorer
          ? 'Aucun but'
          : 'Aucune passe decisive';
    }
    if (selected == '__other__') {
      final other = _otherPlayerController.text.trim();
      if (other.length < 2) {
        _showValidationMessage('Entre le nom du joueur.');
        return null;
      }
      return other;
    }
    return selected;
  }

  void _showValidationMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _togglePlayer(String player, ContestPrediction prediction) {
    setState(() {
      if (_selectedPlayers.contains(player)) {
        _selectedPlayers.remove(player);
        return;
      }
      if (_selectedPlayers.length >= prediction.maxSelections) {
        return;
      }
      _selectedPlayers.add(player);
    });
  }

  @override
  Widget build(BuildContext context) {
    final prediction = widget.data.prediction;
    final homeTeam = prediction?.homeTeam ?? 'Equipe 1';
    final awayTeam = prediction?.awayTeam ?? 'Equipe 2';
    final isConfigured = prediction != null;
    final isOpen = prediction?.isOpen ?? false;
    final icon = prediction?.kind == FootballPredictionKind.startingEleven
        ? Icons.groups_rounded
        : prediction?.kind == FootballPredictionKind.scoreExact
        ? Icons.scoreboard_rounded
        : Icons.sports_soccer_rounded;

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
                  _isDone ? Icons.check_rounded : icon,
                  color: _isDone ? AppColors.accentGreen : AppColors.primary,
                  size: 34,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _isDone ? 'Réponse enregistrée !' : 'Ta réponse',
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
                if (prediction != null)
                  _buildPredictionForm(prediction, isConfigured && isOpen),
                const SizedBox(height: 12),
                Text(
                  isConfigured
                      ? isOpen
                            ? _predictionHelpText(prediction)
                            : 'Ce quiz sport est actuellement fermé.'
                      : 'Ce jeu n’est pas encore configuré par MegaPromo.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: 18),
                AppButton(
                  text: prediction?.actionLabel ?? 'Valider ma réponse',
                  isLoading: _isSaving,
                  onPressed: isConfigured && isOpen && !_isSaving
                      ? _confirm
                      : null,
                ),
              ] else ...[
                Text(
                  _doneSummary.isEmpty
                      ? 'Ta réponse est enregistrée.'
                      : _doneSummary,
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

  Widget _buildPredictionForm(ContestPrediction prediction, bool enabled) {
    switch (prediction.kind) {
      case FootballPredictionKind.scoreExact:
        return Row(
          children: [
            Expanded(
              child: TextField(
                controller: _homeScoreController,
                enabled: enabled,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: InputDecoration(labelText: prediction.homeTeam),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _awayScoreController,
                enabled: enabled,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: InputDecoration(labelText: prediction.awayTeam),
              ),
            ),
          ],
        );
      case FootballPredictionKind.firstScorer:
      case FootballPredictionKind.assistProvider:
        return _SinglePlayerPredictionForm(
          prediction: prediction,
          enabled: enabled,
          selectedPlayer: _selectedPlayer,
          otherController: _otherPlayerController,
          onSelected: (value) => setState(() => _selectedPlayer = value),
        );
      case FootballPredictionKind.startingEleven:
        return _StartingElevenPredictionForm(
          prediction: prediction,
          enabled: enabled,
          selectedPlayers: _selectedPlayers,
          onTogglePlayer: _togglePlayer,
        );
      case FootballPredictionKind.customText:
        return TextField(
          controller: _customTextController,
          enabled: enabled,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(labelText: prediction.prompt),
        );
    }
  }

  String _predictionHelpText(ContestPrediction prediction) {
    return switch (prediction.kind) {
      FootballPredictionKind.scoreExact =>
        'Bonne réponse : ${prediction.pointsExactScore} pts · Réponse partielle : ${prediction.pointsCorrectResult} pts',
      FootballPredictionKind.firstScorer =>
        'Choisis la réponse proposée par la marque. Tu peux choisir "Aucun" si disponible.',
      FootballPredictionKind.assistProvider =>
        'Choisis la réponse proposée par la marque. Tu peux choisir "Aucune" si disponible.',
      FootballPredictionKind.startingEleven =>
        'Selectionne ${prediction.maxSelections} joueurs (${_selectedPlayers.length}/${prediction.maxSelections}).',
      FootballPredictionKind.customText => prediction.prompt,
    };
  }
}

class _PredictionAnswer {
  final String summary;
  final Map<String, dynamic> answers;

  const _PredictionAnswer({required this.summary, required this.answers});
}

class _SinglePlayerPredictionForm extends StatelessWidget {
  final ContestPrediction prediction;
  final bool enabled;
  final String? selectedPlayer;
  final TextEditingController otherController;
  final ValueChanged<String> onSelected;

  const _SinglePlayerPredictionForm({
    required this.prediction,
    required this.enabled,
    required this.selectedPlayer,
    required this.otherController,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final players = prediction.players;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(prediction.prompt, style: AppTextStyles.h3),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (prediction.allowNone)
              _PredictionChoiceChip(
                label: prediction.kind == FootballPredictionKind.firstScorer
                    ? 'Aucun but'
                    : 'Aucune passe',
                selected: selectedPlayer == '__none__',
                enabled: enabled,
                onTap: () => onSelected('__none__'),
              ),
            ...players.map(
              (player) => _PredictionChoiceChip(
                label: player,
                selected: selectedPlayer == player,
                enabled: enabled,
                onTap: () => onSelected(player),
              ),
            ),
            if (prediction.allowOther)
              _PredictionChoiceChip(
                label: 'Autre joueur',
                selected: selectedPlayer == '__other__',
                enabled: enabled,
                onTap: () => onSelected('__other__'),
              ),
          ],
        ),
        if (selectedPlayer == '__other__') ...[
          const SizedBox(height: 12),
          TextField(
            controller: otherController,
            enabled: enabled,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nom du joueur'),
          ),
        ],
      ],
    );
  }
}

class _StartingElevenPredictionForm extends StatelessWidget {
  final ContestPrediction prediction;
  final bool enabled;
  final Set<String> selectedPlayers;
  final void Function(String player, ContestPrediction prediction)
  onTogglePlayer;

  const _StartingElevenPredictionForm({
    required this.prediction,
    required this.enabled,
    required this.selectedPlayers,
    required this.onTogglePlayer,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(prediction.prompt, style: AppTextStyles.h3)),
            const SizedBox(width: 12),
            Text(
              '${selectedPlayers.length}/${prediction.maxSelections}',
              style: AppTextStyles.label.copyWith(color: AppColors.primary),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: prediction.players
              .map((player) {
                return _PredictionChoiceChip(
                  label: player,
                  selected: selectedPlayers.contains(player),
                  enabled:
                      enabled &&
                      (selectedPlayers.contains(player) ||
                          selectedPlayers.length < prediction.maxSelections),
                  onTap: () => onTogglePlayer(player, prediction),
                );
              })
              .toList(growable: false),
        ),
      ],
    );
  }
}

class _PredictionChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _PredictionChoiceChip({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.surfaceElevated;
    final textColor = selected ? Colors.white : AppColors.textSecondary;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: enabled ? color : AppColors.surfaceBorder,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.primaryDark : AppColors.surfaceBorder,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: enabled ? textColor : AppColors.textHint,
            fontWeight: FontWeight.w800,
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
            _NetworkPromoImage(
              url: imageUrl,
              fallback: _ContestHeroFallback(contest: contest),
            )
          else
            _ContestHeroFallback(contest: contest),
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
          if (contest.brandLogoUrl?.isNotEmpty == true)
            Positioned(
              left: 20,
              bottom: 18,
              child: _HeroBrandLogo(url: contest.brandLogoUrl!),
            ),
        ],
      ),
    );
  }
}

class _HeroBrandLogo extends StatelessWidget {
  final String url;

  const _HeroBrandLogo({required this.url});

  @override
  Widget build(BuildContext context) {
    return _BrandLogoImage(url: url, size: 58);
  }
}

class _NetworkPromoImage extends StatelessWidget {
  final String url;
  final Widget fallback;

  const _NetworkPromoImage({required this.url, required this.fallback});

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
          errorBuilder: (_, _, _) => fallback,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Stack(
              fit: StackFit.expand,
              children: [
                fallback,
                const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            );
          },
        );
      },
    );
  }
}

class _ContestHeroFallback extends StatelessWidget {
  final Contest contest;

  const _ContestHeroFallback({required this.contest});

  @override
  Widget build(BuildContext context) {
    final icon = contest.isLive ? Icons.bolt_rounded : contest.type.icon;
    final color = contest.isLive ? AppColors.primaryLight : contest.type.color;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.30),
            AppColors.surface,
            AppColors.background,
          ],
        ),
      ),
      child: Center(
        child: Container(
          width: 98,
          height: 98,
          decoration: BoxDecoration(
            color: AppColors.background.withValues(alpha: 0.50),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppColors.surfaceBorder),
          ),
          child: Icon(icon, color: color, size: 52),
        ),
      ),
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

class _DetailStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primaryLight, size: 20),
        const SizedBox(height: 8),
        Text(label, style: AppTextStyles.bodySmall),
        const SizedBox(height: 4),
        Text(value, style: AppTextStyles.h3),
      ],
    );
  }
}

class _LiveQuizDetailTime extends StatelessWidget {
  final Contest contest;
  final bool inverted;

  const _LiveQuizDetailTime({required this.contest, this.inverted = false});

  @override
  Widget build(BuildContext context) {
    final baseColor = inverted ? Colors.white : AppColors.textPrimary;
    final liveStartsAt = contest.liveStartsAt;
    if (liveStartsAt == null) {
      return Text(
        'À confirmer',
        style: AppTextStyles.h3.copyWith(color: baseColor),
      );
    }

    final now = SyncedClockService.now();
    if (contest.isLiveEnded) {
      return Text(
        'Terminé',
        style: AppTextStyles.h3.copyWith(color: baseColor),
      );
    }
    if (contest.isLiveActiveNow) {
      return Text(
        'En direct',
        style: AppTextStyles.h3.copyWith(color: AppColors.accentGreen),
      );
    }
    if (!now.isBefore(liveStartsAt)) {
      return Text(
        'Bientôt',
        style: AppTextStyles.h3.copyWith(
          color: inverted ? Colors.white : AppColors.primary,
        ),
      );
    }

    return ContestTimer(
      endsAt: liveStartsAt,
      style: AppTextStyles.h3.copyWith(
        color: baseColor,
        fontWeight: FontWeight.w900,
      ),
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
                  'Impossible de charger ce quiz.',
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
  if (AppStoreReviewMode.hideCashAmounts) {
    return 'Récompense partenaire';
  }
  return formatCurrencyAmount(value);
}

String _shortDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
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

String _liveQuizStatusLabel(Contest contest) {
  if (!contest.isLiveReady) return 'Préparation';
  if (contest.isLiveActiveNow) return 'En direct maintenant';
  if (contest.isLiveWaitingStatus) return 'Salle ouverte';
  if (contest.isLiveQueued) return 'File QL';
  final liveStartsAt = contest.liveStartsAt;
  if (liveStartsAt == null) return 'Départ à confirmer';
  return 'Départ ${_shortClockTime(liveStartsAt)}';
}

String _shortClockTime(DateTime date) {
  return '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
}
