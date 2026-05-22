import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mega_promo/core/theme/app_colors.dart';
import 'package:mega_promo/core/theme/app_text_styles.dart';
import 'package:mega_promo/core/widgets/app_button.dart';
import 'package:mega_promo/core/widgets/app_card.dart';

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
    final questions = ref.watch(quizQuestionsProvider(contestId));
    final detail = ref.watch(contestDetailProvider(contestId));
    final detailData = detail.value;

    if (detailData != null &&
        !detailData.contest.isAccessibleForPlan(
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

    if (detailData != null &&
        detailData.hasParticipated &&
        participationId.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: _QuizAlreadyStarted(
          onBack: () => context.go('/contests/$contestId'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: questions.when(
        data: (items) => items.isEmpty
            ? const _EmptyQuiz()
            : _QuizRunner(
                contestId: contestId,
                participationId: participationId,
                isLive: detailData?.contest.isLive ?? false,
                liveStartsAt: detailData?.contest.liveStartsAt,
                questions: items,
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => const _EmptyQuiz(),
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
              Text('Concours réservé', style: AppTextStyles.h2),
              const SizedBox(height: 8),
              Text(
                'Ce quiz est accessible uniquement aux joueurs $label.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySecondary,
              ),
              const SizedBox(height: 20),
              AppButton(text: 'Retour au concours', onPressed: onBack),
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
              AppButton(text: 'Retour au concours', onPressed: onBack),
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

  QuizQuestion get _question => widget.questions[_index];

  @override
  void initState() {
    super.initState();
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
    _questionStartedAt = DateTime.now();
    _selectedIndex = null;
    _locked = false;
    _remaining = _question.timeLimit <= 0 ? 30 : _question.timeLimit;
    _syncWithRealTime();
    _timer = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => _syncWithRealTime(),
    );
  }

  void _syncWithRealTime() {
    if (!mounted || _finishing) return;

    if (widget.isLive && widget.liveStartsAt != null) {
      _syncLiveQuestion();
      return;
    }

    final startedAt = _questionStartedAt;
    if (startedAt == null) return;

    final limit = _question.timeLimit <= 0 ? 30 : _question.timeLimit;
    final elapsed = DateTime.now().difference(startedAt).inMilliseconds;
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

    final elapsedMs = DateTime.now().difference(liveStart).inMilliseconds;
    if (elapsedMs < 0) {
      setState(
        () => _remaining = _question.timeLimit <= 0 ? 30 : _question.timeLimit,
      );
      return;
    }

    var consumedMs = 0;
    for (var i = 0; i < widget.questions.length; i++) {
      final question = widget.questions[i];
      final limitMs = (question.timeLimit <= 0 ? 30 : question.timeLimit) * 1000;
      final segmentMs = limitMs + _reviewDelay.inMilliseconds;

      if (elapsedMs >= consumedMs + segmentMs) {
        _addMissedAnswer(i);
        consumedMs += segmentMs;
        continue;
      }

      final elapsedInQuestion = elapsedMs - consumedMs;
      final isReviewPhase = elapsedInQuestion >= limitMs;
      final nextRemaining = _remainingSeconds(
        totalMs: limitMs,
        elapsedMs: elapsedInQuestion,
        maxSeconds: question.timeLimit <= 0 ? 30 : question.timeLimit,
      );

      setState(() {
        if (_index != i) {
          _index = i;
          _selectedIndex = _answerForIndex(i)?.selectedIndex;
        }
        _remaining = nextRemaining;
        _locked = isReviewPhase || _answerForIndex(i) != null;
      });

      if (isReviewPhase) {
        _addMissedAnswer(i);
      }
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
      _answers.removeWhere((answer) => answer.questionId == _question.id);
      _answers.add(_answerFromIndex(_index, selectedIndex, isCorrect));
    });
    if (autoAdvance) {
      _autoNextTimer?.cancel();
      _autoNextTimer = Timer(_reviewDelay, _nextQuestion);
    }
  }

  void _nextQuestion() {
    if (!mounted || _finishing) return;
    if (widget.isLive && widget.liveStartsAt != null) {
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
        .map((question) => _answers.firstWhere((answer) => answer.questionId == question.id))
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
    return QuizAnswer(
      questionId: question.id,
      selectedIndex: selectedIndex,
      correctIndex: question.correctIndex,
      isCorrect: isCorrect,
      points: isCorrect ? question.points : 0,
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
                                color: AppColors.primary.withValues(alpha: 0.14),
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
                            color: AppColors.primaryLight.withValues(alpha: 0.8),
                            size: 30,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _question.questionText,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.h2.copyWith(height: 1.28),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    ...List.generate(_question.options.length, (index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _AnswerCard(
                          label: String.fromCharCode(65 + index),
                          text: _question.options[index],
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
  final _AnswerState state;
  final VoidCallback? onTap;

  const _AnswerCard({
    required this.label,
    required this.text,
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

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      borderRadius: 16,
      child: Row(
        children: [
          Container(
            alignment: Alignment.center,
            width: 42,
            height: 42,
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
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: AppTextStyles.body.copyWith(height: 1.35)),
          ),
        ],
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
            'Aucune question disponible pour ce concours.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySecondary,
          ),
        ),
      ),
    );
  }
}
