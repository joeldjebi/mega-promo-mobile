import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mega_promo/core/theme/app_colors.dart';
import 'package:mega_promo/core/theme/app_text_styles.dart';
import 'package:mega_promo/core/widgets/app_button.dart';
import 'package:mega_promo/core/widgets/app_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/live_quiz_notification_service.dart';
import '../../contests/providers/contest_providers.dart';
import '../services/live_quiz_service.dart';

class LiveQuizWaitingScreen extends ConsumerStatefulWidget {
  final String contestId;

  const LiveQuizWaitingScreen({super.key, required this.contestId});

  @override
  ConsumerState<LiveQuizWaitingScreen> createState() =>
      _LiveQuizWaitingScreenState();
}

class _LiveQuizWaitingScreenState extends ConsumerState<LiveQuizWaitingScreen> {
  Timer? _timer;
  bool _isJoining = false;
  bool _isStarting = false;
  bool _hasJoinedWaitingRoom = false;
  bool _notificationShown = false;
  bool _autoStartFailed = false;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    WidgetsBinding.instance.addPostFrameCallback((_) => _joinWaitingRoom());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _joinWaitingRoom() async {
    if (_isJoining) return;
    setState(() => _isJoining = true);

    try {
      await Supabase.instance.client.rpc(
        'join_live_quiz_waiting_room',
        params: {'p_contest_id': widget.contestId},
      );
      _hasJoinedWaitingRoom = true;
      clearContestDetailCache(widget.contestId);
      ref.invalidate(contestDetailProvider(widget.contestId));
    } catch (_) {
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

    final remaining = startsAt.difference(DateTime.now());
    if (!mounted) return;
    setState(() => _remaining = remaining.isNegative ? Duration.zero : remaining);

    if (!_hasJoinedWaitingRoom &&
        !_isJoining &&
        remaining <= const Duration(minutes: 5) &&
        remaining > Duration.zero) {
      unawaited(_joinWaitingRoom());
    }

    if (!remaining.isNegative && remaining > Duration.zero) return;
    if (_autoStartFailed) return;
    unawaited(_startQuiz());
  }

  Future<void> _startQuiz({bool manual = false}) async {
    if (_isStarting) return;
    final detail = ref.read(contestDetailProvider(widget.contestId)).value;
    if (detail == null) return;

    if (manual) _autoStartFailed = false;
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
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
      setState(() {
        _isStarting = false;
        _autoStartFailed = true;
      });
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
            final startsAt = data.contest.liveStartsAt;
            final rawRemaining = startsAt == null
                ? _remaining
                : startsAt.difference(DateTime.now());
            final effectiveRemaining = rawRemaining.isNegative
                ? Duration.zero
                : rawRemaining;
            if (startsAt != null && !_notificationShown) {
              _notificationShown = true;
              unawaited(
                LiveQuizNotificationService.showWaitingNotification(
                  contestId: data.contest.id,
                  title: data.contest.title,
                  startsAt: startsAt,
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => context.go('/contests/${widget.contestId}'),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 108,
                    height: 108,
                    margin: const EdgeInsets.only(bottom: 22),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(alpha: 0.16),
                      border: Border.all(
                        color: AppColors.primaryLight.withValues(alpha: 0.34),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.24),
                          blurRadius: 38,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.bolt_rounded,
                      color: AppColors.primaryLight,
                      size: 54,
                    ),
                  ),
                  Text(
                    'Salle d’attente',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.h1,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    data.contest.title,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySecondary,
                  ),
                  const SizedBox(height: 26),
                  AppCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        Text('Départ dans', style: AppTextStyles.label),
                        const SizedBox(height: 10),
                        Text(
                          _formatDuration(effectiveRemaining),
                          style: AppTextStyles.h1.copyWith(
                            color: AppColors.primaryLight,
                            fontSize: 42,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${data.contest.registeredCount} inscrit(s) · ${data.contest.connectedCount} prêt(s)',
                          style: AppTextStyles.bodySecondary,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppCard(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Reste sur cette page. À l’heure exacte, le quiz démarre automatiquement. Si ton téléphone est verrouillé, la notification Quiz Live reste visible sur Android.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySecondary,
                    ),
                  ),
                  const Spacer(),
                  AppButton(
                    text: effectiveRemaining == Duration.zero
                        ? _isStarting
                              ? 'Lancement du quiz...'
                              : 'Démarrer maintenant'
                        : _isJoining
                        ? 'Entrée en salle...'
                        : 'Le quiz démarre automatiquement',
                    isLoading: _isStarting || _isJoining,
                    onPressed: effectiveRemaining == Duration.zero && !_isStarting
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
                      onPressed: () => context.go('/contests/${widget.contestId}'),
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
}

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
