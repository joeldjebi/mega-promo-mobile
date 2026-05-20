import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/utils/auth_debug_logger.dart';
import '../../home/providers/user_profile_provider.dart';

class BadgeProgressContext {
  final bool wonContest;

  const BadgeProgressContext({this.wonContest = false});
}

Future<void> awardBadgesAfterParticipation({
  required SupabaseClient supabase,
  required UserProfile profile,
  required int nextParticipationsToday,
  required int nextPointsTotal,
  BadgeProgressContext context = const BadgeProgressContext(),
}) async {
  final user = supabase.auth.currentUser;
  if (user == null) return;

  try {
    final participations = await supabase
        .from('participations')
        .select('id')
        .eq('user_id', user.id);
    final totalParticipations = participations.length < nextParticipationsToday
        ? nextParticipationsToday
        : participations.length;
    final participationProgress =
        (totalParticipations * profile.badgeMultiplier).floor();
    final pointsProgress = (nextPointsTotal * profile.badgeMultiplier).floor();

    authLogPayload('badgeAwardCheck', {
      'userId': user.id,
      'totalParticipations': totalParticipations,
      'participationProgress': participationProgress,
      'pointsProgress': pointsProgress,
      'badgeMultiplier': profile.badgeMultiplier,
    });

    final badges = await supabase
        .from('badges')
        .select('id, condition_type, condition_value');

    final earned = await supabase
        .from('user_badges')
        .select('badge_id')
        .eq('user_id', user.id);

    final earnedIds = earned
        .map((row) => row['badge_id'] as String?)
        .whereType<String>()
        .toSet();

    final rowsToInsert = <Map<String, dynamic>>[];
    for (final badge in badges) {
      final badgeId = badge['id'] as String;
      if (earnedIds.contains(badgeId)) continue;

      final conditionType = badge['condition_type'] as String? ?? '';
      final conditionValue = (badge['condition_value'] as num?)?.toInt() ?? 1;
      final isUnlocked = _isBadgeUnlocked(
        conditionType: conditionType,
        conditionValue: conditionValue,
        participationProgress: participationProgress,
        pointsProgress: pointsProgress,
        isPremium: profile.isPremium,
        wonContest: context.wonContest,
      );

      if (isUnlocked) {
        rowsToInsert.add({
          'user_id': user.id,
          'badge_id': badgeId,
          'earned_at': DateTime.now().toIso8601String(),
        });
      }
    }

    if (rowsToInsert.isEmpty) {
      authLogResponse('badgeAwardCheck', {'awarded': 0});
      return;
    }

    await supabase.from('user_badges').insert(rowsToInsert);
    authLogResponse('badgeAwardCheck', {'awarded': rowsToInsert.length});
  } catch (error, stackTrace) {
    authLogError('badgeAwardCheck', error, stackTrace);
  }
}

bool _isBadgeUnlocked({
  required String conditionType,
  required int conditionValue,
  required int participationProgress,
  required int pointsProgress,
  required bool isPremium,
  required bool wonContest,
}) {
  if (conditionType == 'participations' ||
      conditionType == 'participation_count') {
    return participationProgress >= conditionValue;
  }
  if (conditionType == 'points' || conditionType == 'points_total') {
    return pointsProgress >= conditionValue;
  }
  if (conditionType == 'premium') return isPremium;
  if (conditionType == 'winner' || conditionType == 'wins') return wonContest;
  return false;
}
