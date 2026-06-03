import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../features/contests/providers/contest_providers.dart';
import '../features/home/providers/home_bootstrap_provider.dart';
import '../features/home/providers/info_message_provider.dart';
import '../features/home/providers/user_profile_provider.dart';
import '../features/notifications/providers/notifications_provider.dart';
import '../features/profile/providers/profile_provider.dart';
import '../features/profile/providers/player_payment_methods_provider.dart';
import '../features/quiz/services/quiz_result_sync_service.dart';
import '../features/rewards/providers/rewards_provider.dart';
import '../services/fcm_service.dart';
import '../services/network_status_service.dart';

class NetworkStatusBanner extends StatefulWidget {
  final Widget child;

  const NetworkStatusBanner({super.key, required this.child});

  @override
  State<NetworkStatusBanner> createState() => _NetworkStatusBannerState();
}

class _NetworkStatusBannerState extends State<NetworkStatusBanner>
    with WidgetsBindingObserver {
  final _networkStatus = NetworkStatusService.instance;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isOffline = _networkStatus.isOffline.value;
    _networkStatus.isOffline.addListener(_handleNetworkStatusChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _networkStatus.start();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _networkStatus.isOffline.removeListener(_handleNetworkStatusChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _networkStatus.start();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _networkStatus.pause();
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final bannerTop = topPadding + kToolbarHeight + 8;

    return Stack(
      children: [
        widget.child,
        Positioned(
          top: bannerTop,
          left: 16,
          right: 16,
          child: IgnorePointer(
            ignoring: true,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              offset: _isOffline ? Offset.zero : const Offset(0, -1.4),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: _isOffline ? 1 : 0,
                child: const _OfflineBanner(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _handleNetworkStatusChanged() {
    if (!mounted) return;
    setState(() => _isOffline = _networkStatus.isOffline.value);
    if (!_networkStatus.isOffline.value) {
      unawaited(QuizResultSyncService.syncPending());
      unawaited(FcmService.syncTokenForCurrentUser(force: true));
      try {
        final container = ProviderScope.containerOf(context, listen: false);
        container
          ..invalidate(homeBootstrapProvider)
          ..invalidate(userProfileProvider)
          ..invalidate(profileDataProvider)
          ..invalidate(playerPaymentProfileProvider)
          ..invalidate(contestsProvider)
          ..invalidate(categoriesProvider)
          ..invalidate(userParticipatedContestIdsProvider)
          ..invalidate(userRegisteredLiveQuizIdsProvider)
          ..invalidate(infoMessagesProvider)
          ..invalidate(notificationsProvider)
          ..invalidate(rewardsProvider);
      } catch (_) {
        // The banner can be mounted before Riverpod is fully reachable.
      }
    }
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF211C4D),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          boxShadow: const [
            BoxShadow(
              color: AppColors.subtleShadow,
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                color: Colors.white,
                size: 17,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Connexion internet instable',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Certaines actions peuvent échouer.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Color(0xFFE5E1FF),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
