import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mega_promo/core/theme/app_colors.dart';
import 'package:mega_promo/core/theme/app_text_styles.dart';
import 'package:mega_promo/core/utils/currency_formatter.dart';
import 'package:mega_promo/core/widgets/app_button.dart';
import 'package:mega_promo/core/widgets/app_card.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/app_store_review_mode.dart';
import '../../../services/app_telemetry_service.dart';
import '../../settings/providers/app_feature_flags_provider.dart';
import '../providers/player_subscription_provider.dart';

const _wavePaymentBaseUrl = 'https://pay.wave.com/m/M_ci_o6-9yu9h5hhm/c/ci/';

class PlayerPlansScreen extends ConsumerWidget {
  const PlayerPlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(playerPlansProvider);
    final featureFlags = ref.watch(appFeatureFlagsProvider);
    final fromContestId = GoRouterState.of(
      context,
    ).uri.queryParameters['fromContest'];
    final plansContent = _PlansContent(
      plans: plans,
      fromContestId: fromContestId,
    );
    final isHiddenForStore = AppStoreReviewMode.hidePaidPlans;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else if (fromContestId != null && fromContestId.isNotEmpty) {
              context.go('/contests/$fromContestId');
            } else {
              context.go('/profile');
            }
          },
        ),
        title: Text(isHiddenForStore ? 'Offres' : 'Mon forfait'),
      ),
      body: SafeArea(
        child: isHiddenForStore
            ? _PlansUnavailable(fromContestId: fromContestId)
            : featureFlags.when(
                data: (flags) => flags.playerSubscriptionsEnabled
                    ? plansContent
                    : _PlansUnavailable(fromContestId: fromContestId),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => plansContent,
              ),
      ),
    );
  }
}

class _PlansContent extends ConsumerWidget {
  final AsyncValue<PlayerPlansData> plans;
  final String? fromContestId;

