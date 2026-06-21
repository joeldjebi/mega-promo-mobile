import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mega_promo/core/theme/app_colors.dart';
import 'package:mega_promo/core/theme/app_text_styles.dart';
import 'package:mega_promo/core/widgets/app_button.dart';
import 'package:mega_promo/src/shared/widgets/promo_watermark_background.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../home/providers/home_bootstrap_provider.dart';
import '../../home/providers/user_profile_provider.dart';
import '../providers/onboarding_provider.dart';
import '../utils/auth_debug_logger.dart';

class OnboardingUsernameScreen extends ConsumerStatefulWidget {
  const OnboardingUsernameScreen({super.key});

  @override
  ConsumerState<OnboardingUsernameScreen> createState() =>
      _OnboardingUsernameScreenState();
}

class _OnboardingUsernameScreenState
    extends ConsumerState<OnboardingUsernameScreen> {
  final TextEditingController _usernameController = TextEditingController();
  Timer? _debounce;
  bool _isChecking = false;
  String? _errorText;
  bool _isAvailable = false;

  static final RegExp _usernameRegex = RegExp(r'^[a-zA-Z0-9_]{3,20}$');

  @override
  void dispose() {
    _debounce?.cancel();
    _usernameController.dispose();
    super.dispose();
  }

  void _onUsernameChanged(String value) {
    _debounce?.cancel();
    final username = value.trim();

    setState(() {
      _isAvailable = false;
      _errorText = null;
    });

    if (username.isEmpty) return;

    if (!_usernameRegex.hasMatch(username)) {
      setState(() {
        _errorText = '3-20 caractères, lettres, chiffres ou underscore.';
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 500), () {
      _checkAvailability(username);
    });
  }

  Future<void> _checkAvailability(String username) async {
    setState(() => _isChecking = true);

    try {
      authLogPayload('onboardingUsernameCheck', {'username': username});
      final isAvailable = await Supabase.instance.client.rpc<bool>(
        'is_username_available',
        params: {'p_username': username},
      );
      authLogResponse('onboardingUsernameCheck', {
        'username': username,
        'isAvailable': isAvailable,
      });

      if (!mounted) return;
      setState(() {
        _isAvailable = isAvailable;
        _errorText = isAvailable ? null : 'Ce pseudo est déjà pris.';
      });
    } catch (error, stackTrace) {
      authLogError('onboardingUsernameCheck', error, stackTrace);
      if (!mounted) return;
      setState(() {
        _isAvailable = false;
        _errorText = 'Impossible de vérifier ce pseudo.';
      });
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  void _continue() {
    final username = _usernameController.text.trim();
    ref.read(onboardingUsernameProvider.notifier).state = username;
    context.go('/onboarding/avatar');
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _isAvailable
        ? AppColors.accentGreen
        : _errorText != null
        ? AppColors.accentRed
        : AppColors.surfaceBorder;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            const PromoWatermarkBackground(colorful: true),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _OnboardingProgress(step: 1),
                  const SizedBox(height: 42),
                  Text('Choisis ton pseudo', style: AppTextStyles.h1),
                  const SizedBox(height: 10),
                  Text(
                    'Il sera visible par tous les joueurs',
                    style: AppTextStyles.bodySecondary,
                  ),
                  const SizedBox(height: 30),
                  TextField(
                    controller: _usernameController,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[a-zA-Z0-9_]'),
                      ),
                      LengthLimitingTextInputFormatter(20),
                    ],
                    textInputAction: TextInputAction.done,
                    style: AppTextStyles.body,
                    decoration: InputDecoration(
                      hintText: 'ex: promo_champion',
                      fillColor: Colors.white.withValues(alpha: 0.92),
                      suffixIcon: _isChecking
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : _isAvailable
                          ? const Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.accentGreen,
                            )
                          : _errorText != null
                          ? const Icon(
                              Icons.error_rounded,
                              color: AppColors.accentRed,
                            )
                          : null,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: statusColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: statusColor, width: 1.6),
                      ),
                    ),
                    onChanged: _onUsernameChanged,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _isAvailable
                        ? 'Pseudo disponible'
                        : _errorText ??
                              'Lettres, chiffres et underscore uniquement.',
                    style: AppTextStyles.bodySmall.copyWith(color: statusColor),
                  ),
                  const Spacer(),
                  AppButton(
                    text: 'Continuer',
                    onPressed: _isAvailable && !_isChecking ? _continue : null,
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

class OnboardingAvatarScreen extends ConsumerStatefulWidget {
  const OnboardingAvatarScreen({super.key});

  @override
  ConsumerState<OnboardingAvatarScreen> createState() =>
      _OnboardingAvatarScreenState();
}

class _OnboardingAvatarScreenState
    extends ConsumerState<OnboardingAvatarScreen> {
  String? _selectedAvatar;
  bool _isSaving = false;

  Future<void> _startPlaying() async {
    final username = ref.read(onboardingUsernameProvider);
    final avatarUrl = _selectedAvatar;
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (username == null || username.trim().isEmpty) {
      context.go('/onboarding');
      return;
    }

    if (avatarUrl == null || user == null) return;

    setState(() => _isSaving = true);

    try {
      final isAvailable = await supabase.rpc<bool>(
        'is_username_available',
        params: {'p_username': username, 'p_exclude_user_id': user.id},
      );
      if (!isAvailable) {
        if (!mounted) return;
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ce pseudo est déjà pris.')),
        );
        return;
      }

      final payload = {
        'id': user.id,
        if (user.phone != null && user.phone!.trim().isNotEmpty)
          'phone': user.phone,
        'username': username,
        'avatar_url': avatarUrl,
        'role': 'player',
        'is_active': true,
      };
      authLogPayload('onboardingSaveProfile', payload);

      final response = await supabase
          .from('users')
          .upsert(payload, onConflict: 'id')
          .select(
            'id, phone, username, avatar_url, role, is_active, created_at',
          )
          .single();
      authLogResponse('onboardingSaveProfile', response);

      if (!mounted) return;
      ref.invalidate(onboardingUsernameProvider);
      ref.invalidate(userProfileProvider);
      ref.invalidate(homeBootstrapProvider);
      clearHomeBootstrapCache(userId: user.id, clearStored: true);
      context.go('/home');
    } catch (error, stackTrace) {
      authLogError('onboardingSaveProfile', error, stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isUsernameConflictError(error)
                ? 'Ce pseudo est déjà pris.'
                : 'Impossible de sauvegarder ton profil.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            const PromoWatermarkBackground(colorful: true),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _OnboardingProgress(step: 2),
                  const SizedBox(height: 34),
                  Text('Choisis ton avatar', style: AppTextStyles.h1),
                  const SizedBox(height: 10),
                  Text(
                    'Sélectionne ton style pour commencer.',
                    style: AppTextStyles.bodySecondary,
                  ),
                  const SizedBox(height: 28),
                  Expanded(
                    child: GridView.builder(
                      itemCount: _avatarOptions.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 14,
                          ),
                      itemBuilder: (context, index) {
                        final avatar = _avatarOptions[index];
                        final isSelected = _selectedAvatar == avatar.id;

                        return _AvatarOption(
                          avatar: avatar,
                          isSelected: isSelected,
                          onTap: () =>
                              setState(() => _selectedAvatar = avatar.id),
                        );
                      },
                    ),
                  ),
                  AppButton(
                    text: 'Commencer',
                    isLoading: _isSaving,
                    onPressed: _selectedAvatar != null && !_isSaving
                        ? _startPlaying
                        : null,
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

bool _isUsernameConflictError(Object error) {
  if (error is! PostgrestException) return false;
  final message = error.message.toLowerCase();
  return error.code == '23505' ||
      message.contains('users_username_lower_unique_idx') ||
      message.contains('duplicate key');
}

class _OnboardingProgress extends StatelessWidget {
  final int step;

  const _OnboardingProgress({required this.step});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Étape $step/2', style: AppTextStyles.label),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: step / 2,
            minHeight: 7,
            backgroundColor: AppColors.surfaceElevated,
            valueColor: const AlwaysStoppedAnimation(AppColors.primary),
          ),
        ),
      ],
    );
  }
}

