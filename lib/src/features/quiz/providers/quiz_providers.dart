import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/question.dart';
import '../services/quiz_asset_preload_service.dart';

final quizQuestionsProvider = FutureProvider.family<List<QuizQuestion>, String>(
  (ref, contestId) async {
    return QuizAssetPreloadService.fetchQuestions(contestId);
  },
);
