import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../services/synced_clock_service.dart';

enum ContestType {
  quiz,
  tirage,
  pronostic,
  other;

  static ContestType fromValue(String? value) {
    return switch (value?.toLowerCase()) {
      'quiz' => ContestType.quiz,
      'tirage' || 'draw' || 'raffle' => ContestType.tirage,
      'pronostic' || 'prediction' => ContestType.pronostic,
      _ => ContestType.other,
    };
  }

  String get label {
    return switch (this) {
      ContestType.quiz => 'QUIZ',
      ContestType.tirage => 'PROMO',
      ContestType.pronostic => 'QUIZ SPORT',
      ContestType.other => 'QUIZ',
    };
  }

  String get filterLabel {
    return switch (this) {
      ContestType.quiz => 'Quiz',
      ContestType.tirage => 'Promotion',
      ContestType.pronostic => 'Quiz sport',
      ContestType.other => 'Autre',
    };
  }

  IconData get icon {
    return switch (this) {
      ContestType.quiz => Icons.quiz_rounded,
      ContestType.tirage => Icons.confirmation_number_rounded,
      ContestType.pronostic => Icons.insights_rounded,
      ContestType.other => Icons.emoji_events_rounded,
    };
  }

  Color get color {
    return switch (this) {
      ContestType.quiz => AppColors.primaryLight,
      ContestType.tirage => AppColors.gold,
      ContestType.pronostic => AppColors.accentGreen,
      ContestType.other => AppColors.accent,
    };
  }
}

class Contest {
  final String id;
  final String title;
  final String description;
  final String? imageUrl;
  final String? brandLogoUrl;
  final String? brandName;
  final ContestType type;
  final String status;
  final String? categoryId;
  final String category;
  final Category? categoryData;
  final String prizeDescription;
  final num prizeValue;
  final int winnersCount;
  final int maxParticipants;
  final DateTime? startsAt;
  final DateTime endsAt;
  final bool isBoosted;
  final int viewsCount;
  final int sharesCount;
  final List<String> allowedPlayerPlanKeys;
  final bool isLive;
  final DateTime? liveStartsAt;
  final String liveStatus;
  final int registeredCount;
  final int connectedCount;
  final int currentQuestionIndex;
  final int liveQuestionsCount;
  final int liveDurationSeconds;
  final int participantsCount;
  final int quizQuestionCount;

  const Contest({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.brandLogoUrl,
    required this.brandName,
    required this.type,
    required this.status,
    required this.categoryId,
    required this.category,
    required this.categoryData,
    required this.prizeDescription,
    required this.prizeValue,
    required this.winnersCount,
    required this.maxParticipants,
    required this.startsAt,
    required this.endsAt,
    required this.isBoosted,
    required this.viewsCount,
    required this.sharesCount,
    required this.allowedPlayerPlanKeys,
    required this.isLive,
    required this.liveStartsAt,
    required this.liveStatus,
    required this.registeredCount,
    required this.connectedCount,
    required this.currentQuestionIndex,
    required this.liveQuestionsCount,
    required this.liveDurationSeconds,
    required this.participantsCount,
    required this.quizQuestionCount,
  });

