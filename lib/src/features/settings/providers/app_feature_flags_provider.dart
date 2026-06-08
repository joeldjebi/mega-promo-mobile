import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/app_store_review_mode.dart';

class AppFeatureFlags {
  final bool playerSubscriptionsEnabled;
  final bool appMaintenanceEnabled;
  final bool playerProfileCoordinatesEnabled;
  final bool playerProfileRewardsEnabled;
  final bool appReviewSafeEnabled;

  const AppFeatureFlags({
    required this.playerSubscriptionsEnabled,
    required this.appMaintenanceEnabled,
    required this.playerProfileCoordinatesEnabled,
    required this.playerProfileRewardsEnabled,
    required this.appReviewSafeEnabled,
  });

  static const defaults = AppFeatureFlags(
    playerSubscriptionsEnabled: true,
    appMaintenanceEnabled: false,
    playerProfileCoordinatesEnabled: true,
    playerProfileRewardsEnabled: true,
    appReviewSafeEnabled: false,
  );

  AppFeatureFlags copyWith({
    bool? playerSubscriptionsEnabled,
    bool? appMaintenanceEnabled,
    bool? playerProfileCoordinatesEnabled,
    bool? playerProfileRewardsEnabled,
    bool? appReviewSafeEnabled,
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
      }
    }

    return AppFeatureFlags(
      playerSubscriptionsEnabled: playerSubscriptionsEnabled,
      appMaintenanceEnabled: appMaintenanceEnabled,
      playerProfileCoordinatesEnabled: playerProfileCoordinatesEnabled,
      playerProfileRewardsEnabled: playerProfileRewardsEnabled,
      appReviewSafeEnabled: appReviewSafeEnabled,
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
        .select('key, is_enabled')
        .inFilter('key', [
          'player_subscriptions',
          'app_maintenance',
          'player_profile_coordinates',
          'player_profile_rewards',
          'app_review_safe',
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
