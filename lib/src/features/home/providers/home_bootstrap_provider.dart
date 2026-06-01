import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/providers/auth_provider.dart';
import '../../auth/utils/auth_debug_logger.dart';
import '../../contests/models/contest.dart';
import '../../../config/app_store_review_mode.dart';
import '../../../services/app_telemetry_service.dart';
import '../../../services/synced_clock_service.dart';
import '../../settings/providers/app_feature_flags_provider.dart';
import 'user_profile_provider.dart';

class HomeBootstrapData {
  final UserProfile profile;
  final List<Contest> contests;
  final Set<String> registeredLiveQuizIds;
  final Set<String> participatedContestIds;
  final int unreadNotificationsCount;
  final DateTime? serverNow;

  const HomeBootstrapData({
    required this.profile,
    required this.contests,
    required this.registeredLiveQuizIds,
    required this.participatedContestIds,
    required this.unreadNotificationsCount,
    required this.serverNow,
  });
}

HomeBootstrapData? _cachedHomeBootstrap;
DateTime? _cachedHomeBootstrapAt;
Future<HomeBootstrapData>? _pendingHomeBootstrap;
String? _pendingHomeBootstrapUserId;
const _storedBootstrapPrefix = 'home_bootstrap_payload_v1';
const _storedBootstrapMaxAge = Duration(seconds: 30);

void clearHomeBootstrapCache({String? userId, bool clearStored = false}) {
  _cachedHomeBootstrap = null;
  _cachedHomeBootstrapAt = null;
  _pendingHomeBootstrap = null;
  _pendingHomeBootstrapUserId = null;
  if (clearStored && userId != null) {
    unawaited(_removeStoredHomeBootstrap(userId));
  }
}

final homeBootstrapProvider = FutureProvider.autoDispose<HomeBootstrapData>((
  ref,
) async {
  ref.watch(appFeatureFlagsProvider);
  final keepAliveLink = ref.keepAlive();
  final cacheTimer = Timer(const Duration(seconds: 25), keepAliveLink.close);
  ref.onDispose(cacheTimer.cancel);

  final supabase = ref.watch(supabaseProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) {
    throw StateError('Utilisateur non connecté.');
  }

  final cached = _cachedHomeBootstrap;
  final cachedAt = _cachedHomeBootstrapAt;
  if (cached != null &&
      cached.profile.id == userId &&
      cachedAt != null &&
      DateTime.now().difference(cachedAt) < const Duration(seconds: 12)) {
    return cached;
  }

  final stored = await _readStoredHomeBootstrap(userId);
  if (stored != null) {
    _cachedHomeBootstrap = stored;
    _cachedHomeBootstrapAt = DateTime.now();
    unawaited(_refreshStoredHomeBootstrap(ref, userId));
    return stored;
  }

  final pending = _pendingHomeBootstrap;
  if (pending != null && _pendingHomeBootstrapUserId == userId) {
    return pending;
  }

  final request = _fetchHomeBootstrap(ref, userId);
  _pendingHomeBootstrap = request;
  _pendingHomeBootstrapUserId = userId;
  try {
    final data = await request;
    _cachedHomeBootstrap = data;
    _cachedHomeBootstrapAt = DateTime.now();
    return data;
  } finally {
    if (identical(_pendingHomeBootstrap, request)) {
      _pendingHomeBootstrap = null;
      _pendingHomeBootstrapUserId = null;
    }
  }
});

Future<HomeBootstrapData> _fetchHomeBootstrap(Ref ref, String userId) async {
  final supabase = ref.watch(supabaseProvider);
  authLogPayload('homeBootstrap', {'userId': userId});
  try {
    await supabase.rpc('process_contest_events');
  } catch (_) {
    try {
      await supabase.rpc('process_live_quiz_events');
    } catch (_) {
      // The bootstrap RPC still filters expired live quizzes client-side if the
      // maintenance RPC has not been deployed yet.
    }
  }

  Object response;
  try {
    response = await supabase.rpc('get_mobile_home_bootstrap');
  } catch (error, stackTrace) {
    authLogError('homeBootstrap', error, stackTrace);
    return _fetchHomeBootstrapFallback(ref, userId);
  }

  final payload = _asMap(response);
  authLogResponse('homeBootstrap', {
    'contests': (payload['contests'] as List?)?.length ?? 0,
    'registeredLiveQuizIds':
        (payload['registered_live_quiz_ids'] as List?)?.length ?? 0,
    'participatedContestIds':
        (payload['participated_contest_ids'] as List?)?.length ?? 0,
  });

  await _writeStoredHomeBootstrap(userId, payload);
  return _payloadToHomeBootstrapData(payload);
}

