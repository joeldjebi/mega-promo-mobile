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

  static const int _mediaCacheWidth = 1400;
  static const int _imageCacheMaximumSize = 500;
  static const int _imageCacheMaximumSizeBytes = 256 * 1024 * 1024;

  static const _questionSelect = '''
    id,
    contest_id,
    question_type,
    prediction_type,
    prediction_payload,
    question_text,
    question_image_url,
    option_a,
    option_a_image_url,
    option_b,
    option_b_image_url,
    option_c,
    option_c_image_url,
    option_d,
    option_d_image_url,
    correct_answer,
    points,
    time_limit
  ''';

  static final Map<String, List<QuizQuestion>> _questionsCache = {};
  static final Map<String, List<QuizQuestion>> _participationQuestionsCache =
      {};
  static final Set<String> _imageCacheKeys = {};
  static final Set<String> _loadedImageUrls = {};
  static final Map<String, Future<List<QuizQuestion>>> _inFlightFetches = {};
  static final Map<String, Future<List<QuizQuestion>>>
  _inFlightParticipationFetches = {};
  static final Map<String, Future<void>> _inFlightImagePreloads = {};

  static List<QuizQuestion>? cachedQuestions(String contestId) {
    return _questionsCache[contestId];
  }

  static void configureImageCache() {
    final imageCache = PaintingBinding.instance.imageCache;
    if (imageCache.maximumSize < _imageCacheMaximumSize) {
      imageCache.maximumSize = _imageCacheMaximumSize;
    }
    if (imageCache.maximumSizeBytes < _imageCacheMaximumSizeBytes) {
      imageCache.maximumSizeBytes = _imageCacheMaximumSizeBytes;
    }
  }

  static ImageProvider<Object> mediaImageProvider(String url) {
    return ResizeImage.resizeIfNeeded(
      _mediaCacheWidth,
      null,
      NetworkImage(url),
    );
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

  static Future<QuizMediaPreloadResult> preloadAvailableMediaForContest(
    BuildContext context, {
    required String contestId,
    bool force = false,
    QuizAssetPreloadProgress? onProgress,
  }) async {
    final questions = await fetchAvailableQuestionsForContest(contestId);
    if (!context.mounted) {
      return const QuizMediaPreloadResult(total: 0, loaded: 0, failedUrls: []);
    }

    return preloadQuestionMedia(
      context,
      cacheScope: contestId,
      questions: questions,
      force: force,
      onProgress: onProgress,
    );
  }

  static Future<List<QuizQuestion>> fetchAvailableQuestionsForContest(
    String contestId,
  ) async {
    try {
      final directRows = await Supabase.instance.client
          .from('questions')
          .select(_questionSelect)
          .eq('contest_id', contestId)
          .eq('is_active', true)
          .order('order_index', ascending: true)
          .timeout(const Duration(seconds: 12));
      final directQuestions = _questionsFromRows(directRows);
      if (directQuestions.isNotEmpty) return directQuestions;

      final contestRow = await Supabase.instance.client
          .from('contests')
          .select('category_id')
          .eq('id', contestId)
          .maybeSingle()
          .timeout(const Duration(seconds: 12));
      final categoryId = (contestRow?['category_id'] as String?)?.trim();
      if (categoryId == null || categoryId.isEmpty) return const [];

      final linkRows = await Supabase.instance.client
          .from('question_bank_categories')
          .select('question_bank_id')
          .eq('category_id', categoryId)
          .timeout(const Duration(seconds: 12));
      final bankIds = linkRows
          .whereType<Map>()
          .map((row) => row['question_bank_id'] as String?)
          .whereType<String>()
          .where((id) => id.trim().isNotEmpty)
          .toSet()
          .toList(growable: false);
      if (bankIds.isEmpty) return const [];

      final bankRows = await Supabase.instance.client
          .from('questions')
          .select(_questionSelect)
          .inFilter('question_bank_id', bankIds)
          .eq('is_active', true)
          .isFilter('contest_id', null)
          .order('order_index', ascending: true)
          .timeout(const Duration(seconds: 15));
      return _questionsFromRows(bankRows);
    } catch (error, stackTrace) {
      authLogError('quizAvailableQuestionsMediaFetch', error, stackTrace);
      return const [];
    }
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

  static List<QuizQuestion> _questionsFromRows(Object? rows) {
    if (rows is! List) return const [];
    return rows
        .whereType<Map>()
        .map((row) => QuizQuestion.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
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

    for (final url in urls) {
      final cacheKey = '$cacheScope::$url';
      if (_loadedImageUrls.contains(url) ||
          (!force && _imageCacheKeys.contains(cacheKey))) {
        loaded++;
        onProgress?.call(loaded, urls.length);
        continue;
      }
      try {
        final preload =
            _inFlightImagePreloads[url] ??
            precacheImage(mediaImageProvider(url), context);
        _inFlightImagePreloads[url] = preload;

        await preload.timeout(perImageTimeout);
        _imageCacheKeys.add(cacheKey);
        _loadedImageUrls.add(url);
      } catch (_) {
        failedUrls.add(url);
      } finally {
        _inFlightImagePreloads.remove(url);
        loaded++;
        onProgress?.call(loaded, urls.length);
      }
    }

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
