import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';

class ParticipationResultDetail {
  final ParticipationResultSummary participation;
  final ParticipationResultContest contest;
  final List<ParticipationLeaderboardPlayer> leaderboard;
  final List<ParticipationAnswerDetail> answers;

  const ParticipationResultDetail({
    required this.participation,
    required this.contest,
    required this.leaderboard,
    required this.answers,
  });

  factory ParticipationResultDetail.fromJson(Map<String, dynamic> json) {
    return ParticipationResultDetail(
      participation: ParticipationResultSummary.fromJson(
        (json['participation'] as Map?)?.cast<String, dynamic>() ?? {},
      ),
      contest: ParticipationResultContest.fromJson(
        (json['contest'] as Map?)?.cast<String, dynamic>() ?? {},
      ),
      leaderboard: (json['leaderboard'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => ParticipationLeaderboardPlayer.fromJson(item.cast()))
          .toList(growable: false),
      answers: (json['answers'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => ParticipationAnswerDetail.fromJson(item.cast()))
          .toList(growable: false),
    );
  }
}

class ParticipationResultSummary {
  final String id;
  final String contestId;
  final int score;
  final int durationMs;
  final int correctAnswers;
  final int totalAnswers;
  final int rank;
  final int participantsCount;
  final DateTime? participatedAt;
  final bool completed;

  const ParticipationResultSummary({
    required this.id,
    required this.contestId,
    required this.score,
    required this.durationMs,
    required this.correctAnswers,
    required this.totalAnswers,
    required this.rank,
    required this.participantsCount,
    required this.participatedAt,
    required this.completed,
  });

  factory ParticipationResultSummary.fromJson(Map<String, dynamic> json) {
    return ParticipationResultSummary(
      id: json['id'] as String? ?? '',
      contestId: json['contest_id'] as String? ?? '',
      score: (json['score'] as num?)?.toInt() ?? 0,
      durationMs: (json['duration_ms'] as num?)?.toInt() ?? 0,
      correctAnswers: (json['correct_answers'] as num?)?.toInt() ?? 0,
      totalAnswers: (json['total_answers'] as num?)?.toInt() ?? 0,
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      participantsCount: (json['participants_count'] as num?)?.toInt() ?? 0,
      participatedAt: DateTime.tryParse(
        json['participated_at'] as String? ?? '',
      ),
      completed: json['completed'] as bool? ?? true,
    );
  }
}

class ParticipationResultContest {
  final String id;
  final String title;
  final String imageUrl;
  final bool isLiveQuiz;
  final String type;
  final String category;
  final DateTime? endsAt;

  const ParticipationResultContest({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.isLiveQuiz,
    required this.type,
    required this.category,
    required this.endsAt,
  });

  factory ParticipationResultContest.fromJson(Map<String, dynamic> json) {
    return ParticipationResultContest(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Quiz MegaPromo',
      imageUrl: json['image_url'] as String? ?? '',
      isLiveQuiz: json['is_live'] as bool? ?? false,
      type: json['type'] as String? ?? 'quiz',
      category: json['category'] as String? ?? '',
      endsAt: DateTime.tryParse(json['ends_at'] as String? ?? ''),
    );
  }
}

class ParticipationLeaderboardPlayer {
  final int rank;
  final String userId;
  final String username;
  final String? avatarUrl;
  final int score;
  final int durationMs;
  final int correctAnswers;
  final int totalAnswers;
  final bool isCurrentUser;

  const ParticipationLeaderboardPlayer({
    required this.rank,
    required this.userId,
    required this.username,
    required this.avatarUrl,
    required this.score,
    required this.durationMs,
    required this.correctAnswers,
    required this.totalAnswers,
    required this.isCurrentUser,
  });

  factory ParticipationLeaderboardPlayer.fromJson(Map<String, dynamic> json) {
    return ParticipationLeaderboardPlayer(
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      userId: json['user_id'] as String? ?? '',
      username: json['username'] as String? ?? 'Joueur',
      avatarUrl: json['avatar_url'] as String?,
      score: (json['score'] as num?)?.toInt() ?? 0,
      durationMs: (json['duration_ms'] as num?)?.toInt() ?? 0,
      correctAnswers: (json['correct_answers'] as num?)?.toInt() ?? 0,
      totalAnswers: (json['total_answers'] as num?)?.toInt() ?? 0,
      isCurrentUser: json['is_current_user'] as bool? ?? false,
    );
  }
}

class ParticipationAnswerOption {
  final String label;
  final String text;
  final String? imageUrl;

  const ParticipationAnswerOption({
    required this.label,
    required this.text,
    required this.imageUrl,
  });

  factory ParticipationAnswerOption.fromJson(Map<String, dynamic> json) {
    final imageUrl = (json['image_url'] as String?)?.trim();
    return ParticipationAnswerOption(
      label: json['label'] as String? ?? '',
      text: json['text'] as String? ?? '',
      imageUrl: imageUrl == null || imageUrl.isEmpty ? null : imageUrl,
    );
  }
}

class ParticipationAnswerDetail {
  final int orderIndex;
  final String questionId;
  final String questionText;
  final String? questionImageUrl;
  final List<ParticipationAnswerOption> options;
  final int? selectedIndex;
  final int correctIndex;
  final bool isCorrect;
  final int points;
  final int elapsedMs;

  const ParticipationAnswerDetail({
    required this.orderIndex,
    required this.questionId,
    required this.questionText,
    required this.questionImageUrl,
    required this.options,
    required this.selectedIndex,
    required this.correctIndex,
    required this.isCorrect,
    required this.points,
    required this.elapsedMs,
  });

  factory ParticipationAnswerDetail.fromJson(Map<String, dynamic> json) {
    final questionImageUrl = (json['question_image_url'] as String?)?.trim();
    return ParticipationAnswerDetail(
      orderIndex: (json['order_index'] as num?)?.toInt() ?? 0,
      questionId: json['question_id'] as String? ?? '',
      questionText: json['question_text'] as String? ?? '',
      questionImageUrl: questionImageUrl == null || questionImageUrl.isEmpty
          ? null
          : questionImageUrl,
      options: (json['options'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => ParticipationAnswerOption.fromJson(item.cast()))
          .toList(growable: false),
      selectedIndex: (json['selected_index'] as num?)?.toInt(),
      correctIndex: (json['correct_index'] as num?)?.toInt() ?? 0,
      isCorrect: json['is_correct'] as bool? ?? false,
      points: (json['points'] as num?)?.toInt() ?? 0,
      elapsedMs: (json['elapsed_ms'] as num?)?.toInt() ?? 0,
    );
  }
}

final participationResultDetailProvider =
    FutureProvider.family<ParticipationResultDetail, String>((
      ref,
      participationId,
    ) async {
      final supabase = ref.watch(supabaseProvider);
      if (participationId.trim().isEmpty) {
        throw StateError('Participation introuvable.');
      }

      final data = await supabase.rpc(
        'get_participation_result_detail',
        params: {'p_participation_id': participationId},
      );

      return ParticipationResultDetail.fromJson(
        (data as Map).cast<String, dynamic>(),
      );
    });
