import 'package:supabase_flutter/supabase_flutter.dart';

import '../../contests/providers/contest_providers.dart';

class LiveQuizStartResult {
  final String participationId;

  const LiveQuizStartResult({required this.participationId});
}

Future<LiveQuizStartResult> startLiveQuizParticipation({
  required ContestDetailData data,
}) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;
  if (user == null) throw StateError('Utilisateur non connecté.');

  final existing = await supabase
      .from('participations')
      .select('id')
      .eq('user_id', user.id)
      .eq('contest_id', data.contest.id)
      .limit(1)
      .maybeSingle();

  if (existing != null) {
    return LiveQuizStartResult(participationId: existing['id'] as String);
  }

  if (data.contest.isLive) {
    final waitingSession = await supabase
        .from('live_sessions')
        .select('id')
        .eq('user_id', user.id)
        .eq('contest_id', data.contest.id)
        .limit(1)
        .maybeSingle();

    if (waitingSession == null) {
      throw StateError(
        'Tu devais entrer en salle d’attente avant le lancement.',
      );
    }
  }

  final participation = await supabase
      .from('participations')
      .insert({
        'user_id': user.id,
        'contest_id': data.contest.id,
        'score': 0,
        'answers': {
          'type': 'quiz_live',
          'status': 'started',
          'started_at': DateTime.now().toIso8601String(),
          'live_starts_at': data.contest.liveStartsAt?.toIso8601String(),
        },
        'completed': false,
        'is_live_session': true,
      })
      .select('id')
      .single();

  await supabase
      .from('users')
      .update({
        'participations_today': data.userProfile.participationsToday + 1,
        'last_participation_date': DateTime.now().toIso8601String().split(
          'T',
        )[0],
      })
      .eq('id', user.id);

  return LiveQuizStartResult(participationId: participation['id'] as String);
}
