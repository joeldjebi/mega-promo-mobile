import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/auth_debug_logger.dart';

final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final authStateProvider = StreamProvider<User?>((ref) async* {
  final auth = ref.watch(supabaseProvider).auth;

  authLogResponse('currentUser', {
    'id': auth.currentUser?.id,
    'phone': auth.currentUser?.phone,
    'role': auth.currentUser?.role,
  });
  yield auth.currentUser;

  yield* auth.onAuthStateChange.map((state) {
    authLogResponse('onAuthStateChange', {
      'event': state.event.name,
      'userId': state.session?.user.id,
      'phone': state.session?.user.phone,
      'hasSession': state.session != null,
    });
    return state.session?.user;
  });
});

final currentUserIdProvider = Provider<String?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.asData?.value?.id ??
      ref.watch(supabaseProvider).auth.currentUser?.id;
});
