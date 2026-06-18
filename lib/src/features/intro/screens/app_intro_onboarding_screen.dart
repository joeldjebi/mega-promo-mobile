import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mega_promo/core/theme/app_colors.dart';
import 'package:mega_promo/core/theme/app_text_styles.dart';
import 'package:mega_promo/src/shared/widgets/promo_watermark_background.dart';
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
      visualType: _IntroVisualType.brands,
      title: 'Découvre des marques',
      body:
          'Explore des campagnes promotionnelles et découvre les produits des entreprises partenaires.',
    ),
    _IntroStep(
      visualType: _IntroVisualType.quiz,
      title: 'Réponds aux quiz',
      body:
          'Participe gratuitement à des quiz simples pour mieux connaître les marques et leurs offres.',
    ),
    _IntroStep(
      visualType: _IntroVisualType.rewards,
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
        child: Stack(
          fit: StackFit.expand,
          children: [
            const PromoWatermarkBackground(colorful: true),
            Padding(
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
                          backgroundColor: Colors.white.withValues(alpha: 0.82),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                            side: const BorderSide(
                              color: AppColors.surfaceBorder,
                            ),
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
                          backgroundColor: Colors.white,
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
          ],
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
              child: _IntroVisualScene(type: step.visualType),
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

class _IntroVisualScene extends StatelessWidget {
  final _IntroVisualType type;

  const _IntroVisualScene({required this.type});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _IntroGlowPainter(type)),
            ),
            switch (type) {
              _IntroVisualType.brands => _BrandsVisual(
                width: width,
                height: height,
              ),
              _IntroVisualType.quiz => _QuizVisual(
                width: width,
                height: height,
              ),
              _IntroVisualType.rewards => _RewardsVisual(
                width: width,
                height: height,
              ),
            },
          ],
        );
      },
    );
  }
}

class _BrandsVisual extends StatelessWidget {
  final double width;
  final double height;

  const _BrandsVisual({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: width * 0.05,
          top: height * 0.05,
          child: const _BrandWordmark(
            label: 'Sublime\nCôte d’Ivoire',
            color: Color(0xFFFF7A1A),
            icon: Icons.wb_sunny_rounded,
            large: true,
          ),
        ),
        Positioned(
          right: width * 0.06,
          top: height * 0.12,
          child: const _BrandWordmark(
            label: 'Orange',
            color: Color(0xFFFF7900),
            icon: Icons.signal_cellular_alt_rounded,
          ),
        ),
        Positioned(
          left: width * 0.10,
          top: height * 0.46,
          child: const _BrandWordmark(
            label: 'Wave',
            color: Color(0xFF20A7F3),
            icon: Icons.wallet_rounded,
          ),
        ),
        Positioned(
          right: width * 0.14,
          top: height * 0.46,
          child: const _BrandWordmark(
            label: 'Air Côte\nd’Ivoire',
            color: Color(0xFF009FE3),
            icon: Icons.flight_takeoff_rounded,
          ),
        ),
        Positioned(
          left: width * 0.02,
          bottom: height * 0.08,
          child: const _BrandWordmark(
            label: 'Moov Africa',
            color: Color(0xFF00A651),
            icon: Icons.public_rounded,
          ),
        ),
        Positioned(
          right: width * 0.02,
          bottom: height * 0.08,
          child: const _BrandWordmark(
            label: 'SIB',
            color: Color(0xFF6A5BE2),
            icon: Icons.account_balance_rounded,
          ),
        ),
        Positioned(
          left: width * 0.42,
          bottom: height * 0.22,
          child: const _BrandWordmark(
            label: 'Solibra',
            color: Color(0xFFE11D48),
            icon: Icons.local_drink_rounded,
          ),
        ),
      ],
    );
  }
}

class _QuizVisual extends StatelessWidget {
  final double width;
  final double height;

  const _QuizVisual({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: width * 0.18,
          top: height * 0.06,
          child: const _QuizBubble(
            label: '?',
            color: AppColors.primary,
            size: 90,
            icon: Icons.quiz_rounded,
          ),
        ),
        Positioned(
          right: width * 0.12,
          top: height * 0.18,
          child: const _QuizBubble(
            label: '10 pts',
            color: AppColors.accentGreen,
            size: 76,
            icon: Icons.bolt_rounded,
          ),
        ),
        Positioned(
          left: width * 0.06,
          top: height * 0.48,
          child: const _AnswerPill(label: 'A', color: AppColors.primary),
        ),
        Positioned(
          left: width * 0.33,
          top: height * 0.55,
          child: const _AnswerPill(label: 'B', color: Color(0xFFF97316)),
        ),
        Positioned(
          right: width * 0.10,
          top: height * 0.50,
          child: const _AnswerPill(label: 'C', color: AppColors.accentGreen),
        ),
        Positioned(
          left: width * 0.22,
          bottom: height * 0.08,
          child: const _QuizTimer(),
        ),
      ],
    );
  }
}

