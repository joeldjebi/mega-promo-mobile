import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mega_promo/core/theme/app_colors.dart';
import 'package:mega_promo/core/theme/app_text_styles.dart';
import 'package:mega_promo/core/widgets/app_button.dart';
import 'package:mega_promo/core/widgets/app_card.dart';

import '../models/question.dart';
import '../providers/quiz_providers.dart';

class QuizScreen extends ConsumerWidget {
  final String contestId;

  const QuizScreen({super.key, required this.contestId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final questions = ref.watch(quizQuestionsProvider(contestId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: questions.when(
        data: (items) => items.isEmpty
            ? const _EmptyQuiz()
            : _QuizRunner(contestId: contestId, questions: items),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => const _EmptyQuiz(),
      ),
    );
  }
}

class _QuizRunner extends StatefulWidget {
  final String contestId;
  final List<QuizQuestion> questions;

  const _QuizRunner({required this.contestId, required this.questions});

  @override
  State<_QuizRunner> createState() => _QuizRunnerState();
}

class _QuizRunnerState extends State<_QuizRunner> {
  final List<QuizAnswer> _answers = [];
  Timer? _timer;
  int _index = 0;
  int _remaining = 30;
  int? _selectedIndex;
  bool _locked = false;

  QuizQuestion get _question => widget.questions[_index];

  @override
  void initState() {
    super.initState();
    _startQuestion();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startQuestion() {
    _timer?.cancel();
    _selectedIndex = null;
    _locked = false;
    _remaining = _question.timeLimit <= 0 ? 30 : _question.timeLimit;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remaining <= 1) {
        _lockAnswer(null);
        _nextQuestion();
        return;
      }
      setState(() => _remaining--);
    });
  }

  void _lockAnswer(int? selectedIndex) {
    if (_locked) return;
    _timer?.cancel();
    final isCorrect = selectedIndex == _question.correctIndex;
    setState(() {
      _selectedIndex = selectedIndex;
      _locked = true;
      _answers.add(
        QuizAnswer(
          questionId: _question.id,
          selectedIndex: selectedIndex,
          correctIndex: _question.correctIndex,
          isCorrect: isCorrect,
          points: isCorrect ? _question.points : 0,
        ),
      );
    });
  }

  void _nextQuestion() {
    if (_index == widget.questions.length - 1) {
      context.go(
        '/contests/${widget.contestId}/quiz/result',
        extra: {'questions': widget.questions, 'answers': _answers},
      );
      return;
    }
    setState(() => _index++);
    _startQuestion();
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_index + 1) / widget.questions.length;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Question ${_index + 1}/${widget.questions.length}',
              style: AppTextStyles.label,
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: AppColors.surfaceElevated,
              color: AppColors.primary,
            ),
            const SizedBox(height: 26),
            Center(
              child: SizedBox(
                width: 88,
                height: 88,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value:
                          _remaining /
                          (_question.timeLimit <= 0 ? 30 : _question.timeLimit),
                      strokeWidth: 7,
                      backgroundColor: AppColors.surfaceElevated,
                      color: _remaining < 10
                          ? AppColors.accentRed
                          : AppColors.primaryLight,
                    ),
                    Center(child: Text('$_remaining', style: AppTextStyles.h2)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              _question.questionText,
              textAlign: TextAlign.center,
              style: AppTextStyles.h2,
            ),
            const SizedBox(height: 28),
            ...List.generate(_question.options.length, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _AnswerCard(
                  label: String.fromCharCode(65 + index),
                  text: _question.options[index],
                  state: _optionState(index),
                  onTap: _locked ? null : () => _lockAnswer(index),
                ),
              );
            }),
            const Spacer(),
            if (_locked) AppButton(text: 'Suivant', onPressed: _nextQuestion),
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
      _AnswerState.normal => AppColors.surfaceBorder,
    };

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.18),
            child: Text(label, style: AppTextStyles.h3.copyWith(color: color)),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(text, style: AppTextStyles.body)),
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
