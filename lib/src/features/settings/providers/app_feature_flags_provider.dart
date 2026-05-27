import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppFeatureFlags {
  final bool playerSubscriptionsEnabled;
  final bool appMaintenanceEnabled;

  const AppFeatureFlags({
    required this.playerSubscriptionsEnabled,
    required this.appMaintenanceEnabled,
  });

  static const defaults = AppFeatureFlags(
    playerSubscriptionsEnabled: true,
    appMaintenanceEnabled: false,
  );

  factory AppFeatureFlags.fromRows(List<dynamic> rows) {
    var playerSubscriptionsEnabled = true;
    var appMaintenanceEnabled = false;

    for (final row in rows) {
      if (row is! Map<String, dynamic>) continue;
      final key = row['key'] as String? ?? '';
      final isEnabled = row['is_enabled'] as bool? ?? true;
      if (key == 'player_subscriptions') {
        playerSubscriptionsEnabled = isEnabled;
      } else if (key == 'app_maintenance') {
        appMaintenanceEnabled = isEnabled;
      }
    }

    return AppFeatureFlags(
      playerSubscriptionsEnabled: playerSubscriptionsEnabled,
      appMaintenanceEnabled: appMaintenanceEnabled,
    );
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
        .inFilter('key', ['player_subscriptions', 'app_maintenance']);

    yield AppFeatureFlags.fromRows(rows);

    yield* supabase
        .from('app_feature_flags')
        .stream(primaryKey: ['key'])
        .map(AppFeatureFlags.fromRows);
  } catch (_) {
    yield AppFeatureFlags.defaults;
  }
});
