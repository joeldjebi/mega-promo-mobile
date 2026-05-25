import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/utils/auth_debug_logger.dart';
import '../models/question.dart';

class QuizAssetPreloadService {
  QuizAssetPreloadService._();

  static final Map<String, List<QuizQuestion>> _questionsCache = {};
  static final Set<String> _imageCacheKeys = {};
  static final Map<String, Future<List<QuizQuestion>>> _inFlightFetches = {};

  static List<QuizQuestion>? cachedQuestions(String contestId) {
    return _questionsCache[contestId];
  }

  static Future<List<QuizQuestion>> fetchQuestions(
    String contestId, {
    bool force = false,
  }) {
    if (!force) {
      final cached = _questionsCache[contestId];
      if (cached != null) return Future.value(cached);
      final inFlight = _inFlightFetches[contestId];
      if (inFlight != null) return inFlight;
    }

    authLogPayload('quizQuestionsFetch', {'contestId': contestId});
    final future = (() async {
      try {
        final rows = await Supabase.instance.client
            .from('questions')
            .select()
            .eq('contest_id', contestId)
            .order('order_index', ascending: true)
            .timeout(const Duration(seconds: 12));
        final questions = rows.map(QuizQuestion.fromJson).toList();
        _questionsCache[contestId] = questions;
        authLogResponse('quizQuestionsFetch', {'count': questions.length});
        return questions;
      } catch (error, stackTrace) {
        authLogError('quizQuestionsFetch', error, stackTrace);
        rethrow;
      } finally {
        _inFlightFetches.remove(contestId);
      }
    })();

    _inFlightFetches[contestId] = future;
    return future;
  }

  static Future<void> preloadForContest(
    BuildContext context, {
    required String contestId,
    bool force = false,
  }) async {
    final questions = await fetchQuestions(contestId, force: force);
    if (!context.mounted) return;

    final urls = <String>{};
    for (final question in questions) {
      final questionImageUrl = question.questionImageUrl;
      if (questionImageUrl != null && questionImageUrl.isNotEmpty) {
        urls.add(questionImageUrl);
      }
      for (final optionImageUrl in question.optionImageUrls) {
        if (optionImageUrl != null && optionImageUrl.isNotEmpty) {
          urls.add(optionImageUrl);
        }
      }
    }

    await Future.wait(
      urls.map((url) async {
        final cacheKey = '$contestId::$url';
        if (!force && _imageCacheKeys.contains(cacheKey)) return;
        try {
          await precacheImage(NetworkImage(url), context);
          _imageCacheKeys.add(cacheKey);
        } catch (_) {
          // A broken remote image should not block the live quiz startup.
        }
      }),
    );
  }

  static void clearContest(String contestId) {
    _questionsCache.remove(contestId);
    _inFlightFetches.remove(contestId);
    _imageCacheKeys.removeWhere((key) => key.startsWith('$contestId::'));
  }
}
