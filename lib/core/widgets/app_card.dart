import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AppCard extends StatefulWidget {
  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;
  final bool useGradient;
  final bool showGlow;
  final double? borderRadius;
  final Gradient? gradient;
  final Color? backgroundColor;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.useGradient = false,
    this.showGlow = false,
    this.borderRadius,
    this.gradient,
    this.backgroundColor,
  });

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _tapLocked = false;

  VoidCallback? get _effectiveOnTap {
    if (widget.onTap == null || _tapLocked) return null;
    return () {
      setState(() => _tapLocked = true);
      widget.onTap?.call();
      Future<void>.delayed(const Duration(milliseconds: 550), () {
        if (mounted) setState(() => _tapLocked = false);
      });
    };
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(widget.borderRadius ?? 16);

    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        onTap: _effectiveOnTap,
        borderRadius: radius,
        child: Ink(
          padding: widget.padding ?? const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: widget.backgroundColor ?? AppColors.surface,
            borderRadius: radius,
            border: Border.all(
              color: widget.showGlow
                  ? AppColors.primary.withValues(alpha: 0.38)
                  : AppColors.surfaceBorder,
              width: widget.showGlow ? 1.2 : 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.subtleShadow,
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
