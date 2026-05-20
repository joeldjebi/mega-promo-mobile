import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../models/question.dart';

final quizQuestionsProvider = FutureProvider.family<List<QuizQuestion>, String>(
  (ref, contestId) async {
    final supabase = ref.watch(supabaseProvider);
    final rows = await supabase
        .from('questions')
        .select()
        .eq('contest_id', contestId)
        .order('order_index', ascending: true);

    return rows.map(QuizQuestion.fromJson).toList();
  },
);
