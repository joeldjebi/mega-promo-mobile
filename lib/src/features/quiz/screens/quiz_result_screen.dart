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
  final List<QuizQuestion> questions;
  final List<QuizAnswer> answers;

  const QuizResultScreen({
    super.key,
    required this.contestId,
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
  double get _ratio =>
      widget.questions.isEmpty ? 0 : _correct / widget.questions.length;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _saveResult());
  }

  Future<void> _saveResult() async {
    if (_saved) return;
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final profile = await ref.read(userProfileProvider.future);
    await supabase.from('participations').insert({
      'user_id': user.id,
      'contest_id': widget.contestId,
      'score': _points,
      'answers': widget.answers.map((answer) => answer.toJson()).toList(),
      'completed': true,
    });
    await supabase
        .from('users')
        .update({
          'points_total': profile.pointsTotal + _points,
          'participations_today': profile.participationsToday + 1,
          'last_participation_date': DateTime.now().toIso8601String().split(
            'T',
          )[0],
        })
        .eq('id', user.id);

    await awardBadgesAfterParticipation(
      supabase: supabase,
      profile: profile,
      nextParticipationsToday: profile.participationsToday + 1,
      nextPointsTotal: profile.pointsTotal + _points,
    );

    ref.invalidate(userProfileProvider);
    _saved = true;
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
          padding: const EdgeInsets.all(24),
          children: [
            Icon(icon, color: color, size: 92)
                .animate()
                .fadeIn(duration: 400.ms)
                .scale(curve: Curves.easeOutBack),
            const SizedBox(height: 18),
            Text(
              'Score final',
              textAlign: TextAlign.center,
              style: AppTextStyles.h1,
            ),
            const SizedBox(height: 8),
            Text(
              '$_correct / ${widget.questions.length} bonnes réponses',
              textAlign: TextAlign.center,
              style: AppTextStyles.h2,
            ),
            const SizedBox(height: 8),
            Text(
              '+$_points points',
              textAlign: TextAlign.center,
              style: AppTextStyles.price,
            ),
            const SizedBox(height: 26),
            Text('Récapitulatif', style: AppTextStyles.h2),
            const SizedBox(height: 14),
            ...List.generate(widget.questions.length, (index) {
              final question = widget.questions[index];
              final answer = widget.answers[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppCard(
                  child: Row(
                    children: [
                      Icon(
                        answer.isCorrect
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        color: answer.isCorrect
                            ? AppColors.accentGreen
                            : AppColors.accentRed,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          question.questionText,
                          style: AppTextStyles.bodySecondary,
                        ),
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
