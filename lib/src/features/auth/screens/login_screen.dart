import 'dart:math' as math;
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mega_promo/core/theme/app_colors.dart';
import 'package:mega_promo/core/theme/app_text_styles.dart';
import 'package:mega_promo/core/widgets/app_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/app_telemetry_service.dart';
import '../../settings/providers/app_feature_flags_provider.dart';
import '../services/auth_profile_service.dart';
import '../services/native_social_auth_service.dart';
import '../utils/app_review_auth.dart';
import '../utils/auth_debug_logger.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  static const _phoneDigitsLength = 10;

  final TextEditingController _phoneController = TextEditingController();
  final FocusNode _phoneFocusNode = FocusNode();
  late final AnimationController _backgroundController;
  bool _isLoading = false;
  NativeSocialProvider? _loadingSocialProvider;

  String get _phoneDigits =>
      _phoneController.text.replaceAll(RegExp(r'\D'), '');
  bool get _hasValidPhone => _phoneDigits.length == _phoneDigitsLength;
  bool get _isBusy => _isLoading || _loadingSocialProvider != null;

  @override
  void initState() {
    super.initState();
    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 11),
    )..repeat();
    _phoneController.addListener(() => setState(() {}));
    _phoneFocusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _phoneController.dispose();
    _phoneFocusNode.dispose();
    super.dispose();
  }

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _continue() async {
    _dismissKeyboard();

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

  Future<void> _continueWithSocial(NativeSocialProvider provider) async {
    _dismissKeyboard();

    setState(() => _loadingSocialProvider = provider);

    final providerLabel = _socialProviderLabel(provider);
    try {
      authLogPayload('signInWithNativeSocial', {'provider': provider.name});

      if (Platform.isAndroid && provider == NativeSocialProvider.google) {
        final launched = await NativeSocialAuthService.signInWithGoogleOAuth();
        authLogResponse('signInWithNativeSocial', {
          'provider': provider.name,
          'mode': 'oauth_external',
          'launched': launched,
        });
        if (!launched && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Impossible d’ouvrir la connexion Google.'),
            ),
          );
        }
        return;
      }

      final response = await NativeSocialAuthService.signIn(provider);
      final session = response.session;
      final user = response.user;

      authLogResponse('signInWithNativeSocial', {
        'provider': provider.name,
        'hasSession': session != null,
        'userId': user?.id,
      });

      if ((session == null || user == null) && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connexion $providerLabel incomplète. Réessaie.'),
          ),
        );
        return;
      }

      if (user != null) {
        final nextRoute = await ensureUserProfileAndResolveRoute(user);
        authLogResponse('signInWithNativeSocialRoute', {
          'provider': provider.name,
          'route': nextRoute,
        });
        if (!mounted) return;
        context.go(nextRoute);
      }
    } on AuthException catch (error) {
      authLogError('signInWithNativeSocial', {
        'provider': provider.name,
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
              fallback: 'Connexion $providerLabel indisponible pour le moment.',
            ),
          ),
        ),
      );
    } catch (error, stackTrace) {
      authLogError('signInWithNativeSocial', error, stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Erreur réseau pendant la connexion $providerLabel. Réessaie.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loadingSocialProvider = null);
      }
    }
  }

  String _socialProviderLabel(NativeSocialProvider provider) {
    return provider == NativeSocialProvider.apple ? 'Apple' : 'Google';
  }

  @override
  Widget build(BuildContext context) {
    final flags = ref.watch(appFeatureFlagsProvider).asData?.value;
    final authMode =
        flags?.playerAuthMode ?? AppFeatureFlags.defaults.playerAuthMode;
    final otpChannel =
        flags?.otpDeliveryChannel ??
        AppFeatureFlags.defaults.otpDeliveryChannel;
    final showSocialAuth = authMode.allowsSocial;
    final showOtpAuth = authMode.allowsOtp;
    final showAppleAuth =
        showSocialAuth && (Platform.isIOS || Platform.isMacOS);
    final usesWhatsapp = otpChannel == OtpDeliveryChannel.whatsapp;
    final channelLabel = usesWhatsapp ? 'WhatsApp' : 'SMS';
    final channelIcon = usesWhatsapp ? Icons.chat_rounded : Icons.sms_rounded;
    final loginSubtitle = showSocialAuth && !showOtpAuth
        ? 'Connecte-toi avec Google ou Apple'
        : showSocialAuth
        ? 'Connecte-toi rapidement ou utilise ton numéro'
        : 'Connecte-toi avec ton numéro de téléphone';

    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final isPhoneKeyboardActive =
        showOtpAuth && bottomInset > 0 && _phoneFocusNode.hasFocus;
    final logoSize = isPhoneKeyboardActive ? 48.0 : 82.0;
    final topPadding = isPhoneKeyboardActive ? 8.0 : 32.0;
    final showSocialOptions = showSocialAuth;
    final contentBottomPadding = isPhoneKeyboardActive ? bottomInset : 96.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: false,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _dismissKeyboard,
        child: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              _LoginPromoWatermark(animation: _backgroundController),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  24,
                  topPadding,
                  24,
                  contentBottomPadding,
                ),
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  offset: isPhoneKeyboardActive
                      ? const Offset(0, -0.025)
                      : Offset.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          width: logoSize,
                          height: logoSize,
                          child: Image.asset(
                            'assets/logo/megapromologo.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      SizedBox(height: isPhoneKeyboardActive ? 8 : 20),
                      Row(
                        children: [
                          Flexible(
                            child: Text('Bienvenue', style: AppTextStyles.h1),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.primary.withValues(
                                  alpha: 0.18,
                                ),
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
                      Text(loginSubtitle, style: AppTextStyles.bodySecondary),
                      SizedBox(height: isPhoneKeyboardActive ? 12 : 34),
                      if (showSocialOptions) ...[
                        _OAuthButton(
                          label: 'Continuer avec Google',
                          icon: Icons.g_mobiledata_rounded,
                          leading: const _GoogleLogoMark(size: 22),
                          compact: isPhoneKeyboardActive,
                          isLoading:
                              _loadingSocialProvider ==
                              NativeSocialProvider.google,
                          onPressed: _isBusy
                              ? null
                              : () => _continueWithSocial(
                                  NativeSocialProvider.google,
                                ),
                        ),
                        if (showAppleAuth) ...[
                          SizedBox(height: isPhoneKeyboardActive ? 8 : 12),
                          _OAuthButton(
                            label: 'Continuer avec Apple',
                            icon: Icons.apple_rounded,
                            compact: isPhoneKeyboardActive,
                            isLoading:
                                _loadingSocialProvider ==
                                NativeSocialProvider.apple,
                            onPressed: _isBusy
                                ? null
                                : () => _continueWithSocial(
                                    NativeSocialProvider.apple,
                                  ),
                          ),
                        ],
                      ],
                      if (showSocialOptions && showOtpAuth) ...[
                        SizedBox(height: isPhoneKeyboardActive ? 10 : 22),
                        const _AuthDivider(label: 'ou avec un code OTP'),
                        SizedBox(height: isPhoneKeyboardActive ? 10 : 22),
                      ],
                      if (isPhoneKeyboardActive) const Spacer(),
                      if (showOtpAuth) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 58,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceElevated,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppColors.surfaceBorder,
                                ),
                              ),
                              child: Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const _CoteDIvoireFlag(),
                                    const SizedBox(width: 9),
                                    Text(
                                      '+225',
                                      style: AppTextStyles.body.copyWith(
                                        height: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                focusNode: _phoneFocusNode,
                                controller: _phoneController,
                                enabled: !_isBusy,
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
                                  prefixIcon: Icon(
                                    Icons.phone_iphone_rounded,
                                    size: 19,
                                  ),
                                ),
                                onSubmitted: (_) {
                                  if (_hasValidPhone && !_isBusy) {
                                    _continue();
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: isPhoneKeyboardActive ? 8 : 24),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              channelIcon,
                              color: AppColors.accentGreen,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Tu recevras ton code OTP par $channelLabel sur ce numéro.',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: isPhoneKeyboardActive ? 8 : 18),
                        AppButton(
                          text: 'Continuer',
                          isLoading: _isLoading,
                          onPressed: _hasValidPhone && !_isBusy
                              ? _continue
                              : null,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: isPhoneKeyboardActive
          ? const SizedBox.shrink()
          : SafeArea(
              top: false,
              child: ColoredBox(
                color: AppColors.background.withValues(alpha: 0.96),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 10),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.surfaceBorder.withValues(alpha: 0.65),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: _LegalConsentText(
                        onTermsTap: () => context.push('/legal/terms'),
                        onPrivacyTap: () => context.push('/legal/privacy'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _LegalConsentText extends StatelessWidget {
  final VoidCallback onTermsTap;
  final VoidCallback onPrivacyTap;

  const _LegalConsentText({
    required this.onTermsTap,
    required this.onPrivacyTap,
  });

  @override
  Widget build(BuildContext context) {
    return Text.rich(
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
            recognizer: TapGestureRecognizer()..onTap = onTermsTap,
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
            recognizer: TapGestureRecognizer()..onTap = onPrivacyTap,
          ),
          const TextSpan(text: '.'),
        ],
      ),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: AppTextStyles.bodySmall.copyWith(height: 1.25),
    );
  }
}

class _LoginPromoWatermark extends StatelessWidget {
  final Animation<double> animation;

  const _LoginPromoWatermark({required this.animation});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            return CustomPaint(
              painter: _LoginPromoWatermarkPainter(animation.value),
              child: const SizedBox.expand(),
            );
          },
        ),
      ),
    );
  }
}

