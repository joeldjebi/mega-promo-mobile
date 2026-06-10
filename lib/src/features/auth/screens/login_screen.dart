import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mega_promo/core/theme/app_colors.dart';
import 'package:mega_promo/core/theme/app_text_styles.dart';
import 'package:mega_promo/core/widgets/app_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/app_telemetry_service.dart';
import '../utils/app_review_auth.dart';
import '../utils/auth_debug_logger.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _phoneDigitsLength = 10;

  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;

  String get _phoneDigits =>
      _phoneController.text.replaceAll(RegExp(r'\D'), '');
  bool get _hasValidPhone => _phoneDigits.length == _phoneDigitsLength;

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
    final digits = _phoneDigits;
    final phone = '+225$digits';

    if (!_hasValidPhone) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Entre les 10 chiffres.')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final payload = {'phone': phone};
      authLogPayload('signInWithOtp', payload);

      if (isAppReviewPhone(phone)) {
        authLogResponse('signInWithOtp', {
          'success': true,
          'mode': 'app_review_static_otp',
        });
        if (!mounted) return;
        context.go(
          Uri(
            path: '/verify-otp',
            queryParameters: {'phone': phone},
          ).toString(),
        );
        return;
      }

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppTelemetryService.userMessageForError(
              error,
              fallback: 'Impossible d’envoyer le code. Réessaie.',
            ),
          ),
        ),
      );
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
                'Connecte-toi avec ton numéro WhatsApp',
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
                      inputFormatters: [
                        _PhoneNumberInputFormatter(
                          maxDigits: _phoneDigitsLength,
                        ),
                      ],
                      style: AppTextStyles.body,
                      decoration: const InputDecoration(
                        hintText: 'Numéro de téléphone',
                        prefixIcon: Icon(Icons.phone_iphone_rounded, size: 19),
                      ),
                      onSubmitted: (_) {
                        if (_hasValidPhone && !_isLoading) {
                          _continue();
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.chat_rounded,
                    color: AppColors.accentGreen,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tu recevras ton code OTP par WhatsApp sur ce numéro.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              AppButton(
                text: 'Continuer',
                isLoading: _isLoading,
                onPressed: _hasValidPhone && !_isLoading ? _continue : null,
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

class _PhoneNumberInputFormatter extends TextInputFormatter {
  final int maxDigits;

  const _PhoneNumberInputFormatter({required this.maxDigits});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text
        .replaceAll(RegExp(r'\D'), '')
        .characters
        .take(maxDigits)
        .join();
    final formatted = _formatDigits(digits);
    final digitsBeforeCursor = newValue.text
        .substring(0, newValue.selection.end.clamp(0, newValue.text.length))
        .replaceAll(RegExp(r'\D'), '')
        .length
        .clamp(0, digits.length);
    final cursorOffset = _offsetForDigitIndex(formatted, digitsBeforeCursor);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: cursorOffset),
      composing: TextRange.empty,
    );
  }

  String _formatDigits(String digits) {
    final buffer = StringBuffer();
    for (var index = 0; index < digits.length; index += 1) {
      if (index > 0 && index.isEven) buffer.write(' ');
      buffer.write(digits[index]);
    }
    return buffer.toString();
  }

  int _offsetForDigitIndex(String formatted, int digitIndex) {
    if (digitIndex <= 0) return 0;
    var seenDigits = 0;
    for (var index = 0; index < formatted.length; index += 1) {
      if (_isDigit(formatted.codeUnitAt(index))) {
        seenDigits += 1;
        if (seenDigits == digitIndex) return index + 1;
      }
    }
    return formatted.length;
  }

  bool _isDigit(int codeUnit) {
    return codeUnit >= 48 && codeUnit <= 57;
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
