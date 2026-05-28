import 'package:flutter/foundation.dart';

class AppStoreReviewMode {
  const AppStoreReviewMode._();

  static const bool _reviewSafeBuildDefault = bool.fromEnvironment(
    'MEGA_PROMO_REVIEW_SAFE',
    defaultValue: true,
  );
  static bool _runtimeEnabled = _reviewSafeBuildDefault;

  static void setRuntimeEnabled(bool isEnabled) {
    _runtimeEnabled = isEnabled;
  }

  static bool get enabled =>
      _runtimeEnabled &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android ||
          kIsWeb);

  static bool get hideCashAmounts => enabled;

  static bool get hidePaidPlans => enabled;

  static bool get hideRandomOrPredictionCampaigns => enabled;
}