  factory Contest.fromJson(Map<String, dynamic> json) {
    final rewardMetadata = _jsonMap(json['reward_metadata']);
    return Contest(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Quiz MegaPromo',
      description: json['description'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      brandLogoUrl: json['brand_logo_url'] as String?,
      brandName: json['brand_name'] as String?,
      type: ContestType.fromValue(json['type'] as String?),
      status: json['status'] as String? ?? 'active',
      categoryId: json['category_id'] as String?,
      category: _categoryName(json),
      categoryData: Category.fromEmbeddedJson(json['categories']),
      prizeDescription: json['prize_description'] as String? ?? '',
      prizeValue: json['prize_value'] as num? ?? 0,
      winnersCount: (json['winners_count'] as num?)?.toInt() ?? 1,
      maxParticipants: (json['max_participants'] as num?)?.toInt() ?? 0,
      startsAt: DateTime.tryParse(json['starts_at'] as String? ?? ''),
      endsAt:
          DateTime.tryParse(json['ends_at'] as String? ?? '') ??
          SyncedClockService.now(),
      isBoosted: json['is_boosted'] as bool? ?? false,
      viewsCount: (json['views_count'] as num?)?.toInt() ?? 0,
      sharesCount: (json['shares_count'] as num?)?.toInt() ?? 0,
      allowedPlayerPlanKeys: _allowedPlanKeys(json['allowed_player_plan_keys']),
      isLive: json['is_live'] as bool? ?? false,
      liveStartsAt: DateTime.tryParse(json['live_starts_at'] as String? ?? ''),
      liveStatus: json['live_status'] as String? ?? 'scheduled',
      registeredCount: (json['registered_count'] as num?)?.toInt() ?? 0,
      connectedCount: (json['connected_count'] as num?)?.toInt() ?? 0,
      currentQuestionIndex:
          (json['current_question_index'] as num?)?.toInt() ?? 0,
      liveQuestionsCount: (json['live_questions_count'] as num?)?.toInt() ?? 0,
      liveDurationSeconds:
          (json['live_duration_seconds'] as num?)?.toInt() ?? 0,
      participantsCount: (json['participants_count'] as num?)?.toInt() ?? 0,
      quizQuestionCount: _questionCountFromMetadata(rewardMetadata),
    );
  }

  Contest copyWithCategory(Category? category) {
    return Contest(
      id: id,
      title: title,
      description: description,
      imageUrl: imageUrl,
      brandLogoUrl: brandLogoUrl,
      brandName: brandName,
      type: type,
      status: status,
      categoryId: categoryId,
      category: category?.name ?? this.category,
      categoryData: category ?? categoryData,
      prizeDescription: prizeDescription,
      prizeValue: prizeValue,
      winnersCount: winnersCount,
      maxParticipants: maxParticipants,
      startsAt: startsAt,
      endsAt: endsAt,
      isBoosted: isBoosted,
      viewsCount: viewsCount,
      sharesCount: sharesCount,
      allowedPlayerPlanKeys: allowedPlayerPlanKeys,
      isLive: isLive,
      liveStartsAt: liveStartsAt,
      liveStatus: liveStatus,
      registeredCount: registeredCount,
      connectedCount: connectedCount,
      currentQuestionIndex: currentQuestionIndex,
      liveQuestionsCount: liveQuestionsCount,
      liveDurationSeconds: liveDurationSeconds,
      participantsCount: participantsCount,
      quizQuestionCount: quizQuestionCount,
    );
  }

  Contest copyWithViewsCount(int viewsCount) {
    return Contest(
      id: id,
      title: title,
      description: description,
      imageUrl: imageUrl,
      brandLogoUrl: brandLogoUrl,
      brandName: brandName,
      type: type,
      status: status,
      categoryId: categoryId,
      category: category,
      categoryData: categoryData,
      prizeDescription: prizeDescription,
      prizeValue: prizeValue,
      winnersCount: winnersCount,
      maxParticipants: maxParticipants,
      startsAt: startsAt,
      endsAt: endsAt,
      isBoosted: isBoosted,
      viewsCount: viewsCount,
      sharesCount: sharesCount,
      allowedPlayerPlanKeys: allowedPlayerPlanKeys,
      isLive: isLive,
      liveStartsAt: liveStartsAt,
      liveStatus: liveStatus,
      registeredCount: registeredCount,
      connectedCount: connectedCount,
      currentQuestionIndex: currentQuestionIndex,
      liveQuestionsCount: liveQuestionsCount,
      liveDurationSeconds: liveDurationSeconds,
      participantsCount: participantsCount,
      quizQuestionCount: quizQuestionCount,
    );
  }

  bool isAccessibleForPlan(String planKey) {
    if (allowedPlayerPlanKeys.isEmpty) return true;
    final normalizedPlanKey = planKey == 'standard' ? 'free' : planKey;
    return allowedPlayerPlanKeys.contains(normalizedPlanKey);
  }

  bool get isLiveEnded {
    final normalizedStatus = liveStatus.toLowerCase();
    final normalizedContestStatus = status.toLowerCase();
    if (!isLive) return false;
    if (normalizedContestStatus == 'inactive' ||
        normalizedContestStatus == 'ended' ||
        normalizedContestStatus == 'completed' ||
        normalizedContestStatus == 'finished' ||
        normalizedStatus == 'ended' ||
        normalizedStatus == 'completed' ||
        normalizedStatus == 'finished') {
      return true;
    }
    if (!isLivePlayableStatus) return false;
    return !computedLiveEndsAt.isAfter(SyncedClockService.now());
  }

  bool get isLiveReady =>
      !isLive || (liveQuestionsCount > 0 && liveDurationSeconds > 0);

  bool get isLivePlayableStatus {
    final normalizedStatus = liveStatus.toLowerCase();
    return normalizedStatus == 'playing' ||
        normalizedStatus == 'active' ||
        normalizedStatus == 'open';
  }

  bool get isLiveWaitingStatus => liveStatus.toLowerCase() == 'waiting';

  bool get isLiveReservationOpen {
    if (!isLive || isLiveEnded) return false;
    return isLiveWaitingStatus || isLiveActiveNow;
  }

  bool get isLiveQueued {
    if (!isLive || isLiveEnded || isLiveActiveNow) return false;
    final startsAt = liveStartsAt;
    if (startsAt == null) return false;
    return !isLivePlayableStatus && !isLiveWaitingStatus;
  }

  DateTime get computedLiveEndsAt {
    if (!isLive) return endsAt;
    final startsAt = liveStartsAt;
    if (startsAt == null || liveDurationSeconds <= 0) return endsAt;
    final computedEnd = startsAt.add(Duration(seconds: liveDurationSeconds));
    return computedEnd.isBefore(endsAt) ? computedEnd : endsAt;
  }

  bool get isLiveActiveNow {
    if (!isLive || isLiveEnded) return false;
    if (!isLivePlayableStatus) return false;
    final now = SyncedClockService.now();
    return liveStartsAt != null &&
        !now.isBefore(liveStartsAt!) &&
        now.isBefore(computedLiveEndsAt);
  }

  bool get isLiveVisibleOnHome {
    if (!isLive) return false;
    return isLiveReady && !isLiveEnded;
  }

  String get accessLabel {
    if (allowedPlayerPlanKeys.isEmpty) return 'Tous les joueurs';
    return allowedPlayerPlanKeys
        .map((key) {
          return switch (key) {
            'free' => 'Standard',
            'premium' => 'Premium',
            'vip' => 'VIP',
            _ => key,
          };
        })
        .join(' + ');
  }
}

Map<String, dynamic> _jsonMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, entry) => MapEntry('$key', entry));
  }
  return const {};
}

