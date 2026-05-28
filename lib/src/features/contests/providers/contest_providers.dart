import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../auth/utils/auth_debug_logger.dart';
import '../../home/providers/home_bootstrap_provider.dart';
import '../../home/providers/user_profile_provider.dart';
import '../../../config/app_store_review_mode.dart';
import '../../../services/app_telemetry_service.dart';
import '../../../services/synced_clock_service.dart';
import '../../settings/providers/app_feature_flags_provider.dart';
import '../models/contest.dart';

final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  authLogPayload('categoriesFetch', {
    'table': 'categories',
    'filter': {'is_active': true},
  });

  final rows = await supabase
      .from('categories')
      .select('id, name, description, icon, color, is_active')
      .eq('is_active', true)
      .order('name', ascending: true);
  authLogResponse('categoriesFetch', {'count': rows.length});

  return rows.map(Category.fromJson).toList();
});

final contestsProvider = StreamProvider<List<Contest>>((ref) async* {
  ref.watch(appFeatureFlagsProvider);
  final supabase = ref.watch(supabaseProvider);
  final bootstrap = ref.watch(homeBootstrapProvider).value;
  final userPlanKey =
      bootstrap?.profile.planKey ??
      ref.watch(userProfileProvider).value?.planKey ??
      'free';
  authLogPayload('contestsStream', {
    'table': 'contests',
    'filter': {'status': 'active', 'liveEndedWindow': 'same-day'},
    'order': 'starts_at asc',
    'playerPlan': userPlanKey,
  });
  await _processLiveQuizEvents(supabase);

  var lastGoodContests = const <Contest>[];
  final bootstrapContests = bootstrap?.contests;
  if (bootstrapContests != null) {
    lastGoodContests = _sortContests(
      bootstrapContests
          .where(_isVisibleForAppStoreReview)
          .where((contest) => contest.isAccessibleForPlan(userPlanKey))
          .where((contest) => !contest.isLive || contest.isLiveReady)
          .toList(),
    );
    yield lastGoodContests;
  }

  try {
    lastGoodContests = await _loadContestsSnapshot(supabase, userPlanKey);
    yield lastGoodContests;
  } catch (error, stackTrace) {
    authLogError('contestsInitialSnapshot', error, stackTrace);
    if (!AppTelemetryService.isRetryableNetworkError(error)) rethrow;
    unawaited(
      AppTelemetryService.recordError(
        error,
        stackTrace,
        reason: 'contests_initial_snapshot_network',
      ),
    );
    if (bootstrapContests == null) {
      yield lastGoodContests;
    }
  }

  final stream = supabase
      .from('contests')
      .stream(primaryKey: ['id'])
      .order('starts_at', ascending: true)
      .asyncMap((rows) async {
        authLogResponse('contestsStream', {'count': rows.length});
        await _processLiveQuizEvents(supabase);
        try {
          lastGoodContests = await _loadContestsSnapshot(
            supabase,
            userPlanKey,
          );
          return lastGoodContests;
        } catch (error, stackTrace) {
          authLogError('contestsStreamSnapshot', error, stackTrace);
          if (!AppTelemetryService.isRetryableNetworkError(error)) rethrow;
          unawaited(
            AppTelemetryService.recordError(
              error,
              stackTrace,
              reason: 'contests_stream_snapshot_network',
            ),
          );
          return lastGoodContests;
        }
      });

  yield* stream.handleError((Object error, StackTrace stackTrace) {
    authLogError('contestsStream', error, stackTrace);
  });
});

Future<List<Contest>> _loadContestsSnapshot(
  dynamic supabase,
  String userPlanKey,
) async {
  final rows = await _fetchContestsWithLiveDuration(supabase);
  final now = SyncedClockService.now();
  final contests = rows
      .map(Contest.fromJson)
      .where((contest) {
        if (contest.isLive) return contest.isLiveVisibleOnHome;
        return contest.status == 'active' && contest.endsAt.isAfter(now);
      })
      .where(_isVisibleForAppStoreReview)
      .where((contest) => contest.isAccessibleForPlan(userPlanKey))
      .toList();
  return _sortContests(contests);
}

