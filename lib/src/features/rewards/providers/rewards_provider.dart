import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../auth/utils/auth_debug_logger.dart';

class RewardPrize {
  final String id;
  final String description;
  final num value;
  final String status;
  final String? paymentMethod;
  final String? paymentNumber;
  final DateTime createdAt;
  final DateTime? sentAt;

  const RewardPrize({
    required this.id,
    required this.description,
    required this.value,
    required this.status,
    required this.paymentMethod,
    required this.paymentNumber,
    required this.createdAt,
    required this.sentAt,
  });

  factory RewardPrize.fromJson(Map<String, dynamic> json) {
    return RewardPrize(
      id: json['id'] as String,
      description: json['prize_description'] as String? ?? 'Gain MegaPromo',
      value: json['prize_value'] as num? ?? 0,
      status: json['status'] as String? ?? 'pending',
      paymentMethod: json['payment_method'] as String?,
      paymentNumber: json['payment_number'] as String?,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      sentAt: DateTime.tryParse(json['sent_at'] as String? ?? ''),
    );
  }

  bool get isReceived {
    final normalized = status.toLowerCase();
    return normalized == 'received' ||
        normalized == 'sent' ||
        normalized == 'paid' ||
        normalized == 'recu' ||
        normalized == 'reçu';
  }

  bool get isRejected {
    final normalized = status.toLowerCase();
    return normalized == 'rejected' ||
        normalized == 'cancelled' ||
        normalized == 'annule' ||
        normalized == 'annulé';
  }
}

final rewardsProvider = FutureProvider<List<RewardPrize>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final user = supabase.auth.currentUser;
  if (user == null) return const [];

  authLogPayload('rewardsFetch', {'user_id': user.id});
  final rows = await supabase
      .from('winners')
      .select(
        'id, prize_description, prize_value, payment_method, payment_number, status, sent_at, created_at',
      )
      .eq('user_id', user.id)
      .order('created_at', ascending: false);
  authLogResponse('rewardsFetch', {'count': rows.length});

  return rows.map(RewardPrize.fromJson).toList();
});