class _LoginPromoWatermarkPainter extends CustomPainter {
  final double progress;

  const _LoginPromoWatermarkPainter(this.progress);

  static const _bandLabels = [
    'MEGA PROMO',
    '-50%',
    'BON',
    'COUPON',
    '-25%',
    'MEGA PROMO',
    'CADEAU',
    '-70%',
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.primary.withValues(alpha: 0.055),
          Colors.white.withValues(alpha: 0),
          AppColors.goldLight.withValues(alpha: 0.08),
        ],
        stops: const [0, 0.54, 1],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, backgroundPaint);

    _paintBand(
      canvas,
      size,
      y: size.height * 0.08,
      angle: -0.18,
      speed: 22,
      color: AppColors.primary,
      reverse: false,
    );
    _paintBand(
      canvas,
      size,
      y: size.height * 0.32,
      angle: 0.16,
      speed: 18,
      color: AppColors.gold,
      reverse: true,
    );
    _paintBand(
      canvas,
      size,
      y: size.height * 0.68,
      angle: -0.72,
      speed: 20,
      color: AppColors.primaryDark,
      reverse: false,
    );
    _paintBand(
      canvas,
      size,
      y: size.height * 0.92,
      angle: math.pi / 2,
      speed: 16,
      color: AppColors.accentGreen,
      reverse: true,
    );

    _paintFloatingCoupons(canvas, size);
  }

  void _paintBand(
    Canvas canvas,
    Size size, {
    required double y,
    required double angle,
    required double speed,
    required Color color,
    required bool reverse,
  }) {
    final phase = reverse ? 1 - progress : progress;
    final travel = phase * speed;
    final center = Offset(size.width / 2, y);
    final longWidth = math.max(size.width, size.height) * 2.15;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);

    final bandRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: longWidth, height: 38),
      const Radius.circular(19),
    );
    canvas.drawRRect(bandRect, Paint()..color = color.withValues(alpha: 0.035));

    var cursor = -longWidth / 2 - 80 + travel;
    var index = 0;
    while (cursor < longWidth / 2 + 120) {
      final label = _bandLabels[index % _bandLabels.length];
      final glow = 0.5 + 0.5 * math.sin((progress * math.pi * 2) + index);
      final opacity = 0.055 + (glow * 0.045);
      final style = TextStyle(
        color: color.withValues(alpha: opacity),
        fontSize: label == 'MEGA PROMO' ? 18 : 15,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
      );
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: TextDirection.ltr,
      )..layout();

      if (label == 'COUPON' || label == 'BON') {
        final ticketRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(cursor - 10, -16, painter.width + 20, 32),
          const Radius.circular(8),
        );
        canvas.drawRRect(
          ticketRect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = color.withValues(alpha: opacity * 0.8),
        );
      }

      painter.paint(canvas, Offset(cursor, -painter.height / 2));
      cursor += painter.width + 34;
      index += 1;
    }

    canvas.restore();
  }

  void _paintFloatingCoupons(Canvas canvas, Size size) {
    final items = [
      (Offset(size.width * 0.08, size.height * 0.18), -0.42, '-30%'),
      (Offset(size.width * 0.82, size.height * 0.24), 0.34, 'BON'),
      (Offset(size.width * 0.14, size.height * 0.78), 0.25, '-15%'),
      (Offset(size.width * 0.78, size.height * 0.76), -0.30, 'VIP'),
    ];

    for (var index = 0; index < items.length; index += 1) {
      final item = items[index];
      final pulse = 0.5 + 0.5 * math.sin(progress * math.pi * 2 + index * 1.4);
      final color = index.isEven ? AppColors.primary : AppColors.gold;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = color.withValues(alpha: 0.055 + pulse * 0.055);

      canvas.save();
      canvas.translate(item.$1.dx, item.$1.dy);
      canvas.rotate(item.$2);
      final rect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(-34, -18, 68, 36),
        const Radius.circular(10),
      );
      canvas.drawRRect(rect, paint);

      final textPainter = TextPainter(
        text: TextSpan(
          text: item.$3,
          style: TextStyle(
            color: color.withValues(alpha: 0.08 + pulse * 0.07),
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(-textPainter.width / 2, -textPainter.height / 2),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _LoginPromoWatermarkPainter oldDelegate) {
    return oldDelegate.progress != progress;
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

class _OAuthButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Widget? leading;
  final bool compact;
  final bool isLoading;
  final VoidCallback? onPressed;

  const _OAuthButton({
    required this.label,
    required this.icon,
    this.leading,
    this.compact = false,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || isLoading;

    return SizedBox(
      height: compact ? 48 : 56,
      child: OutlinedButton(
        onPressed: disabled ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          disabledForegroundColor: AppColors.textHint,
          side: BorderSide(color: AppColors.surfaceBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: AppColors.surfaceElevated,
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  leading ?? Icon(icon, size: compact ? 22 : 24),
                  SizedBox(width: compact ? 8 : 10),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.button.copyWith(
                        color: disabled
                            ? AppColors.textHint
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _GoogleLogoMark extends StatelessWidget {
  final double size;

  const _GoogleLogoMark({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.16;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.34;
    final rect = Rect.fromCircle(center: center, radius: radius);

    void drawArc(Color color, double start, double sweep) {
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..color = color
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );
    }

    drawArc(const Color(0xFF4285F4), -0.12, math.pi * 0.42);
    drawArc(const Color(0xFF34A853), math.pi * 0.30, math.pi * 0.48);
    drawArc(const Color(0xFFFBBC05), math.pi * 0.82, math.pi * 0.36);
    drawArc(const Color(0xFFEA4335), math.pi * 1.18, math.pi * 0.62);

    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(size.width * 0.53, size.height * 0.50),
      Offset(size.width * 0.86, size.height * 0.50),
      barPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.74, size.height * 0.50),
      Offset(size.width * 0.74, size.height * 0.63),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AuthDivider extends StatelessWidget {
  final String label;

  const _AuthDivider({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.surfaceBorder)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.surfaceBorder)),
      ],
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