bool _isVisibleForAppStoreReview(Contest contest) {
  if (!AppStoreReviewMode.hideRandomOrPredictionCampaigns) return true;
  return contest.type != ContestType.tirage &&
      contest.type != ContestType.pronostic;
}

List<Contest> _sortContests(List<Contest> contests) {
  contests.sort((a, b) {
    final boostCompare = b.isBoosted.toString().compareTo(
      a.isBoosted.toString(),
    );
    if (boostCompare != 0) return boostCompare;
    return (a.startsAt ?? a.endsAt).compareTo(b.startsAt ?? b.endsAt);
  });
  return contests;
}

Future<void> _processLiveQuizEvents(dynamic supabase) async {
  try {
    await supabase.rpc('process_contest_events');
  } catch (_) {
    try {
      await supabase.rpc('process_live_quiz_events');
    } catch (_) {
      // The stream can still render with the current rows if the maintenance
      // RPC has not been deployed yet.
    }
  }
}

final userParticipatedContestIdsProvider = StreamProvider<Set<String>>((ref) {
  final supabase = ref.watch(supabaseProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(const <String>{});

  return supabase
      .from('participations')
      .stream(primaryKey: ['id'])
      .eq('user_id', userId)
      .map((rows) {
        return rows
            .map((row) => row['contest_id'] as String?)
            .whereType<String>()
            .toSet();
      });
});

final userRegisteredLiveQuizIdsProvider = StreamProvider<Set<String>>((ref) {
  final supabase = ref.watch(supabaseProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(const <String>{});

  return supabase
      .from('live_quiz_registrations')
      .stream(primaryKey: ['id'])
      .eq('user_id', userId)
      .map((rows) {
        return rows
            .where((row) => (row['status'] as String? ?? '') == 'registered')
            .map((row) => row['contest_id'] as String?)
            .whereType<String>()
            .toSet();
      });
});

final contestsShuffleSeedProvider =
    NotifierProvider<ContestsShuffleSeedNotifier, int>(
      ContestsShuffleSeedNotifier.new,
    );

class ContestsShuffleSeedNotifier extends Notifier<int> {
  @override
  int build() {
    final userId = ref.watch(currentUserIdProvider);
    return nextContestShuffleSeed(userId);
  }

  void refresh() {
    state = nextContestShuffleSeed(ref.read(currentUserIdProvider));
  }
}

int nextContestShuffleSeed([String? userId]) {
  final userHash = userId == null ? 0 : userId.hashCode;
  return DateTime.now().microsecondsSinceEpoch ^ userHash;
}

List<Contest> shuffleContestsForSession(Iterable<Contest> contests, int seed) {
  final shuffled = contests.toList()
    ..sort((first, second) {
      final firstRank = _stableContestRank(first.id, seed);
      final secondRank = _stableContestRank(second.id, seed);
      if (firstRank != secondRank) return firstRank.compareTo(secondRank);
      return first.id.compareTo(second.id);
    });
  return shuffled;
}

int _stableContestRank(String value, int seed) {
  var hash = 0x811c9dc5 ^ seed;
  for (final codeUnit in value.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash;
}

final contestParticipantsCountProvider = FutureProvider.autoDispose
    .family<int, String>((ref, contestId) async {
      final supabase = ref.watch(supabaseProvider);
      final participants = await supabase
          .from('participations')
          .select('id')
          .eq('contest_id', contestId);

      return participants.length;
    });

class ContestDetailData {
  final Contest contest;
  final bool hasParticipated;
  final ContestUserRanking? userRanking;
  final UserProfile userProfile;
  final int participantsCount;
  final ContestPrediction? prediction;
  final ContestDrawSettings? drawSettings;
  final bool hasLiveRegistration;

  const ContestDetailData({
    required this.contest,
    required this.hasParticipated,
    required this.userRanking,
    required this.userProfile,
    required this.participantsCount,
    required this.prediction,
    required this.drawSettings,
    required this.hasLiveRegistration,
  });
}

class ContestUserRanking {
  final int rank;
  final int score;
  final int totalParticipants;

  const ContestUserRanking({
    required this.rank,
    required this.score,
    required this.totalParticipants,
  });
}

class ContestPrediction {
  final String predictionType;
  final String homeTeam;
  final String awayTeam;
  final String matchLabel;
  final DateTime? matchDate;
  final int? homeScore;
  final int? awayScore;
  final String status;
  final int pointsExactScore;
  final int pointsCorrectResult;
  final Map<String, dynamic> options;
  final Map<String, dynamic> metadata;

  const ContestPrediction({
    required this.predictionType,
    required this.homeTeam,
    required this.awayTeam,
    required this.matchLabel,
    required this.matchDate,
    required this.homeScore,
    required this.awayScore,
    required this.status,
    required this.pointsExactScore,
    required this.pointsCorrectResult,
    required this.options,
    required this.metadata,
  });

  factory ContestPrediction.fromJson(Map<String, dynamic> json) {
    final options = _jsonMap(json['options']);
    final metadata = _jsonMap(json['metadata']);
    return ContestPrediction(
      predictionType:
          json['prediction_type'] as String? ??
          metadata['theme'] as String? ??
          'score_exact',
      homeTeam: json['home_team'] as String? ?? 'Equipe 1',
      awayTeam: json['away_team'] as String? ?? 'Equipe 2',
      matchLabel: json['match_label'] as String? ?? 'Quiz sport',
      matchDate: DateTime.tryParse(json['match_date'] as String? ?? ''),
      homeScore: (json['home_score'] as num?)?.toInt(),
      awayScore: (json['away_score'] as num?)?.toInt(),
      status: json['status'] as String? ?? 'open',
      pointsExactScore: (json['points_exact_score'] as num?)?.toInt() ?? 50,
      pointsCorrectResult:
          (json['points_correct_result'] as num?)?.toInt() ?? 20,
      options: options,
      metadata: metadata,
    );
  }

  bool get isOpen => status == 'open';

  FootballPredictionKind get kind =>
      FootballPredictionKind.fromKey(predictionType);

  String get prompt =>
      options['prompt'] as String? ??
      metadata['hint'] as String? ??
      kind.defaultPrompt;

  String get actionLabel =>
      options['action_label'] as String? ?? kind.defaultActionLabel;

  List<String> get players {
    final configured = _stringList(options['players']);
    if (configured.isNotEmpty) return configured;
    return kind.defaultPlayers;
  }

  bool get allowNone => options['allow_none'] as bool? ?? false;

  bool get allowOther => options['allow_other'] as bool? ?? true;

  int get minSelections =>
      (options['min_selections'] as num?)?.toInt() ?? kind.defaultMinSelections;

  int get maxSelections =>
      (options['max_selections'] as num?)?.toInt() ?? kind.defaultMaxSelections;
}

enum FootballPredictionKind {
  scoreExact,
  firstScorer,
  assistProvider,
  startingEleven,
  customText;

  factory FootballPredictionKind.fromKey(String value) {
    final normalized = value.trim().toLowerCase();
    return switch (normalized) {
      'score_exact' || 'exact_score' || 'score' => scoreExact,
      'first_scorer' || 'first_goal' || 'first_goal_scorer' => firstScorer,
      'assist_provider' || 'first_assist' || 'passeur' => assistProvider,
      'starting_eleven' || 'starting_lineup' || 'lineup' => startingEleven,
      'custom_text' || 'free_text' || 'text' => customText,
      _ => scoreExact,
    };
  }

  String get storageKey {
    return switch (this) {
      scoreExact => 'score_exact',
      firstScorer => 'first_scorer',
      assistProvider => 'assist_provider',
      startingEleven => 'starting_eleven',
      customText => 'custom_text',
    };
  }

  String get defaultPrompt {
    return switch (this) {
      scoreExact => 'Quel sera le score final ?',
      firstScorer => 'Qui marquera le premier but ?',
      assistProvider => 'Qui fera la premiere passe decisive ?',
      startingEleven => 'Selectionne les 11 joueurs titulaires.',
      customText => 'Entre ta réponse.',
    };
  }

  String get defaultActionLabel {
    return switch (this) {
      scoreExact => 'Valider mon score',
      firstScorer => 'Valider ma réponse',
      assistProvider => 'Valider ma réponse',
      startingEleven => 'Valider mon XI',
      customText => 'Valider ma réponse',
    };
  }

  int get defaultMinSelections => this == startingEleven ? 11 : 1;

  int get defaultMaxSelections => this == startingEleven ? 11 : 1;

  List<String> get defaultPlayers => const [
    'Yahia Fofana',
    'Serge Aurier',
    'Wilfried Singo',
    'Evan Ndicka',
    'Ghislain Konan',
    'Seko Fofana',
    'Franck Kessie',
    'Ibrahim Sangare',
    'Simon Adingra',
    'Nicolas Pepe',
    'Sebastien Haller',
    'Oumar Diakite',
    'Karim Konate',
    'Jean-Philippe Krasso',
    'Max-Alain Gradel',
    'Jeremie Boga',
    'Odilon Kossounou',
    'Willy Boly',
  ];
}

Map<String, dynamic> _jsonMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  return <String, dynamic>{};
}

List<String> _stringList(dynamic value) {
  if (value is! List) return const <String>[];
  return value
      .map((item) => item?.toString().trim() ?? '')
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

class ContestDrawSettings {
  final int standardTickets;
  final int premiumTickets;
  final String confirmationMessage;
  final DateTime? winnerAnnouncementAt;
  final String rules;

  const ContestDrawSettings({
    required this.standardTickets,
    required this.premiumTickets,
    required this.confirmationMessage,
    required this.winnerAnnouncementAt,
    required this.rules,
  });

  factory ContestDrawSettings.fromJson(Map<String, dynamic> json) {
    return ContestDrawSettings(
      standardTickets: (json['standard_tickets'] as num?)?.toInt() ?? 1,
      premiumTickets: (json['premium_tickets'] as num?)?.toInt() ?? 2,
      confirmationMessage:
          json['confirmation_message'] as String? ??
          'Participation validée ! Les lauréats seront annoncés bientôt.',
      winnerAnnouncementAt: DateTime.tryParse(
        json['winner_announcement_at'] as String? ?? '',
      ),
      rules: json['rules'] as String? ?? '',
    );
  }
}

final Map<String, ContestDetailData> _contestDetailCache = {};

String _contestDetailCacheKey(String userId, String contestId) {
  return '$userId::$contestId';
}

void clearContestDetailCache(String contestId) {
  _contestDetailCache.removeWhere((key, _) => key.endsWith('::$contestId'));
}

void clearAllContestDetailCache() {
  _contestDetailCache.clear();
}

Contest? _findContest(List<Contest>? contests, String contestId) {
  if (contests == null) return null;
  for (final contest in contests) {
    if (contest.id == contestId) return contest;
  }
  return null;
}

Future<Contest> _fetchContestDetailContest(
  dynamic supabase,
  String contestId,
) async {
  final contestRows = await _fetchContestsWithLiveDuration(
    supabase,
    contestId: contestId,
  );
  if (contestRows.isEmpty) {
    throw StateError('Quiz introuvable.');
  }
  final contestRow = contestRows.first;
  authLogResponse('contestDetailFetch', contestRow);
  return Contest.fromJson(contestRow);
}

Future<Map<String, dynamic>?> _fetchContestParticipation(
  dynamic supabase,
  String userId,
  String contestId,
) async {
  authLogPayload('contestParticipationCheck', {
    'userId': userId,
    'contestId': contestId,
  });
  final participation = await supabase
      .from('participations')
      .select('id')
      .eq('user_id', userId)
      .eq('contest_id', contestId)
      .maybeSingle();
  authLogResponse('contestParticipationCheck', participation);
  if (participation == null) return null;
  return Map<String, dynamic>.from(participation as Map);
}

Future<bool> _fetchLiveRegistration(
  dynamic supabase,
  String userId,
  String contestId,
) async {
  try {
    authLogPayload('liveRegistrationCheck', {
      'userId': userId,
      'contestId': contestId,
    });
    final registration = await supabase
        .from('live_quiz_registrations')
        .select('id')
        .eq('user_id', userId)
        .eq('contest_id', contestId)
        .maybeSingle();
    authLogResponse('liveRegistrationCheck', registration);
    return registration != null;
  } catch (error, stackTrace) {
    authLogError('liveRegistrationCheck', error, stackTrace);
    return false;
  }
}

final contestDetailProvider = FutureProvider.family<ContestDetailData, String>((
  ref,
  contestId,
) async {
  final supabase = ref.watch(supabaseProvider);
  final bootstrap = ref.read(homeBootstrapProvider).value;
  final userId = ref.watch(currentUserIdProvider);

  if (userId == null) {
    throw StateError('Utilisateur non connecté.');
  }

  final cacheKey = _contestDetailCacheKey(userId, contestId);
  final cachedDetail = _contestDetailCache[cacheKey];
  if (cachedDetail != null && !cachedDetail.contest.isLive) {
    authLogResponse('contestDetailCache', {
      'contestId': contestId,
      'hit': true,
    });
    return cachedDetail;
  } else if (cachedDetail != null) {
    authLogResponse('contestDetailCache', {
      'contestId': contestId,
      'hit': false,
      'reason': 'live_contest_requires_fresh_state',
    });
  }

  final bootstrapContest = _findContest(bootstrap?.contests, contestId);
  authLogPayload('contestDetailFetch', {'contestId': contestId});
  await _processLiveQuizEvents(supabase);
  final contestFuture = bootstrapContest != null && !bootstrapContest.isLive
      ? Future<Contest>.value(bootstrapContest)
      : _fetchContestDetailContest(supabase, contestId);
  final profileFuture = bootstrap?.profile == null
      ? fetchCurrentUserProfile(ref, userId: userId)
      : Future<UserProfile>.value(bootstrap!.profile);
  final participationFuture =
      bootstrap?.participatedContestIds.contains(contestId) == true
      ? Future<Map<String, dynamic>?>.value(<String, dynamic>{'id': 'cached'})
      : _fetchContestParticipation(supabase, userId, contestId);

  final liveRegistrationFuture =
      bootstrap?.registeredLiveQuizIds.contains(contestId) == true
      ? Future<bool>.value(true)
      : _fetchLiveRegistration(supabase, userId, contestId);

  var contest = await contestFuture;
  final profile = await profileFuture;
  final participation = await participationFuture;
  var hasLiveRegistration = contest.isLive
      ? await liveRegistrationFuture
      : false;

  if (contest.categoryId != null) {
    try {
      if (contest.categoryData == null) {
        authLogPayload('contestCategoryFetch', {
          'categoryId': contest.categoryId,
        });
        final categoryRow = await supabase
            .from('categories')
            .select('id, name, description, icon, color, is_active')
            .eq('id', contest.categoryId!)
            .maybeSingle();
        authLogResponse('contestCategoryFetch', categoryRow);
        contest = contest.copyWithCategory(
          categoryRow == null ? null : Category.fromJson(categoryRow),
        );
      }
    } catch (error, stackTrace) {
      authLogError('contestCategoryFetch', error, stackTrace);
    }
  }

  try {
    authLogPayload('contestIncrementView', {
      'contestId': contestId,
      'mode': 'unique_user_per_day',
    });
    final viewResponse = await supabase.rpc(
      'register_contest_view',
      params: {'p_contest_id': contestId},
    );
    authLogResponse('contestIncrementView', viewResponse);
    if (viewResponse is Map<String, dynamic>) {
      final nextViewsCount = (viewResponse['views_count'] as num?)?.toInt();
      if (nextViewsCount != null) {
        contest = contest.copyWithViewsCount(nextViewsCount);
      }
    }
  } catch (error, stackTrace) {
    authLogError('contestIncrementView', error, stackTrace);
  }

  ContestUserRanking? userRanking;
  var participantsCount = contest.participantsCount;
  if (participation != null) {
    authLogPayload('contestParticipantsFetch', {
      'contestId': contestId,
      'reason': 'ranking',
    });
    final participants = await supabase
        .from('participations')
        .select('id, user_id, score')
        .eq('contest_id', contestId)
        .order('score', ascending: false);
    participantsCount = participants.length;
    authLogResponse('contestParticipantsFetch', {'count': participants.length});
    final userIndex = participants.indexWhere(
      (row) => row['user_id'] == userId,
    );
    if (userIndex >= 0) {
      final score = (participants[userIndex]['score'] as num?)?.toInt() ?? 0;
      userRanking = ContestUserRanking(
        rank: userIndex + 1,
        score: score,
        totalParticipants: participants.length,
      );
    }
  }

  ContestPrediction? prediction;
  if (contest.type == ContestType.pronostic) {
    try {
      authLogPayload('contestPredictionFetch', {'contestId': contestId});
      final row = await supabase
          .from('contest_predictions')
          .select()
          .eq('contest_id', contestId)
          .maybeSingle();
      authLogResponse('contestPredictionFetch', row);
      if (row != null) prediction = ContestPrediction.fromJson(row);
      if (row == null) {
        authLogResponse('contestPredictionFetch', {
          'configured': false,
          'message': 'No row found in contest_predictions for this contest.',
        });
      }
    } catch (error, stackTrace) {
      authLogError('contestPredictionFetch', error, stackTrace);
    }
  }

  ContestDrawSettings? drawSettings;
  if (contest.type == ContestType.tirage) {
    try {
      authLogPayload('contestDrawSettingsFetch', {'contestId': contestId});
      final row = await supabase
          .from('contest_draw_settings')
          .select()
          .eq('contest_id', contestId)
          .maybeSingle();
      authLogResponse('contestDrawSettingsFetch', row);
      if (row != null) drawSettings = ContestDrawSettings.fromJson(row);
      if (row == null) {
        authLogResponse('contestDrawSettingsFetch', {
          'configured': false,
          'message': 'No row found in contest_draw_settings for this contest.',
        });
      }
    } catch (error, stackTrace) {
      authLogError('contestDrawSettingsFetch', error, stackTrace);
    }
  }

  final detail = ContestDetailData(
    contest: contest,
    hasParticipated: participation != null,
    userRanking: userRanking,
    userProfile: profile,
    participantsCount: participantsCount,
    prediction: prediction,
    drawSettings: drawSettings,
    hasLiveRegistration: hasLiveRegistration,
  );
  _contestDetailCache[cacheKey] = detail;

  return detail;
});

Future<List<Map<String, dynamic>>> _fetchContestsWithLiveDuration(
  dynamic supabase, {
  String? contestId,
}) async {
  final query = supabase.from('contests').select('*, questions(time_limit)');
  final rows = contestId == null
      ? await query
      : await query.eq('id', contestId);

  return (rows as List<dynamic>)
      .map((row) {
        final json = Map<String, dynamic>.from(row as Map);
        final questions = json.remove('questions');
        final durationSeconds = questions is List
            ? questions.fold<int>(0, (total, question) {
                if (question is! Map) return total;
                final value = question['time_limit'];
                return total + ((value as num?)?.toInt() ?? 0);
              })
            : 0;
        json['live_questions_count'] = questions is List ? questions.length : 0;
        json['live_duration_seconds'] = durationSeconds;
        return json;
      })
      .toList(growable: false);
}
