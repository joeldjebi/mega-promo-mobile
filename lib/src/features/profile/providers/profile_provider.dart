import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/auth_provider.dart';
import '../../auth/utils/auth_debug_logger.dart';
import '../../home/providers/user_profile_provider.dart';
import '../../../services/network_status_service.dart';

class ProfileData {
  final UserProfile user;
  final List<Map<String, dynamic>> badges;
  final List<Map<String, dynamic>> participations;
  final List<Map<String, dynamic>> wins;

  const ProfileData({
    required this.user,
    required this.badges,
    required this.participations,
    required this.wins,
  });
}

final profileDataProvider = FutureProvider<ProfileData>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) throw StateError('Utilisateur non connecté.');

  final profile = await ref.watch(userProfileProvider.future);
  final badges = await _safeFetchList(
    'profileBadges',
    () => supabase
        .from('user_badges')
        .select('badges(name, description, icon_url)')
        .eq('user_id', userId),
  );
  final participations = await _safeFetchList(
    'profileParticipations',
    () => supabase
        .from('participations')
        .select('id, contest_id, score, participated_at, contests(title)')
        .eq('user_id', userId)
        .order('participated_at', ascending: false)
        .limit(5),
  );
  final wins = await _safeFetchList(
    'profileWins',
    () => supabase
        .from('winners')
        .select('id, prize_description, status, created_at, contests(title)')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(5),
  );

  return ProfileData(
    user: profile,
    badges: badges,
    participations: participations,
    wins: wins,
  );
});

Future<List<Map<String, dynamic>>> fetchProfileParticipationsPage({
  required int limit,
  int offset = 0,
}) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;
  if (user == null) return const [];

  return _safeFetchList(
    'profileParticipationsPage',
    () => supabase
        .from('participations')
        .select(
          'id, contest_id, score, participated_at, completed, contests(title)',
        )
        .eq('user_id', user.id)
        .order('participated_at', ascending: false)
        .range(offset, offset + limit - 1),
  );
}

Future<List<Map<String, dynamic>>> fetchProfileWinsPage({
  required int limit,
  int offset = 0,
}) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;
  if (user == null) return const [];

  return _safeFetchList(
    'profileWinsPage',
    () => supabase
        .from('winners')
        .select('id, prize_description, status, created_at, contests(title)')
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1),
  );
}

Future<List<Map<String, dynamic>>> _safeFetchList(
  String step,
  Future<List<Map<String, dynamic>>> Function() fetch,
) async {
  try {
    authLogPayload(step, {'request': 'select'});
    final rows = await fetch();
    authLogResponse(step, {'count': rows.length});
    return rows;
  } catch (error, stackTrace) {
    NetworkStatusService.instance.markOfflineFromError(error);
    authLogError(step, error, stackTrace);
    return const [];
  }
}
