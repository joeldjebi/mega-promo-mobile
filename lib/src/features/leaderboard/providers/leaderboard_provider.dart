import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';

class LeaderboardData {
  final List<LeaderboardUser> users;
  final LeaderboardUser? currentUser;
  final int? currentUserRank;
  final bool hasContestScope;
  final bool hasLiveQuizScope;

  const LeaderboardData({
    required this.users,
    required this.currentUser,
    required this.currentUserRank,
    required this.hasContestScope,
    required this.hasLiveQuizScope,
  });
}

enum LeaderboardScope { system, liveQuiz, contest }

class LeaderboardRequest {
  final LeaderboardScope scope;
  final String? contestId;

  const LeaderboardRequest._({required this.scope, this.contestId});

  const LeaderboardRequest.system() : this._(scope: LeaderboardScope.system);

  const LeaderboardRequest.liveQuiz()
    : this._(scope: LeaderboardScope.liveQuiz);

  const LeaderboardRequest.contest(String contestId)
    : this._(scope: LeaderboardScope.contest, contestId: contestId);

  @override
  bool operator ==(Object other) {
    return other is LeaderboardRequest &&
        other.scope == scope &&
        other.contestId == contestId;
  }

  @override
  int get hashCode => Object.hash(scope, contestId);
}

class LeaderboardUser {
  final String id;
  final String username;
  final String? avatarUrl;
  final int points;
  final int? rank;

  const LeaderboardUser({
    required this.id,
    required this.username,
    required this.avatarUrl,
    required this.points,
    this.rank,
  });

  factory LeaderboardUser.fromUser(Map<String, dynamic> json) {
    return LeaderboardUser(
      id: json['id'] as String,
      username: json['username'] as String? ?? 'Joueur',
      avatarUrl: json['avatar_url'] as String?,
      points: (json['points_total'] as num?)?.toInt() ?? 0,
      rank: (json['rank'] as num?)?.toInt(),
    );
  }
}

final leaderboardProvider =
    StreamProvider.family<LeaderboardData, LeaderboardRequest>((ref, request) {
      final supabase = ref.watch(supabaseProvider);
      final currentUserId = ref.watch(currentUserIdProvider);

      if (request.scope == LeaderboardScope.system) {
        return supabase
            .from('participations')
            .stream(primaryKey: ['id'])
            .order('score', ascending: false)
            .limit(1)
            .asyncMap((_) async {
              return await _fetchLeaderboardRpc(supabase, request) ??
                  _buildParticipationLeaderboardData(supabase, currentUserId);
            });
      }

      if (request.scope == LeaderboardScope.liveQuiz) {
        return supabase
            .from('participations')
            .stream(primaryKey: ['id'])
            .order('score', ascending: false)
            .limit(1)
            .asyncMap((_) async {
              return await _fetchLeaderboardRpc(supabase, request) ??
                  _buildParticipationLeaderboardData(
                    supabase,
                    currentUserId,
                    liveQuizOnly: true,
                  );
            });
      }

      final contestId = request.contestId;
      if (contestId == null || contestId.isEmpty) {
        return Stream.value(
          const LeaderboardData(
            users: [],
            currentUser: null,
            currentUserRank: null,
            hasContestScope: false,
            hasLiveQuizScope: false,
          ),
        );
      }

      return supabase
          .from('participations')
          .stream(primaryKey: ['id'])
          .eq('contest_id', contestId)
          .order('score', ascending: false)
          .limit(100)
          .asyncMap((rows) async {
            final rpcData = await _fetchLeaderboardRpc(supabase, request);
            if (rpcData != null) return rpcData;

            final ids = rows.map((row) => row['user_id'] as String).toList();
            if (ids.isEmpty) {
              final currentRank = await _fetchCurrentContestRank(
                supabase,
                contestId,
                currentUserId,
              );
              return LeaderboardData(
                users: const [],
                currentUser: currentRank?.user,
                currentUserRank: currentRank?.rank,
                hasContestScope: true,
                hasLiveQuizScope: false,
              );
            }
            final users = await supabase
                .from('users')
                .select(
                  'id, username, avatar_url, points_total, role, is_active, '
                  'account_status',
                )
                .inFilter('id', ids);
            final usersById = {
              for (final user in users) user['id'] as String: user,
            };

            final leaderboardUsers = <LeaderboardUser>[];
            for (final row in rows) {
              final user = usersById[row['user_id']];
              if (user == null || !_isVisiblePlayerRow(user)) continue;
              leaderboardUsers.add(
                LeaderboardUser(
                  id: row['user_id'] as String,
                  username: user['username'] as String? ?? 'Joueur',
                  avatarUrl: user['avatar_url'] as String?,
                  points: (row['score'] as num?)?.toInt() ?? 0,
                ),
              );
            }

            final visibleIndex = leaderboardUsers.indexWhere(
              (user) => user.id == currentUserId,
            );
            final currentRank = visibleIndex >= 0
                ? _CurrentContestRank(
                    user: leaderboardUsers[visibleIndex],
                    rank: visibleIndex + 1,
                  )
                : await _fetchCurrentContestRank(
                    supabase,
                    contestId,
                    currentUserId,
                  );

            return LeaderboardData(
              users: leaderboardUsers,
              currentUser: currentRank?.user,
              currentUserRank: currentRank?.rank,
              hasContestScope: true,
              hasLiveQuizScope: false,
            );
          });
    });

