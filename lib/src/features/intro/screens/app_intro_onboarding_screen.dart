import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:mega_promo/core/theme/app_colors.dart';
import 'package:mega_promo/core/theme/app_text_styles.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/app_onboarding_service.dart';

class AppIntroOnboardingScreen extends StatefulWidget {
  const AppIntroOnboardingScreen({super.key});

  @override
  State<AppIntroOnboardingScreen> createState() =>
      _AppIntroOnboardingScreenState();
}

class _AppIntroOnboardingScreenState extends State<AppIntroOnboardingScreen> {
  final _controller = PageController();
  int _index = 0;
  bool _isClosing = false;

  static const _steps = [
    _IntroStep(
      asset: 'assets/onboarding/discover_brands.svg',
      icon: Icons.storefront_rounded,
      visualLabel: 'Marques',
      visualDetail: 'Produits & offres',
      title: 'Découvre des marques',
      body:
          'Explore des campagnes promotionnelles et découvre les produits des entreprises partenaires.',
    ),
    _IntroStep(
      asset: 'assets/onboarding/play_quiz.svg',
      icon: Icons.quiz_rounded,
      visualLabel: 'Quiz gratuit',
      visualDetail: 'Question / réponse',
      title: 'Réponds aux quiz',
      body:
          'Participe gratuitement à des quiz simples pour mieux connaître les marques et leurs offres.',
    ),
    _IntroStep(
      asset: 'assets/onboarding/earn_rewards.svg',
      icon: Icons.card_giftcard_rounded,
      visualLabel: 'Récompenses',
      visualDetail: 'Bons & cadeaux',
      title: 'Profite des récompenses',
      body:
          'Reçois des récompenses promotionnelles offertes par les partenaires, sans mise ni achat obligatoire.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_isClosing) return;
    setState(() => _isClosing = true);
    await AppOnboardingService.markSeen();
    if (!mounted) return;
    final hasUser = Supabase.instance.client.auth.currentUser != null;
    context.go(hasUser ? '/home' : '/login');
  }

  void _next() {
    if (_index == _steps.length - 1) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _previous() {
    if (_index == 0) return;
    _controller.previousPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final canGoBack = _index > 0;
    final isLast = _index == _steps.length - 1;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 22),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.22),
                          blurRadius: 18,
                          offset: const Offset(0, 9),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/logo/megapromologo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _isClosing ? null : _finish,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                        side: const BorderSide(color: AppColors.surfaceBorder),
                      ),
                    ),
                    child: Text(
                      'Passer',
                      style: AppTextStyles.bodySecondary.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _steps.length,
                  onPageChanged: (value) => setState(() => _index = value),
                  itemBuilder: (context, index) {
                    final step = _steps[index];
                    return _IntroStepView(step: step);
                  },
                ),
              ),
              Row(
                children: [
                  _IntroDots(index: _index, count: _steps.length),
                  const Spacer(),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: canGoBack ? 1 : 0,
                    child: _CircleNavButton(
                      icon: Icons.arrow_back_rounded,
                      backgroundColor: AppColors.surface,
                      foregroundColor: AppColors.textPrimary,
                      onTap: canGoBack ? _previous : null,
                    ),
                  ),
                  const SizedBox(width: 14),
                  _CircleNavButton(
                    icon: isLast
                        ? Icons.check_rounded
                        : Icons.arrow_forward_rounded,
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    showRing: true,
                    onTap: _isClosing ? null : _next,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntroStepView extends StatelessWidget {
  final _IntroStep step;

  const _IntroStepView({required this.step});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final visualHeight = (constraints.maxHeight * 0.58).clamp(260.0, 430.0);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: visualHeight,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(34),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.10),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: SvgPicture.asset(
                        step.asset,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 18,
                    top: 18,
                    child: _VisualBadge(
                      icon: step.icon,
                      label: step.visualLabel,
                      isPrimary: true,
                    ),
                  ),
                  Positioned(
                    right: 18,
                    bottom: 18,
                    child: _VisualBadge(
                      icon: Icons.verified_rounded,
                      label: step.visualDetail,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Text(
              step.title,
              style: AppTextStyles.h1.copyWith(
                fontSize: 28,
                height: 1.05,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              step.body,
              style: AppTextStyles.bodySecondary.copyWith(
                fontSize: 17,
                height: 1.28,
                color: AppColors.textHint,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 36),
          ],
        );
      },
    );
  }
}

class _IntroDots extends StatelessWidget {
  final int index;
  final int count;

  const _IntroDots({required this.index, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(count, (dotIndex) {
        final isActive = dotIndex == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: isActive ? 18 : 8,
          height: 8,
          margin: const EdgeInsets.only(right: 7),
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : AppColors.surfaceBorder,
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}

class _VisualBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isPrimary;

  const _VisualBadge({
    required this.icon,
    required this.label,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final background = isPrimary ? AppColors.primary : Colors.white;
    final foreground = isPrimary ? Colors.white : AppColors.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isPrimary
              ? Colors.white.withValues(alpha: 0.18)
              : AppColors.primary.withValues(alpha: 0.14),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: foreground, size: 17),
          const SizedBox(width: 7),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: foreground,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleNavButton extends StatelessWidget {
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback? onTap;
  final bool showRing;

  const _CircleNavButton({
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onTap,
    this.showRing = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          border: showRing
              ? Border.all(
                  color: AppColors.primary.withValues(alpha: 0.26),
                  width: 7,
                  strokeAlign: BorderSide.strokeAlignOutside,
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: backgroundColor.withValues(alpha: 0.24),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(icon, color: foregroundColor, size: 24),
      ),
    );
  }
}

class _IntroStep {
  final String asset;
  final IconData icon;
  final String visualLabel;
  final String visualDetail;
  final String title;
  final String body;

  const _IntroStep({
    required this.asset,
    required this.icon,
    required this.visualLabel,
    required this.visualDetail,
    required this.title,
    required this.body,
  });
}
