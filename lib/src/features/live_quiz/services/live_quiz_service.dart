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

  if (data.contest.isLive && !data.contest.isLiveReady) {
    throw StateError('L’arène du Quiz Live se prépare. Reviens vite.');
  }

  if (data.contest.isLive && data.contest.isLiveEnded) {
    throw StateError('Ce Quiz Live est terminé.');
  }

  if (data.contest.isLive && !data.contest.isLiveActiveNow) {
    throw StateError('Ce Quiz Live n’est pas ouvert actuellement.');
  }

  final response = await supabase.rpc(
    'start_live_quiz_participation',
    params: {'p_contest_id': data.contest.id},
  );
  final payload = response is Map<String, dynamic>
      ? response
      : Map<String, dynamic>.from(response as Map);
  final participationId = payload['participation_id'] as String?;
  if (participationId == null || participationId.isEmpty) {
    throw StateError('Impossible de demarrer ce Quiz Live.');
  }

  return LiveQuizStartResult(participationId: participationId);
}