  const _PlansContent({required this.plans, required this.fromContestId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return plans.when(
      data: (data) => RefreshIndicator(
        onRefresh: () => ref.refresh(playerPlansProvider.future),
        child: Builder(
          builder: (context) {
            final defaultFreePlan = _defaultFreePlan(data.plans);

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              children: [
                _CurrentSubscriptionCard(
                  subscription: data.currentSubscription,
                  defaultFreePlan: defaultFreePlan,
                ),
                const SizedBox(height: 16),
                Text('Choisir un forfait', style: AppTextStyles.h2),
                const SizedBox(height: 12),
                ...data.plans.map(
                  (plan) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _PlanCard(
                      plan: plan,
                      currentSubscription: data.currentSubscription,
                      paymentMethods: data.paymentMethods,
                      onSubscribe: () => _confirmSubscription(
                        context,
                        ref,
                        plan,
                        data.paymentMethods,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.workspace_premium_rounded,
                color: AppColors.textHint,
                size: 44,
              ),
              const SizedBox(height: 14),
              Text(
                'Forfaits indisponibles',
                style: AppTextStyles.h2,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Vérifie ta connexion ou les accès Supabase.',
                style: AppTextStyles.bodySecondary,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              AppButton(
                text: 'Réessayer',
                isOutlined: true,
                onPressed: () => ref.invalidate(playerPlansProvider),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

PlayerPlan? _defaultFreePlan(List<PlayerPlan> plans) {
  for (final plan in plans) {
    if (_isFreePlan(plan)) return plan;
  }
  return null;
}

bool _isFreePlan(PlayerPlan plan) {
  final key = plan.key.trim().toLowerCase();
  return plan.price == 0 || key == 'free' || key == 'standard';
}

class _PlansUnavailable extends StatelessWidget {
  final String? fromContestId;

  const _PlansUnavailable({required this.fromContestId});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: AppCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_clock_rounded,
                color: AppColors.textHint,
                size: 42,
              ),
              const SizedBox(height: 14),
              Text(
                'Offres indisponibles',
                textAlign: TextAlign.center,
                style: AppTextStyles.h2.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                'Cette section est temporairement indisponible.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySecondary,
              ),
              const SizedBox(height: 16),
              AppButton(
                text: 'Retour',
                isOutlined: true,
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else if (fromContestId?.isNotEmpty == true) {
                    context.go('/contests/$fromContestId');
                  } else {
                    context.go('/profile');
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CurrentSubscriptionCard extends StatelessWidget {
  final PlayerSubscription? subscription;
  final PlayerPlan? defaultFreePlan;

  const _CurrentSubscriptionCard({
    required this.subscription,
    required this.defaultFreePlan,
  });

  @override
  Widget build(BuildContext context) {
    final status = subscription?.status;
    final isPending = status == 'pending';
    final title = subscription == null
        ? defaultFreePlan?.name ?? 'Forfait gratuit'
        : subscription!.planName;

    return AppCard(
      padding: const EdgeInsets.all(13),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (isPending ? AppColors.gold : AppColors.primary)
                  .withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPending
                  ? Icons.pending_actions_rounded
                  : Icons.workspace_premium_rounded,
              color: isPending ? AppColors.gold : AppColors.primary,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.h3.copyWith(fontSize: 14)),
                const SizedBox(height: 3),
                Text(
                  subscription == null
                      ? 'Actif automatiquement pour commencer à jouer.'
                      : isPending
                      ? 'En attente de validation.'
                      : 'Valide jusqu’au ${_formatDate(subscription!.expiresAt)}.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySecondary.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final PlayerPlan plan;
  final PlayerSubscription? currentSubscription;
  final List<PaymentMethodOption> paymentMethods;
  final VoidCallback onSubscribe;

  const _PlanCard({
    required this.plan,
    required this.currentSubscription,
    required this.paymentMethods,
    required this.onSubscribe,
  });

  @override
  Widget build(BuildContext context) {
    final hasActiveSubscription = currentSubscription?.status == 'active';
    final isCurrent =
        (currentSubscription?.planId == plan.id && hasActiveSubscription) ||
        (!hasActiveSubscription && _isFreePlan(plan));
    final hasPending =
        currentSubscription?.planId == plan.id &&
        currentSubscription?.status == 'pending';

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.name,
                      style: AppTextStyles.h2.copyWith(fontSize: 18),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      plan.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySecondary.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                formatCurrencyAmount(plan.price, zeroLabel: 'Gratuit'),
                style: AppTextStyles.price.copyWith(fontSize: 17),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _PlanMetric(
                icon: Icons.confirmation_number_rounded,
                label: '${plan.dailyParticipationLimit}/jour',
              ),
              _PlanMetric(
                icon: Icons.local_activity_rounded,
                label: '+${plan.bonusTickets} participation',
              ),
              _PlanMetric(
                icon: Icons.military_tech_rounded,
                label: 'x${plan.badgeMultiplier.toStringAsFixed(1)} badges',
              ),
            ],
          ),
          if (plan.benefits.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...plan.benefits
                .take(4)
                .map(
                  (benefit) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.accentGreen,
                          size: 16,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            benefit.label,
                            style: AppTextStyles.bodySecondary.copyWith(
                              color: AppColors.textPrimary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
          const SizedBox(height: 10),
          AppButton(
            text: isCurrent
                ? 'Forfait actif'
                : hasPending
                ? 'En attente'
                : plan.price == 0
                ? 'Activer'
                : 'Souscrire',
            icon: isCurrent
                ? Icons.check_rounded
                : hasPending
                ? Icons.pending_rounded
                : Icons.workspace_premium_rounded,
            isOutlined: isCurrent || hasPending,
            height: 48,
            onPressed: isCurrent || hasPending ? null : onSubscribe,
          ),
        ],
      ),
    );
  }
}

class _PlanMetric extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PlanMetric({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.primary, size: 15),
          const SizedBox(width: 5),
          Text(label, style: AppTextStyles.bodySmall.copyWith(fontSize: 10.5)),
        ],
      ),
    );
  }
}

Future<void> _confirmSubscription(
  BuildContext context,
  WidgetRef ref,
  PlayerPlan plan,
  List<PaymentMethodOption> paymentMethods,
) async {
  final result = await showModalBottomSheet<Object?>(
    context: context,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return _SubscriptionConfirmationSheet(
        plan: plan,
        paymentMethods: paymentMethods,
      );
    },
  );

  if (!context.mounted) return;
  if (result == null) return;

  final selectedPaymentMethod = result is PaymentMethodOption ? result : null;
  if (plan.price > 0 && selectedPaymentMethod == null) return;

  try {
    await subscribeToPlayerPlan(ref, plan, selectedPaymentMethod);
    if (!context.mounted) return;

    var paymentLinkOpened = true;
    if (plan.price > 0 && selectedPaymentMethod != null) {
      paymentLinkOpened = await _openPayment(selectedPaymentMethod, plan.price);
      if (!context.mounted) return;
    }

    final proofPhone = selectedPaymentMethod?.proofPhone;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          plan.price == 0
              ? 'Forfait activé.'
              : paymentLinkOpened
              ? 'Validation en attente. Envoie la preuve${proofPhone?.isNotEmpty == true ? ' au $proofPhone' : ''}.'
              : 'Souscription créée, mais le lien de validation ne s’est pas ouvert.',
        ),
      ),
    );
  } catch (error, stackTrace) {
    await AppTelemetryService.recordError(
      error,
      stackTrace,
      reason: 'player_subscription_failed',
      context: {'plan_id': plan.id, 'plan_key': plan.key, 'price': plan.price},
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppTelemetryService.userMessageForError(
            error,
            fallback: 'Souscription impossible pour le moment. Réessaie.',
          ),
        ),
      ),
    );
  }
}

class _SubscriptionConfirmationSheet extends StatefulWidget {
  final PlayerPlan plan;
  final List<PaymentMethodOption> paymentMethods;

  const _SubscriptionConfirmationSheet({
    required this.plan,
    required this.paymentMethods,
  });

  @override
  State<_SubscriptionConfirmationSheet> createState() =>
      _SubscriptionConfirmationSheetState();
}

class _SubscriptionConfirmationSheetState
    extends State<_SubscriptionConfirmationSheet> {
  PaymentMethodOption? _selectedMethod;

  @override
  void initState() {
    super.initState();
    _selectedMethod = widget.paymentMethods.isEmpty
        ? null
        : widget.paymentMethods.first;
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final selectedMethod = _selectedMethod;

    if (plan.price == 0) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SheetHandle(),
              const SizedBox(height: 16),
              Text(
                'Activer ${plan.name}',
                style: AppTextStyles.h2.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                'Ce forfait gratuit sera activé immédiatement.',
                style: AppTextStyles.bodySecondary.copyWith(fontSize: 12),
              ),
              const SizedBox(height: 16),
              AppButton(
                text: 'Activer',
                icon: Icons.check_rounded,
                height: 50,
                onPressed: () => Navigator.of(context).pop(true),
              ),
              const SizedBox(height: 8),
              AppButton(
                text: 'Annuler',
                isGhost: true,
                height: 44,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      );
    }

    if (widget.paymentMethods.isEmpty) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _SheetHandle(),
              const SizedBox(height: 16),
              const Icon(
                Icons.payment_rounded,
                color: AppColors.textHint,
                size: 36,
              ),
              const SizedBox(height: 12),
              Text(
                'Validation indisponible',
                style: AppTextStyles.h2.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                'Aucun opérateur actif pour le moment.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySecondary.copyWith(fontSize: 12),
              ),
              const SizedBox(height: 16),
              AppButton(
                text: 'Fermer',
                isOutlined: true,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return ConstrainedBox(
            constraints: BoxConstraints(maxHeight: constraints.maxHeight),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SheetHandle(),
                  const SizedBox(height: 16),
                  Text(
                    'Choisir un opérateur',
                    style: AppTextStyles.h2.copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sélectionne comment valider ${plan.name}. Ensuite, envoie la preuve pour validation.',
                    style: AppTextStyles.bodySecondary.copyWith(fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  ...widget.paymentMethods.map(
                    (method) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _PaymentMethodTile(
                        method: method,
                        isSelected: selectedMethod?.id == method.id,
                        onTap: () => setState(() => _selectedMethod = method),
                      ),
                    ),
                  ),
                  if (selectedMethod != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.surfaceBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _PaymentStep(
                            icon: Icons.info_outline_rounded,
                            text: selectedMethod.instructions.isEmpty
                                ? 'Continue avec ${selectedMethod.name}, puis envoie la preuve.'
                                : selectedMethod.instructions,
                          ),
                          if (selectedMethod.proofPhone.isNotEmpty) ...[
                            const SizedBox(height: 7),
                            _PaymentStep(
                              icon: Icons.send_rounded,
                              text:
                                  'Preuve à envoyer au ${selectedMethod.proofPhone}.',
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  AppButton(
                    text: selectedMethod == null
                        ? 'Choisis un opérateur'
                        : 'Continuer avec ${selectedMethod.name}',
                    icon: Icons.check_rounded,
                    height: 50,
                    onPressed: selectedMethod == null
                        ? null
                        : () => Navigator.of(context).pop(selectedMethod),
                  ),
                  const SizedBox(height: 8),
                  AppButton(
                    text: 'Annuler',
                    isGhost: true,
                    height: 44,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 42,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.surfaceBorder,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _PaymentMethodTile extends StatelessWidget {
  final PaymentMethodOption method;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaymentMethodTile({
    required this.method,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.10)
              : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.surfaceBorder,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: isSelected ? AppColors.primary : AppColors.textHint,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    method.name,
                    style: AppTextStyles.h3.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    method.country,
                    style: AppTextStyles.bodySmall.copyWith(fontSize: 10.5),
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

class _PaymentStep extends StatelessWidget {
  final IconData icon;
  final String text;

  const _PaymentStep({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary, size: 17),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

Future<bool> _openPayment(PaymentMethodOption method, int amount) async {
  final baseUrl = method.paymentUrl.isNotEmpty
      ? method.paymentUrl
      : _wavePaymentBaseUrl;
  final uri = Uri.parse(baseUrl).replace(
    queryParameters: {
      ...Uri.parse(baseUrl).queryParameters,
      'amount': '$amount',
    },
  );
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}
