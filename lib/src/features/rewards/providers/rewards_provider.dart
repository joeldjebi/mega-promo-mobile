import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../auth/utils/auth_debug_logger.dart';

class RewardPrize {
  final String id;
  final String contestId;
  final String contestTitle;
  final bool isLiveQuiz;
  final String description;
  final num value;
  final String status;
  final String rewardType;
  final String? rewardCode;
  final String rewardClaimStatus;
  final String? rewardDeliveryInstructions;
  final String? paymentMethod;
  final String? paymentNumber;
  final DateTime createdAt;
  final DateTime? sentAt;

  const RewardPrize({
    required this.id,
    required this.contestId,
    required this.contestTitle,
    required this.isLiveQuiz,
    required this.description,
    required this.value,
    required this.status,
    required this.rewardType,
    required this.rewardCode,
    required this.rewardClaimStatus,
    required this.rewardDeliveryInstructions,
    required this.paymentMethod,
    required this.paymentNumber,
    required this.createdAt,
    required this.sentAt,
  });

  factory RewardPrize.fromJson(
    Map<String, dynamic> json, {
    required Map<String, Map<String, dynamic>> contestsById,
  }) {
    final contestId = json['contest_id'] as String? ?? '';
    final contest = contestsById[contestId];

    return RewardPrize(
      id: json['id'] as String,
      contestId: contestId,
      contestTitle: contest?['title'] as String? ?? 'Quiz MegaPromo',
      isLiveQuiz: contest?['is_live'] as bool? ?? false,
      description:
          json['prize_description'] as String? ?? 'Récompense MegaPromo',
      value: json['prize_value'] as num? ?? 0,
      status: json['status'] as String? ?? 'pending',
      rewardType: json['reward_type'] as String? ?? 'mobile_money',
      rewardCode: json['reward_code'] as String?,
      rewardClaimStatus: json['reward_claim_status'] as String? ?? 'pending',
      rewardDeliveryInstructions:
          json['reward_delivery_instructions'] as String?,
      paymentMethod: json['payment_method'] as String?,
      paymentNumber: json['payment_number'] as String?,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      sentAt: DateTime.tryParse(json['sent_at'] as String? ?? ''),
    );
  }

