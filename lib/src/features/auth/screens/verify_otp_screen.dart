import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mega_promo/core/theme/app_colors.dart';
import 'package:mega_promo/core/theme/app_text_styles.dart';
import 'package:mega_promo/core/widgets/app_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_profile_service.dart';
import '../utils/auth_debug_logger.dart';

class VerifyOtpScreen extends StatefulWidget {
  final String phone;

  const VerifyOtpScreen({super.key, required this.phone});

  @override
  State<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends State<VerifyOtpScreen> {
  static const int _otpLength = 6;
  static const int _resendDuration = 60;

  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;
  Timer? _timer;
  int _secondsRemaining = _resendDuration;
  bool _isSubmitting = false;
  bool _isApplyingCode = false;

  String get _code => _controllers.map((controller) => controller.text).join();
  bool get _isComplete => _code.length == _otpLength;
  bool get _canResend => _secondsRemaining == 0;
  String get _phone => widget.phone.isEmpty ? '+225 XXXXXXXX' : widget.phone;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(_otpLength, (_) => TextEditingController());
    _focusNodes = List.generate(_otpLength, (_) => FocusNode());
    _startCountdown();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNodes.first.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _secondsRemaining = _resendDuration);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining <= 1) {
        timer.cancel();
        if (mounted) {
          setState(() => _secondsRemaining = 0);
        }
        return;
      }

      if (mounted) {
        setState(() => _secondsRemaining--);
      }
    });
  }

  void _applyOtpCode(String rawValue, {int startIndex = 0}) {
    final digits = rawValue.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return;

    _isApplyingCode = true;
    for (var offset = 0; offset < digits.length; offset += 1) {
      final targetIndex = startIndex + offset;
      if (targetIndex >= _otpLength) break;
      final controller = _controllers[targetIndex];
      controller.text = digits[offset];
      controller.selection = TextSelection.collapsed(
        offset: controller.text.length,
      );
    }
    _isApplyingCode = false;

    final nextEmptyIndex = _controllers.indexWhere(
      (controller) => controller.text.isEmpty,
    );
    if (nextEmptyIndex == -1) {
      FocusScope.of(context).unfocus();
    } else {
      _focusNodes[nextEmptyIndex].requestFocus();
    }

    setState(() {});
    if (_isComplete) {
      Future.microtask(_submit);
    }
  }

  void _handleDigitChanged(String value, int index) {
    if (_isApplyingCode) return;

    if (value.length > 1) {
      _applyOtpCode(value, startIndex: index);
      return;
    }

    if (value.isNotEmpty && index < _otpLength - 1) {
      _focusNodes[index + 1].requestFocus();
    }

    if (_isComplete) {
      _submit();
      return;
    }

    setState(() {});
  }

  KeyEventResult _handleBackspace(KeyEvent event, int index) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.backspace ||
        _controllers[index].text.isNotEmpty ||
        index == 0) {
      return KeyEventResult.ignored;
    }

    _focusNodes[index - 1].requestFocus();
    _controllers[index - 1].clear();
    setState(() {});
    return KeyEventResult.handled;
  }

  Future<void> _submit() async {
    if (!_isComplete || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      final payload = {
        'phone': _phone,
        'token': _code,
        'type': OtpType.sms.name,
      };
      authLogPayload('verifyOTP', payload);

      final response = await Supabase.instance.client.auth.verifyOTP(
        phone: _phone,
        token: _code,
        type: OtpType.sms,
      );
      authLogResponse('verifyOTP', {
        'userId': response.user?.id,
        'phone': response.user?.phone,
        'hasSession': response.session != null,
        'accessToken': response.session?.accessToken != null
            ? '[present]'
            : null,
        'refreshToken': response.session?.refreshToken != null
            ? '[present]'
            : null,
      });

      final user = response.user ?? Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw const AuthException(
          'Utilisateur introuvable après vérification.',
        );
      }
      authLogResponse('user', {
        'id': user.id,
        'phone': user.phone,
        'email': user.email,
        'role': user.role,
        'createdAt': user.createdAt,
        'lastSignInAt': user.lastSignInAt,
        'metadata': user.userMetadata,
      });

      final nextRoute = await ensureUserProfileAndResolveRoute(
        user,
        phone: user.phone ?? _phone,
      );

      if (!mounted) return;
      context.go(nextRoute);
    } on AuthException catch (error) {
      authLogError('verifyOTP', {
        'message': error.message,
        'statusCode': error.statusCode,
        'code': error.code,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error, stackTrace) {
      authLogError('verifyOTP', error, stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de vérifier le code. Réessaie.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _resendCode() async {
    if (!_canResend) return;

    try {
      final payload = {'phone': _phone};
      authLogPayload('resendOtp', payload);

      await Supabase.instance.client.auth.signInWithOtp(phone: _phone);
      authLogResponse('resendOtp', {'success': true});

      for (final controller in _controllers) {
        controller.clear();
      }
      _focusNodes.first.requestFocus();
      _startCountdown();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nouveau code envoyé au $_phone.')),
      );
    } on AuthException catch (error) {
      authLogError('resendOtp', {
        'message': error.message,
        'statusCode': error.statusCode,
        'code': error.code,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error, stackTrace) {
      authLogError('resendOtp', error, stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur réseau. Vérifie ta connexion et réessaie.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => context.go('/login'),
                  icon: const Icon(Icons.arrow_back_rounded),
                  color: AppColors.textPrimary,
                  tooltip: 'Changer de numéro',
                ),
              ),
              const Spacer(),
              Text('Code de vérification', style: AppTextStyles.h1),
              const SizedBox(height: 10),
              Text(
                'Un code a été envoyé au $_phone',
                style: AppTextStyles.bodySecondary,
              ),
              const SizedBox(height: 34),
              AutofillGroup(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                    _otpLength,
                    (index) => _OtpDigitField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      enableAutofill: index == 0,
                      maxLength: index == 0 ? _otpLength : 1,
                      onChanged: (value) => _handleDigitChanged(value, index),
                      onKeyEvent: (event) => _handleBackspace(event, index),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              AppButton(
                text: 'Vérifier',
                isLoading: _isSubmitting,
                onPressed: _isComplete && !_isSubmitting ? _submit : null,
              ),
              const SizedBox(height: 22),
              TextButton(
                onPressed: _canResend ? _resendCode : null,
                child: Text(
                  _canResend
                      ? 'Renvoyer le code'
                      : 'Renvoyer le code dans ${_secondsRemaining}s',
                  style: AppTextStyles.button.copyWith(
                    color: _canResend
                        ? AppColors.primaryLight
                        : AppColors.textHint,
                  ),
                ),
              ),
              const Spacer(flex: 2),
              AppButton(
                text: 'Changer de numéro',
                icon: Icons.arrow_back_rounded,
                isOutlined: true,
                onPressed: () => context.go('/login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OtpDigitField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enableAutofill;
  final int maxLength;
  final ValueChanged<String> onChanged;
  final KeyEventResult Function(KeyEvent event) onKeyEvent;

  const _OtpDigitField({
    required this.controller,
    required this.focusNode,
    required this.enableAutofill,
    required this.maxLength,
    required this.onChanged,
    required this.onKeyEvent,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 58,
      child: Focus(
        onKeyEvent: (node, event) => onKeyEvent(event),
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          autofillHints: enableAutofill
              ? const [AutofillHints.oneTimeCode]
              : null,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(maxLength),
          ],
          style: AppTextStyles.h2,
          cursorColor: AppColors.primaryLight,
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: AppColors.surfaceElevated,
            contentPadding: EdgeInsets.zero,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.surfaceBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: AppColors.primaryLight,
                width: 1.6,
              ),
            ),
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
