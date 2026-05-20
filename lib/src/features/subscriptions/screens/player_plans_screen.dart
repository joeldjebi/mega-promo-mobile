import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mega_promo/core/theme/app_colors.dart';
import 'package:mega_promo/core/theme/app_text_styles.dart';
import 'package:mega_promo/core/widgets/app_button.dart';
import 'package:mega_promo/core/widgets/app_card.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/player_subscription_provider.dart';

const _paymentProofPhone = '+225 0758754662';
const _wavePaymentBaseUrl =
    'https://pay.wave.com/m/M_ci_o6-9yu9h5hhm/c/ci/';

class PlayerPlansScreen extends ConsumerWidget {
  const PlayerPlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(playerPlansProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/profile');
            }
          },
        ),
        title: const Text('Mon forfait'),
      ),
      body: SafeArea(
        child: data.when(
          data: (data) => RefreshIndicator(
            onRefresh: () => ref.refresh(playerPlansProvider.future),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              children: [
                _CurrentSubscriptionCard(
                  subscription: data.currentSubscription,
                ),
                const SizedBox(height: 20),
                const _OfflinePaymentInfoCard(),
                const SizedBox(height: 20),
                Text('Choisir un forfait', style: AppTextStyles.h2),
                const SizedBox(height: 12),
                ...data.plans.map(
                  (plan) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _PlanCard(
                      plan: plan,
                      currentSubscription: data.currentSubscription,
                      onSubscribe: () => _confirmSubscription(
                        context,
                        ref,
                        plan,
                      ),
                    ),
                  ),
                ),
              ],
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
        ),
      ),
    );
  }
}

class _OfflinePaymentInfoCard extends StatelessWidget {
  const _OfflinePaymentInfoCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              color: AppColors.primary,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Paiement hors système', style: AppTextStyles.h3),
                const SizedBox(height: 5),
                Text(
                  'Veuillez payer 3virgules avec Wave. Après paiement, envoie la preuve au $_paymentProofPhone. MegaPromo vérifiera puis le Super Admin activera ton forfait.',
                  style: AppTextStyles.bodySecondary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentSubscriptionCard extends StatelessWidget {
  final PlayerSubscription? subscription;

  const _CurrentSubscriptionCard({required this.subscription});

  @override
  Widget build(BuildContext context) {
    final status = subscription?.status;
    final isPending = status == 'pending';
    final title = subscription == null
        ? 'Aucun forfait actif'
        : subscription!.planName;

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
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
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.h3),
                const SizedBox(height: 4),
                Text(
                  subscription == null
                      ? 'Sélectionne un forfait pour obtenir plus d’avantages.'
                      : isPending
                      ? 'En attente : paie avec Wave puis envoie la preuve au $_paymentProofPhone.'
                      : 'Valide jusqu’au ${_formatDate(subscription!.expiresAt)}.',
                  style: AppTextStyles.bodySecondary,
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
  final VoidCallback onSubscribe;

  const _PlanCard({
    required this.plan,
    required this.currentSubscription,
    required this.onSubscribe,
  });

  @override
  Widget build(BuildContext context) {
    final isCurrent =
        currentSubscription?.planId == plan.id &&
        currentSubscription?.status == 'active';
    final hasPending =
        currentSubscription?.planId == plan.id &&
        currentSubscription?.status == 'pending';

    return AppCard(
      padding: const EdgeInsets.all(18),
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
                    Text(plan.name, style: AppTextStyles.h2),
                    const SizedBox(height: 5),
                    Text(plan.description, style: AppTextStyles.bodySecondary),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                plan.price == 0 ? 'Gratuit' : '${plan.price} FCFA',
                style: AppTextStyles.price,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _PlanMetric(
                icon: Icons.confirmation_number_rounded,
                label: '${plan.dailyParticipationLimit}/jour',
              ),
              _PlanMetric(
                icon: Icons.local_activity_rounded,
                label: '+${plan.bonusTickets} ticket',
              ),
              _PlanMetric(
                icon: Icons.military_tech_rounded,
                label: 'x${plan.badgeMultiplier.toStringAsFixed(1)} badges',
              ),
            ],
          ),
          if (plan.benefits.isNotEmpty) ...[
            const SizedBox(height: 16),
            ...plan.benefits.take(4).map(
                  (benefit) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.accentGreen,
                          size: 18,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            benefit.label,
                            style: AppTextStyles.bodySecondary.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
          const SizedBox(height: 16),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.primary, size: 15),
          const SizedBox(width: 6),
          Text(label, style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}

Future<void> _confirmSubscription(
  BuildContext context,
  WidgetRef ref,
  PlayerPlan plan,
) async {
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceBorder,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text('Confirmer la souscription', style: AppTextStyles.h2),
              const SizedBox(height: 8),
              Text(
                plan.price == 0
                    ? 'Activer le forfait ${plan.name}.'
                    : 'Tu vas créer une demande de souscription au forfait ${plan.name}. Ensuite, le lien Wave de 3virgules va s’ouvrir pour payer ${plan.price} FCFA. Après paiement, envoie la preuve au $_paymentProofPhone. Le Super Admin validera ton abonnement après vérification.',
                style: AppTextStyles.bodySecondary,
              ),
              if (plan.price > 0) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.surfaceBorder),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PaymentStep(
                        icon: Icons.open_in_new_rounded,
                        text:
                            'Clique sur Confirmer pour payer 3virgules avec Wave.',
                      ),
                      SizedBox(height: 8),
                      _PaymentStep(
                        icon: Icons.receipt_long_rounded,
                        text: 'Fais une capture ou garde le reçu de paiement.',
                      ),
                      SizedBox(height: 8),
                      _PaymentStep(
                        icon: Icons.send_rounded,
                        text:
                            'Envoie la preuve au $_paymentProofPhone pour validation.',
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              AppButton(
                text: plan.price == 0 ? 'Activer' : 'Confirmer et payer',
                icon: Icons.check_rounded,
                onPressed: () => Navigator.of(context).pop(true),
              ),
              const SizedBox(height: 10),
              AppButton(
                text: 'Annuler',
                isGhost: true,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ],
          ),
        ),
      );
    },
  );

  if (confirmed != true || !context.mounted) return;

  try {
    await subscribeToPlayerPlan(ref, plan);
    if (!context.mounted) return;

    var paymentLinkOpened = true;
    if (plan.price > 0) {
      paymentLinkOpened = await _openWavePayment(plan.price);
      if (!context.mounted) return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          plan.price == 0
              ? 'Forfait activé.'
              : paymentLinkOpened
              ? 'Paiement en attente. Envoie la preuve au $_paymentProofPhone.'
              : 'Souscription créée, mais le lien Wave ne s’est pas ouvert.',
        ),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Souscription impossible : $error')),
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

Future<bool> _openWavePayment(int amount) async {
  final uri = Uri.parse('$_wavePaymentBaseUrl?amount=$amount');
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}
