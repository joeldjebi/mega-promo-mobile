import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme/app_theme.dart';
import 'src/config/supabase_config.dart';
import 'src/config/router.dart';
import 'src/features/auth/providers/auth_provider.dart';
import 'src/services/device_telemetry_service.dart';
import 'src/services/fcm_service.dart';
import 'src/services/live_quiz_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final firebaseReady = await _initializeFirebase();
  await Supabase.initialize(url: kSupabaseUrl, anonKey: kSupabaseAnonKey);
  await LiveQuizNotificationService.initialize();
  DeviceTelemetryService.initialize();
  if (firebaseReady) {
    unawaited(FcmService.initialize());
  }

  runApp(const ProviderScope(child: KonkourApp()));
}

Future<bool> _initializeFirebase() async {
  try {
    await Firebase.initializeApp();
    return true;
  } on FirebaseException catch (error) {
    debugPrint('Firebase disabled: ${error.code} ${error.message}');
    return false;
  } catch (error) {
    debugPrint('Firebase disabled: $error');
    return false;
  }
}

class KonkourApp extends ConsumerWidget {
  const KonkourApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    ref.listen(authStateProvider, (previous, next) {
      unawaited(FcmService.syncTokenForCurrentUser());
      unawaited(DeviceTelemetryService.syncForCurrentUser(force: true));
    });

    return MaterialApp.router(
      title: 'MegaPromo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
      scaffoldMessengerKey: scaffoldMessengerKey,
    );
  }
}
