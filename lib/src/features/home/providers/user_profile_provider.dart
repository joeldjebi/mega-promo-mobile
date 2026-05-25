import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../auth/utils/auth_debug_logger.dart';

class UserProfile {
  final String id;
  final String? phone;
  final String username;
  final String? avatarUrl;
  final bool isPremium;
  final int pointsTotal;
  final int participationsToday;
  final String planName;
  final String planKey;
  final int dailyParticipationLimit;
  final int bonusTickets;
  final double badgeMultiplier;

  const UserProfile({
    required this.id,
    required this.phone,
    required this.username,
    required this.avatarUrl,
    required this.isPremium,
    required this.pointsTotal,
    required this.participationsToday,
    required this.planName,
    required this.planKey,
    required this.dailyParticipationLimit,
    required this.bonusTickets,
    required this.badgeMultiplier,
  });

  factory UserProfile.fromJson(
    Map<String, dynamic> json, {
    Map<String, dynamic>? activeSubscription,
  }) {
    final plan = activeSubscription?['player_plans'] as Map<String, dynamic>?;
    final planKey = plan?['key'] as String? ?? 'free';
    final hasPaidPlan = activeSubscription != null && planKey != 'free';

    return UserProfile(
      id: json['id'] as String,
      phone: json['phone'] as String?,
      username: (json['username'] as String?)?.trim().isNotEmpty == true
          ? json['username'] as String
          : 'Joueur',
      avatarUrl: json['avatar_url'] as String?,
      isPremium: (json['is_premium'] as bool? ?? false) || hasPaidPlan,
      pointsTotal: (json['points_total'] as num?)?.toInt() ?? 0,
      participationsToday: _isToday(json['last_participation_date'] as String?)
          ? (json['participations_today'] as num?)?.toInt() ?? 0
          : 0,
      planName: plan?['name'] as String? ?? 'Standard',
      planKey: planKey,
      dailyParticipationLimit:
          (plan?['daily_participation_limit'] as num?)?.toInt() ?? 3,
      bonusTickets: (plan?['bonus_tickets'] as num?)?.toInt() ?? 0,
      badgeMultiplier: _doubleValue(plan?['badge_multiplier']) ?? 1,
    );
  }
}

double? _doubleValue(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

bool _isToday(String? value) {
  if (value == null || value.isEmpty) return false;
  final date = DateTime.tryParse(value);
  if (date == null) return false;
  final now = DateTime.now();
  return date.year == now.year &&
      date.month == now.month &&
      date.day == now.day;
}

Future<UserProfile> fetchCurrentUserProfile(Ref ref, {String? userId}) async {
  final supabase = ref.watch(supabaseProvider);
  final resolvedUserId = userId ?? supabase.auth.currentUser?.id;

  if (resolvedUserId == null) {
    throw StateError('Utilisateur non connecté.');
  }

  authLogPayload('userProfileFetch', {'id': resolvedUserId});
  final profileFuture = supabase
      .from('users')
      .select(
        'id, phone, username, avatar_url, is_premium, points_total, participations_today, last_participation_date',
      )
      .eq('id', resolvedUserId)
      .single();

  authLogPayload('userActiveSubscriptionFetch', {'userId': resolvedUserId});
  final subscriptionFuture = supabase
      .from('player_subscriptions')
      .select(
        'id, status, expires_at, player_plans(key, name, daily_participation_limit, bonus_tickets, badge_multiplier)',
      )
      .eq('user_id', resolvedUserId)
      .eq('status', 'active')
      .gte('expires_at', DateTime.now().toIso8601String())
      .order('created_at', ascending: false)
      .limit(1)
      .maybeSingle();

  final data = await profileFuture;
  authLogResponse('userProfileFetch', data);

  Map<String, dynamic>? activeSubscription;
  try {
    activeSubscription = await subscriptionFuture;
    authLogResponse('userActiveSubscriptionFetch', activeSubscription);
  } catch (error, stackTrace) {
    authLogError('userActiveSubscriptionFetch', error, stackTrace);
  }

  return UserProfile.fromJson(data, activeSubscription: activeSubscription);
}

final userProfileProvider = FutureProvider.autoDispose<UserProfile>((
  ref,
) async {
  final userId = ref.watch(currentUserIdProvider);
  final keepAliveLink = ref.keepAlive();
  final cacheTimer = Timer(const Duration(seconds: 45), keepAliveLink.close);
  ref.onDispose(cacheTimer.cancel);

  return fetchCurrentUserProfile(ref, userId: userId);
});