HomeBootstrapData _payloadToHomeBootstrapData(Map<String, dynamic> payload) {
  final profileJson = _asMap(payload['profile']);
  final activeSubscription = payload['active_subscription'] == null
      ? null
      : _asMap(payload['active_subscription']);
  final profile = UserProfile.fromJson(
    profileJson,
    activeSubscription: activeSubscription,
  );

  final contests = _asList(payload['contests'])
      .map(_asMap)
      .map(Contest.fromJson)
      .where((contest) {
        if (contest.isLive) {
          return contest.isLiveReady && contest.isLiveVisibleOnHome;
        }
        return contest.status == 'active';
      })
      .where(_isVisibleForAppStoreReview)
      .where((contest) => contest.isAccessibleForPlan(profile.planKey))
      .toList();

  return HomeBootstrapData(
    profile: profile,
    contests: contests,
    registeredLiveQuizIds: _stringSet(payload['registered_live_quiz_ids']),
    participatedContestIds: _stringSet(payload['participated_contest_ids']),
    unreadNotificationsCount:
        (payload['unread_notifications_count'] as num?)?.toInt() ?? 0,
    serverNow: DateTime.tryParse(payload['server_now'] as String? ?? ''),
  );
}

Future<void> _refreshStoredHomeBootstrap(Ref ref, String userId) async {
  try {
    final data = await _fetchHomeBootstrap(ref, userId);
    _cachedHomeBootstrap = data;
    _cachedHomeBootstrapAt = DateTime.now();
    ref.invalidateSelf();
  } catch (_) {
    // The persisted cache has already made the screen usable.
  }
}

Future<HomeBootstrapData> _fetchHomeBootstrapFallback(
  Ref ref,
  String userId,
) async {
  final supabase = ref.watch(supabaseProvider);
  authLogPayload('homeBootstrapFallback', {'userId': userId});

  try {
    await supabase.rpc('process_contest_events');
  } catch (_) {
    try {
      await supabase.rpc('process_live_quiz_events');
    } catch (_) {
      // The fallback must keep the Home usable even before maintenance RPCs are
      // deployed.
    }
  }

  UserProfile profile;
  try {
    profile = await fetchCurrentUserProfile(ref, userId: userId);
  } catch (error, stackTrace) {
    authLogError('homeBootstrapFallbackProfile', error, stackTrace);
    if (AppTelemetryService.isRetryableNetworkError(error)) {
      final cached = _cachedHomeBootstrap;
      if (cached != null && cached.profile.id == userId) {
        unawaited(
          AppTelemetryService.recordError(
            error,
            stackTrace,
            reason: 'home_bootstrap_fallback_profile_network',
          ),
        );
        return cached;
      }
    }
    rethrow;
  }

  var contests = const <Contest>[];
  try {
    contests = (await _fetchFallbackContests(supabase))
        .where(_isVisibleForAppStoreReview)
        .where((contest) => contest.isAccessibleForPlan(profile.planKey))
        .toList();
  } catch (error, stackTrace) {
    authLogError('homeBootstrapFallbackContests', error, stackTrace);
    if (!AppTelemetryService.isRetryableNetworkError(error)) rethrow;
    unawaited(
      AppTelemetryService.recordError(
        error,
        stackTrace,
        reason: 'home_bootstrap_fallback_contests_network',
      ),
    );
    contests = _cachedHomeBootstrap?.profile.id == userId
        ? _cachedHomeBootstrap!.contests
        : const <Contest>[];
  }

  final registeredRows = await _selectRowsOrEmpty(
    supabase
        .from('live_quiz_registrations')
        .select('contest_id')
        .eq('user_id', userId)
        .eq('status', 'registered'),
    reason: 'home_bootstrap_fallback_registered_network',
  );
  final participatedRows = await _selectRowsOrEmpty(
    supabase.from('participations').select('contest_id').eq('user_id', userId),
    reason: 'home_bootstrap_fallback_participated_network',
  );
  final unreadRows = await _selectRowsOrEmpty(
    supabase
        .from('notifications')
        .select('id')
        .eq('user_id', userId)
        .eq('is_read', false),
    reason: 'home_bootstrap_fallback_unread_network',
  );

  final data = HomeBootstrapData(
    profile: profile,
    contests: contests,
    registeredLiveQuizIds: _rowsToContestIds(registeredRows),
    participatedContestIds: _rowsToContestIds(participatedRows),
    unreadNotificationsCount: unreadRows.length,
    serverNow: SyncedClockService.now(),
  );

  authLogResponse('homeBootstrapFallback', {
    'contests': data.contests.length,
    'registeredLiveQuizIds': data.registeredLiveQuizIds.length,
    'participatedContestIds': data.participatedContestIds.length,
  });
  _cachedHomeBootstrap = data;
  _cachedHomeBootstrapAt = DateTime.now();
  return data;
}

