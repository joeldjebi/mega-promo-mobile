import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/auth_provider.dart';
import '../../auth/utils/auth_debug_logger.dart';
import '../../home/providers/user_profile_provider.dart';

const _fallbackPaymentMethods = [
  PaymentMethodOption(
    id: 'wave-default',
    name: 'Wave',
    operatorKey: 'wave',
    country: 'Côte d’Ivoire',
    paymentUrl: 'https://pay.wave.com/m/M_ci_o6-9yu9h5hhm/c/ci/',
    instructions:
        'Suis les instructions, puis envoie la capture ou la référence pour validation.',
    proofPhone: '+225 0758754662',
    isActive: true,
    orderIndex: 1,
  ),
];

class PlayerPlan {
  final String id;
  final String key;
  final String name;
  final String description;
  final int price;
  final int durationDays;
  final int dailyParticipationLimit;
  final int bonusTickets;
  final double badgeMultiplier;
  final bool isActive;
  final int orderIndex;
  final List<PlayerPlanBenefit> benefits;

  const PlayerPlan({
    required this.id,
    required this.key,
    required this.name,
    required this.description,
    required this.price,
    required this.durationDays,
    required this.dailyParticipationLimit,
    required this.bonusTickets,
    required this.badgeMultiplier,
    required this.isActive,
    required this.orderIndex,
    required this.benefits,
  });

  factory PlayerPlan.fromJson(
    Map<String, dynamic> json,
    List<PlayerPlanBenefit> benefits,
  ) {
    return PlayerPlan(
      id: json['id'] as String,
      key: json['key'] as String? ?? '',
      name: json['name'] as String? ?? 'Forfait',
      description: json['description'] as String? ?? '',
      price: (json['price'] as num?)?.toInt() ?? 0,
      durationDays: (json['duration_days'] as num?)?.toInt() ?? 30,
      dailyParticipationLimit:
          (json['daily_participation_limit'] as num?)?.toInt() ?? 3,
      bonusTickets: (json['bonus_tickets'] as num?)?.toInt() ?? 0,
      badgeMultiplier: _doubleValue(json['badge_multiplier']) ?? 1,
      isActive: json['is_active'] as bool? ?? true,
      orderIndex: (json['order_index'] as num?)?.toInt() ?? 0,
      benefits: benefits,
    );
  }
}

