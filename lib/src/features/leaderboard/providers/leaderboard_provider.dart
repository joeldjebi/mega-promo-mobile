import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';

class LeaderboardUser {
  final String id;
  final String username;
  final String? avatarUrl;
  final int points;

  const LeaderboardUser({
    required this.id,
    required this.username,
    required this.avatarUrl,
    required this.points,
  });

  factory LeaderboardUser.fromUser(Map<String, dynamic> json) {
    return LeaderboardUser(
      id: json['id'] as String,
      username: json['username'] as String? ?? 'Joueur',
      avatarUrl: json['avatar_url'] as String?,
      points: (json['points_total'] as num?)?.toInt() ?? 0,
    );
  }
}

final leaderboardProvider =
    StreamProvider.family<List<LeaderboardUser>, String?>((ref, contestId) {
      final supabase = ref.watch(supabaseProvider);

      if (contestId == null || contestId.isEmpty) {
        return supabase
            .from('users')
            .stream(primaryKey: ['id'])
            .order('points_total', ascending: false)
            .limit(100)
            .map((rows) => rows.map(LeaderboardUser.fromUser).toList());
      }

      return supabase
          .from('participations')
          .stream(primaryKey: ['id'])
          .eq('contest_id', contestId)
          .order('score', ascending: false)
          .limit(100)
          .asyncMap((rows) async {
            final ids = rows.map((row) => row['user_id'] as String).toList();
            if (ids.isEmpty) return <LeaderboardUser>[];
            final users = await supabase
                .from('users')
                .select('id, username, avatar_url')
                .inFilter('id', ids);
            final usersById = {
              for (final user in users) user['id'] as String: user,
            };
            return rows.map((row) {
              final user = usersById[row['user_id']] ?? <String, dynamic>{};
              return LeaderboardUser(
                id: row['user_id'] as String,
                username: user['username'] as String? ?? 'Joueur',
                avatarUrl: user['avatar_url'] as String?,
                points: (row['score'] as num?)?.toInt() ?? 0,
              );
            }).toList();
          });
    });
