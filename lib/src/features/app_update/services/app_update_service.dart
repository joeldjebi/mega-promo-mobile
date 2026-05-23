import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class AppUpdateConfig {
  final int minimumBuild;
  final int latestBuild;
  final String storeUrl;
  final String title;
  final String message;
  final bool forceUpdate;

  const AppUpdateConfig({
    required this.minimumBuild,
    required this.latestBuild,
    required this.storeUrl,
    required this.title,
    required this.message,
    required this.forceUpdate,
  });

  bool get hasStoreUrl => storeUrl.trim().isNotEmpty;
}

class AppUpdateStatus {
  final bool mustUpdate;
  final bool shouldUpdate;
  final AppUpdateConfig? config;

  const AppUpdateStatus({
    required this.mustUpdate,
    required this.shouldUpdate,
    required this.config,
  });

  static const none = AppUpdateStatus(
    mustUpdate: false,
    shouldUpdate: false,
    config: null,
  );
}

class AppUpdateService {
  AppUpdateService._();

  static const String androidFallbackStoreUrl =
      'https://play.google.com/store/apps/details?id=com.moyoo.megapromo';

  static Future<AppUpdateStatus> check() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 1;
      final platform = _platformKey;
      if (platform == null) return AppUpdateStatus.none;

      final row = await Supabase.instance.client
          .from('app_update_config')
          .select()
          .eq('key', 'main')
          .eq('is_active', true)
          .maybeSingle();

      if (row == null) return AppUpdateStatus.none;

      final minimumBuild =
          (row['minimum_${platform}_build'] as num?)?.toInt() ?? currentBuild;
      final latestBuild =
          (row['latest_${platform}_build'] as num?)?.toInt() ?? currentBuild;
      final storeUrl = row['${platform}_store_url'] as String? ?? '';
      final forceUpdate = row['force_update'] as bool? ?? false;
      final config = AppUpdateConfig(
        minimumBuild: minimumBuild,
        latestBuild: latestBuild,
        storeUrl: storeUrl,
        title: row['title'] as String? ?? 'Mise à jour disponible',
        message:
            row['message'] as String? ??
            'Une nouvelle version de MegaPromo est disponible.',
        forceUpdate: forceUpdate,
      );

      final mustUpdate = currentBuild < minimumBuild || forceUpdate;
      final shouldUpdate = mustUpdate || currentBuild < latestBuild;
      return AppUpdateStatus(
        mustUpdate: mustUpdate,
        shouldUpdate: shouldUpdate,
        config: config,
      );
    } catch (_) {
      return AppUpdateStatus.none;
    }
  }

  static Future<bool> openStore(AppUpdateConfig config) async {
    final url = config.storeUrl.trim().isNotEmpty
        ? config.storeUrl.trim()
        : fallbackStoreUrl;
    if (url.isEmpty) return false;
    return openStoreUrl(url);
  }

  static Future<bool> openCurrentPlatformStore() async {
    final status = await check();
    final storeUrl = status.config?.storeUrl.trim();
    final url = storeUrl != null && storeUrl.isNotEmpty
        ? storeUrl
        : fallbackStoreUrl;
    if (url.isEmpty) return false;
    return openStoreUrl(url);
  }

  static Future<bool> openStoreUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static String get fallbackStoreUrl {
    if (kIsWeb) return '';
    if (Platform.isAndroid) return androidFallbackStoreUrl;
    return '';
  }

  static String? get _platformKey {
    if (kIsWeb) return null;
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return null;
  }
}
