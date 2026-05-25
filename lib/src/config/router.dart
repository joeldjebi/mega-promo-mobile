import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/providers/auth_provider.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/onboarding_screen.dart';
import '../features/auth/screens/splash_screen.dart';
import '../features/auth/screens/verify_otp_screen.dart';
import '../features/account/screens/account_reactivation_screen.dart';
import '../features/contests/screens/contest_detail_screen.dart';
import '../features/contests/screens/contests_screen.dart';
import '../features/home/screens/home_screen.dart';
import '../features/leaderboard/screens/leaderboard_screen.dart';
import '../features/legal/screens/legal_page_screen.dart';
import '../features/live_quiz/screens/live_quiz_waiting_screen.dart';
import '../features/main/screens/main_shell.dart';
import '../features/notifications/screens/notifications_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/quiz/models/question.dart';
import '../features/quiz/screens/quiz_result_screen.dart';
import '../features/quiz/screens/quiz_screen.dart';
import '../features/rewards/screens/rewards_screen.dart';
import '../features/rewards/screens/reward_victory_screen.dart';
import '../features/subscriptions/screens/player_plans_screen.dart';
import '../services/app_telemetry_service.dart';
import '../services/fcm_service.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final supabase = ref.watch(supabaseProvider);
  final routerRefresh = GoRouterRefreshStream(supabase.auth.onAuthStateChange);
  ref.onDispose(routerRefresh.dispose);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    debugLogDiagnostics: false,
    observers: [AppTelemetryNavigatorObserver()],
    refreshListenable: routerRefresh,
    redirect: (context, state) async {
      final authState = ref.read(authStateProvider);
      if (authState.isLoading && !authState.hasValue) {
        return null;
      }

      final currentUser = authState.asData?.value;
      final isLogged = currentUser != null;
      final location = state.uri.path;
      final goingToLogin = location == '/login';
      final goingToSplash = location == '/splash';
      final goingToVerifyOtp = location == '/verify-otp';
      final goingToLegal = location.startsWith('/legal/');
      final goingToAccountReactivation = location == '/account/reactivation';
      final goingToOnboarding = location.startsWith('/onboarding');
      final goingToMainRoute =
          location == '/home' ||
          location == '/leaderboard' ||
          location == '/rewards' ||
          location.startsWith('/rewards/') ||
          location == '/profile' ||
          location == '/subscriptions' ||
          location == '/notifications' ||
          location == '/contests' ||
          location.startsWith('/c/') ||
          location.startsWith('/contests/');

      final goingToProtectedRoute =
          goingToMainRoute || goingToOnboarding || goingToAccountReactivation;
      final goingToAuthRoute =
          goingToLogin || goingToSplash || goingToVerifyOtp || goingToLegal;

      if (!isLogged && goingToProtectedRoute) {
        return '/login';
      }

      if (isLogged) {
        final accountRedirect = await _accountStatusRedirect(
          userId: currentUser.id,
          goingToAccountReactivation: goingToAccountReactivation,
        );
        if (accountRedirect != null) return accountRedirect;
      }

      if (isLogged && (goingToLogin || goingToSplash || goingToVerifyOtp)) {
        return '/home';
      }

      if (isLogged || goingToAuthRoute) {
        return null;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/legal/:key',
        builder: (context, state) =>
            LegalPageScreen(pageKey: state.pathParameters['key'] ?? 'terms'),
      ),
      GoRoute(
        path: '/verify-otp',
        builder: (context, state) =>
            VerifyOtpScreen(phone: state.uri.queryParameters['phone'] ?? ''),
      ),
      GoRoute(
        path: '/account/reactivation',
        builder: (context, state) => const AccountReactivationScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingUsernameScreen(),
      ),
      GoRoute(
        path: '/onboarding/avatar',
        builder: (context, state) => const OnboardingAvatarScreen(),
      ),
      GoRoute(
        path: '/c/:id',
        redirect: (context, state) {
          final contestId = state.pathParameters['id'] ?? '';
          return contestId.isEmpty ? '/contests' : '/contests/$contestId';
        },
      ),
      GoRoute(
        path: '/contests/:id',
        builder: (context, state) =>
            ContestDetailScreen(contestId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: '/contests/:id/quiz',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return QuizScreen(
            contestId: state.pathParameters['id'] ?? '',
            participationId: extra['participationId'] as String? ?? '',
          );
        },
      ),
      GoRoute(
        path: '/contests/:id/live-waiting',
        builder: (context, state) =>
            LiveQuizWaitingScreen(contestId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: '/contests/:id/quiz/result',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return QuizResultScreen(
            contestId: state.pathParameters['id'] ?? '',
            participationId: extra['participationId'] as String? ?? '',
            questions: extra['questions'] as List<QuizQuestion>? ?? const [],
            answers: extra['answers'] as List<QuizAnswer>? ?? const [],
          );
        },
      ),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/contests',
            builder: (context, state) => const ContestsScreen(),
          ),
          GoRoute(
            path: '/leaderboard',
            builder: (context, state) => LeaderboardScreen(
              contestId: state.uri.queryParameters['contestId'],
            ),
          ),
          GoRoute(
            path: '/rewards',
            builder: (context, state) => const RewardsScreen(),
          ),
          GoRoute(
            path: '/rewards/:winnerId',
            builder: (context, state) => RewardVictoryScreen(
              winnerId: state.pathParameters['winnerId'] ?? '',
            ),
          ),
          GoRoute(
            path: '/notifications',
            builder: (context, state) => const NotificationsScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/subscriptions',
            builder: (context, state) => const PlayerPlansScreen(),
          ),
        ],
      ),
    ],
  );
});

Future<String?> _accountStatusRedirect({
  required String userId,
  required bool goingToAccountReactivation,
}) async {
  try {
    final profile = await Supabase.instance.client
        .from('users')
        .select('is_active, account_status')
        .eq('id', userId)
        .maybeSingle();
    if (profile == null) return null;

    final accountStatus = profile['account_status'] as String?;
    final isActive = profile['is_active'] as bool? ?? true;
    final isPendingDeletion =
        accountStatus == 'pending_deletion' ||
        (accountStatus == null && isActive == false);

    if (isPendingDeletion) {
      return goingToAccountReactivation ? null : '/account/reactivation';
    }

    if (goingToAccountReactivation) return '/home';

    if (accountStatus == 'deleted') {
      await Supabase.instance.client.auth.signOut();
      return '/login';
    }
  } catch (error, stackTrace) {
    debugPrint('[ROUTER][accountStatus] skipped: $error');
    unawaited(
      AppTelemetryService.recordError(
        error,
        stackTrace,
        reason: 'account_status_redirect_failed',
      ),
    );
  }

  return null;
}

class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<dynamic> _subscription;

  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
