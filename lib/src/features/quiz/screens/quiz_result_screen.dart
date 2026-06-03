import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mega_promo/core/theme/app_colors.dart';
import 'package:mega_promo/core/theme/app_text_styles.dart';
import 'package:mega_promo/core/widgets/app_button.dart';
import 'package:mega_promo/core/widgets/app_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../home/providers/user_profile_provider.dart';
import '../../rewards/services/badge_award_service.dart';
import '../../../services/app_logger.dart';
import '../../../services/app_telemetry_service.dart';
import '../../../services/network_status_service.dart';
import '../../social/share_helpers.dart';
import '../models/question.dart';
import '../services/quiz_asset_preload_service.dart';
import '../services/quiz_result_sync_service.dart';

class QuizResultScreen extends ConsumerStatefulWidget {
  final String contestId;
  final String participationId;
  final List<QuizQuestion> questions;
  final List<QuizAnswer> answers;
  final int? liveElapsedMs;

  const QuizResultScreen({
    super.key,
    required this.contestId,
    required this.participationId,
    required this.questions,
    required this.answers,
    this.liveElapsedMs,
  });

  @override
  ConsumerState<QuizResultScreen> createState() => _QuizResultScreenState();
}

class _QuizResultScreenState extends ConsumerState<QuizResultScreen> {
  bool _saved = false;
  Future<_ContestResultVisibility>? _visibilityFuture;
  Future<_StoredQuizResult?>? _storedResultFuture;
  List<QuizQuestion>? _storedQuestions;
  List<QuizAnswer>? _storedAnswers;

  List<QuizQuestion> get _questions => widget.questions.isNotEmpty
      ? widget.questions
      : _storedQuestions ?? const [];

  List<QuizAnswer> get _answers =>
      widget.answers.isNotEmpty ? widget.answers : _storedAnswers ?? const [];

  int get _correct => _answers.where((answer) => answer.isCorrect).length;
  int get _points => _answers.fold(0, (sum, answer) => sum + answer.points);
  int get _durationMs =>
      widget.liveElapsedMs ??
      _answers.fold(0, (sum, answer) => sum + answer.elapsedMs);
  double get _ratio => _questions.isEmpty ? 0 : _correct / _questions.length;

  QuizAnswer _answerAt(int index) {
    final answers = _answers;
    if (index < answers.length) return answers[index];
    final question = _questions[index];
    return QuizAnswer(
      questionId: question.id,
      selectedIndex: null,
      correctIndex: question.correctIndex,
      isCorrect: false,
      points: 0,
      elapsedMs: (question.timeLimit <= 0 ? 30 : question.timeLimit) * 1000,
    );
  }

  String _answerLabel(int? index) {
    if (index == null) return 'Non répondu';
    return String.fromCharCode(65 + index);
  }

  String _answerText(QuizQuestion question, int? index) {
    if (index == null) return 'Non répondu';
    if (index < 0 || index >= question.options.length) {
      return _answerLabel(index);
    }
    final optionText = question.optionLabel(index).trim();
    if (optionText.isEmpty) return _answerLabel(index);
    return '${_answerLabel(index)} · $optionText';
  }

  String _formatDuration(int milliseconds) {
    final safeMilliseconds = milliseconds.clamp(0, 999999999);
    final minutes = safeMilliseconds ~/ Duration.millisecondsPerMinute;
    final seconds =
        (safeMilliseconds % Duration.millisecondsPerMinute) ~/
        Duration.millisecondsPerSecond;
    final remainingMilliseconds =
        safeMilliseconds % Duration.millisecondsPerSecond;
    final millisecondsLabel = remainingMilliseconds.toString().padLeft(3, '0');

    if (minutes > 0) {
      final secondsLabel = seconds.toString().padLeft(2, '0');
      return '$minutes min $secondsLabel s $millisecondsLabel ms';
    }

    return '$seconds s $millisecondsLabel ms';
  }

