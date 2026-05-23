import 'package:flutter/material.dart';
import 'package:mega_promo/core/theme/app_colors.dart';
import 'package:mega_promo/core/theme/app_text_styles.dart';
import 'package:mega_promo/core/widgets/app_button.dart';

import '../services/app_update_service.dart';

class ForceUpdateScreen extends StatelessWidget {
  final AppUpdateConfig config;

  const ForceUpdateScreen({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: const Icon(
                  Icons.system_update_rounded,
                  color: AppColors.primaryLight,
                  size: 42,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                config.title,
                textAlign: TextAlign.center,
                style: AppTextStyles.h1,
              ),
              const SizedBox(height: 12),
              Text(
                config.message,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySecondary,
              ),
              const SizedBox(height: 28),
              AppButton(
                text: 'Mettre à jour',
                icon: Icons.open_in_new_rounded,
                onPressed: config.hasStoreUrl
                    ? () => AppUpdateService.openStore(config)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