class _RewardsVisual extends StatelessWidget {
  final double width;
  final double height;

  const _RewardsVisual({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: width * 0.08,
          top: height * 0.06,
          child: const _RewardToken(
            label: 'CASH',
            icon: Icons.payments_rounded,
            color: AppColors.accentGreen,
            large: true,
          ),
        ),
        Positioned(
          right: width * 0.08,
          top: height * 0.12,
          child: const _RewardToken(
            label: 'Cadeau',
            icon: Icons.card_giftcard_rounded,
            color: AppColors.primary,
          ),
        ),
        Positioned(
          left: width * 0.16,
          top: height * 0.48,
          child: const _RewardToken(
            label: 'Bonus',
            icon: Icons.stars_rounded,
            color: AppColors.gold,
          ),
        ),
        Positioned(
          right: width * 0.12,
          top: height * 0.48,
          child: const _RewardToken(
            label: 'Concert',
            icon: Icons.confirmation_number_rounded,
            color: Color(0xFFF472B6),
          ),
        ),
        Positioned(
          left: width * 0.38,
          bottom: height * 0.07,
          child: const _RewardToken(
            label: '-50%',
            icon: Icons.local_offer_rounded,
            color: Color(0xFFF97316),
          ),
        ),
      ],
    );
  }
}

class _BrandWordmark extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final bool large;

  const _BrandWordmark({
    required this.label,
    required this.color,
    required this.icon,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final diameter = large ? 132.0 : 82.0;
    return Transform.rotate(
      angle: large ? -0.08 : 0.08,
      child: Container(
        width: diameter,
        height: diameter,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: large ? 0.18 : 0.13),
          border: Border.all(
            color: color.withValues(alpha: large ? 0.30 : 0.22),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: large ? 28 : 21),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: large ? 2 : 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySmall.copyWith(
                  color: color,
                  fontSize: large ? 15 : 12,
                  fontWeight: FontWeight.w900,
                  height: 1.02,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuizBubble extends StatelessWidget {
  final String label;
  final Color color;
  final double size;
  final IconData icon;

  const _QuizBubble({
    required this.label,
    required this.color,
    required this.size,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.16),
        border: Border.all(color: color.withValues(alpha: 0.32), width: 1.4),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: size * 0.28),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.h2.copyWith(
              color: color,
              fontSize: size * 0.22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnswerPill extends StatelessWidget {
  final String label;
  final Color color;

  const _AnswerPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 82,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: AppTextStyles.h2.copyWith(
          color: color,
          fontSize: 22,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _QuizTimer extends StatelessWidget {
  const _QuizTimer();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.timer_rounded, color: AppColors.primary, size: 22),
        const SizedBox(width: 8),
        Text(
          '00:20',
          style: AppTextStyles.h2.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _RewardToken extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool large;

  const _RewardToken({
    required this.label,
    required this.icon,
    required this.color,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = large ? 118.0 : 90.0;
    return Transform.rotate(
      angle: large ? -0.12 : 0.10,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(large ? 32 : 26),
          color: color.withValues(alpha: large ? 0.18 : 0.14),
          border: Border.all(color: color.withValues(alpha: 0.30)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: large ? 34 : 27),
            const SizedBox(height: 7),
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: large ? 15 : 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntroGlowPainter extends CustomPainter {
  final _IntroVisualType type;

  const _IntroGlowPainter(this.type);

  @override
  void paint(Canvas canvas, Size size) {
    final colors = switch (type) {
      _IntroVisualType.brands => [
        const Color(0xFFFF7900),
        AppColors.primary,
        AppColors.accentGreen,
      ],
      _IntroVisualType.quiz => [
        AppColors.primary,
        const Color(0xFFF97316),
        AppColors.accentGreen,
      ],
      _IntroVisualType.rewards => [
        AppColors.accentGreen,
        AppColors.goldLight,
        const Color(0xFFF472B6),
      ],
    };

    final circles = [
      (
        Offset(size.width * 0.25, size.height * 0.25),
        size.width * 0.34,
        colors[0],
      ),
      (
        Offset(size.width * 0.76, size.height * 0.32),
        size.width * 0.30,
        colors[1],
      ),
      (
        Offset(size.width * 0.50, size.height * 0.74),
        size.width * 0.36,
        colors[2],
      ),
    ];

    for (final circle in circles) {
      canvas.drawCircle(
        circle.$1,
        circle.$2,
        Paint()
          ..shader = RadialGradient(
            colors: [
              circle.$3.withValues(alpha: 0.18),
              circle.$3.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: circle.$1, radius: circle.$2)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _IntroGlowPainter oldDelegate) {
    return oldDelegate.type != type;
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
  final _IntroVisualType visualType;
  final String title;
  final String body;

  const _IntroStep({
    required this.visualType,
    required this.title,
    required this.body,
  });
}

enum _IntroVisualType { brands, quiz, rewards }
