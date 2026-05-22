import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mega_promo/core/theme/app_colors.dart';
import 'package:mega_promo/core/theme/app_text_styles.dart';
import 'package:mega_promo/core/widgets/app_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/auth_debug_logger.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;

  bool get _hasPhone => _phoneController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    final phone = '+225$digits';

    if (digits.length < 8) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Entre un numéro valide.')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final payload = {'phone': phone};
      authLogPayload('signInWithOtp', payload);

      await Supabase.instance.client.auth.signInWithOtp(phone: phone);
      authLogResponse('signInWithOtp', {'success': true});

      if (!mounted) return;
      context.go(
        Uri(path: '/verify-otp', queryParameters: {'phone': phone}).toString(),
      );
    } on AuthException catch (error) {
      authLogError('signInWithOtp', {
        'message': error.message,
        'statusCode': error.statusCode,
        'code': error.code,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error, stackTrace) {
      authLogError('signInWithOtp', error, stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur réseau. Vérifie ta connexion et réessaie.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(
                child: Image.asset(
                  'assets/logo/megapromologo.png',
                  width: 82,
                  height: 82,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Flexible(child: Text('Bienvenue', style: AppTextStyles.h1)),
                  const SizedBox(width: 10),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.18),
                      ),
                    ),
                    child: const Icon(
                      Icons.waving_hand_rounded,
                      color: AppColors.primary,
                      size: 19,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Connecte-toi avec ton numéro',
                style: AppTextStyles.bodySecondary,
              ),
              const SizedBox(height: 34),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 58,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.surfaceBorder),
                    ),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const _CoteDIvoireFlag(),
                          const SizedBox(width: 9),
                          Text(
                            '+225',
                            style: AppTextStyles.body.copyWith(height: 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: AppTextStyles.body,
                      decoration: const InputDecoration(
                        hintText: 'Numéro de téléphone',
                        prefixIcon: Icon(Icons.phone_iphone_rounded, size: 19),
                      ),
                      onSubmitted: (_) {
                        if (_hasPhone && !_isLoading) {
                          _continue();
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              AppButton(
                text: 'Continuer',
                isLoading: _isLoading,
                onPressed: _hasPhone && !_isLoading ? _continue : null,
              ),
              const Spacer(flex: 2),
              Text.rich(
                TextSpan(
                  text: 'En continuant, tu acceptes nos ',
                  children: [
                    TextSpan(
                      text: 'conditions générales d’utilisation',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w800,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.primaryDark,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => context.push('/legal/terms'),
                    ),
                    const TextSpan(text: ' et notre '),
                    TextSpan(
                      text: 'politique de confidentialité',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w800,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.primaryDark,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => context.push('/legal/privacy'),
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoteDIvoireFlag extends StatelessWidget {
  const _CoteDIvoireFlag();

  static const _flagUrl =
      'https://upload.wikimedia.org/wikipedia/commons/thumb/f/fe/Flag_of_C%C3%B4te_d%27Ivoire.svg/langfr-3840px-Flag_of_C%C3%B4te_d%27Ivoire.svg.png';

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        width: 24,
        height: 16,
        child: Image.network(
          _flagUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const _CoteDIvoireFlagFallback(),
        ),
      ),
    );
  }
}

class _CoteDIvoireFlagFallback extends StatelessWidget {
  const _CoteDIvoireFlagFallback();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(child: ColoredBox(color: Color(0xFFFF8200))),
        Expanded(child: ColoredBox(color: Colors.white)),
        Expanded(child: ColoredBox(color: Color(0xFF009A44))),
      ],
    );
  }
}
