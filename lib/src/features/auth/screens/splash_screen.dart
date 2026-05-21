import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:mega_promo/core/theme/app_colors.dart';
import 'package:mega_promo/core/theme/app_text_styles.dart';

import '../providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 2500), _handleNavigation);
  }

  void _handleNavigation() {
    final user = ref.read(authStateProvider).asData?.value;
    if (user != null) {
      if (mounted) {
        context.go('/home');
      }
    } else {
      if (mounted) {
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                  width: 132,
                  height: 132,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(34),
                    border: Border.all(color: AppColors.surfaceBorder),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.18),
                        blurRadius: 34,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/logo/megapromologo.png',
                    fit: BoxFit.contain,
                  ),
                )
                .animate()
                .fadeIn(duration: 650.ms, curve: Curves.easeOutCubic)
                .scale(
                  begin: const Offset(0.82, 0.82),
                  end: const Offset(1, 1),
                  duration: 650.ms,
                  curve: Curves.easeOutBack,
                ),
            const SizedBox(height: 8),
            Text('Joue. Gagne. Vis.', style: AppTextStyles.bodySecondary),
          ],
        ),
      ),
    );
  }
}
