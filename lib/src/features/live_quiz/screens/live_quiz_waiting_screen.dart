import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mega_promo/core/theme/app_colors.dart';
import 'package:mega_promo/core/theme/app_text_styles.dart';
import 'package:mega_promo/core/utils/currency_formatter.dart';
import 'package:mega_promo/core/widgets/app_button.dart';
import 'package:mega_promo/core/widgets/app_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/app_store_review_mode.dart';
import '../../../services/app_telemetry_service.dart';
import '../../../services/app_logger.dart';
import '../../../services/live_quiz_notification_service.dart';
import '../../../services/network_status_service.dart';
import '../../../services/synced_clock_service.dart';
import '../../contests/providers/contest_providers.dart';
import '../../home/providers/home_bootstrap_provider.dart';
import '../../quiz/services/quiz_asset_preload_service.dart';
import '../services/live_quiz_service.dart';

class LiveQuizWaitingScreen extends ConsumerStatefulWidget {
  final String contestId;

  const LiveQuizWaitingScreen({super.key, required this.contestId});

  @override
  ConsumerState<LiveQuizWaitingScreen> createState() =>
      _LiveQuizWaitingScreenState();
}

class _LiveQuizWaitingScreenState extends ConsumerState<LiveQuizWaitingScreen>
    with WidgetsBindingObserver {
  Timer? _timer;
  Timer? _connectionQualityTimer;
  RealtimeChannel? _waitingRefreshChannel;
  DateTime? _backgroundedAt;
  DateTime? _lastRealtimeUpdateAt;
  DateTime? _lastNetworkIssueAt;
  DateTime? _lastAutoStartAttemptAt;
  bool _isJoining = false;
  bool _isStarting = false;
  bool _hasJoinedWaitingRoom = false;
  bool _autoStartFailed = false;
  bool _isPreloadingAssets = false;
  bool _hasPreloadedAssets = false;
  bool _isArenaWindowOpen = false;
  bool _finalClockSyncDone = false;
  bool _isCheckingConnectionQuality = false;
  Duration _remaining = Duration.zero;
  Duration? _lastServerLatency;
  int _connectionQuality = 72;
  int _autoStartAttempts = 0;
  int? _lastRenderedServerSecond;
  String? _lastLiveActivitySignature;
  String? _preloadedAssetsSignature;

  static const _autoStartRetryDelay = Duration(seconds: 3);
  static const _autoStartMaxAttempts = 12;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(
      AppTelemetryService.setScreen(
        'LiveQuizWaitingScreen',
        parameters: {'contest_id': widget.contestId},
      ),
    );
    unawaited(AppTelemetryService.setContext({'contest_id': widget.contestId}));
    _subscribeWaitingUpdates();
    unawaited(SyncedClockService.sync(force: true).whenComplete(_startTicker));
    _startConnectionQualityChecks();
    WidgetsBinding.instance.addPostFrameCallback((_) => _joinWaitingRoom());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _connectionQualityTimer?.cancel();
    final channel = _waitingRefreshChannel;
    if (channel != null) {
      unawaited(Supabase.instance.client.removeChannel(channel));
    }
    super.dispose();
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
      unawaited(SyncedClockService.sync(force: true));
      unawaited(_checkConnectionQuality());
      clearContestDetailCache(widget.contestId);
      ref.invalidate(contestDetailProvider(widget.contestId));
      QuizAssetPreloadService.clearContest(widget.contestId);
      _preloadedAssetsSignature = null;
      _hasPreloadedAssets = false;
      _isArenaWindowOpen = false;
      _finalClockSyncDone = false;
      unawaited(_joinWaitingRoom());
      _tick();
    }
  }

  void _startTicker() {
    if (!mounted || _timer != null) return;
    _tick();
    _scheduleNextTick();
  }

  void _scheduleNextTick() {
    _timer?.cancel();
    if (!mounted) return;

    final syncedNow = SyncedClockService.now();
    final elapsedInCurrentSecond = syncedNow.millisecondsSinceEpoch.remainder(
      1000,
    );
    final delayMs = elapsedInCurrentSecond == 0
        ? 1000
        : 1000 - elapsedInCurrentSecond;

    _timer = Timer(Duration(milliseconds: delayMs), () {
      _tick();
      _scheduleNextTick();
    });
  }

  void _subscribeWaitingUpdates() {
    final supabase = Supabase.instance.client;

    void refreshWaitingState(PostgresChangePayload payload) {
      _lastRealtimeUpdateAt = DateTime.now();
      _recomputeConnectionQuality();
      clearContestDetailCache(widget.contestId);
      ref.invalidate(contestDetailProvider(widget.contestId));
    }

    _waitingRefreshChannel = supabase
        .channel('live-quiz-waiting-${widget.contestId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'contests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.contestId,
          ),
          callback: refreshWaitingState,
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
          callback: refreshWaitingState,
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
          callback: refreshWaitingState,
        )
        .subscribe();
  }

  Future<void> _joinWaitingRoom() async {
    if (_isJoining) return;
    final detail = ref.read(contestDetailProvider(widget.contestId)).value;
    if (detail != null && !detail.contest.isLiveReservationOpen) return;
    setState(() => _isJoining = true);

    try {
      await Supabase.instance.client.rpc(
        'join_live_quiz_waiting_room',
        params: {'p_contest_id': widget.contestId},
      );
      _hasJoinedWaitingRoom = true;
      unawaited(
        AppLogger.info(
          'live_quiz',
          'join_waiting_room',
          'Joueur entre dans la salle attente QL.',
          entityType: 'contest',
          entityId: widget.contestId,
          metadata: {'connection_quality': _connectionQuality},
        ),
      );
      _recomputeConnectionQuality();
      clearContestDetailCache(widget.contestId);
      ref.invalidate(contestDetailProvider(widget.contestId));
    } catch (error) {
      if (AppTelemetryService.isRetryableNetworkError(error)) {
        _lastNetworkIssueAt = DateTime.now();
        _recomputeConnectionQuality();
      }
      unawaited(
        AppLogger.warning(
          'live_quiz',
          'join_waiting_room_failed',
          'Echec entree salle attente QL.',
          entityType: 'contest',
          entityId: widget.contestId,
          metadata: {
            'retryable_network': AppTelemetryService.isRetryableNetworkError(
              error,
            ),
            'error': error.toString(),
          },
        ),
      );
      // The screen still acts as the waiting surface if the player is already in
      // the room or if the server window just changed while navigating.
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  void _tick() {
    final detail = ref.read(contestDetailProvider(widget.contestId)).value;
    final startsAt = detail?.contest.liveStartsAt;
    if (startsAt == null) return;

    final syncedNow = SyncedClockService.now();
    final remaining = startsAt.difference(syncedNow);
    final nextRemaining = remaining.isNegative
        ? Duration.zero
        : Duration(seconds: (remaining.inMilliseconds / 1000).ceil());
    final nextArenaWindowOpen =
        remaining <= const Duration(minutes: 5) && remaining > Duration.zero;
    final serverSecond = SyncedClockService.currentServerSecond;
    if (!mounted) return;
    if (_remaining != nextRemaining ||
        _isArenaWindowOpen != nextArenaWindowOpen ||
        _lastRenderedServerSecond != serverSecond) {
      setState(() {
        _remaining = nextRemaining;
        _isArenaWindowOpen = nextArenaWindowOpen;
        _lastRenderedServerSecond = serverSecond;
      });
    }

    if (!_hasJoinedWaitingRoom && !_isJoining && remaining > Duration.zero) {
      unawaited(_joinWaitingRoom());
    }

    if (!_finalClockSyncDone &&
        remaining <= const Duration(minutes: 1) &&
        remaining > Duration.zero) {
      _finalClockSyncDone = true;
      unawaited(
        SyncedClockService.sync(force: true).whenComplete(() {
          if (mounted) _tick();
        }),
      );
    }

    if (!remaining.isNegative && remaining > Duration.zero) return;
    final lastAttemptAt = _lastAutoStartAttemptAt;
    if (_isStarting ||
        (_autoStartFailed && _autoStartAttempts >= _autoStartMaxAttempts) ||
        (lastAttemptAt != null &&
            DateTime.now().difference(lastAttemptAt) < _autoStartRetryDelay)) {
      return;
    }
    _lastAutoStartAttemptAt = DateTime.now();
    _autoStartAttempts += 1;
    unawaited(_startQuiz());
  }

  Future<void> _startQuiz({bool manual = false}) async {
    if (_isStarting) return;
    var detail = ref.read(contestDetailProvider(widget.contestId)).value;
    if (detail == null) return;

    if (manual) {
      _autoStartFailed = false;
      _autoStartAttempts = 0;
    }

    final now = SyncedClockService.now();
    final liveStartsAt = detail.contest.liveStartsAt;
    final shouldForceServerSync =
        detail.contest.isLive &&
        liveStartsAt != null &&
        !now.isBefore(liveStartsAt);

    if (shouldForceServerSync) {
      detail =
          await _refreshContestDetailFromServer(forceProcessLiveEvents: true) ??
          detail;
      if (!mounted) return;
    }

    if (detail.contest.isLiveEnded) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ce Quiz Live est terminé.')),
      );
      context.go('/home');
      return;
    }

    final refreshedLiveStartsAt = detail.contest.liveStartsAt;
    final canAttemptStart =
        detail.contest.isLiveActiveNow ||
        (detail.contest.isLiveWaitingStatus &&
            refreshedLiveStartsAt != null &&
            !SyncedClockService.now().isBefore(refreshedLiveStartsAt));

    if (!detail.contest.isLiveReady || !canAttemptStart) {
      if (!manual) {
        _autoStartFailed = true;
        unawaited(
          AppLogger.warning(
            'live_quiz',
            'auto_start_deferred',
            'Demarrage automatique differe: etat QL pas encore pret.',
            entityType: 'contest',
            entityId: widget.contestId,
            metadata: {
              'live_status': detail.contest.liveStatus,
              'is_live_ready': detail.contest.isLiveReady,
              'attempt': _autoStartAttempts,
            },
          ),
        );
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            detail.contest.isLiveQueued
                ? 'Ce Quiz Live est dans la file d’attente.'
                : 'L’arène du Quiz Live se prépare. Reviens vite.',
          ),
        ),
      );
      return;
    }

    if (!await NetworkStatusService.instance.ensureOnline()) {
      if (!manual) {
        _autoStartFailed = true;
        _lastNetworkIssueAt = DateTime.now();
        _recomputeConnectionQuality();
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(NetworkStatusService.offlineActionMessage),
        ),
      );
      return;
    }

    setState(() => _isStarting = true);
    try {
      final result = await startLiveQuizParticipation(data: detail);
      await LiveQuizNotificationService.cancelWaitingNotification(
        widget.contestId,
      );
      clearContestDetailCache(widget.contestId);
      if (!mounted) return;
      context.go(
        '/contests/${widget.contestId}/quiz',
        extra: {'participationId': result.participationId},
      );
    } catch (error, stackTrace) {
      unawaited(
        AppTelemetryService.recordError(
          error,
          stackTrace,
          reason: 'live_quiz_auto_start_failed',
          context: {'contest_id': widget.contestId},
        ),
      );
      if (!mounted) return;
      if (manual) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppTelemetryService.userMessageForError(
                error,
                fallback: 'Le démarrage automatique a échoué. Réessaie.',
              ),
            ),
          ),
        );
      }
      setState(() {
        _isStarting = false;
        _autoStartFailed = true;
      });
    }
  }

  Future<ContestDetailData?> _refreshContestDetailFromServer({
    required bool forceProcessLiveEvents,
  }) async {
    try {
      await SyncedClockService.sync(force: true);
      if (forceProcessLiveEvents &&
          NetworkStatusService.instance.canAttemptNetwork) {
        await Supabase.instance.client.rpc('process_live_quiz_events');
      }
      clearContestDetailCache(widget.contestId);
      ref.invalidate(contestDetailProvider(widget.contestId));
      return await ref.read(contestDetailProvider(widget.contestId).future);
    } catch (error, stackTrace) {
      if (AppTelemetryService.isRetryableNetworkError(error)) {
        _lastNetworkIssueAt = DateTime.now();
        _recomputeConnectionQuality();
      }
      unawaited(
        AppLogger.warning(
          'live_quiz',
          'refresh_live_state_failed',
          'Impossible de rafraichir etat QL avant demarrage.',
          entityType: 'contest',
          entityId: widget.contestId,
          metadata: {'error': error.toString()},
        ),
      );
      unawaited(
        AppTelemetryService.recordError(
          error,
          stackTrace,
          reason: 'live_quiz_refresh_before_start_failed',
          context: {'contest_id': widget.contestId},
        ),
      );
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(contestDetailProvider(widget.contestId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: detail.when(
          data: (data) {
            if (data.contest.isLiveEnded) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!context.mounted) return;
                clearContestDetailCache(widget.contestId);
                clearHomeBootstrapCache(
                  userId: Supabase.instance.client.auth.currentUser?.id,
                  clearStored: true,
                );
                ref.invalidate(contestDetailProvider(widget.contestId));
                ref.invalidate(contestsProvider);
                ref.invalidate(homeBootstrapProvider);
                context.go('/home');
              });
              return const Center(child: CircularProgressIndicator());
            }

            final startsAt = data.contest.liveStartsAt;
            final rawRemaining = startsAt == null
                ? _remaining
                : startsAt.difference(SyncedClockService.now());
            final effectiveRemaining = rawRemaining.isNegative
                ? Duration.zero
                : Duration(
                    seconds: (rawRemaining.inMilliseconds / 1000).ceil(),
                  );
            final arenaWindowOpen =
                startsAt != null &&
                rawRemaining <= const Duration(minutes: 5) &&
                rawRemaining > Duration.zero;
            _syncWaitingNotification(data, startsAt);
            _maybePreloadQuizAssets(data, startsAt, effectiveRemaining);

            return Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () =>
                          context.go('/contests/${widget.contestId}'),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isTight = constraints.maxHeight < 560;
                        final isVeryTight = constraints.maxHeight < 480;
                        final iconSize = isVeryTight
                            ? 58.0
                            : isTight
                            ? 72.0
                            : 92.0;
                        final timerFontSize = isVeryTight
                            ? 30.0
                            : isTight
                            ? 34.0
                            : 40.0;
                        final sectionGap = isVeryTight
                            ? 8.0
                            : isTight
                            ? 10.0
                            : 14.0;
                        final cardPadding = isVeryTight
                            ? 12.0
                            : isTight
                            ? 14.0
                            : 16.0;

                        return FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.topCenter,
                          child: SizedBox(
                            width: constraints.maxWidth,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(height: isVeryTight ? 2 : 8),
                                Align(
                                  child: Container(
                                    width: iconSize,
                                    height: iconSize,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.primary.withValues(
                                        alpha: 0.16,
                                      ),
                                      border: Border.all(
                                        color: AppColors.primaryLight
                                            .withValues(alpha: 0.34),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primary.withValues(
                                            alpha: 0.20,
                                          ),
                                          blurRadius: isVeryTight ? 22 : 32,
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      Icons.bolt_rounded,
                                      color: AppColors.primaryLight,
                                      size: iconSize * 0.50,
                                    ),
                                  ),
                                ),
                                SizedBox(height: sectionGap),
                                Text(
                                  'Salle d’attente',
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.h1.copyWith(
                                    fontSize: isVeryTight ? 24 : 28,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  data.contest.title,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.bodySecondary.copyWith(
                                    fontSize: isVeryTight ? 12 : 13,
                                  ),
                                ),
                                SizedBox(height: sectionGap),
                                AppCard(
                                  padding: EdgeInsets.all(cardPadding),
                                  child: Column(
                                    children: [
                                      Text(
                                        'Départ dans',
                                        style: AppTextStyles.label,
                                      ),
                                      const SizedBox(height: 6),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          _formatDuration(effectiveRemaining),
                                          maxLines: 1,
                                          style: AppTextStyles.h1.copyWith(
                                            color: AppColors.primaryLight,
                                            fontSize: timerFontSize,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '${data.contest.registeredCount} inscrit(s) · ${data.contest.connectedCount} prêt(s)',
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTextStyles.bodySecondary
                                            .copyWith(
                                              fontSize: isVeryTight ? 11 : 12,
                                            ),
                                      ),
                                      if (arenaWindowOpen &&
                                          (_isPreloadingAssets ||
                                              !_hasPreloadedAssets)) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          'Chargement de l’arène...',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTextStyles.bodySmall
                                              .copyWith(
                                                color: AppColors.primaryLight,
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ] else if (arenaWindowOpen ||
                                          _hasPreloadedAssets) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          'Arène prête',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTextStyles.bodySmall
                                              .copyWith(
                                                color: AppColors.accentGreen,
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                SizedBox(height: isVeryTight ? 8 : 10),
                                _ConnectionQualityCard(
                                  percent: _connectionQuality,
                                  label: _connectionQualityLabel(
                                    _connectionQuality,
                                  ),
                                  latency: _lastServerLatency,
                                  isChecking: _isCheckingConnectionQuality,
                                  compact: isTight,
                                ),
                                SizedBox(height: isVeryTight ? 7 : 10),
                                AppCard(
                                  padding: EdgeInsets.all(
                                    isVeryTight ? 11 : 13,
                                  ),
                                  child: Text(
                                    'Reste sur cette page. Le quiz démarre automatiquement à l’heure exacte.',
                                    textAlign: TextAlign.center,
                                    maxLines: isVeryTight ? 2 : 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.bodySecondary.copyWith(
                                      fontSize: isVeryTight ? 11 : 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  AppButton(
                    text: effectiveRemaining == Duration.zero
                        ? _isStarting
                              ? 'Lancement du quiz...'
                              : 'Démarrer maintenant'
                        : _isJoining
                        ? 'Entrée en salle...'
                        : 'Le quiz démarre automatiquement',
                    isLoading: _isStarting || _isJoining,
                    onPressed:
                        effectiveRemaining == Duration.zero && !_isStarting
                        ? () => _startQuiz(manual: true)
                        : null,
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: AppCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Salle indisponible', style: AppTextStyles.h2),
                    const SizedBox(height: 8),
                    Text('$error', style: AppTextStyles.bodySecondary),
                    const SizedBox(height: 16),
                    AppButton(
                      text: 'Retour',
                      onPressed: () =>
                          context.go('/contests/${widget.contestId}'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _syncWaitingNotification(ContestDetailData data, DateTime? startsAt) {
    if (startsAt == null) return;

    final signature = [
      data.contest.id,
      startsAt.millisecondsSinceEpoch,
      data.contest.registeredCount,
      data.contest.connectedCount,
    ].join('|');
    if (_lastLiveActivitySignature == signature) return;
    _lastLiveActivitySignature = signature;

    const showClassicNotification = false;

    unawaited(
      LiveQuizNotificationService.showWaitingNotification(
        contestId: data.contest.id,
        title: data.contest.title,
        startsAt: startsAt,
        prizeLabel: _formatPrize(data.contest.prizeValue),
        registeredCount: data.contest.registeredCount,
        connectedCount: data.contest.connectedCount,
        showClassicNotification: showClassicNotification,
      ),
    );
  }

  void _maybePreloadQuizAssets(
    ContestDetailData data,
    DateTime? startsAt,
    Duration remaining,
  ) {
    if (startsAt == null || !data.contest.isLiveReady) return;
    if (remaining > const Duration(minutes: 5)) return;
    final signature = [
      data.contest.id,
      startsAt.millisecondsSinceEpoch,
      data.contest.liveDurationSeconds,
      data.contest.liveQuestionsCount,
    ].join('|');
    if (_preloadedAssetsSignature == signature) return;
    _preloadedAssetsSignature = signature;
    _hasPreloadedAssets = false;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final startedAt = DateTime.now();
      setState(() => _isPreloadingAssets = true);
      unawaited(
        QuizAssetPreloadService.preloadForContest(
          context,
          contestId: data.contest.id,
        ).whenComplete(() async {
          final elapsed = DateTime.now().difference(startedAt);
          const minimumVisibleDuration = Duration(seconds: 3);
          if (elapsed < minimumVisibleDuration) {
            await Future<void>.delayed(minimumVisibleDuration - elapsed);
          }
          if (mounted) {
            setState(() {
              _isPreloadingAssets = false;
              _hasPreloadedAssets = true;
            });
          }
        }),
      );
    });
  }

  void _startConnectionQualityChecks() {
    unawaited(_checkConnectionQuality());
    _connectionQualityTimer?.cancel();
    _connectionQualityTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => unawaited(_checkConnectionQuality()),
    );
  }

  Future<void> _checkConnectionQuality() async {
    if (_isCheckingConnectionQuality) return;
    _isCheckingConnectionQuality = true;
    if (mounted) setState(() {});

    try {
      final localBefore = DateTime.now();
      final response = await Supabase.instance.client.rpc('server_now');
      final localAfter = DateTime.now();
      final serverNow = DateTime.tryParse(response.toString());
      _lastServerLatency = localAfter.difference(localBefore);

      if (serverNow != null) {
        final localMidpoint = localBefore.add(
          Duration(
            microseconds:
                localAfter.difference(localBefore).inMicroseconds ~/ 2,
          ),
        );
        _recomputeConnectionQuality(
          measuredOffset: serverNow.difference(localMidpoint),
        );
      } else {
        _recomputeConnectionQuality();
      }
    } catch (error) {
      if (AppTelemetryService.isRetryableNetworkError(error)) {
        _lastNetworkIssueAt = DateTime.now();
      }
      _recomputeConnectionQuality();
    } finally {
      _isCheckingConnectionQuality = false;
      if (mounted) setState(() {});
    }
  }

  void _recomputeConnectionQuality({Duration? measuredOffset}) {
    final now = DateTime.now();
    var score = 100;

    final latencyMs = _lastServerLatency?.inMilliseconds;
    if (latencyMs == null) {
      score -= 12;
    } else if (latencyMs > 2000) {
      score -= 50;
    } else if (latencyMs > 1000) {
      score -= 35;
    } else if (latencyMs > 500) {
      score -= 18;
    } else if (latencyMs > 250) {
      score -= 8;
    }

    final offsetMs = measuredOffset?.inMilliseconds.abs();
    if (offsetMs == null) {
      score -= 5;
    } else if (offsetMs > 3000) {
      score -= 20;
    } else if (offsetMs > 1500) {
      score -= 12;
    } else if (offsetMs > 500) {
      score -= 5;
    }

    final realtimeAge = _lastRealtimeUpdateAt == null
        ? null
        : now.difference(_lastRealtimeUpdateAt!);
    if (realtimeAge == null) {
      score -= 8;
    } else if (realtimeAge > const Duration(minutes: 2)) {
      score -= 28;
    } else if (realtimeAge > const Duration(minutes: 1)) {
      score -= 18;
    } else if (realtimeAge > const Duration(seconds: 20)) {
      score -= 8;
    }

    final issueAge = _lastNetworkIssueAt == null
        ? null
        : now.difference(_lastNetworkIssueAt!);
    if (issueAge != null && issueAge < const Duration(seconds: 30)) {
      score -= 25;
    } else if (issueAge != null && issueAge < const Duration(minutes: 2)) {
      score -= 10;
    }

    if (!_hasJoinedWaitingRoom) score -= 5;

    final nextQuality = score.clamp(5, 100).toInt();
    if (!mounted) {
      _connectionQuality = nextQuality;
      return;
    }
    if (_connectionQuality != nextQuality) {
      setState(() => _connectionQuality = nextQuality);
    }
  }

  String _connectionQualityLabel(int percent) {
    if (percent >= 90) return 'Excellente';
    if (percent >= 75) return 'Bonne';
    if (percent >= 55) return 'Moyenne';
    return 'Instable';
  }
}

class _ConnectionQualityCard extends StatelessWidget {
  final int percent;
  final String label;
  final Duration? latency;
  final bool isChecking;
  final bool compact;

  const _ConnectionQualityCard({
    required this.percent,
    required this.label,
    required this.latency,
    required this.isChecking,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = percent >= 75
        ? AppColors.accentGreen
        : percent >= 55
        ? AppColors.gold
        : AppColors.accentRed;
    final latencyLabel = latency == null
        ? 'mesure en cours'
        : '${latency!.inMilliseconds} ms';

    return AppCard(
      padding: EdgeInsets.fromLTRB(14, compact ? 9 : 12, 14, compact ? 9 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.network_check_rounded, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Qualité internet $percent% · $label',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                    fontSize: compact ? 12 : null,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (isChecking)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                ),
            ],
          ),
          SizedBox(height: compact ? 7 : 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: percent / 100,
              minHeight: compact ? 6 : 7,
              backgroundColor: AppColors.surfaceBorder,
              color: color,
            ),
          ),
          SizedBox(height: compact ? 5 : 7),
          Text(
            'Temps de réponse: $latencyLabel',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontSize: compact ? 10.5 : null,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDuration(Duration duration) {
  final days = duration.inDays;
  final hours = duration.inHours.remainder(24);
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');

  if (days > 0) {
    return '${days}j ${hours}h ${minutes.toString().padLeft(2, '0')}min';
  }
  if (duration.inHours > 0) {
    return '${duration.inHours}h ${minutes.toString().padLeft(2, '0')}min';
  }

  return '${minutes.toString().padLeft(2, '0')}:$seconds';
}

String _formatPrize(num value) {
  if (AppStoreReviewMode.hideCashAmounts) {
    return 'Récompense partenaire';
  }
  return formatCurrencyAmount(value, zeroLabel: 'Récompense surprise');
}
