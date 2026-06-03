import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/question.dart';
import '../services/quiz_asset_preload_service.dart';

class QuizQuestionsRequest {
  final String contestId;
  final String participationId;

  const QuizQuestionsRequest({
    required this.contestId,
    required this.participationId,
  });

  @override
  bool operator ==(Object other) {
    return other is QuizQuestionsRequest &&
        other.contestId == contestId &&
        other.participationId == participationId;
  }

  @override
  int get hashCode => Object.hash(contestId, participationId);
}

final quizQuestionsProvider =
    FutureProvider.family<List<QuizQuestion>, QuizQuestionsRequest>((
      ref,
      request,
    ) async {
      return QuizAssetPreloadService.fetchParticipationQuestions(
        contestId: request.contestId,
        participationId: request.participationId,
      );
    });
