import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class AppButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final bool isGhost;
  final IconData? icon;
  final Color? color;
  final double? width;
  final double height;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.isGhost = false,
    this.icon,
    this.color,
    this.width,
    this.height = 54,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _tapLocked = false;

  VoidCallback? get _effectiveOnPressed {
    if (widget.onPressed == null || widget.isLoading || _tapLocked) {
      return null;
    }
    return () {
      setState(() => _tapLocked = true);
      widget.onPressed?.call();
      Future<void>.delayed(const Duration(milliseconds: 650), () {
        if (mounted) setState(() => _tapLocked = false);
      });
    };
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isGhost) return _buildGhost();
    if (widget.isOutlined) return _buildOutlined();
    return _buildPrimary();
  }

  Widget _buildPrimary() {
    final isDisabled = _effectiveOnPressed == null;

    return SizedBox(
      width: widget.width ?? double.infinity,
      height: widget.height,
      child: Container(
        decoration: BoxDecoration(
          color: isDisabled
              ? AppColors.surfaceBorder
              : widget.color ?? AppColors.primary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDisabled
                ? AppColors.surfaceBorder
                : (widget.color ?? AppColors.primaryDark).withValues(
                    alpha: 0.18,
                  ),
            width: 0.8,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _effectiveOnPressed,
            borderRadius: BorderRadius.circular(16),
            child: Center(
              child: _buildChild(
                isDisabled ? AppColors.textHint : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOutlined() {
    return SizedBox(
      width: widget.width ?? double.infinity,
      height: widget.height,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.color ?? AppColors.primary,
            width: 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _effectiveOnPressed,
            borderRadius: BorderRadius.circular(16),
            child: Center(
              child: _buildChild(widget.color ?? AppColors.primary),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGhost() {
    return SizedBox(
      width: widget.width ?? double.infinity,
      height: widget.height,
      child: TextButton(
        onPressed: _effectiveOnPressed,
        style: TextButton.styleFrom(
          foregroundColor: widget.color ?? AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _buildChild(widget.color ?? AppColors.primary),
      ),
    );
  }

  Widget _buildChild(Color contentColor) {
    if (widget.isLoading) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(color: contentColor, strokeWidth: 2),
      );
    }
    if (widget.icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(widget.icon, size: 18, color: contentColor),
          const SizedBox(width: 8),
          Text(
            widget.text,
            style: AppTextStyles.button.copyWith(color: contentColor),
          ),
        ],
      );
    }
    return Text(
      widget.text,
      style: AppTextStyles.button.copyWith(color: contentColor),
    );
  }
}
