import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class AppButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    if (isGhost) return _buildGhost();
    if (isOutlined) return _buildOutlined();
    return _buildPrimary();
  }

  Widget _buildPrimary() {
    final isDisabled = onPressed == null;

    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: Container(
        decoration: BoxDecoration(
          color: isDisabled
              ? AppColors.surfaceBorder
              : color ?? AppColors.primary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDisabled
                ? AppColors.surfaceBorder
                : (color ?? AppColors.primaryDark).withValues(alpha: 0.18),
            width: 0.8,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isLoading ? null : onPressed,
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
      width: width ?? double.infinity,
      height: height,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color ?? AppColors.primary, width: 1),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isLoading ? null : onPressed,
            borderRadius: BorderRadius.circular(16),
            child: Center(child: _buildChild(color ?? AppColors.primary)),
          ),
        ),
      ),
    );
  }

  Widget _buildGhost() {
    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: TextButton(
        onPressed: isLoading ? null : onPressed,
        style: TextButton.styleFrom(
          foregroundColor: color ?? AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _buildChild(color ?? AppColors.primary),
      ),
    );
  }

  Widget _buildChild(Color contentColor) {
    if (isLoading) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(color: contentColor, strokeWidth: 2),
      );
    }
    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: contentColor),
          const SizedBox(width: 8),
          Text(text, style: AppTextStyles.button.copyWith(color: contentColor)),
        ],
      );
    }
    return Text(
      text,
      style: AppTextStyles.button.copyWith(color: contentColor),
    );
  }
}
