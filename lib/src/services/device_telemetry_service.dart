import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_telemetry_service.dart';
import 'network_status_service.dart';

class DeviceTelemetryService {
  DeviceTelemetryService._();

  static final _observer = _DeviceTelemetryLifecycleObserver();
  static bool _initialized = false;
  static DateTime? _lastSyncAt;

  static void initialize() {
    if (_initialized) return;
    WidgetsBinding.instance.addObserver(_observer);
    _initialized = true;
    unawaited(syncForCurrentUser());
  }

  static Future<void> syncForCurrentUser({bool force = false}) async {
    if (!NetworkStatusService.instance.canAttemptNetwork) return;

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final lastSyncAt = _lastSyncAt;
    if (!force &&
        lastSyncAt != null &&
        DateTime.now().difference(lastSyncAt) < const Duration(minutes: 15)) {
      return;
    }

    try {
      final payload = await Future.wait([
        collectDeviceInfo(),
        _collectLocationInfo(),
      ]);

      await supabase.rpc(
        'sync_player_device_location',
        params: {'p_device_info': payload[0], 'p_location_info': payload[1]},
      );
      _lastSyncAt = DateTime.now();
    } catch (error) {
      NetworkStatusService.instance.markOfflineFromError(error);
      if (AppTelemetryService.isRetryableNetworkError(error)) {
        debugPrint('Device telemetry sync skipped: network unavailable');
        return;
      }
      debugPrint('Device telemetry sync failed: $error');
    }
  }

  static Future<Map<String, dynamic>> collectDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    final packageInfo = await PackageInfo.fromPlatform();
    final baseInfo = <String, dynamic>{
      'captured_at': DateTime.now().toIso8601String(),
      'app_name': packageInfo.appName,
      'app_version': packageInfo.version,
      'app_build': packageInfo.buildNumber,
      'platform': defaultTargetPlatform.name,
    };

    if (kIsWeb) return baseInfo;

    if (Platform.isAndroid) {
      final android = await deviceInfo.androidInfo;
      return {
        ...baseInfo,
        'os': 'android',
        'os_version': android.version.release,
        'sdk_int': android.version.sdkInt,
        'brand': android.brand,
        'manufacturer': android.manufacturer,
        'model': android.model,
        'device': android.device,
        'product': android.product,
        'is_physical_device': android.isPhysicalDevice,
      };
    }

    if (Platform.isIOS) {
      final ios = await deviceInfo.iosInfo;
      return {
        ...baseInfo,
        'os': 'ios',
        'os_version': ios.systemVersion,
        'name': ios.name,
        'model': ios.model,
        'localized_model': ios.localizedModel,
        'identifier_for_vendor': ios.identifierForVendor,
        'is_physical_device': ios.isPhysicalDevice,
      };
    }

    return {
      ...baseInfo,
      'os': Platform.operatingSystem,
      'os_version': Platform.operatingSystemVersion,
    };
  }

  static Future<Map<String, dynamic>> _collectLocationInfo() async {
    final capturedAt = DateTime.now().toIso8601String();

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return {
          'captured_at': capturedAt,
          'permission': 'service_disabled',
          'service_enabled': false,
        };
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return {
          'captured_at': capturedAt,
          'permission': permission.name,
          'service_enabled': true,
        };
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 8),
        ),
      );

      return {
        'captured_at': capturedAt,
        'permission': permission.name,
        'service_enabled': true,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'altitude': position.altitude,
        'speed': position.speed,
        'heading': position.heading,
        'position_timestamp': position.timestamp.toIso8601String(),
      };
    } catch (error) {
      return {
        'captured_at': capturedAt,
        'permission': 'error',
        'error': error.toString(),
      };
    }
  }
}

class _DeviceTelemetryLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(DeviceTelemetryService.syncForCurrentUser());
    }
  }
}
