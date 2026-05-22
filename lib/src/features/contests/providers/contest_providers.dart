import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../auth/utils/auth_debug_logger.dart';
import '../../home/providers/user_profile_provider.dart';
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

final contestsProvider = StreamProvider<List<Contest>>((ref) {
  final supabase = ref.watch(supabaseProvider);
  final userPlanKey = ref.watch(userProfileProvider).value?.planKey ?? 'free';
  authLogPayload('contestsStream', {
    'table': 'contests',
    'filter': {'status': 'active', 'liveEndedWindow': '24h'},
    'order': 'starts_at asc',
    'playerPlan': userPlanKey,
  });

  final stream = supabase
      .from('contests')
      .stream(primaryKey: ['id'])
      .order('starts_at', ascending: true)
      .map((rows) {
        authLogResponse('contestsStream', {'count': rows.length});
        final now = DateTime.now();
        final contests = rows
            .map(Contest.fromJson)
            .where((contest) {
              if (contest.isLive) return contest.isLiveVisibleOnHome;
              return contest.status == 'active' && contest.endsAt.isAfter(now);
            })
            .where((contest) => contest.isAccessibleForPlan(userPlanKey))
            .toList();
        contests.sort((a, b) {
          final boostCompare = b.isBoosted.toString().compareTo(
            a.isBoosted.toString(),
          );
          if (boostCompare != 0) return boostCompare;
          return (a.startsAt ?? a.endsAt).compareTo(b.startsAt ?? b.endsAt);
        });
        return contests;
      });

  return stream.handleError((Object error, StackTrace stackTrace) {
    authLogError('contestsStream', error, stackTrace);
  });
});

final userParticipatedContestIdsProvider = StreamProvider<Set<String>>((ref) {
  final supabase = ref.watch(supabaseProvider);
  final user = supabase.auth.currentUser;
  if (user == null) return Stream.value(const <String>{});

  return supabase
      .from('participations')
      .stream(primaryKey: ['id'])
      .eq('user_id', user.id)
      .map((rows) {
        return rows
            .map((row) => row['contest_id'] as String?)
            .whereType<String>()
            .toSet();
      });
});

final userRegisteredLiveQuizIdsProvider = StreamProvider<Set<String>>((ref) {
  final supabase = ref.watch(supabaseProvider);
  final user = supabase.auth.currentUser;
  if (user == null) return Stream.value(const <String>{});

  return supabase
      .from('live_quiz_registrations')
      .stream(primaryKey: ['id'])
      .eq('user_id', user.id)
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
    final supabase = ref.watch(supabaseProvider);
    return nextContestShuffleSeed(supabase.auth.currentUser?.id);
  }

  void refresh() {
    final supabase = ref.read(supabaseProvider);
    state = nextContestShuffleSeed(supabase.auth.currentUser?.id);
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
  final UserProfile userProfile;
  final int participantsCount;
  final ContestPrediction? prediction;
  final ContestDrawSettings? drawSettings;
  final bool hasLiveRegistration;

  const ContestDetailData({
    required this.contest,
    required this.hasParticipated,
    required this.userProfile,
    required this.participantsCount,
    required this.prediction,
    required this.drawSettings,
    required this.hasLiveRegistration,
  });
}

class ContestPrediction {
  final String homeTeam;
  final String awayTeam;
  final String matchLabel;
  final DateTime? matchDate;
  final int? homeScore;
  final int? awayScore;
  final String status;
  final int pointsExactScore;
  final int pointsCorrectResult;

  const ContestPrediction({
    required this.homeTeam,
    required this.awayTeam,
    required this.matchLabel,
    required this.matchDate,
    required this.homeScore,
    required this.awayScore,
    required this.status,
    required this.pointsExactScore,
    required this.pointsCorrectResult,
  });

  factory ContestPrediction.fromJson(Map<String, dynamic> json) {
    return ContestPrediction(
      homeTeam: json['home_team'] as String? ?? 'Equipe 1',
      awayTeam: json['away_team'] as String? ?? 'Equipe 2',
      matchLabel: json['match_label'] as String? ?? 'Pronostic du match',
      matchDate: DateTime.tryParse(json['match_date'] as String? ?? ''),
      homeScore: (json['home_score'] as num?)?.toInt(),
      awayScore: (json['away_score'] as num?)?.toInt(),
      status: json['status'] as String? ?? 'open',
      pointsExactScore: (json['points_exact_score'] as num?)?.toInt() ?? 50,
      pointsCorrectResult:
          (json['points_correct_result'] as num?)?.toInt() ?? 20,
    );
  }

  bool get isOpen => status == 'open';
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
          'Tu participes ! Les gagnants seront annoncés bientôt.',
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

final contestDetailProvider = FutureProvider.family<ContestDetailData, String>((
  ref,
  contestId,
) async {
  final supabase = ref.watch(supabaseProvider);
  final user = supabase.auth.currentUser;

  if (user == null) {
    throw StateError('Utilisateur non connecté.');
  }

  final cacheKey = _contestDetailCacheKey(user.id, contestId);
  final cachedDetail = _contestDetailCache[cacheKey];
  if (cachedDetail != null) {
    authLogResponse('contestDetailCache', {
      'contestId': contestId,
      'hit': true,
    });
    return cachedDetail;
  }

  authLogPayload('contestDetailFetch', {'contestId': contestId});
  final contestRow = await supabase
      .from('contests')
      .select()
      .eq('id', contestId)
      .single();
  authLogResponse('contestDetailFetch', contestRow);
  var contest = Contest.fromJson(contestRow);

  if (contest.categoryId != null) {
    try {
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
      final counted = viewResponse['counted'] == true;
      if (nextViewsCount != null) {
        contest = contest.copyWithViewsCount(nextViewsCount);
      }
      if (counted) {
        ref.invalidate(contestsProvider);
      }
    }
  } catch (error, stackTrace) {
    authLogError('contestIncrementView', error, stackTrace);
  }

  authLogPayload('contestParticipationCheck', {
    'userId': user.id,
    'contestId': contestId,
  });
  final participation = await supabase
      .from('participations')
      .select('id')
      .eq('user_id', user.id)
      .eq('contest_id', contestId)
      .maybeSingle();
  authLogResponse('contestParticipationCheck', participation);

  var hasLiveRegistration = false;
  if (contest.isLive) {
    try {
      authLogPayload('liveRegistrationCheck', {
        'userId': user.id,
        'contestId': contestId,
      });
      final registration = await supabase
          .from('live_quiz_registrations')
          .select('id')
          .eq('user_id', user.id)
          .eq('contest_id', contestId)
          .maybeSingle();
      authLogResponse('liveRegistrationCheck', registration);
      hasLiveRegistration = registration != null;
    } catch (error, stackTrace) {
      authLogError('liveRegistrationCheck', error, stackTrace);
    }
  }

  authLogPayload('contestParticipantsFetch', {'contestId': contestId});
  final participants = await supabase
      .from('participations')
      .select('id')
      .eq('contest_id', contestId);
  authLogResponse('contestParticipantsFetch', {'count': participants.length});

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

  final profile = await fetchCurrentUserProfile(ref);

  final detail = ContestDetailData(
    contest: contest,
    hasParticipated: participation != null,
    userProfile: profile,
    participantsCount: participants.length,
    prediction: prediction,
    drawSettings: drawSettings,
    hasLiveRegistration: hasLiveRegistration,
  );
  _contestDetailCache[cacheKey] = detail;

  return detail;
});