class _AvatarOptionData {
  final String id;
  final IconData icon;
  final Color color;

  const _AvatarOptionData({
    required this.id,
    required this.icon,
    required this.color,
  });
}

const List<_AvatarOptionData> _avatarOptions = [
  _AvatarOptionData(
    id: 'avatar_1',
    icon: Icons.emoji_events_rounded,
    color: AppColors.gold,
  ),
  _AvatarOptionData(
    id: 'avatar_2',
    icon: Icons.bolt_rounded,
    color: AppColors.primaryLight,
  ),
  _AvatarOptionData(
    id: 'avatar_3',
    icon: Icons.star_rounded,
    color: AppColors.accent,
  ),
  _AvatarOptionData(
    id: 'avatar_4',
    icon: Icons.workspace_premium_rounded,
    color: AppColors.accentGreen,
  ),
  _AvatarOptionData(
    id: 'avatar_5',
    icon: Icons.local_fire_department_rounded,
    color: Color(0xFFFF8A4C),
  ),
  _AvatarOptionData(
    id: 'avatar_6',
    icon: Icons.diamond_rounded,
    color: Color(0xFF38BDF8),
  ),
  _AvatarOptionData(
    id: 'avatar_7',
    icon: Icons.sports_esports_rounded,
    color: Color(0xFFF472B6),
  ),
  _AvatarOptionData(
    id: 'avatar_8',
    icon: Icons.rocket_launch_rounded,
    color: Color(0xFFA3E635),
  ),
  _AvatarOptionData(
    id: 'avatar_9',
    icon: Icons.campaign_rounded,
    color: Color(0xFFFACC15),
  ),
  _AvatarOptionData(
    id: 'avatar_10',
    icon: Icons.shield_rounded,
    color: Color(0xFF60A5FA),
  ),
  _AvatarOptionData(
    id: 'avatar_11',
    icon: Icons.favorite_rounded,
    color: Color(0xFFFB7185),
  ),
  _AvatarOptionData(
    id: 'avatar_12',
    icon: Icons.auto_awesome_rounded,
    color: Color(0xFFC084FC),
  ),
];

class _AvatarOption extends StatelessWidget {
  final _AvatarOptionData avatar;
  final bool isSelected;
  final VoidCallback onTap;

  const _AvatarOption({
    required this.avatar,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: avatar.color.withValues(alpha: 0.18),
              border: Border.all(
                color: isSelected ? AppColors.primaryLight : Colors.transparent,
                width: 2,
              ),
            ),
            child: Center(
              child: Icon(avatar.icon, color: avatar.color, size: 30),
            ),
          ),
          if (isSelected)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: AppColors.textPrimary,
                  size: 16,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
