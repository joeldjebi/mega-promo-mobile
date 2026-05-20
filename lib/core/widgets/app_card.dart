import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;
  final bool useGradient;
  final bool showGlow;
  final double? borderRadius;
  final Gradient? gradient;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.useGradient = false,
    this.showGlow = false,
    this.borderRadius,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding ?? const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(borderRadius ?? 16),
          border: Border.all(
            color: showGlow
                ? AppColors.primary.withValues(alpha: 0.38)
                : AppColors.surfaceBorder,
            width: showGlow ? 1.2 : 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.subtleShadow,
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}
