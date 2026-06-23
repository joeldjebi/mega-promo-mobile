import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/app_store_review_mode.dart';

enum OtpDeliveryChannel {
  sms,
  whatsapp;

  static OtpDeliveryChannel fromValue(Object? value) {
    final normalized = value?.toString().trim().toLowerCase();
    return normalized == 'whatsapp'
        ? OtpDeliveryChannel.whatsapp
        : OtpDeliveryChannel.sms;
  }
}

enum PlayerAuthMode {
  otp,
  social,
  hybrid;

  static PlayerAuthMode fromValue(Object? value) {
    final normalized = value?.toString().trim().toLowerCase();
    if (normalized == 'social' ||
        normalized == 'google_apple' ||
        normalized == 'google_apple_only') {
      return PlayerAuthMode.social;
    }
    if (normalized == 'hybrid' ||
        normalized == 'social_otp' ||
        normalized == 'google_apple_otp') {
      return PlayerAuthMode.hybrid;
    }
    return PlayerAuthMode.otp;
  }

  bool get allowsOtp =>
      this == PlayerAuthMode.otp || this == PlayerAuthMode.hybrid;
  bool get allowsSocial =>
      this == PlayerAuthMode.social || this == PlayerAuthMode.hybrid;
}

class QuizRulesText {
  final bool enabled;
  final int showCount;
  final String title;
  final String objective;
  final List<String> rules;

  const QuizRulesText({
    required this.enabled,
    required this.showCount,
    required this.title,
    required this.objective,
    required this.rules,
  });

  static const jcqDefault = QuizRulesText(
    enabled: true,
    showCount: 3,
    title: 'Règles du JCQ',
    objective:
        'Réponds aux questions, marque le maximum de points et tente de gagner la récompense annoncée.',
    rules: [
      'Le JCQ se joue à ton rythme, tant que le concours est ouvert.',
      'Chaque question a une seule bonne réponse.',
      'Les bonnes réponses rapportent des points selon la difficulté.',
      'Le classement tient compte du score et du temps de réponse.',
      'Une participation validée ne peut plus être recommencée.',
    ],
  );

  static const qlDefault = QuizRulesText(
    enabled: true,
    showCount: 2,
    title: 'Règles du Quiz Live',
    objective:
        'Rejoins l’arène à l’heure prévue, réponds en direct et vise la meilleure place au classement.',
    rules: [
      'Le QL démarre à une heure précise pour tous les joueurs inscrits.',
      'Réserve ta place avant le départ et entre en salle d’attente.',
      'Les questions s’enchaînent en direct avec un temps limité.',
      'Le score dépend des bonnes réponses et de ta rapidité.',
      'Une déconnexion ou un retard peut te faire perdre des points.',
    ],
  );

  factory QuizRulesText.fromMetadata(
    Object? value, {
    required QuizRulesText fallback,
  }) {
    if (value is! Map) return fallback;
    final enabled = value['enabled'] is bool
        ? value['enabled'] as bool
        : fallback.enabled;
    final showCount = _readInt(
      value['show_count'] ?? value['showCount'],
      fallback.showCount,
    );
    final title = _readString(value['title'], fallback.title);
    final objective = _readString(value['objective'], fallback.objective);
    final rawRules = value['rules'];
    final rules = rawRules is List
        ? rawRules
              .map((item) => item?.toString().trim() ?? '')
              .where((item) => item.isNotEmpty)
              .toList(growable: false)
        : fallback.rules;
    return QuizRulesText(
      enabled: enabled,
      showCount: showCount,
      title: title,
      objective: objective,
      rules: rules.isEmpty ? fallback.rules : rules,
    );
  }

  static String _readString(Object? value, String fallback) {
    final normalized = value?.toString().trim() ?? '';
    return normalized.isEmpty ? fallback : normalized;
  }

  static int _readInt(Object? value, int fallback) {
    if (value is int) return value < 0 ? 0 : value;
    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed == null) return fallback;
    return parsed < 0 ? 0 : parsed;
  }
}

class QuizRulesContent {
  final QuizRulesText jcq;
  final QuizRulesText ql;

  const QuizRulesContent({required this.jcq, required this.ql});

  static const defaults = QuizRulesContent(
    jcq: QuizRulesText.jcqDefault,
    ql: QuizRulesText.qlDefault,
  );

  factory QuizRulesContent.fromMetadata(Object? value) {
    if (value is! Map) return defaults;
    return QuizRulesContent(
      jcq: QuizRulesText.fromMetadata(
        value['jcq'],
        fallback: QuizRulesText.jcqDefault,
      ),
      ql: QuizRulesText.fromMetadata(
        value['ql'],
        fallback: QuizRulesText.qlDefault,
      ),
    );
  }
}

class AppFeatureFlags {
  final bool playerSubscriptionsEnabled;
  final bool appMaintenanceEnabled;
  final bool playerProfileCoordinatesEnabled;
  final bool playerProfileRewardsEnabled;
  final bool appReviewSafeEnabled;
  final bool playerAccountLinkingEnabled;
  final OtpDeliveryChannel otpDeliveryChannel;
  final PlayerAuthMode playerAuthMode;
  final QuizRulesContent quizRulesContent;

  const AppFeatureFlags({
    required this.playerSubscriptionsEnabled,
    required this.appMaintenanceEnabled,
    required this.playerProfileCoordinatesEnabled,
    required this.playerProfileRewardsEnabled,
    required this.appReviewSafeEnabled,
    required this.playerAccountLinkingEnabled,
    required this.otpDeliveryChannel,
    required this.playerAuthMode,
    required this.quizRulesContent,
  });

