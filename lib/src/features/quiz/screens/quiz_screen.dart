import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mega_promo/core/theme/app_colors.dart';
import 'package:mega_promo/core/theme/app_text_styles.dart';
import 'package:mega_promo/core/widgets/app_button.dart';
import 'package:mega_promo/core/widgets/app_card.dart';

import '../../../services/app_telemetry_service.dart';
import '../../../services/synced_clock_service.dart';
import '../../contests/providers/contest_providers.dart';
import '../models/question.dart';
import '../providers/quiz_providers.dart';

class QuizScreen extends ConsumerWidget {
  final String contestId;
  final String participationId;

  const QuizScreen({
    super.key,
    required this.contestId,
    required this.participationId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(contestDetailProvider(contestId));

    return detail.when(
      data: (detailData) {
        if (!detailData.contest.isAccessibleForPlan(
          detailData.userProfile.planKey,
        )) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: _QuizAccessDenied(
              label: detailData.contest.accessLabel,
              onBack: () => context.go('/contests/$contestId'),
            ),
          );
        }

        if (detailData.contest.isLive) {
          if (detailData.contest.isLiveEnded) {
            return Scaffold(
              backgroundColor: AppColors.background,
              body: _LiveQuizUnavailable(
                title: 'Quiz Live terminé',
                message:
                    'La fenêtre de jeu est fermée. Les résultats seront pris en compte selon les réponses envoyées dans le temps imparti.',
                onBack: () => context.go('/home'),
              ),
            );
          }

          if (!detailData.contest.isLiveActiveNow) {
            return Scaffold(
              backgroundColor: AppColors.background,
              body: _LiveQuizUnavailable(
                title: 'Quiz Live pas encore lancé',
                message:
                    'Reste en salle d’attente. Le quiz s’ouvrira automatiquement à l’heure prévue.',
                onBack: () => context.go('/contests/$contestId/live-waiting'),
              ),
            );
          }
        }

        if (detailData.hasParticipated && participationId.isEmpty) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: _QuizAlreadyStarted(
              onBack: () => context.go('/contests/$contestId'),
            ),
          );
        }

        final questions = ref.watch(quizQuestionsProvider(contestId));

        return Scaffold(
          backgroundColor: AppColors.background,
          body: questions.when(
            data: (items) => items.isEmpty
                ? const _EmptyQuiz()
                : _QuizRunner(
                    contestId: contestId,
                    participationId: participationId,
                    isLive: detailData.contest.isLive,
                    liveStartsAt: detailData.contest.liveStartsAt,
                    questions: items,
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => const _EmptyQuiz(),
          ),
        );
      },
      loading: () => const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => Scaffold(
        backgroundColor: AppColors.background,
        body: _LiveQuizUnavailable(
          title: 'Quiz indisponible',
          message: 'Impossible de vérifier l’état du quiz pour le moment.',
          onBack: () => context.go('/home'),
        ),
      ),
    );
  }
}

