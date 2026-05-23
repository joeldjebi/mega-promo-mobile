import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../services/app_telemetry_service.dart';

void authLog(String step, Object? value) {
  debugPrint('[AUTH][$step] $value');
}

void authLogPayload(String step, Map<String, dynamic> payload) {
  authLog('$step][payload', payload);
}

void authLogResponse(String step, Object? response) {
  authLog('$step][response', response);
}

void authLogError(String step, Object error, [StackTrace? stackTrace]) {
  authLog('$step][error', error);
  if (stackTrace != null) {
    authLog('$step][stackTrace', stackTrace);
  }
  unawaited(AppTelemetryService.recordError(error, stackTrace, reason: step));
}
