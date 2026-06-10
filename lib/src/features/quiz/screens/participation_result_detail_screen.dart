import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../home/screens/home_screen.dart';
import '../providers/participation_result_provider.dart';

class ParticipationResultDetailScreen extends ConsumerWidget {
  final String participationId;

  const ParticipationResultDetailScreen({
    super.key,
    required this.participationId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(
      participationResultDetailProvider(participationId),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
              return;
            }
            context.go('/profile');
          },
          tooltip: 'Retour',
        ),
        title: const Text('Mon résultat'),
      ),
      body: SafeArea(
        child: result.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _ResultError(
            message: 'Impossible de charger ce résultat.',
            onRetry: () => ref.invalidate(
              participationResultDetailProvider(participationId),
            ),
          ),
          data: (detail) => RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(
                participationResultDetailProvider(participationId),
              );
              await ref.read(
                participationResultDetailProvider(participationId).future,
              );
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
              children: [
                _ResultHero(detail: detail),
                const SizedBox(height: 14),
                _LeaderboardSection(detail: detail),
                const SizedBox(height: 14),
                _AnswersSection(answers: detail.answers),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultHero extends StatelessWidget {
  final ParticipationResultDetail detail;

  const _ResultHero({required this.detail});

  @override
  Widget build(BuildContext context) {
    final performance = detail.participation;
    final total = performance.totalAnswers <= 0 ? 1 : performance.totalAnswers;
    final percent = (performance.correctAnswers / total).clamp(0.0, 1.0);

    return AppCard(
      padding: EdgeInsets.zero,
      borderRadius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (detail.contest.imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(22),
              ),
              child: AspectRatio(
                aspectRatio: 16 / 7,
                child: Image.network(
                  detail.contest.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    child: const Icon(Icons.emoji_events_rounded, size: 42),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detail.contest.title,
                  style: AppTextStyles.h2,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _ScoreTile(
                        label: 'Score',
                        value: '${performance.score}',
                        icon: Icons.bolt_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ScoreTile(
                        label: 'Rang',
                        value: performance.rank <= 0
                            ? '-'
                            : '${performance.rank}',
                        icon: Icons.leaderboard_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ScoreTile(
                        label: 'Justes',
                        value:
                            '${performance.correctAnswers}/${performance.totalAnswers}',
                        icon: Icons.check_circle_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: percent,
                    minHeight: 8,
                    backgroundColor: AppColors.surfaceBorder,
                    color: AppColors.accentGreen,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MetaPill(
                      icon: Icons.timer_rounded,
                      label: _formatDuration(performance.durationMs),
                    ),
                    _MetaPill(
                      icon: Icons.groups_rounded,
                      label:
                          '${performance.participantsCount} participant${performance.participantsCount > 1 ? 's' : ''}',
                    ),
                    if (detail.contest.category.trim().isNotEmpty)
                      _MetaPill(
                        icon: Icons.category_rounded,
                        label: detail.contest.category,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _ScoreTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primaryLight, size: 18),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: AppTextStyles.h2),
          ),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardSection extends StatelessWidget {
  final ParticipationResultDetail detail;

  const _LeaderboardSection({required this.detail});

  @override
  Widget build(BuildContext context) {
    final players = detail.leaderboard;
    return AppCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events_rounded, color: AppColors.gold),
              const SizedBox(width: 8),
              Expanded(child: Text('Top 10', style: AppTextStyles.h2)),
            ],
          ),
          const SizedBox(height: 12),
          if (players.isEmpty)
            Text('Classement indisponible.', style: AppTextStyles.bodySecondary)
          else
            ...players.map((player) => _LeaderboardRow(player: player)),
        ],
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final ParticipationLeaderboardPlayer player;

  const _LeaderboardRow({required this.player});

  @override
  Widget build(BuildContext context) {
    final isCurrent = player.isCurrentUser;
    final avatar = avatarForId(player.avatarUrl);
    final avatarUrl = player.avatarUrl?.trim() ?? '';
    final hasRemoteAvatar =
        avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: isCurrent
            ? AppColors.primary.withValues(alpha: 0.10)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrent ? AppColors.primaryLight : AppColors.surfaceBorder,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text(
              '${player.rank}',
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          CircleAvatar(
            radius: 17,
            backgroundColor: avatar.color.withValues(alpha: 0.14),
            backgroundImage: hasRemoteAvatar ? NetworkImage(avatarUrl) : null,
            child: hasRemoteAvatar
                ? null
                : Icon(avatar.icon, color: avatar.color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCurrent ? '${player.username} · Toi' : player.username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body,
                ),
                Text(
                  '${player.correctAnswers}/${player.totalAnswers} bonnes réponses · ${_formatDuration(player.durationMs)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${player.score}',
            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _AnswersSection extends StatelessWidget {
  final List<ParticipationAnswerDetail> answers;

  const _AnswersSection({required this.answers});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fact_check_rounded, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(child: Text('Mes réponses', style: AppTextStyles.h2)),
            ],
          ),
          const SizedBox(height: 12),
          if (answers.isEmpty)
            Text(
              'Le détail des réponses est indisponible.',
              style: AppTextStyles.bodySecondary,
            )
          else
            ...answers.map((answer) => _AnswerCard(answer: answer)),
        ],
      ),
    );
  }
}

class _AnswerCard extends StatelessWidget {
  final ParticipationAnswerDetail answer;

  const _AnswerCard({required this.answer});

  @override
  Widget build(BuildContext context) {
    final selected = _optionAt(answer.selectedIndex);
    final correct = _optionAt(answer.correctIndex);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: answer.isCorrect
                      ? AppColors.accentGreen.withValues(alpha: 0.16)
                      : AppColors.accentRed.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  answer.isCorrect ? Icons.check_rounded : Icons.close_rounded,
                  color: answer.isCorrect
                      ? AppColors.accentGreen
                      : AppColors.accentRed,
                  size: 17,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  answer.questionText.isEmpty
                      ? 'Question ${answer.orderIndex}'
                      : answer.questionText,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (answer.questionImageUrl != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  answer.questionImageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: AppColors.surface,
                    child: const Icon(Icons.image_not_supported_rounded),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          _AnswerLine(
            label: 'Ta réponse',
            option: selected,
            color: answer.isCorrect
                ? AppColors.accentGreen
                : AppColors.accentRed,
          ),
          const SizedBox(height: 6),
          _AnswerLine(
            label: 'Bonne réponse',
            option: correct,
            color: AppColors.accentGreen,
          ),
        ],
      ),
    );
  }

  ParticipationAnswerOption? _optionAt(int? index) {
    if (index == null || index < 0 || index >= answer.options.length) {
      return null;
    }
    return answer.options[index];
  }
}

class _AnswerLine extends StatelessWidget {
  final String label;
  final ParticipationAnswerOption? option;
  final Color color;

  const _AnswerLine({
    required this.label,
    required this.option,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final option = this.option;
    final text = option == null
        ? 'Aucune réponse'
        : option.text.trim().isEmpty
        ? 'Image ${option.label}'
        : '${option.label}. ${option.text}';

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textHint,
                  ),
                ),
                Text(text, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          if (option?.imageUrl != null) ...[
            const SizedBox(width: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                option!.imageUrl!,
                width: 58,
                height: 46,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  width: 58,
                  height: 46,
                  color: AppColors.surface,
                  child: const Icon(Icons.image_rounded, size: 18),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.textSecondary),
          const SizedBox(width: 5),
          Text(label, style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}

class _ResultError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ResultError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, size: 44),
          const SizedBox(height: 12),
          Text(message, style: AppTextStyles.body, textAlign: TextAlign.center),
          const SizedBox(height: 18),
          AppButton(text: 'Réessayer', onPressed: onRetry),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Retour'),
          ),
        ],
      ),
    );
  }
}

String _formatDuration(int durationMs) {
  if (durationMs <= 0 || durationMs >= 2147483647) return '-';
  final seconds = (durationMs / 1000).round();
  final minutes = seconds ~/ 60;
  final rest = seconds % 60;
  if (minutes <= 0) return '${rest}s';
  return '${minutes}min ${rest}s';
}
