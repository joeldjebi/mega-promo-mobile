import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Text(
                'MegaPromo',
                style: AppTextStyles.displayLarge.copyWith(
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'La plateforme ivoirienne des quiz promotionnels gratuits.',
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 40),
              AppCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Prêt à découvrir ?', style: AppTextStyles.titleLarge),
                    const SizedBox(height: 16),
                    Text(
                      'Découvre les produits des marques, réponds aux quiz et cumule des points chaque jour.',
                      style: AppTextStyles.bodyLarge,
                    ),
                    const SizedBox(height: 24),
                    AppButton(
                      text: 'Commencer',
                      onPressed: () => context.go('/auth'),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Center(
                child: Text(
                  'Quiz produits • Défis • Récompenses',
                  style: AppTextStyles.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final TextEditingController _phoneController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connexion')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Connexion par téléphone', style: AppTextStyles.titleLarge),
              const SizedBox(height: 12),
              Text(
                'Utilise ton numéro ivoirien pour recevoir un code OTP.',
                style: AppTextStyles.bodyLarge,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Numéro de téléphone',
                  hintText: '+225 01 02 03 04',
                ),
              ),
              const SizedBox(height: 24),
              AppButton(
                text: 'Recevoir le code',
                onPressed: () {
                  context.go('/otp');
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Tu peux également accéder à toutes les fonctionnalités après vérification OTP.',
                style: AppTextStyles.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OtpVerificationPage extends StatefulWidget {
  const OtpVerificationPage({super.key});

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage> {
  final TextEditingController _otpController = TextEditingController();

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vérification OTP')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tape le code reçu', style: AppTextStyles.titleLarge),
              const SizedBox(height: 12),
              Text(
                'Nous t’avons envoyé un code à ton numéro. Entre-le pour continuer.',
                style: AppTextStyles.bodyLarge,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Code OTP',
                  hintText: '123456',
                ),
              ),
              const SizedBox(height: 24),
              AppButton(
                text: 'Valider le code',
                onPressed: () {
                  context.go('/onboarding');
                },
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {},
                child: const Text('Renvoyer le code'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bienvenue')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Onboarding', style: AppTextStyles.titleLarge),
              const SizedBox(height: 12),
              Text(
                'Configure ton pseudo et ton avatar pour commencer.',
                style: AppTextStyles.bodyLarge,
              ),
              const Spacer(),
              AppButton(text: 'Choisir mon pseudo', onPressed: () {}),
              const SizedBox(height: 16),
              AppButton(
                text: 'Choisir mon avatar',
                onPressed: () {},
                isOutlined: true,
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Accueil')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quiz actifs', style: AppTextStyles.titleLarge),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Quiz de marque', style: AppTextStyles.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Exemple de quiz promotionnel affiché ici.',
                    style: AppTextStyles.bodyLarge,
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