double? _doubleValue(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

class PlayerPlanBenefit {
  final String id;
  final String planId;
  final String label;
  final String description;
  final String icon;
  final int orderIndex;

  const PlayerPlanBenefit({
    required this.id,
    required this.planId,
    required this.label,
    required this.description,
    required this.icon,
    required this.orderIndex,
  });

  factory PlayerPlanBenefit.fromJson(Map<String, dynamic> json) {
    return PlayerPlanBenefit(
      id: json['id'] as String,
      planId: json['plan_id'] as String,
      label: json['label'] as String? ?? 'Avantage',
      description: json['description'] as String? ?? '',
      icon: json['icon'] as String? ?? '',
      orderIndex: (json['order_index'] as num?)?.toInt() ?? 0,
    );
  }
}

class PlayerSubscription {
  final String id;
  final String userId;
  final String planId;
  final String planName;
  final int amount;
  final String status;
  final DateTime startsAt;
  final DateTime expiresAt;
  final String paymentMethod;
  final String paymentReference;

  const PlayerSubscription({
    required this.id,
    required this.userId,
    required this.planId,
    required this.planName,
    required this.amount,
    required this.status,
    required this.startsAt,
    required this.expiresAt,
    required this.paymentMethod,
    required this.paymentReference,
  });

  factory PlayerSubscription.fromJson(Map<String, dynamic> json) {
    final plan = json['player_plans'] as Map<String, dynamic>?;
    return PlayerSubscription(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      planId: json['plan_id'] as String,
      planName: plan?['name'] as String? ?? 'Forfait',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'pending',
      startsAt:
          DateTime.tryParse(json['starts_at'] as String? ?? '') ??
          DateTime.now(),
      expiresAt:
          DateTime.tryParse(json['expires_at'] as String? ?? '') ??
          DateTime.now(),
      paymentMethod: json['payment_method'] as String? ?? '',
      paymentReference: json['payment_reference'] as String? ?? '',
    );
  }
}

class PaymentMethodOption {
  final String id;
  final String name;
  final String operatorKey;
  final String country;
  final String paymentUrl;
  final String instructions;
  final String proofPhone;
  final bool isActive;
  final int orderIndex;

  const PaymentMethodOption({
    required this.id,
    required this.name,
    required this.operatorKey,
    required this.country,
    required this.paymentUrl,
    required this.instructions,
    required this.proofPhone,
    required this.isActive,
    required this.orderIndex,
  });

  factory PaymentMethodOption.fromJson(Map<String, dynamic> json) {
    return PaymentMethodOption(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Validation',
      operatorKey: json['operator_key'] as String? ?? 'manual',
      country: json['country'] as String? ?? 'Côte d’Ivoire',
      paymentUrl: json['payment_url'] as String? ?? '',
      instructions: json['instructions'] as String? ?? '',
      proofPhone: json['proof_phone'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? true,
      orderIndex: (json['order_index'] as num?)?.toInt() ?? 0,
    );
  }
}

class PlayerPlansData {
  final List<PlayerPlan> plans;
  final PlayerSubscription? currentSubscription;
  final List<PaymentMethodOption> paymentMethods;

  const PlayerPlansData({
    required this.plans,
    required this.currentSubscription,
    required this.paymentMethods,
  });
}

final playerPlansProvider = FutureProvider.autoDispose<PlayerPlansData>((
  ref,
) async {
  final supabase = ref.watch(supabaseProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) throw StateError('Utilisateur non connecté.');

  authLogPayload('playerPlansFetch', {'request': 'select'});
  final plansRows = await supabase
      .from('player_plans')
      .select(
        'id, key, name, description, price, duration_days, daily_participation_limit, bonus_tickets, badge_multiplier, is_active, order_index',
      )
      .eq('is_active', true)
      .order('order_index', ascending: true);

  final benefitsRows = await supabase
      .from('player_plan_benefits')
      .select('id, plan_id, label, description, icon, order_index')
      .order('order_index', ascending: true);

  final benefits = benefitsRows
      .map(PlayerPlanBenefit.fromJson)
      .toList(growable: false);
  final benefitsByPlan = <String, List<PlayerPlanBenefit>>{};
  for (final benefit in benefits) {
    benefitsByPlan.putIfAbsent(benefit.planId, () => []).add(benefit);
  }

  final plans = plansRows
      .map((row) => PlayerPlan.fromJson(row, benefitsByPlan[row['id']] ?? []))
      .toList(growable: false);

  authLogResponse('playerPlansFetch', {'count': plans.length});

  var paymentMethods = _fallbackPaymentMethods;
  try {
    final paymentMethodRows = await supabase
        .from('payment_methods')
        .select(
          'id, name, operator_key, country, payment_url, instructions, proof_phone, is_active, order_index',
        )
        .eq('is_active', true)
        .order('order_index', ascending: true);
    paymentMethods = paymentMethodRows
        .map(PaymentMethodOption.fromJson)
        .toList(growable: false);
    if (paymentMethods.isEmpty) {
      paymentMethods = _fallbackPaymentMethods;
    }
  } catch (error, stackTrace) {
    authLogError('paymentMethodsFetch', error, stackTrace);
  }

  authLogPayload('playerSubscriptionFetch', {'userId': userId});
  final subscriptionRows = await supabase
      .from('player_subscriptions')
      .select(
        'id, user_id, plan_id, amount, status, starts_at, expires_at, payment_method, payment_reference, player_plans(name)',
      )
      .eq('user_id', userId)
      .inFilter('status', ['active', 'pending'])
      .order('created_at', ascending: false)
      .limit(1);
  authLogResponse('playerSubscriptionFetch', {
    'count': subscriptionRows.length,
  });

  return PlayerPlansData(
    plans: plans,
    currentSubscription: subscriptionRows.isEmpty
        ? null
        : PlayerSubscription.fromJson(subscriptionRows.first),
    paymentMethods: paymentMethods,
  );
});

Future<PlayerSubscription> subscribeToPlayerPlan(
  WidgetRef ref,
  PlayerPlan plan,
  PaymentMethodOption? paymentMethod,
) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;
  if (user == null) throw StateError('Utilisateur non connecté.');

  final now = DateTime.now();
  final expiresAt = now.add(Duration(days: plan.durationDays));
  final status = plan.price == 0 ? 'active' : 'pending';

  final selectedPaymentMethod = plan.price == 0 ? null : paymentMethod;
  final payload = {
    'user_id': user.id,
    'plan_id': plan.id,
    'amount': plan.price,
    'status': status,
    'starts_at': now.toIso8601String(),
    'expires_at': expiresAt.toIso8601String(),
    'payment_method': plan.price == 0
        ? 'free'
        : selectedPaymentMethod?.operatorKey ?? 'mobile_money',
    if (plan.price > 0)
      'payment_reference':
          '${selectedPaymentMethod?.operatorKey ?? 'manual'}_${now.millisecondsSinceEpoch}',
  };

  authLogPayload('playerSubscribe', payload);
  final data = await supabase
      .from('player_subscriptions')
      .insert(payload)
      .select(
        'id, user_id, plan_id, amount, status, starts_at, expires_at, payment_method, payment_reference, player_plans(name)',
      )
      .single();
  authLogResponse('playerSubscribe', data);

  if (plan.price == 0) {
    await supabase
        .from('users')
        .update({'is_premium': false, 'premium_expires_at': null})
        .eq('id', user.id);
  }

  ref.invalidate(playerPlansProvider);
  ref.invalidate(userProfileProvider);

  return PlayerSubscription.fromJson(data);
}