  bool get isPaid {
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

class WinnerVictoryDetail {
  final RewardPrize reward;
  final VictoryContest contest;
  final VictoryPerformance performance;
  final List<VictoryPodiumPlayer> topThree;

  const WinnerVictoryDetail({
    required this.reward,
    required this.contest,
    required this.performance,
    required this.topThree,
  });

  factory WinnerVictoryDetail.fromJson(Map<String, dynamic> json) {
    final winner = (json['winner'] as Map?)?.cast<String, dynamic>() ?? {};
    final contest = (json['contest'] as Map?)?.cast<String, dynamic>() ?? {};
    final performance =
        (json['performance'] as Map?)?.cast<String, dynamic>() ?? {};
    final topThree = (json['top_three'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => VictoryPodiumPlayer.fromJson(item.cast()))
        .toList();

    final contestId = contest['id'] as String? ?? '';

    return WinnerVictoryDetail(
      reward: RewardPrize(
        id: winner['id'] as String? ?? '',
        contestId: contestId,
        contestTitle: contest['title'] as String? ?? 'Quiz MegaPromo',
        isLiveQuiz: contest['is_live'] as bool? ?? false,
        description:
            winner['prize_description'] as String? ?? 'Récompense MegaPromo',
        value: winner['prize_value'] as num? ?? 0,
        status: winner['status'] as String? ?? 'pending',
        rewardType: winner['reward_type'] as String? ?? 'mobile_money',
        rewardCode: winner['reward_code'] as String?,
        rewardClaimStatus:
            winner['reward_claim_status'] as String? ?? 'pending',
        rewardDeliveryInstructions:
            winner['reward_delivery_instructions'] as String?,
        paymentMethod: winner['payment_method'] as String?,
        paymentNumber: winner['payment_number'] as String?,
        createdAt:
            DateTime.tryParse(winner['created_at'] as String? ?? '') ??
            DateTime.now(),
        sentAt: DateTime.tryParse(winner['sent_at'] as String? ?? ''),
      ),
      contest: VictoryContest.fromJson(contest),
      performance: VictoryPerformance.fromJson(performance),
      topThree: topThree,
    );
  }
}

class VictoryContest {
  final String id;
  final String title;
  final String imageUrl;
  final bool isLiveQuiz;

  const VictoryContest({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.isLiveQuiz,
  });

  factory VictoryContest.fromJson(Map<String, dynamic> json) {
    return VictoryContest(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Quiz MegaPromo',
      imageUrl: json['image_url'] as String? ?? '',
      isLiveQuiz: json['is_live'] as bool? ?? false,
    );
  }
}

class VictoryPerformance {
  final int rank;
  final int score;
  final int durationMs;
  final int correctAnswers;
  final int totalAnswers;
  final DateTime? participatedAt;

  const VictoryPerformance({
    required this.rank,
    required this.score,
    required this.durationMs,
    required this.correctAnswers,
    required this.totalAnswers,
    required this.participatedAt,
  });

  factory VictoryPerformance.fromJson(Map<String, dynamic> json) {
    return VictoryPerformance(
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      score: (json['score'] as num?)?.toInt() ?? 0,
      durationMs: (json['duration_ms'] as num?)?.toInt() ?? 0,
      correctAnswers: (json['correct_answers'] as num?)?.toInt() ?? 0,
      totalAnswers: (json['total_answers'] as num?)?.toInt() ?? 0,
      participatedAt: DateTime.tryParse(
        json['participated_at'] as String? ?? '',
      ),
    );
  }
}

class VictoryPodiumPlayer {
  final int rank;
  final String userId;
  final String username;
  final String? avatarUrl;
  final int score;
  final int durationMs;
  final bool isCurrentUser;

  const VictoryPodiumPlayer({
    required this.rank,
    required this.userId,
    required this.username,
    required this.avatarUrl,
    required this.score,
    required this.durationMs,
    required this.isCurrentUser,
  });

  factory VictoryPodiumPlayer.fromJson(Map<String, dynamic> json) {
    return VictoryPodiumPlayer(
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      userId: json['user_id'] as String? ?? '',
      username: json['username'] as String? ?? 'Joueur',
      avatarUrl: json['avatar_url'] as String?,
      score: (json['score'] as num?)?.toInt() ?? 0,
      durationMs: (json['duration_ms'] as num?)?.toInt() ?? 0,
      isCurrentUser: json['is_current_user'] as bool? ?? false,
    );
  }
}

final rewardsProvider = FutureProvider<List<RewardPrize>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const [];

  authLogPayload('rewardsFetch', {'user_id': userId});
  final rows = await supabase
      .from('winners')
      .select(
        'id, contest_id, prize_description, prize_value, reward_type, reward_code, reward_claim_status, reward_delivery_instructions, payment_method, payment_number, status, sent_at, created_at',
      )
      .eq('user_id', userId)
      .neq('status', 'cancelled')
      .order('created_at', ascending: false);
  authLogResponse('rewardsFetch', {'count': rows.length});

  final contestIds = rows
      .map((row) => row['contest_id'] as String?)
      .whereType<String>()
      .toSet()
      .toList();
  final contestsById = <String, Map<String, dynamic>>{};

  if (contestIds.isNotEmpty) {
    final contests = await supabase
        .from('contests')
        .select('id, title, is_live')
        .inFilter('id', contestIds);

    for (final contest in contests) {
      final id = contest['id'] as String?;
      if (id != null) contestsById[id] = contest;
    }
  }

  return rows
      .map((row) => RewardPrize.fromJson(row, contestsById: contestsById))
      .toList();
});

final winnerVictoryDetailProvider =
    FutureProvider.family<WinnerVictoryDetail, String>((ref, winnerId) async {
      final supabase = ref.watch(supabaseProvider);
      final user = supabase.auth.currentUser;
      if (user == null || winnerId.isEmpty) {
        throw StateError('Utilisateur non connecté.');
      }

      final data = await supabase.rpc(
        'get_winner_victory_detail',
        params: {'p_winner_id': winnerId},
      );

      final payload = (data as Map).cast<String, dynamic>();
      final winner = (payload['winner'] as Map?)?.cast<String, dynamic>() ?? {};
      final rewardFields = await supabase
          .from('winners')
          .select(
            'reward_type, reward_code, reward_claim_status, reward_delivery_instructions',
          )
          .eq('id', winnerId)
          .eq('user_id', user.id)
          .maybeSingle();

      if (rewardFields != null) {
        payload['winner'] = {
          ...winner,
          ...rewardFields,
        };
      }

      return WinnerVictoryDetail.fromJson(payload);
    });