int _questionCountFromMetadata(Map<String, dynamic> metadata) {
  final value = metadata['question_count'];
  if (value is num) return value.toInt().clamp(1, 50);
  if (value is String) {
    final parsed = int.tryParse(value);
    if (parsed != null) return parsed.clamp(1, 50);
  }
  return 5;
}

List<String> _allowedPlanKeys(Object? value) {
  if (value is! List) return const [];
  final keys = <String>{};
  for (final item in value) {
    if (item == 'standard' || item == 'free') keys.add('free');
    if (item == 'premium') keys.add('premium');
    if (item == 'vip') keys.add('vip');
  }
  return keys.toList(growable: false);
}

String _categoryName(Map<String, dynamic> json) {
  final embeddedCategory = json['categories'];
  if (embeddedCategory is Map<String, dynamic>) {
    final name = embeddedCategory['name'] as String?;
    if (name != null && name.trim().isNotEmpty) return name;
  }

  return json['category'] as String? ?? 'Général';
}

class Category {
  final String id;
  final String name;
  final String? description;
  final IconData icon;
  final Color color;
  final bool isActive;

  const Category({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.isActive,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Général',
      description: json['description'] as String?,
      icon: _iconFromValue(json['icon'] as String?),
      color: _colorFromValue(json['color'] as String?),
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  static Category? fromEmbeddedJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    return Category.fromJson(value);
  }
}

IconData _iconFromValue(String? value) {
  return switch (value?.toLowerCase()) {
    'food' || 'restaurant' => Icons.restaurant_rounded,
    'tech' || 'phone' => Icons.devices_rounded,
    'sport' || 'sports' => Icons.sports_soccer_rounded,
    'money' || 'cash' => Icons.payments_rounded,
    'beauty' => Icons.spa_rounded,
    'shopping' => Icons.shopping_bag_rounded,
    'game' || 'gaming' => Icons.sports_esports_rounded,
    _ => Icons.category_rounded,
  };
}

Color _colorFromValue(String? value) {
  if (value == null || value.trim().isEmpty) return AppColors.primaryLight;

  final normalized = value.replaceFirst('#', '');
  final parsed = int.tryParse(normalized, radix: 16);
  if (parsed == null) return AppColors.primaryLight;

  return Color(0xFF000000 | parsed);
}
