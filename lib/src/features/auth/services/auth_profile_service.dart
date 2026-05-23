import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/auth_debug_logger.dart';

Future<String> ensureUserProfileAndResolveRoute(
  User user, {
  String? phone,
}) async {
  final supabase = Supabase.instance.client;
  final fallbackPhone = phone ?? user.phone;
  final now = DateTime.now().toIso8601String().split('T').first;

  final profilePayload = {
    'id': user.id,
    'select': 'username,is_active,account_status',
  };
  authLogPayload('profileCheck', profilePayload);
  var profile = await supabase
      .from('users')
      .select('id, username, phone, is_active, account_status')
      .eq('id', user.id)
      .maybeSingle();
  authLogResponse('profileCheck', profile);

  final accountStatus = profile?['account_status'] as String?;
  if (profile != null &&
      (accountStatus == 'pending_deletion' ||
          (accountStatus == null && profile['is_active'] == false))) {
    return '/account/reactivation';
  }

  if (profile != null && accountStatus == 'deleted') {
    await supabase.auth.signOut();
    throw const AuthException('account_deleted');
  }

  final ensurePayload = {
    'id': user.id,
    if (fallbackPhone != null && fallbackPhone.trim().isNotEmpty)
      'phone': fallbackPhone,
    'role': 'player',
    'is_premium': false,
    'points_total': 0,
    'participations_today': 0,
    'last_participation_date': now,
    'is_active': true,
  };

  if (profile == null) {
    authLogPayload('ensureUserProfile', ensurePayload);
    profile = await supabase
        .from('users')
        .insert(ensurePayload)
        .select('id, phone, username, role, is_active, created_at')
        .single();
    authLogResponse('ensureUserProfile', profile);
  } else if ((profile['phone'] as String?) == null &&
      fallbackPhone != null &&
      fallbackPhone.trim().isNotEmpty) {
    authLogPayload('ensureUserProfilePhone', {
      'id': user.id,
      'phone': fallbackPhone,
    });
    profile = await supabase
        .from('users')
        .update({'phone': fallbackPhone})
        .eq('id', user.id)
        .select('id, phone, username')
        .single();
    authLogResponse('ensureUserProfilePhone', profile);
  }

  final username = profile['username'] as String?;
  return username != null && username.trim().isNotEmpty
      ? '/home'
      : '/onboarding';
}