bool _isVisibleForAppStoreReview(Contest contest) {
  if (!AppStoreReviewMode.hideRandomOrPredictionCampaigns) return true;
  return contest.type != ContestType.tirage &&
      contest.type != ContestType.pronostic;
}

Future<List<dynamic>> _selectRowsOrEmpty(
  dynamic query, {
  required String reason,
}) async {
  try {
    final rows = await query;
    return rows is List ? rows : const <dynamic>[];
  } catch (error, stackTrace) {
    authLogError(reason, error, stackTrace);
    if (!AppTelemetryService.isRetryableNetworkError(error)) rethrow;
    unawaited(
      AppTelemetryService.recordError(error, stackTrace, reason: reason),
    );
    return const <dynamic>[];
  }
}

Future<HomeBootstrapData?> _readStoredHomeBootstrap(String userId) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_storedBootstrapPrefix::$userId');
    if (raw == null || raw.isEmpty) return null;

    final envelope = jsonDecode(raw);
    if (envelope is! Map) return null;
    final cachedAt = DateTime.tryParse(envelope['cached_at'] as String? ?? '');
    if (cachedAt == null ||
        DateTime.now().difference(cachedAt) > _storedBootstrapMaxAge) {
      return null;
    }

    final payload = _asMap(envelope['payload']);
    if (payload.isEmpty) return null;
    authLogResponse('homeBootstrapStoredCache', {
      'ageSeconds': DateTime.now().difference(cachedAt).inSeconds,
      'contests': (payload['contests'] as List?)?.length ?? 0,
    });
    return _payloadToHomeBootstrapData(payload);
  } catch (error, stackTrace) {
    authLogError('homeBootstrapStoredCache', error, stackTrace);
    return null;
  }
}

Future<void> _writeStoredHomeBootstrap(
  String userId,
  Map<String, dynamic> payload,
) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_storedBootstrapPrefix::$userId',
      jsonEncode(<String, dynamic>{
        'cached_at': DateTime.now().toIso8601String(),
        'payload': payload,
      }),
    );
  } catch (error, stackTrace) {
    authLogError('homeBootstrapStoreWrite', error, stackTrace);
  }
}

Future<void> _removeStoredHomeBootstrap(String userId) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_storedBootstrapPrefix::$userId');
  } catch (error, stackTrace) {
    authLogError('homeBootstrapStoredCacheRemove', error, stackTrace);
  }
}

Future<List<Contest>> _fetchFallbackContests(dynamic supabase) async {
  final rows = await supabase
      .from('contests')
      .select('*, questions(time_limit)')
      .order('starts_at', ascending: true);
  final now = SyncedClockService.now();

  final contests = (rows as List<dynamic>)
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
        return Contest.fromJson(json);
      })
      .where((contest) {
        if (contest.isLive) return contest.isLiveVisibleOnHome;
        return contest.status == 'active' && contest.endsAt.isAfter(now);
      })
      .toList();

  contests.sort((a, b) {
    final boostCompare = b.isBoosted.toString().compareTo(
      a.isBoosted.toString(),
    );
    if (boostCompare != 0) return boostCompare;
    return _contestScheduleAt(a).compareTo(_contestScheduleAt(b));
  });
  return contests;
}

DateTime _contestScheduleAt(Contest contest) {
  if (contest.isLive && contest.liveStartsAt != null) {
    return contest.liveStartsAt!;
  }
  return contest.startsAt ?? contest.endsAt;
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

List<dynamic> _asList(Object? value) {
  if (value is List) return value;
  return const <dynamic>[];
}

Set<String> _stringSet(Object? value) {
  return _asList(value).map((item) => item.toString()).toSet();
}

Set<String> _rowsToContestIds(Object? rows) {
  return _asList(rows)
      .map(_asMap)
      .map((row) => row['contest_id'] as String?)
      .whereType<String>()
      .toSet();
}
