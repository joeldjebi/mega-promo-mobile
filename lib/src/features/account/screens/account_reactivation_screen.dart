import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mega_promo/core/theme/app_colors.dart';
import 'package:mega_promo/core/theme/app_text_styles.dart';
import 'package:mega_promo/core/widgets/app_button.dart';
import 'package:mega_promo/core/widgets/app_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/app_telemetry_service.dart';

class AccountReactivationScreen extends StatefulWidget {
  const AccountReactivationScreen({super.key});

  @override
  State<AccountReactivationScreen> createState() =>
      _AccountReactivationScreenState();
}

class _AccountReactivationScreenState extends State<AccountReactivationScreen> {
  bool _isReactivating = false;
  bool _isSigningOut = false;
  DateTime? _scheduledAt;

  @override
  void initState() {
    super.initState();
    unawaited(_loadDeletionInfo());
  }

  Future<void> _loadDeletionInfo() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final profile = await Supabase.instance.client
          .from('users')
          .select('deletion_scheduled_at')
          .eq('id', user.id)
          .maybeSingle();
      final scheduledAt = DateTime.tryParse(
        profile?['deletion_scheduled_at'] as String? ?? '',
      );
      if (mounted) setState(() => _scheduledAt = scheduledAt);
    } catch (_) {
      // The date is helpful but not required to let the user decide.
    }
  }

  Future<void> _reactivate() async {
    if (_isReactivating) return;
    setState(() => _isReactivating = true);

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) {
      if (mounted) context.go('/login');
      return;
    }

    try {
      await supabase
          .from('users')
          .update({
            'is_active': true,
            'account_status': 'active',
            'deletion_requested_at': null,
            'deletion_scheduled_at': null,
            'deleted_at': null,
          })
          .eq('id', user.id);

      if (!mounted) return;
      context.go('/home');
    } catch (error, stackTrace) {
      unawaited(
        AppTelemetryService.recordError(
          error,
          stackTrace,
          reason: 'account_reactivation_failed',
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de réactiver le compte pour le moment.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isReactivating = false);
    }
  }

  Future<void> _continueDeletion() async {
    if (_isSigningOut) return;
    setState(() => _isSigningOut = true);

    await Supabase.instance.client.auth.signOut();
    if (mounted) context.go('/login');
  }

  String get _scheduledLabel {
    final scheduledAt = _scheduledAt;
    if (scheduledAt == null) return 'dans 30 jours';
    return 'le ${scheduledAt.day.toString().padLeft(2, '0')}/'
        '${scheduledAt.month.toString().padLeft(2, '0')}/'
        '${scheduledAt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
          child: Column(
            children: [
              const Spacer(),
              AppCard(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                borderRadius: 24,
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.goldSoft,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Icon(
                        Icons.manage_history_rounded,
                        color: AppColors.gold,
                        size: 34,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Compte en cours de suppression',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.h2,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Tu as demandé la fermeture de ce compte. Sa suppression définitive est prévue $_scheduledLabel.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySecondary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Si tu annules la fermeture maintenant, tu récupères tes points, badges, participations et récompenses.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 20),
                    AppButton(
                      text: 'Annuler la fermeture',
                      isLoading: _isReactivating,
                      onPressed: _isSigningOut ? null : _reactivate,
                    ),
                    const SizedBox(height: 10),
                    AppButton(
                      text: 'Continuer la suppression',
                      isGhost: true,
                      color: AppColors.accentRed,
                      isLoading: _isSigningOut,
                      onPressed: _isReactivating ? null : _continueDeletion,
                    ),
                  ],
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
