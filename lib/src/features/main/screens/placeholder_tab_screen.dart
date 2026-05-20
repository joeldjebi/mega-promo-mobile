import 'package:flutter/material.dart';
import 'package:mega_promo/core/theme/app_colors.dart';
import 'package:mega_promo/core/theme/app_text_styles.dart';

class PlaceholderTabScreen extends StatelessWidget {
  final String title;

  const PlaceholderTabScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(child: Text(title, style: AppTextStyles.h1)),
      ),
    );
  }
}