  @override
  void initState() {
    super.initState();
    _visibilityFuture = _loadContestResultVisibility();
    if (widget.questions.isEmpty || widget.answers.isEmpty) {
      _storedResultFuture = _loadStoredQuizResult();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.answers.isNotEmpty) unawaited(_saveResult());
    });
  }

  Future<_StoredQuizResult?> _loadStoredQuizResult() async {
    final participationId = widget.participationId.trim();
    if (participationId.isEmpty) return null;

    final row = await Supabase.instance.client
        .from('participations')
        .select('id, answers')
        .eq('id', participationId)
        .maybeSingle();
    if (row == null) return null;

    final payload = row['answers'];
    final answersMap = payload is Map
        ? Map<String, dynamic>.from(payload)
        : const <String, dynamic>{};
    final items = answersMap['items'];
    final answers = items is List
        ? items
              .whereType<Map>()
              .map(
                (item) => _quizAnswerFromJson(Map<String, dynamic>.from(item)),
              )
              .toList()
        : const <QuizAnswer>[];
    final questions = await QuizAssetPreloadService.fetchParticipationQuestions(
      contestId: widget.contestId,
      participationId: participationId,
    );
    if (mounted) {
      setState(() {
        _storedQuestions = questions;
        _storedAnswers = answers;
      });
    }
    return _StoredQuizResult(questions: questions, answers: answers);
  }

  Future<_ContestResultVisibility> _loadContestResultVisibility() async {
    try {
      final row = await Supabase.instance.client
          .from('contests')
          .select('id, type, status, is_live, ends_at, live_status')
          .eq('id', widget.contestId)
          .maybeSingle();
      if (row == null) return const _ContestResultVisibility.hidden();

      final isLive = row['is_live'] as bool? ?? false;
      final type = (row['type'] as String? ?? '').toLowerCase().trim();
      if (isLive) return const _ContestResultVisibility.visible();
      if (type != 'quiz') return const _ContestResultVisibility.visible();

      final status = (row['status'] as String? ?? '').toLowerCase().trim();
      final endsAt = DateTime.tryParse(row['ends_at'] as String? ?? '');
      final isFinished =
          status == 'ended' ||
          status == 'completed' ||
          status == 'finished' ||
          (endsAt != null && !endsAt.isAfter(DateTime.now()));

      return isFinished
          ? const _ContestResultVisibility.visible()
          : _ContestResultVisibility.hidden(endsAt: endsAt);
    } catch (error) {
      NetworkStatusService.instance.markOfflineFromError(error);
      return const _ContestResultVisibility.hidden();
    }
  }

  Future<void> _saveResult() async {
    if (_saved || !mounted) return;
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final contestId = widget.contestId;
    final participationId = widget.participationId;
    final totalQuestions = widget.questions.length;
    final points = _points;
    final durationMs = _durationMs;
    final correctCount = _correct;
    final answersPayload = widget.answers
        .map((answer) => answer.toJson())
        .toList();
    final useBackendScoring =
        participationId.isNotEmpty && widget.liveElapsedMs == null;

    await QuizResultSyncService.enqueue(
      userId: user.id,
      contestId: contestId,
      participationId: participationId,
      points: points,
      durationMs: durationMs,
      correctCount: correctCount,
      totalQuestions: totalQuestions,
      answers: answersPayload,
      backendScoring: useBackendScoring,
    );

    if (!await NetworkStatusService.instance.ensureOnline()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Résultat non confirmé, réessaie avant de quitter.'),
        ),
      );
      return;
    }

    _saved = true;
    try {
      final profile = await ref.read(userProfileProvider.future);
      var savedPoints = points;
      var savedDurationMs = durationMs;
      var savedCorrectCount = correctCount;
      var savedTotalQuestions = totalQuestions;

      if (useBackendScoring) {
        final result = await supabase.rpc(
          'submit_quiz_result',
          params: {
            'p_participation_id': participationId,
            'p_answers': answersPayload,
          },
        );
        if (result is Map) {
          savedPoints = (result['score'] as num?)?.toInt() ?? savedPoints;
          savedDurationMs =
              (result['duration_ms'] as num?)?.toInt() ?? savedDurationMs;
          savedCorrectCount =
              (result['correct_count'] as num?)?.toInt() ?? savedCorrectCount;
          savedTotalQuestions =
              (result['total_questions'] as num?)?.toInt() ??
              savedTotalQuestions;
        }
      } else if (participationId.isNotEmpty) {
        await supabase
            .from('participations')
            .update({
              'score': points,
              'answers': {
                'type': 'quiz',
                'status': 'completed',
                'completed_at': DateTime.now().toIso8601String(),
                'duration_ms': durationMs,
                'correct_count': correctCount,
                'total_questions': totalQuestions,
                'items': answersPayload,
              },
              'completed': true,
            })
            .eq('id', participationId)
            .eq('user_id', user.id);
      } else {
        await supabase.from('participations').insert({
          'user_id': user.id,
          'contest_id': contestId,
          'score': points,
          'answers': {
            'type': 'quiz',
            'status': 'completed',
            'completed_at': DateTime.now().toIso8601String(),
            'duration_ms': durationMs,
            'correct_count': correctCount,
            'total_questions': totalQuestions,
            'items': answersPayload,
          },
          'completed': true,
        });
        await supabase
            .from('users')
            .update({
              'participations_today': profile.participationsToday + 1,
              'last_participation_date': DateTime.now().toIso8601String().split(
                'T',
              )[0],
            })
            .eq('id', user.id);
      }

      if (!useBackendScoring) {
        await supabase
            .from('users')
            .update({'points_total': profile.pointsTotal + savedPoints})
            .eq('id', user.id);
      }

      await awardBadgesAfterParticipation(
        supabase: supabase,
        profile: profile,
        nextParticipationsToday: participationId.isNotEmpty
            ? profile.participationsToday
            : profile.participationsToday + 1,
        nextPointsTotal: profile.pointsTotal + savedPoints,
      );

      unawaited(
        AppLogger.info(
          'quiz',
          'result_saved',
          'Resultat quiz sauvegarde.',
          entityType: 'contest',
          entityId: contestId,
          metadata: {
            'participation_id': participationId.isEmpty
                ? null
                : participationId,
            'points': savedPoints,
            'duration_ms': savedDurationMs,
            'correct_count': savedCorrectCount,
            'total_questions': savedTotalQuestions,
            'computed_by_backend': useBackendScoring,
          },
        ),
      );

      unawaited(QuizResultSyncService.syncPending());
      if (!mounted) return;
      ref.invalidate(userProfileProvider);
    } catch (error, stackTrace) {
      if (AppTelemetryService.isRetryableNetworkError(error)) {
        _saved = false;
        debugPrint('[QUIZ_RESULT][save_network_retry] $error');
      } else {
        unawaited(
          AppLogger.error(
            'quiz',
            'result_save_failed',
            'Echec sauvegarde resultat quiz.',
            entityType: 'contest',
            entityId: contestId,
            error: error,
            stackTrace: stackTrace,
          ),
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Résultat non confirmé, réessaie avant de quitter.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FutureBuilder<_ContestResultVisibility>(
          future: _visibilityFuture,
          builder: (context, snapshot) {
            final visibility = snapshot.data;
            if (visibility == null || !visibility.canShowResult) {
              return _PendingContestResultView(
                contestId: widget.contestId,
                availableAt: visibility?.availableAt,
              );
            }

            final storedResultFuture = _storedResultFuture;
            if (storedResultFuture != null &&
                (_storedQuestions == null || _storedAnswers == null)) {
              return FutureBuilder<_StoredQuizResult?>(
                future: storedResultFuture,
                builder: (context, storedSnapshot) {
                  if (storedSnapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final stored = storedSnapshot.data;
                  if (stored == null || stored.answers.isEmpty) {
                    return const _StoredResultUnavailableView();
                  }
                  return _buildResultList(context);
                },
              );
            }

            return _buildResultList(context);
          },
        ),
      ),
    );
  }

  Widget _buildResultList(BuildContext context) {
    final icon = _ratio > 0.8
        ? Icons.emoji_events_rounded
        : _ratio >= 0.5
        ? Icons.auto_awesome_rounded
        : Icons.favorite_rounded;
    final color = _ratio > 0.8
        ? AppColors.gold
        : _ratio >= 0.5
        ? AppColors.primaryLight
        : AppColors.accentGreen;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      children: [
        AppCard(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          borderRadius: 18,
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.16),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: color, size: 26),
                      )
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .scale(curve: Curves.easeOutBack),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Score final', style: AppTextStyles.h3),
                        const SizedBox(height: 2),
                        Text(
                          '+$_points points',
                          style: AppTextStyles.price.copyWith(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _ResultStat(
                      label: 'Bonnes réponses',
                      value: '$_correct/${_questions.length}',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ResultStat(
                      label: 'Réussite',
                      value: '${(_ratio * 100).round()}%',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _ResultStat(
                label: 'Temps de réponse global',
                value: _formatDuration(_durationMs),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Text('Réponses', style: AppTextStyles.h2),
        const SizedBox(height: 14),
        ...List.generate(_questions.length, (index) {
          final question = _questions[index];
          final answer = _answerAt(index);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              padding: const EdgeInsets.all(14),
              borderRadius: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        answer.isCorrect
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        color: answer.isCorrect
                            ? AppColors.accentGreen
                            : AppColors.accentRed,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (question.questionText.trim().isNotEmpty)
                              Text(
                                question.questionText,
                                style: AppTextStyles.body.copyWith(
                                  fontWeight: FontWeight.w700,
                                  height: 1.35,
                                ),
                              ),
                            if (question.hasQuestionImage) ...[
                              if (question.questionText.trim().isNotEmpty)
                                const SizedBox(height: 8),
                              _ResultImage(
                                imageUrl: question.questionImageUrl!,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (question.hasImageOptions) ...[
                    const SizedBox(height: 10),
                    GridView.builder(
                      itemCount: question.optionImageUrls.length,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            crossAxisSpacing: 6,
                            mainAxisSpacing: 6,
                          ),
                      itemBuilder: (context, optionIndex) {
                        final isCorrect = optionIndex == answer.correctIndex;
                        final isSelected = optionIndex == answer.selectedIndex;
                        final color = isCorrect
                            ? AppColors.accentGreen
                            : isSelected
                            ? AppColors.accentRed
                            : AppColors.surfaceBorder;
                        return DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: color, width: 1.5),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: Image.network(
                              question.optionImageUrls[optionIndex]!,
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _AnswerPill(
                        label: 'Ta réponse',
                        value: _answerText(question, answer.selectedIndex),
                        color: answer.isCorrect
                            ? AppColors.accentGreen
                            : AppColors.accentRed,
                      ),
                      _AnswerPill(
                        label: 'Bonne réponse',
                        value: _answerText(question, answer.correctIndex),
                        color: AppColors.primaryLight,
                      ),
                      _AnswerPill(
                        label: 'Points',
                        value: '+${answer.points}',
                        color: AppColors.gold,
                      ),
                      _AnswerPill(
                        label: 'Temps',
                        value: _formatDuration(answer.elapsedMs),
                        color: AppColors.primaryLight,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 18),
        AppButton(
          text: 'Voir le classement',
          onPressed: () =>
              context.go('/leaderboard?contestId=${widget.contestId}'),
        ),
        const SizedBox(height: 12),
        AppButton(
          text: 'Partager mon score',
          isOutlined: true,
          onPressed: () => shareScore(
            contestTitle: 'Quiz MegaPromo',
            correctAnswers: _correct,
            totalQuestions: _questions.length,
            points: _points,
          ),
        ),
      ],
    );
  }
}

class _ContestResultVisibility {
  final bool canShowResult;
  final DateTime? availableAt;

  const _ContestResultVisibility._({
    required this.canShowResult,
    this.availableAt,
  });

  const _ContestResultVisibility.visible()
    : this._(canShowResult: true, availableAt: null);

  const _ContestResultVisibility.hidden({DateTime? endsAt})
    : this._(canShowResult: false, availableAt: endsAt);
}

class _StoredQuizResult {
  final List<QuizQuestion> questions;
  final List<QuizAnswer> answers;

  const _StoredQuizResult({required this.questions, required this.answers});
}

QuizAnswer _quizAnswerFromJson(Map<String, dynamic> json) {
  return QuizAnswer(
    questionId: json['question_id'] as String? ?? '',
    selectedIndex: (json['selected_index'] as num?)?.toInt(),
    correctIndex: (json['correct_index'] as num?)?.toInt() ?? 0,
    isCorrect: json['is_correct'] as bool? ?? false,
    points: (json['points'] as num?)?.toInt() ?? 0,
    elapsedMs: (json['elapsed_ms'] as num?)?.toInt() ?? 0,
  );
}

class _StoredResultUnavailableView extends StatelessWidget {
  const _StoredResultUnavailableView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: AppCard(
          padding: const EdgeInsets.all(18),
          borderRadius: 20,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: AppColors.textHint,
                size: 34,
              ),
              const SizedBox(height: 12),
              Text(
                'Résultat indisponible',
                textAlign: TextAlign.center,
                style: AppTextStyles.h3,
              ),
              const SizedBox(height: 6),
              Text(
                'Nous n’avons pas encore trouvé le détail de ta participation. Réessaie dans un instant.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySecondary,
              ),
              const SizedBox(height: 14),
              AppButton(
                text: 'Retour au concours',
                onPressed: () => context.pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingContestResultView extends StatelessWidget {
  final String contestId;
  final DateTime? availableAt;

  const _PendingContestResultView({
    required this.contestId,
    required this.availableAt,
  });

  @override
  Widget build(BuildContext context) {
    final availableLabel = availableAt == null
        ? 'après la fin du concours'
        : 'le ${availableAt!.day.toString().padLeft(2, '0')}/'
              '${availableAt!.month.toString().padLeft(2, '0')} '
              'à ${availableAt!.hour.toString().padLeft(2, '0')}:'
              '${availableAt!.minute.toString().padLeft(2, '0')}';

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      children: [
        AppCard(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
          borderRadius: 22,
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_clock_rounded,
                  color: AppColors.primary,
                  size: 34,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Participation enregistrée',
                textAlign: TextAlign.center,
                style: AppTextStyles.h2.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Ton résultat sera disponible $availableLabel. Tu recevras une notification lorsque le JCQ sera terminé.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySecondary.copyWith(height: 1.45),
              ),
              const SizedBox(height: 18),
              _ResultPrivacyNotice(),
            ],
          ),
        ),
        const SizedBox(height: 18),
        AppButton(
          text: 'Retour aux concours',
          onPressed: () => context.go('/contests'),
        ),
        const SizedBox(height: 12),
        AppButton(
          text: 'Voir le détail du concours',
          isOutlined: true,
          onPressed: () => context.go('/contests/$contestId'),
        ),
      ],
    );
  }
}

class _ResultPrivacyNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.verified_user_rounded,
            color: AppColors.accentGreen,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Pour préserver l’équité, les scores et les bonnes réponses restent masqués jusqu’à la clôture.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultImage extends StatelessWidget {
  final String imageUrl;

  const _ResultImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.network(
        imageUrl,
        height: 120,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: 120,
            color: AppColors.surfaceElevated,
            alignment: Alignment.center,
            child: const Icon(
              Icons.broken_image_rounded,
              color: AppColors.textHint,
            ),
          );
        },
      ),
    );
  }
}

class _ResultStat extends StatelessWidget {
  final String label;
  final String value;

  const _ResultStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        children: [
          Text(value, style: AppTextStyles.h3),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _AnswerPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _AnswerPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: RichText(
        text: TextSpan(
          style: AppTextStyles.bodySmall,
          children: [
            TextSpan(text: '$label · '),
            TextSpan(
              text: value,
              style: AppTextStyles.bodySmall.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
