import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../services/legal_page_service.dart';

class LegalPageScreen extends StatelessWidget {
  const LegalPageScreen({super.key, required this.pageKey});

  final String pageKey;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FutureBuilder<LegalPage>(
          future: LegalPageService.fetch(pageKey),
          builder: (context, snapshot) {
            final page = snapshot.data;

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            if (context.canPop()) {
                              context.pop();
                            } else {
                              context.go('/login');
                            }
                          },
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            page?.title ?? _fallbackTitle(pageKey),
                            style: AppTextStyles.h2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (snapshot.hasError)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _LegalError(pageKey: pageKey),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                    sliver: SliverList.separated(
                      itemCount: _paragraphs(page?.content ?? '').length,
                      separatorBuilder: (_, _) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final paragraph =
                            _paragraphs(page?.content ?? '')[index];
                        return Text(
                          paragraph,
                          style: AppTextStyles.bodySecondary.copyWith(
                            color: AppColors.textPrimary,
                            height: 1.65,
                          ),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  static String _fallbackTitle(String key) {
    return key == 'privacy'
        ? 'Politique de confidentialité'
        : 'Conditions générales d’utilisation';
  }

  static List<String> _paragraphs(String content) {
    final parts = content
        .split(RegExp(r'\n\s*\n'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    return parts.isEmpty ? ['Contenu indisponible pour le moment.'] : parts;
  }
}

class _LegalError extends StatelessWidget {
  const _LegalError({required this.pageKey});

  final String pageKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.description_outlined,
            color: AppColors.textHint,
            size: 42,
          ),
          const SizedBox(height: 14),
          Text(
            LegalPageScreen._fallbackTitle(pageKey),
            textAlign: TextAlign.center,
            style: AppTextStyles.h2,
          ),
          const SizedBox(height: 8),
          Text(
            'Impossible de charger cette page pour le moment.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySecondary,
          ),
        ],
      ),
    );
  }
}