bool _isVisiblePlayerRow(Map<String, dynamic> row) {
  final role = (row['role'] as String?)?.toLowerCase().trim();
  final accountStatus = (row['account_status'] as String?)
      ?.toLowerCase()
      .trim();
  final username = (row['username'] as String?)?.trim();
  final isActive = row['is_active'];

  if (isActive == false) return false;
  if (accountStatus == 'deleted' ||
      accountStatus == 'disabled' ||
      accountStatus == 'banned') {
    return false;
  }
  if (role == 'admin' ||
      role == 'super_admin' ||
      role == 'sa' ||
      role == 'support') {
    return false;
  }
  if (username == 'Joueur supprimé') return false;

  return true;
}

Future<LeaderboardData?> _fetchLeaderboardRpc(
  dynamic supabase,
  LeaderboardRequest request,
) async {
  try {
    final params = <String, dynamic>{
      'p_scope': switch (request.scope) {
        LeaderboardScope.liveQuiz => 'live_quiz',
        LeaderboardScope.contest => 'contest',
        LeaderboardScope.system => 'system',
      },
      'p_limit': 100,
    };
    if (request.scope == LeaderboardScope.contest) {
      params['p_contest_id'] = request.contestId;
    }

    final payload = await supabase.rpc(
      'get_mobile_leaderboard',
      params: params,
    );
    if (payload is! Map) return null;

    final users = ((payload['users'] as List?) ?? const [])
        .whereType<Map>()
        .map((row) => _leaderboardUserFromPayload(row))
        .toList();
    final currentUserPayload = payload['current_user'];
    final currentUser = currentUserPayload is Map
        ? _leaderboardUserFromPayload(currentUserPayload)
        : null;

    return LeaderboardData(
      users: users,
      currentUser: currentUser,
      currentUserRank: (payload['current_user_rank'] as num?)?.toInt(),
      hasContestScope: request.scope == LeaderboardScope.contest,
      hasLiveQuizScope: request.scope == LeaderboardScope.liveQuiz,
    );
  } catch (_) {
    return null;
  }
}

LeaderboardUser _leaderboardUserFromPayload(Map<dynamic, dynamic> row) {
  return LeaderboardUser(
    id: row['id'] as String,
    username: row['username'] as String? ?? 'Joueur',
    avatarUrl: row['avatar_url'] as String?,
    points: (row['points'] as num?)?.toInt() ?? 0,
    rank: (row['rank'] as num?)?.toInt(),
  );
}

Future<LeaderboardData> _buildParticipationLeaderboardData(
  dynamic supabase,
  String? currentUserId, {
  bool liveQuizOnly = false,
}) async {
  var contestIds = <String>[];
  if (liveQuizOnly) {
    final contests = await supabase
        .from('contests')
        .select('id')
        .eq('is_live', true);
    contestIds = {
      for (final contest in contests) contest['id'] as String,
    }.toList();

    if (contestIds.isEmpty) {
      return const LeaderboardData(
        users: [],
        currentUser: null,
        currentUserRank: null,
        hasContestScope: false,
        hasLiveQuizScope: true,
      );
    }
  }

  final participationRows = liveQuizOnly
      ? await _fetchLiveQuizParticipationRows(supabase, contestIds)
      : await supabase
            .from('participations')
            .select('user_id, contest_id, score')
            .limit(5000);

  if (participationRows.isEmpty) {
    return LeaderboardData(
      users: [],
      currentUser: null,
      currentUserRank: null,
      hasContestScope: false,
      hasLiveQuizScope: liveQuizOnly,
    );
  }

  final scoresByUser = <String, int>{};
  for (final row in participationRows) {
    final userId = row['user_id'] as String?;
    if (userId == null) continue;
    final score = (row['score'] as num?)?.toInt() ?? 0;
    scoresByUser[userId] = (scoresByUser[userId] ?? 0) + score;
  }

  if (scoresByUser.isEmpty) {
    return LeaderboardData(
      users: [],
      currentUser: null,
      currentUserRank: null,
      hasContestScope: false,
      hasLiveQuizScope: liveQuizOnly,
    );
  }

  final userIds = scoresByUser.keys.toList();
  final users = await supabase
      .from('users')
      .select(
        'id, username, avatar_url, points_total, role, is_active, '
        'account_status',
      )
      .inFilter('id', userIds);
  final usersById = {for (final user in users) user['id'] as String: user};

  final leaderboardUsers =
      scoresByUser.entries
          .map((entry) {
            final user = usersById[entry.key];
            if (user == null || !_isVisiblePlayerRow(user)) return null;
            return LeaderboardUser(
              id: entry.key,
              username: user['username'] as String? ?? 'Joueur',
              avatarUrl: user['avatar_url'] as String?,
              points: entry.value,
            );
          })
          .whereType<LeaderboardUser>()
          .toList()
        ..sort((a, b) => b.points.compareTo(a.points));

  final topUsers = leaderboardUsers.take(100).toList();
  final currentUserIndex = leaderboardUsers.indexWhere(
    (user) => user.id == currentUserId,
  );

  return LeaderboardData(
    users: topUsers,
    currentUser: currentUserIndex >= 0
        ? leaderboardUsers[currentUserIndex]
        : null,
    currentUserRank: currentUserIndex >= 0 ? currentUserIndex + 1 : null,
    hasContestScope: false,
    hasLiveQuizScope: liveQuizOnly,
  );
}