class _LiveQuizUnavailable extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onBack;

  const _LiveQuizUnavailable({
    required this.title,
    required this.message,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: AppCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.event_busy_rounded,
                color: AppColors.gold,
                size: 42,
              ),
              const SizedBox(height: 14),
              Text(title, textAlign: TextAlign.center, style: AppTextStyles.h2),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySecondary,
              ),
              const SizedBox(height: 20),
              AppButton(text: 'Retour', onPressed: onBack),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuizAccessDenied extends StatelessWidget {
  final String label;
  final VoidCallback onBack;

  const _QuizAccessDenied({required this.label, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: AppCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_rounded, color: AppColors.gold, size: 42),
              const SizedBox(height: 14),
              Text('Quiz réservé', style: AppTextStyles.h2),
              const SizedBox(height: 8),
              Text(
                'Ce quiz est accessible uniquement aux joueurs $label.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySecondary,
              ),
              const SizedBox(height: 20),
              AppButton(text: 'Retour au quiz', onPressed: onBack),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuizAlreadyStarted extends StatelessWidget {
  final VoidCallback onBack;

  const _QuizAlreadyStarted({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: AppCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_clock_rounded,
                color: AppColors.gold,
                size: 42,
              ),
              const SizedBox(height: 14),
              Text('Participation déjà lancée', style: AppTextStyles.h2),
              const SizedBox(height: 8),
              Text(
                'Tu as déjà ouvert ce quiz. Pour garantir l’équité, une participation commencée ne peut pas être relancée.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySecondary,
              ),
              const SizedBox(height: 20),
              AppButton(text: 'Retour au quiz', onPressed: onBack),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuizRunner extends StatefulWidget {
  final String contestId;
  final String participationId;
  final bool isLive;
  final DateTime? liveStartsAt;
  final List<QuizQuestion> questions;

  const _QuizRunner({
    required this.contestId,
    required this.participationId,
    required this.isLive,
    required this.liveStartsAt,
    required this.questions,
  });

  @override
  State<_QuizRunner> createState() => _QuizRunnerState();
}

class _QuizRunnerState extends State<_QuizRunner> with WidgetsBindingObserver {
  static const _reviewDelay = Duration(seconds: 2);

  final List<QuizAnswer> _answers = [];
  Timer? _timer;
  Timer? _autoNextTimer;
  DateTime? _questionStartedAt;
  int _index = 0;
  int _remaining = 30;
  int? _selectedIndex;
  bool _locked = false;
  bool _finishing = false;
  bool _isLiveSelfPaced = false;

  QuizQuestion get _question => widget.questions[_index];
  int get _liveDurationMs {
    return widget.questions.fold<int>(0, (total, question) {
      return total + (question.timeLimit <= 0 ? 30 : question.timeLimit) * 1000;
    });
  }

  DateTime? get _liveEndsAt {
    final liveStart = widget.liveStartsAt;
    if (!widget.isLive || liveStart == null) return null;
    return liveStart.add(Duration(milliseconds: _liveDurationMs));
  }

  @override
  void initState() {
    super.initState();
    unawaited(
      AppTelemetryService.setScreen(
        'QuizScreen',
        parameters: {
          'contest_id': widget.contestId,
          'participation_id': widget.participationId,
        },
      ),
    );
    unawaited(
      AppTelemetryService.setContext({
        'contest_id': widget.contestId,
        'participation_id': widget.participationId,
      }),
    );
    WidgetsBinding.instance.addObserver(this);
    _startQuestion();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _autoNextTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncWithRealTime();
    }
  }

  void _startQuestion() {
    _timer?.cancel();
    _autoNextTimer?.cancel();
    _questionStartedAt = SyncedClockService.now();
    _selectedIndex = null;
    _locked = false;
    _remaining = _question.timeLimit <= 0 ? 30 : _question.timeLimit;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _precacheQuestionImages(_index);
      _precacheQuestionImages(_index + 1);
    });
    _syncWithRealTime();
    _timer = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => _syncWithRealTime(),
    );
  }

  void _precacheQuestionImages(int index) {
    if (index < 0 || index >= widget.questions.length) return;
    final question = widget.questions[index];
    final urls = <String>[
      if (question.questionImageUrl?.isNotEmpty == true)
        question.questionImageUrl!,
      ...question.optionImageUrls.whereType<String>().where(
        (url) => url.isNotEmpty,
      ),
    ];
    for (final url in urls) {
      unawaited(precacheImage(NetworkImage(url), context).catchError((_) {}));
    }
  }

  void _syncWithRealTime() {
    if (!mounted || _finishing) return;

    if (widget.isLive && widget.liveStartsAt != null) {
      final liveEndsAt = _liveEndsAt;
      if (liveEndsAt != null &&
          !SyncedClockService.now().isBefore(liveEndsAt)) {
        _finishQuiz();
        return;
      }

      if (_isLiveSelfPaced) {
        // Keep the player experience fluid after an answer while preserving the
        // global live deadline above.
      } else {
        _syncLiveQuestion();
        return;
      }
    }

    final startedAt = _questionStartedAt;
    if (startedAt == null) return;

    final limit = _question.timeLimit <= 0 ? 30 : _question.timeLimit;
    final elapsed = SyncedClockService.now()
        .difference(startedAt)
        .inMilliseconds;
    final nextRemaining = _remainingSeconds(
      totalMs: limit * 1000,
      elapsedMs: elapsed,
      maxSeconds: limit,
    );

    if (nextRemaining != _remaining) {
      setState(() => _remaining = nextRemaining);
    }

    if (!_locked && elapsed >= limit * 1000) {
      _lockAnswer(null, autoAdvance: true);
    }
  }

  void _syncLiveQuestion() {
    final liveStart = widget.liveStartsAt;
    if (liveStart == null) return;

    final elapsedMs = SyncedClockService.now()
        .difference(liveStart)
        .inMilliseconds;
    if (elapsedMs < 0) {
      setState(
        () => _remaining = _question.timeLimit <= 0 ? 30 : _question.timeLimit,
      );
      return;
    }

    var consumedMs = 0;
    for (var i = 0; i < widget.questions.length; i++) {
      final question = widget.questions[i];
      final limitMs =
          (question.timeLimit <= 0 ? 30 : question.timeLimit) * 1000;

      if (elapsedMs >= consumedMs + limitMs) {
        _addMissedAnswer(i);
        consumedMs += limitMs;
        continue;
      }

      final elapsedInQuestion = elapsedMs - consumedMs;
      final nextRemaining = _remainingSeconds(
        totalMs: limitMs,
        elapsedMs: elapsedInQuestion,
        maxSeconds: question.timeLimit <= 0 ? 30 : question.timeLimit,
      );

      setState(() {
        if (_index != i) {
          _index = i;
          _questionStartedAt = liveStart.add(
            Duration(milliseconds: consumedMs),
          );
          _selectedIndex = _answerForIndex(i)?.selectedIndex;
        }
        _remaining = nextRemaining;
        _locked = _answerForIndex(i) != null;
      });
      return;
    }

    _finishQuiz();
  }

  void _lockAnswer(int? selectedIndex, {bool autoAdvance = true}) {
    if (_locked) return;
    final isCorrect = selectedIndex == _question.correctIndex;
    setState(() {
      _selectedIndex = selectedIndex;
      _locked = true;
      if (widget.isLive &&
          widget.liveStartsAt != null &&
          selectedIndex != null) {
        _isLiveSelfPaced = true;
      }
      _answers.removeWhere((answer) => answer.questionId == _question.id);
      _answers.add(_answerFromIndex(_index, selectedIndex, isCorrect));
    });
    if (autoAdvance) {
      _autoNextTimer?.cancel();
      if (selectedIndex != null) {
        _nextQuestion();
      } else {
        _autoNextTimer = Timer(_reviewDelay, _nextQuestion);
      }
    }
  }

  void _nextQuestion() {
    if (!mounted || _finishing) return;
    if (widget.isLive && widget.liveStartsAt != null && !_isLiveSelfPaced) {
      _syncLiveQuestion();
      if (_locked) return;
    }

    if (_index == widget.questions.length - 1) {
      _finishQuiz();
      return;
    }
    setState(() => _index++);
    _startQuestion();
  }

  void _finishQuiz() {
    if (_finishing) return;
    _finishing = true;
    _timer?.cancel();
    _autoNextTimer?.cancel();
    for (var i = 0; i < widget.questions.length; i++) {
      _addMissedAnswer(i);
    }
    final orderedAnswers = widget.questions
        .map(
          (question) =>
              _answers.firstWhere((answer) => answer.questionId == question.id),
        )
        .toList();
    context.go(
      '/contests/${widget.contestId}/quiz/result',
      extra: {
        'participationId': widget.participationId,
        'questions': widget.questions,
        'answers': orderedAnswers,
      },
    );
  }

  int _remainingSeconds({
    required int totalMs,
    required int elapsedMs,
    required int maxSeconds,
  }) {
    return ((totalMs - elapsedMs) / 1000).ceil().clamp(0, maxSeconds).toInt();
  }

  QuizAnswer _answerFromIndex(int index, int? selectedIndex, bool isCorrect) {
    final question = widget.questions[index];
    final startedAt = _questionStartedAt;
    final elapsedMs = startedAt == null
        ? (question.timeLimit <= 0 ? 30 : question.timeLimit) * 1000
        : SyncedClockService.now()
              .difference(startedAt)
              .inMilliseconds
              .clamp(
                0,
                (question.timeLimit <= 0 ? 30 : question.timeLimit) * 1000,
              );
    return QuizAnswer(
      questionId: question.id,
      selectedIndex: selectedIndex,
      correctIndex: question.correctIndex,
      isCorrect: isCorrect,
      points: isCorrect ? question.points : 0,
      elapsedMs: elapsedMs,
    );
  }

  QuizAnswer? _answerForIndex(int index) {
    if (index < 0 || index >= widget.questions.length) return null;
    final questionId = widget.questions[index].id;
    for (final answer in _answers) {
      if (answer.questionId == questionId) return answer;
    }
    return null;
  }

  void _addMissedAnswer(int index) {
    if (_answerForIndex(index) != null) return;
    final question = widget.questions[index];
    _answers.add(
      QuizAnswer(
        questionId: question.id,
        selectedIndex: null,
        correctIndex: question.correctIndex,
        isCorrect: false,
        points: 0,
        elapsedMs: (question.timeLimit <= 0 ? 30 : question.timeLimit) * 1000,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_index + 1) / widget.questions.length;
    final isLastQuestion = _index == widget.questions.length - 1;
    final questionDuration = _question.timeLimit <= 0
        ? 30
        : _question.timeLimit;
    final actionText = _locked
        ? (isLastQuestion ? 'Résultat dans 2 sec...' : 'Question suivante...')
        : 'Choisis une réponse';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(
                                  alpha: 0.14,
                                ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                widget.isLive ? 'QUIZ LIVE' : 'QUIZ',
                                style: AppTextStyles.label.copyWith(
                                  color: AppColors.primaryLight,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${_index + 1}/${widget.questions.length}',
                              style: AppTextStyles.label,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 8,
                            backgroundColor: AppColors.surfaceElevated,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 62,
                    height: 62,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: questionDuration == 0
                              ? 0
                              : _remaining / questionDuration,
                          strokeWidth: 7,
                          backgroundColor: AppColors.surfaceElevated,
                          color: _remaining < 10
                              ? AppColors.accentRed
                              : AppColors.primaryLight,
                        ),
                        Center(
                          child: Text(
                            '$_remaining',
                            style: AppTextStyles.h3.copyWith(fontSize: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppCard(
                      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
                      borderRadius: 24,
                      child: Column(
                        children: [
                          Icon(
                            Icons.help_rounded,
                            color: AppColors.primaryLight.withValues(
                              alpha: 0.8,
                            ),
                            size: 30,
                          ),
                          const SizedBox(height: 12),
                          if (_question.questionText.trim().isNotEmpty)
                            Text(
                              _question.questionText,
                              textAlign: TextAlign.center,
                              style: AppTextStyles.h2.copyWith(height: 1.28),
                            ),
                          if (_question.hasQuestionImage) ...[
                            if (_question.questionText.trim().isNotEmpty)
                              const SizedBox(height: 14),
                            _QuizMediaImage(
                              imageUrl: _question.questionImageUrl!,
                              height: 210,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (_question.hasImageOptions)
                      GridView.builder(
                        itemCount: _question.optionImageUrls.length,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 0.92,
                            ),
                        itemBuilder: (context, index) {
                          return _AnswerCard(
                            label: String.fromCharCode(65 + index),
                            text: _question.options[index],
                            imageUrl: _question.optionImageUrls[index],
                            state: _optionState(index),
                            onTap: _locked ? null : () => _lockAnswer(index),
                          );
                        },
                      )
                    else
                      ...List.generate(_question.options.length, (index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _AnswerCard(
                            label: String.fromCharCode(65 + index),
                            text: _question.options[index],
                            imageUrl: _question.optionImageUrls[index],
                            state: _optionState(index),
                            onTap: _locked ? null : () => _lockAnswer(index),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            AppButton(
              text: actionText,
              onPressed: _locked ? _nextQuestion : null,
            ),
          ],
        ),
      ),
    );
  }

  _AnswerState _optionState(int index) {
    if (!_locked) {
      return _selectedIndex == index
          ? _AnswerState.selected
          : _AnswerState.normal;
    }
    if (index == _question.correctIndex) return _AnswerState.correct;
    if (index == _selectedIndex) return _AnswerState.incorrect;
    return _AnswerState.normal;
  }
}

enum _AnswerState { normal, selected, correct, incorrect }

class _AnswerCard extends StatelessWidget {
  final String label;
  final String text;
  final String? imageUrl;
  final _AnswerState state;
  final VoidCallback? onTap;

  const _AnswerCard({
    required this.label,
    required this.text,
    required this.imageUrl,
    required this.state,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      _AnswerState.selected => AppColors.primaryLight,
      _AnswerState.correct => AppColors.accentGreen,
      _AnswerState.incorrect => AppColors.accentRed,
      _AnswerState.normal => AppColors.primaryDark,
    };

    final hasImage = imageUrl?.isNotEmpty == true;

    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.all(hasImage ? 10 : 14),
      borderRadius: 16,
      child: hasImage
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _QuizMediaImage(imageUrl: imageUrl!)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _AnswerLetter(label: label, color: color, size: 34),
                    if (text.trim().isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          text,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySmall.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            )
          : Row(
              children: [
                _AnswerLetter(label: label, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: AppTextStyles.body.copyWith(height: 1.35),
                  ),
                ),
              ],
            ),
    );
  }
}

class _AnswerLetter extends StatelessWidget {
  final String label;
  final Color color;
  final double size;

  const _AnswerLetter({
    required this.label,
    required this.color,
    this.size = 42,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.32),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Text(
        label,
        style: AppTextStyles.h3.copyWith(
          color: Colors.white,
          fontSize: size <= 34 ? 15 : 18,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _QuizMediaImage extends StatelessWidget {
  final String imageUrl;
  final double? height;

  const _QuizMediaImage({required this.imageUrl, this.height});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: height,
        color: AppColors.surfaceElevated,
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Icon(
                Icons.broken_image_rounded,
                color: AppColors.textHint,
                size: height == null ? 32 : 46,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _EmptyQuiz extends StatelessWidget {
  const _EmptyQuiz();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Aucune question disponible pour ce quiz.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySecondary,
          ),
        ),
      ),
    );
  }
}
