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
import '../../social/share_helpers.dart';
import '../models/question.dart';

class QuizResultScreen extends ConsumerStatefulWidget {
  final String contestId;
  final String participationId;
  final List<QuizQuestion> questions;
  final List<QuizAnswer> answers;

  const QuizResultScreen({
    super.key,
    required this.contestId,
    required this.participationId,
    required this.questions,
    required this.answers,
  });

  @override
  ConsumerState<QuizResultScreen> createState() => _QuizResultScreenState();
}

class _QuizResultScreenState extends ConsumerState<QuizResultScreen> {
  bool _saved = false;

  int get _correct => widget.answers.where((answer) => answer.isCorrect).length;
  int get _points =>
      widget.answers.fold(0, (sum, answer) => sum + answer.points);
  int get _durationMs =>
      widget.answers.fold(0, (sum, answer) => sum + answer.elapsedMs);
  double get _ratio =>
      widget.questions.isEmpty ? 0 : _correct / widget.questions.length;

  QuizAnswer _answerAt(int index) {
    if (index < widget.answers.length) return widget.answers[index];
    final question = widget.questions[index];
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_saveResult());
    });
  }

  Future<void> _saveResult() async {
    if (_saved || !mounted) return;
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    _saved = true;
    final contestId = widget.contestId;
    final participationId = widget.participationId;
    final totalQuestions = widget.questions.length;
    final points = _points;
    final durationMs = _durationMs;
    final correctCount = _correct;
    final profile = await ref.read(userProfileProvider.future);
    final answersPayload = widget.answers
        .map((answer) => answer.toJson())
        .toList();

    if (participationId.isNotEmpty) {
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

    await supabase
        .from('users')
        .update({'points_total': profile.pointsTotal + points})
        .eq('id', user.id);

    await awardBadgesAfterParticipation(
      supabase: supabase,
      profile: profile,
      nextParticipationsToday: participationId.isNotEmpty
          ? profile.participationsToday
          : profile.participationsToday + 1,
      nextPointsTotal: profile.pointsTotal + points,
    );

    if (!mounted) return;
    ref.invalidate(userProfileProvider);
  }

  @override
  Widget build(BuildContext context) {
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

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
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
                          value: '$_correct/${widget.questions.length}',
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
            ...List.generate(widget.questions.length, (index) {
              final question = widget.questions[index];
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
                            final isCorrect =
                                optionIndex == answer.correctIndex;
                            final isSelected =
                                optionIndex == answer.selectedIndex;
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
                totalQuestions: widget.questions.length,
                points: _points,
              ),
            ),
          ],
        ),
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
