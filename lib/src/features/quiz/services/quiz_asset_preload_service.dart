import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/utils/auth_debug_logger.dart';
import '../models/question.dart';

typedef QuizAssetPreloadProgress = void Function(int loaded, int total);

class QuizMediaPreloadResult {
  final int total;
  final int loaded;
  final List<String> failedUrls;

  const QuizMediaPreloadResult({
    required this.total,
    required this.loaded,
    required this.failedUrls,
  });

  bool get isComplete => failedUrls.isEmpty;
}

class QuizAssetPreloadService {
  QuizAssetPreloadService._();

  static final Map<String, List<QuizQuestion>> _questionsCache = {};
  static final Map<String, List<QuizQuestion>> _participationQuestionsCache =
      {};
  static final Set<String> _imageCacheKeys = {};
  static final Map<String, Future<List<QuizQuestion>>> _inFlightFetches = {};
  static final Map<String, Future<List<QuizQuestion>>>
  _inFlightParticipationFetches = {};

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

  static Future<List<QuizQuestion>> fetchParticipationQuestions({
    required String contestId,
    required String participationId,
    bool force = false,
  }) {
    if (participationId.isEmpty) return fetchQuestions(contestId, force: force);

    final cacheKey = '$contestId::$participationId';
    if (!force) {
      final cached = _participationQuestionsCache[cacheKey];
      if (cached != null) return Future.value(cached);
      final inFlight = _inFlightParticipationFetches[cacheKey];
      if (inFlight != null) return inFlight;
    }

    authLogPayload('quizParticipationQuestionsFetch', {
      'contestId': contestId,
      'participationId': participationId,
    });
    final future = (() async {
      try {
        final rows = await Supabase.instance.client
            .rpc(
              'get_quiz_participation_questions',
              params: {'p_participation_id': participationId},
            )
            .timeout(const Duration(seconds: 12));
        final questions = rows is List
            ? rows
                  .whereType<Map>()
                  .map(
                    (row) =>
                        QuizQuestion.fromJson(Map<String, dynamic>.from(row)),
                  )
                  .toList()
            : const <QuizQuestion>[];
        if (questions.isEmpty) {
          return fetchQuestions(contestId, force: force);
        }
        _participationQuestionsCache[cacheKey] = questions;
        authLogResponse('quizParticipationQuestionsFetch', {
          'count': questions.length,
        });
        return questions;
      } catch (error, stackTrace) {
        authLogError('quizParticipationQuestionsFetch', error, stackTrace);
        return fetchQuestions(contestId, force: force);
      } finally {
        _inFlightParticipationFetches.remove(cacheKey);
      }
    })();

    _inFlightParticipationFetches[cacheKey] = future;
    return future;
  }

  static Future<void> preloadForContest(
    BuildContext context, {
    required String contestId,
    bool force = false,
  }) async {
    final questions = await fetchQuestions(contestId, force: force);
    if (!context.mounted) return;

    await preloadQuestionMedia(
      context,
      cacheScope: contestId,
      questions: questions,
      force: force,
    );
  }

  static List<String> mediaUrlsForQuestions(List<QuizQuestion> questions) {
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
    return urls.toList(growable: false);
  }

  static Future<QuizMediaPreloadResult> preloadQuestionMedia(
    BuildContext context, {
    required String cacheScope,
    required List<QuizQuestion> questions,
    bool force = false,
    Duration perImageTimeout = const Duration(seconds: 15),
    QuizAssetPreloadProgress? onProgress,
  }) async {
    final urls = mediaUrlsForQuestions(questions);
    if (urls.isEmpty) {
      onProgress?.call(0, 0);
      return const QuizMediaPreloadResult(total: 0, loaded: 0, failedUrls: []);
    }

    var loaded = 0;
    final failedUrls = <String>[];
    onProgress?.call(loaded, urls.length);

    await Future.wait(
      urls.map((url) async {
        final cacheKey = '$cacheScope::$url';
        if (!force && _imageCacheKeys.contains(cacheKey)) {
          loaded++;
          onProgress?.call(loaded, urls.length);
          return;
        }
        try {
          await precacheImage(
            NetworkImage(url),
            context,
          ).timeout(perImageTimeout);
          _imageCacheKeys.add(cacheKey);
        } catch (_) {
          failedUrls.add(url);
        } finally {
          loaded++;
          onProgress?.call(loaded, urls.length);
        }
      }),
    );

    return QuizMediaPreloadResult(
      total: urls.length,
      loaded: loaded,
      failedUrls: failedUrls,
    );
  }

  static void clearContest(String contestId) {
    _questionsCache.remove(contestId);
    _inFlightFetches.remove(contestId);
    _participationQuestionsCache.removeWhere(
      (key, value) => key.startsWith('$contestId::'),
    );
    _inFlightParticipationFetches.removeWhere(
      (key, value) => key.startsWith('$contestId::'),
    );
    _imageCacheKeys.removeWhere((key) => key.startsWith('$contestId::'));
  }
}