Future<List<Map<String, dynamic>>> _fetchLiveQuizParticipationRows(
  dynamic supabase,
  List<String> liveContestIds,
) async {
  final rowsByKey = <String, Map<String, dynamic>>{};

  if (liveContestIds.isNotEmpty) {
    final contestRows = await supabase
        .from('participations')
        .select('id, user_id, contest_id, score')
        .inFilter('contest_id', liveContestIds)
        .limit(5000);
    for (final row in contestRows) {
      rowsByKey[(row['id'] as String?) ??
          '${row['user_id']}-${row['contest_id']}'] = Map<String, dynamic>.from(
        row,
      );
    }
  }

  try {
    final sessionRows = await supabase
        .from('participations')
        .select('id, user_id, contest_id, score')
        .eq('is_live_session', true)
        .limit(5000);
    for (final row in sessionRows) {
      rowsByKey[(row['id'] as String?) ??
          '${row['user_id']}-${row['contest_id']}'] = Map<String, dynamic>.from(
        row,
      );
    }
  } catch (_) {
    // Older databases may not have is_live_session until the RPC migration runs.
  }

  return rowsByKey.values.toList();
}

class _CurrentContestRank {
  final LeaderboardUser user;
  final int rank;

  const _CurrentContestRank({required this.user, required this.rank});
}

Future<_CurrentContestRank?> _fetchCurrentContestRank(
  dynamic supabase,
  String contestId,
  String? currentUserId,
) async {
  if (currentUserId == null) return null;

  final participation = await supabase
      .from('participations')
      .select('user_id, score')
      .eq('contest_id', contestId)
      .eq('user_id', currentUserId)
      .maybeSingle();
  if (participation == null) return null;

  final user = await supabase
      .from('users')
      .select(
        'id, username, avatar_url, points_total, role, is_active, '
        'account_status',
      )
      .eq('id', currentUserId)
      .maybeSingle();
  if (user == null || !_isVisiblePlayerRow(user)) return null;

  final allParticipations = await supabase
      .from('participations')
      .select('user_id, score')
      .eq('contest_id', contestId);

  final allUserIds = allParticipations
      .map((row) => row['user_id'] as String?)
      .whereType<String>()
      .toSet()
      .toList();

  if (allUserIds.isEmpty) {
    return _CurrentContestRank(
      user: LeaderboardUser(
        id: currentUserId,
        username: user['username'] as String? ?? 'Joueur',
        avatarUrl: user['avatar_url'] as String?,
        points: (participation['score'] as num?)?.toInt() ?? 0,
      ),
      rank: 1,
    );
  }

  final users = await supabase
      .from('users')
      .select('id, username, role, is_active, account_status')
      .inFilter('id', allUserIds);
  final visibleUserIds = {
    for (final row in users)
      if (_isVisiblePlayerRow(row)) row['id'] as String,
  };

  final currentScore = (participation['score'] as num?)?.toInt() ?? 0;
  final strongerPlayers = allParticipations.where((row) {
    final userId = row['user_id'] as String?;
    if (userId == null || !visibleUserIds.contains(userId)) return false;
    final score = (row['score'] as num?)?.toInt() ?? 0;
    return score > currentScore;
  }).length;

  return _CurrentContestRank(
    user: LeaderboardUser(
      id: currentUserId,
      username: user['username'] as String? ?? 'Joueur',
      avatarUrl: user['avatar_url'] as String?,
      points: currentScore,
    ),
    rank: strongerPlayers + 1,
  );
}