  static const defaults = AppFeatureFlags(
    playerSubscriptionsEnabled: true,
    appMaintenanceEnabled: false,
    playerProfileCoordinatesEnabled: true,
    playerProfileRewardsEnabled: true,
    appReviewSafeEnabled: false,
    playerAccountLinkingEnabled: true,
    otpDeliveryChannel: OtpDeliveryChannel.sms,
    playerAuthMode: PlayerAuthMode.otp,
    quizRulesContent: QuizRulesContent.defaults,
  );

  AppFeatureFlags copyWith({
    bool? playerSubscriptionsEnabled,
    bool? appMaintenanceEnabled,
    bool? playerProfileCoordinatesEnabled,
    bool? playerProfileRewardsEnabled,
    bool? appReviewSafeEnabled,
    bool? playerAccountLinkingEnabled,
    OtpDeliveryChannel? otpDeliveryChannel,
    PlayerAuthMode? playerAuthMode,
    QuizRulesContent? quizRulesContent,
  }) {
    return AppFeatureFlags(
      playerSubscriptionsEnabled:
          playerSubscriptionsEnabled ?? this.playerSubscriptionsEnabled,
      appMaintenanceEnabled:
          appMaintenanceEnabled ?? this.appMaintenanceEnabled,
      playerProfileCoordinatesEnabled:
          playerProfileCoordinatesEnabled ??
          this.playerProfileCoordinatesEnabled,
      playerProfileRewardsEnabled:
          playerProfileRewardsEnabled ?? this.playerProfileRewardsEnabled,
      appReviewSafeEnabled: appReviewSafeEnabled ?? this.appReviewSafeEnabled,
      playerAccountLinkingEnabled:
          playerAccountLinkingEnabled ?? this.playerAccountLinkingEnabled,
      otpDeliveryChannel: otpDeliveryChannel ?? this.otpDeliveryChannel,
      playerAuthMode: playerAuthMode ?? this.playerAuthMode,
      quizRulesContent: quizRulesContent ?? this.quizRulesContent,
    );
  }

  AppFeatureFlags appStoreSafe() {
    AppStoreReviewMode.setRuntimeEnabled(appReviewSafeEnabled);
    if (!AppStoreReviewMode.hidePaidPlans) return this;
    return copyWith(playerSubscriptionsEnabled: false);
  }

  factory AppFeatureFlags.fromRows(List<dynamic> rows) {
    var playerSubscriptionsEnabled = true;
    var appMaintenanceEnabled = false;
    var playerProfileCoordinatesEnabled = true;
    var playerProfileRewardsEnabled = true;
    var appReviewSafeEnabled = false;
    var playerAccountLinkingEnabled = true;
    var otpDeliveryChannel = OtpDeliveryChannel.sms;
    var playerAuthMode = PlayerAuthMode.otp;
    var quizRulesContent = QuizRulesContent.defaults;

    for (final row in rows) {
      if (row is! Map<String, dynamic>) continue;
      final key = row['key'] as String? ?? '';
      final isEnabled = row['is_enabled'] as bool? ?? true;
      if (key == 'player_subscriptions') {
        playerSubscriptionsEnabled = isEnabled;
      } else if (key == 'app_maintenance') {
        appMaintenanceEnabled = isEnabled;
      } else if (key == 'player_profile_coordinates') {
        playerProfileCoordinatesEnabled = isEnabled;
      } else if (key == 'player_profile_rewards') {
        playerProfileRewardsEnabled = isEnabled;
      } else if (key == 'app_review_safe') {
        appReviewSafeEnabled = isEnabled;
      } else if (key == 'player_account_linking') {
        playerAccountLinkingEnabled = isEnabled;
      } else if (key == 'otp_delivery_channel' && isEnabled) {
        final metadata = row['metadata'];
        if (metadata is Map) {
          otpDeliveryChannel = OtpDeliveryChannel.fromValue(
            metadata['channel'],
          );
        }
      } else if (key == 'player_auth_mode' && isEnabled) {
        final metadata = row['metadata'];
        if (metadata is Map) {
          playerAuthMode = PlayerAuthMode.fromValue(metadata['mode']);
        }
      } else if (key == 'quiz_rules_content' && isEnabled) {
        quizRulesContent = QuizRulesContent.fromMetadata(row['metadata']);
      }
    }

    return AppFeatureFlags(
      playerSubscriptionsEnabled: playerSubscriptionsEnabled,
      appMaintenanceEnabled: appMaintenanceEnabled,
      playerProfileCoordinatesEnabled: playerProfileCoordinatesEnabled,
      playerProfileRewardsEnabled: playerProfileRewardsEnabled,
      appReviewSafeEnabled: appReviewSafeEnabled,
      playerAccountLinkingEnabled: playerAccountLinkingEnabled,
      otpDeliveryChannel: otpDeliveryChannel,
      playerAuthMode: playerAuthMode,
      quizRulesContent: quizRulesContent,
    ).appStoreSafe();
  }
}

final appFeatureFlagsProvider = StreamProvider.autoDispose<AppFeatureFlags>((
  ref,
) async* {
  try {
    final supabase = Supabase.instance.client;
    final rows = await supabase
        .from('app_feature_flags')
        .select('key, is_enabled, metadata')
        .inFilter('key', [
          'player_subscriptions',
          'app_maintenance',
          'player_profile_coordinates',
          'player_profile_rewards',
          'app_review_safe',
          'player_account_linking',
          'otp_delivery_channel',
          'player_auth_mode',
          'quiz_rules_content',
        ]);

    yield AppFeatureFlags.fromRows(rows);

    yield* supabase
        .from('app_feature_flags')
        .stream(primaryKey: ['key'])
        .map(AppFeatureFlags.fromRows);
  } catch (_) {
    yield AppFeatureFlags.defaults.appStoreSafe();
  }
});
