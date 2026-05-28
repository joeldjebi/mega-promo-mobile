import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mega_promo/core/theme/app_colors.dart';
import 'package:mega_promo/core/theme/app_text_styles.dart';
import 'package:mega_promo/core/widgets/app_button.dart';
import 'package:mega_promo/core/widgets/app_card.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/app_telemetry_service.dart';
import '../../home/providers/home_bootstrap_provider.dart';
import '../../home/providers/user_profile_provider.dart';
import '../../home/screens/home_screen.dart';
import '../../settings/providers/app_feature_flags_provider.dart';
import '../providers/player_payment_methods_provider.dart';
import '../providers/profile_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  ProfileData? _lastProfileData;

  @override
  Widget build(BuildContext context) {
    final watchedProfile = ref.watch(profileDataProvider);
    final latestProfile = watchedProfile.asData?.value;
    if (latestProfile != null) _lastProfileData = latestProfile;
    final profile = _lastProfileData == null
        ? watchedProfile
        : AsyncData(_lastProfileData!);
    final featureFlags = ref.watch(appFeatureFlagsProvider).maybeWhen(
          data: (flags) => flags,
          orElse: () => AppFeatureFlags.defaults,
        );

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F9),
      body: SafeArea(
        child: profile.when(
          data: (data) => _CompactProfilePage(
            data: data,
            showPlansAction: featureFlags.playerSubscriptionsEnabled,
            onEdit: () => _showEditProfileSheet(context, ref, data),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Profil indisponible',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactProfilePage extends StatelessWidget {
  final ProfileData data;
  final bool showPlansAction;
  final VoidCallback onEdit;

  const _CompactProfilePage({
    required this.data,
    required this.showPlansAction,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxHeight < 700;
        final horizontalPadding = 18.0;
        final topPadding = isCompact ? 12.0 : 18.0;
        const bottomPadding = 12.0;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            topPadding,
            horizontalPadding,
            bottomPadding,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - topPadding - bottomPadding,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _CompactProfileHeader(
                  data: data,
                  isCompact: isCompact,
                  onEdit: onEdit,
                ),
                SizedBox(height: isCompact ? 12 : 16),
                _ProfileStatsStrip(data: data, isCompact: isCompact),
                SizedBox(height: isCompact ? 10 : 14),
                SizedBox(
                  height: isCompact ? 278 : 318,
                  child: _ProfileActionPanel(
                    data: data,
                    showPlansAction: showPlansAction,
                    isCompact: isCompact,
                    onEdit: onEdit,
                  ),
                ),
                SizedBox(height: isCompact ? 8 : 10),
                SizedBox(
                  width: double.infinity,
                  height: isCompact ? 42 : 46,
                  child: TextButton.icon(
                    onPressed: () async {
                      await Supabase.instance.client.auth.signOut();
                      if (context.mounted) context.go('/login');
                    },
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text('Se déconnecter'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.accentRed,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: isCompact ? 10 : 12),
                _ProfileFooter(isCompact: isCompact),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProfileFooter extends StatelessWidget {
  final bool isCompact;

  const _ProfileFooter({required this.isCompact});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final packageInfo = snapshot.data;
        final version = packageInfo == null
            ? 'Version indisponible'
            : 'Version ${packageInfo.version} (build ${packageInfo.buildNumber})';

        return Column(
          children: [
            Text(
              version,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textHint,
                fontSize: isCompact ? 10 : 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 4,
              children: [
                _FooterLink(
                  label: 'Conditions Générales',
                  onTap: () => context.push('/legal/terms'),
                ),
                Text(
                  '|',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textHint.withValues(alpha: 0.62),
                  ),
                ),
                _FooterLink(
                  label: 'Politique de Confidentialité',
                  onTap: () => context.push('/legal/privacy'),
                ),
              ],
            ),
            InkWell(
              onTap: () => _confirmCloseAccount(context),
              borderRadius: BorderRadius.circular(999),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                child: Text(
                  'Fermer mon compte MegaPromo',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textHint,
                    fontSize: isCompact ? 11 : 13,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.textHint,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FooterLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _FooterLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textHint,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

Future<void> _confirmCloseAccount(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Fermer mon compte ?'),
      content: const Text(
        'Ton compte sera fermé maintenant et sa suppression définitive sera programmée dans 30 jours. Si tu reviens avant ce délai, tu pourras annuler la fermeture et récupérer ton historique.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: TextButton.styleFrom(foregroundColor: AppColors.accentRed),
          child: const Text('Fermer mon compte'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;
  if (user == null) return;

  try {
    final now = DateTime.now();
    await supabase
        .from('users')
        .update({
          'is_active': false,
          'account_status': 'pending_deletion',
          'deletion_requested_at': now.toIso8601String(),
          'deletion_scheduled_at': now
              .add(const Duration(days: 30))
              .toIso8601String(),
          'deleted_at': null,
        })
        .eq('id', user.id);
    await supabase.auth.signOut();
    if (context.mounted) context.go('/login');
  } catch (error, stackTrace) {
    await AppTelemetryService.recordError(
      error,
      stackTrace,
      reason: 'close_account_failed',
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Impossible de fermer le compte pour le moment.'),
      ),
    );
  }
}

class _CompactProfileHeader extends StatelessWidget {
  final ProfileData data;
  final bool isCompact;
  final VoidCallback onEdit;

  const _CompactProfileHeader({
    required this.data,
    required this.isCompact,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final avatar = avatarForId(data.user.avatarUrl);
    final avatarSize = isCompact ? 74.0 : 86.0;
    final statusLabel = data.user.isPremium ? 'Premium' : 'Standard';
    final showStatusPill =
        data.user.planName.trim().toLowerCase() != statusLabel.toLowerCase();

    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: avatarSize,
              height: avatarSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: avatar.color.withValues(alpha: 0.18),
                shape: BoxShape.circle,
                border: Border.all(
                  color: avatar.color.withValues(alpha: 0.48),
                  width: 1.2,
                ),
              ),
              child: Icon(
                avatar.icon,
                color: avatar.color,
                size: isCompact ? 34 : 40,
              ),
            ),
            Positioned(
              right: -4,
              bottom: 0,
              child: Material(
                color: Colors.white,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onEdit,
                  child: Container(
                    width: 31,
                    height: 31,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surfaceBorder),
                    ),
                    child: const Icon(
                      Icons.edit_rounded,
                      color: AppColors.textSecondary,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: isCompact ? 9 : 12),
        Text(
          data.user.username,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.h1.copyWith(
            color: AppColors.textPrimary,
            fontSize: isCompact ? 20 : 23,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          data.user.phone ?? 'Joueur MegaPromo',
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodySecondary.copyWith(
            fontSize: isCompact ? 12 : 13,
          ),
        ),
        SizedBox(height: isCompact ? 7 : 9),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _CompactPill(text: data.user.planName),
            if (showStatusPill) ...[
              const SizedBox(width: 8),
              _CompactPill(
                text: statusLabel,
                highlighted: data.user.isPremium,
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _CompactPill extends StatelessWidget {
  final String text;
  final bool highlighted;

  const _CompactPill({required this.text, this.highlighted = false});

  @override
  Widget build(BuildContext context) {
    final color = highlighted ? AppColors.gold : AppColors.primary;

    return Container(
      constraints: const BoxConstraints(maxWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.bodySmall.copyWith(
          color: highlighted ? AppColors.gold : AppColors.primary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
    );
  }
}

class _ProfileStatsStrip extends StatelessWidget {
  final ProfileData data;
  final bool isCompact;

  const _ProfileStatsStrip({required this.data, required this.isCompact});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: isCompact ? 70 : 76,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: _CompactStat(
              label: 'Points',
              value: '${data.user.pointsTotal}',
              icon: Icons.bolt_rounded,
              isCompact: isCompact,
            ),
          ),
          const _CompactDivider(),
          Expanded(
            child: _CompactStat(
              label: 'Parties',
              value: '${data.participations.length}',
              icon: Icons.confirmation_number_rounded,
              isCompact: isCompact,
            ),
          ),
          const _CompactDivider(),
          Expanded(
            child: _CompactStat(
              label: 'Récompenses',
              value: '${data.wins.length}',
              icon: Icons.card_giftcard_rounded,
              isCompact: isCompact,
            ),
          ),
          const _CompactDivider(),
          Expanded(
            child: _CompactStat(
              label: 'Badges',
              value: '${data.badges.length}',
              icon: Icons.military_tech_rounded,
              isCompact: isCompact,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool isCompact;

  const _CompactStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.isCompact,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: AppColors.primary, size: isCompact ? 15 : 17),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.h3.copyWith(
            color: AppColors.textPrimary,
            fontSize: isCompact ? 15 : 16,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textHint,
            fontSize: isCompact ? 9 : 10,
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _CompactDivider extends StatelessWidget {
  const _CompactDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 34, color: const Color(0xFFE8E9EE));
  }
}

class _ProfileActionPanel extends StatelessWidget {
  final ProfileData data;
  final bool showPlansAction;
  final bool isCompact;
  final VoidCallback onEdit;

  const _ProfileActionPanel({
    required this.data,
    required this.showPlansAction,
    required this.isCompact,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final actions = [
      if (showPlansAction)
        _ProfileAction(
          icon: Icons.workspace_premium_rounded,
          title: 'Forfait',
          subtitle:
              '${data.user.dailyParticipationLimit}/jour · +${data.user.bonusTickets} participation',
          onTap: () => context.push('/subscriptions'),
        ),
      _ProfileAction(
        icon: Icons.notifications_none_rounded,
        title: 'Notifications',
        subtitle: 'Alertes et récompenses',
        onTap: () => context.push('/notifications'),
      ),
      _ProfileAction(
        icon: Icons.history_rounded,
        title: 'Participations',
        subtitle: data.participations.isEmpty
            ? 'Aucune'
            : '${data.participations.length} récentes',
        onTap: () => _showProfileActivitySheet(
          context,
          title: 'Toutes mes participations',
          icon: Icons.history_rounded,
          loader: () => fetchProfileParticipationsPage(limit: 50),
        ),
      ),
      _ProfileAction(
        icon: Icons.card_giftcard_rounded,
        title: 'Récompenses',
        subtitle: data.wins.isEmpty ? 'Aucun' : '${data.wins.length} récents',
        onTap: () => _showProfileActivitySheet(
          context,
          title: 'Toutes mes récompenses',
          icon: Icons.card_giftcard_rounded,
          loader: () => fetchProfileWinsPage(limit: 50),
        ),
      ),
      _ProfileAction(
        icon: Icons.military_tech_outlined,
        title: 'Badges',
        subtitle: data.badges.isEmpty ? 'Aucun' : '${data.badges.length}',
        onTap: () => _showBadgesSheet(context, data.badges),
      ),
      _ProfileAction(
        icon: Icons.account_balance_wallet_rounded,
        title: 'Coordonnées',
        subtitle: 'Coordonnées',
        onTap: () => _showPaymentMethodsSheet(context),
      ),
    ];

    final actionRows = <List<_ProfileAction>>[];
    for (var index = 0; index < actions.length; index += 2) {
      actionRows.add(actions.skip(index).take(2).toList());
    }

    return Container(
      padding: EdgeInsets.all(isCompact ? 10 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        children: [
          for (var rowIndex = 0; rowIndex < actionRows.length; rowIndex++) ...[
            if (rowIndex > 0) const SizedBox(height: 10),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _ProfileActionTile(
                      action: actionRows[rowIndex][0],
                      isCompact: isCompact,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: actionRows[rowIndex].length > 1
                        ? _ProfileActionTile(
                            action: actionRows[rowIndex][1],
                            isCompact: isCompact,
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfileAction {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ProfileAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}

class _ProfileActionTile extends StatelessWidget {
  final _ProfileAction action;
  final bool isCompact;

  const _ProfileActionTile({required this.action, required this.isCompact});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF6F7FA),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: action.onTap,
        child: Padding(
          padding: EdgeInsets.all(isCompact ? 9 : 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    width: isCompact ? 30 : 34,
                    height: isCompact ? 30 : 34,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: AppColors.surfaceBorder),
                    ),
                    child: Icon(
                      action.icon,
                      color: AppColors.textSecondary,
                      size: isCompact ? 16 : 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      action.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.h3.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: isCompact ? 13 : 14,
                        fontWeight: FontWeight.w600,
                        height: 1.05,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: isCompact ? 5 : 7),
              Text(
                action.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textHint,
                  fontSize: isCompact ? 9.5 : 10,
                  height: 1.05,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _showPaymentMethodsSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _PaymentMethodsSheet(),
  );
}

class _PaymentMethodsSheet extends ConsumerWidget {
  const _PaymentMethodsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(playerPaymentProfileProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.52,
      maxChildSize: 0.92,
      builder: (context, controller) => Container(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: profile.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => const Center(
            child: Text('Impossible de charger tes coordonnées.'),
          ),
          data: (data) => ListView(
            controller: controller,
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
              Text(
                'Coordonnées de réception',
                style: AppTextStyles.h2.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Ces informations servent uniquement à remettre tes récompenses promotionnelles. MegaPromo voit le numéro choisi pour organiser la remise avec toi. Tu peux ajouter un premier numéro librement. Pour modifier un numéro ou en ajouter un deuxième, une vérification d’identité est requise.',
                style: AppTextStyles.bodySecondary,
              ),
              const SizedBox(height: 16),
              _KycStatusCard(profile: data),
              const SizedBox(height: 14),
              if (data.methods.isEmpty)
                const _EmptyPaymentMethodCard()
              else
                ...data.methods.map(
                  (method) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _PaymentMethodCard(
                      method: method,
                      onTap: () {
                        if (!data.hasApprovedKyc) {
                          _showKycRequiredSheet(context, ref, data);
                          return;
                        }
                        _showSavePaymentMethodSheet(context, method: method);
                      },
                    ),
                  ),
                ),
              if (data.methods.length < 2) ...[
                const SizedBox(height: 6),
                AppButton(
                  text: data.methods.isEmpty
                      ? 'Ajouter mon numéro de réception'
                      : 'Ajouter un deuxième numéro',
                  icon: Icons.add_card_rounded,
                  onPressed: () {
                    if (data.methods.isNotEmpty && !data.hasApprovedKyc) {
                      _showKycRequiredSheet(context, ref, data);
                      return;
                    }
                    _showSavePaymentMethodSheet(context);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _KycStatusCard extends StatelessWidget {
  final PlayerPaymentProfile profile;

  const _KycStatusCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final status = profile.latestKyc?.status;
    final rejectionReason = profile.latestKyc?.rejectionReason.trim() ?? '';
    final color = status == 'approved'
        ? AppColors.accentGreen
        : status == 'rejected'
        ? AppColors.accentRed
        : AppColors.gold;
    final label = status == 'approved'
        ? 'Identité vérifiée'
        : status == 'rejected'
        ? 'Vérification refusée'
        : status == 'pending'
        ? 'Vérification en cours'
        : 'Identité non vérifiée';

    final detail = status == 'rejected' && rejectionReason.isNotEmpty
        ? rejectionReason
        : status == 'pending'
        ? 'Ton document est en cours de contrôle. Tu pourras ajouter ou modifier un autre numéro après validation.'
        : null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_user_rounded, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (detail != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    detail,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPaymentMethodCard extends StatelessWidget {
  const _EmptyPaymentMethodCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          const Icon(
            Icons.account_balance_wallet_rounded,
            color: AppColors.gold,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Aucun numéro enregistré. Ajoute ton numéro préféré pour recevoir tes récompenses plus vite.',
              style: AppTextStyles.bodySecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  final PlayerPaymentMethod method;
  final VoidCallback onTap;

  const _PaymentMethodCard({required this.method, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AppCard(
        child: Row(
          children: [
            const Icon(Icons.phone_iphone_rounded, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(method.operatorName, style: AppTextStyles.h3),
                  Text(
                    method.isWhatsapp
                        ? '${method.phone} · WhatsApp'
                        : method.phone,
                    style: AppTextStyles.bodySecondary,
                  ),
                ],
              ),
            ),
            if (method.isPrimary)
              const _CompactPill(text: 'Principal', highlighted: true),
            const SizedBox(width: 8),
            const Icon(Icons.edit_rounded, color: AppColors.textHint, size: 18),
          ],
        ),
      ),
    );
  }
}

void _showKycRequiredSheet(
  BuildContext context,
  WidgetRef ref,
  PlayerPaymentProfile profile,
) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: _KycRequiredSheet(profile: profile),
    ),
  );
}

class _KycRequiredSheet extends ConsumerStatefulWidget {
  final PlayerPaymentProfile profile;

  const _KycRequiredSheet({required this.profile});

  @override
  ConsumerState<_KycRequiredSheet> createState() => _KycRequiredSheetState();
}

class _KycRequiredSheetState extends ConsumerState<_KycRequiredSheet> {
  final _imagePicker = ImagePicker();
  String _documentType = 'national_id';
  XFile? _frontFile;
  XFile? _backFile;
  bool _saving = false;

  bool get _requiresBackFile => _documentType == 'national_id';

  bool get _hasRequiredFiles =>
      _frontFile != null && (!_requiresBackFile || _backFile != null);

  @override
  Widget build(BuildContext context) {
    final latestIdentity = widget.profile.latestKyc;
    final latestStatus = latestIdentity?.status;
    final rejectionReason = latestIdentity?.rejectionReason.trim() ?? '';
    final canSubmit =
        latestStatus == null ||
        (latestStatus == 'rejected' && rejectionReason.isNotEmpty);
    final title = latestStatus == 'pending'
        ? 'Vérification en cours'
        : 'Vérification d’identité';
    final description = latestStatus == 'pending'
        ? 'Ton document est déjà envoyé. MegaPromo doit le valider avant que tu puisses ajouter un 2e numéro ou modifier un numéro existant.'
        : 'Pour ajouter un 2e numéro ou modifier un numéro existant, MegaPromo doit confirmer que le compte t’appartient. Cela protège tes récompenses contre les changements frauduleux.';

    final maxSheetHeight = MediaQuery.sizeOf(context).height * 0.86;

    return Container(
      constraints: BoxConstraints(maxHeight: maxSheetHeight),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Text(title, style: AppTextStyles.h2),
          const SizedBox(height: 8),
          Text(description, style: AppTextStyles.bodySecondary),
          if (latestStatus == 'rejected' && rejectionReason.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.accentRed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.accentRed.withValues(alpha: 0.18),
                ),
              ),
              child: Text(
                rejectionReason,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          if (canSubmit) ...[
            const SizedBox(height: 16),
            _NativeSelectField(
              label: 'Type de pièce',
              value: _documentType,
              options: const [
                _NativeSelectOption(
                  value: 'national_id',
                  label: 'Carte Nationale d’Identité',
                ),
                _NativeSelectOption(value: 'passport', label: 'Passport'),
                _NativeSelectOption(
                  value: 'driver_license',
                  label: 'Permis de conduire',
                ),
              ],
              enabled: !_saving,
              onChanged: (value) => setState(() {
                _documentType = value;
                if (!_requiresBackFile) _backFile = null;
              }),
            ),
            const SizedBox(height: 10),
            Text(
              _documentType == 'national_id'
                  ? 'Pièces à fournir : recto et verso de ta CNI.'
                  : 'Pièce à fournir : photo lisible du document.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textHint,
              ),
            ),
            const SizedBox(height: 12),
            _KycFilePickerTile(
              label: _documentType == 'national_id'
                  ? 'Charger le recto'
                  : 'Charger le document',
              fileName: _frontFile?.name,
              enabled: !_saving,
              onTap: () => _pickFile(isBack: false),
            ),
            if (_requiresBackFile) ...[
              const SizedBox(height: 10),
              _KycFilePickerTile(
                label: 'Charger le verso',
                fileName: _backFile?.name,
                enabled: !_saving,
                onTap: () => _pickFile(isBack: true),
              ),
            ],
            const SizedBox(height: 18),
            AppButton(
              text: _saving ? 'Envoi...' : 'Envoyer ma pièce',
              icon: Icons.verified_rounded,
              onPressed: _saving || !_hasRequiredFiles
                  ? null
                  : () async {
                      setState(() => _saving = true);
                      try {
                        final frontFile = _frontFile;
                        final backFile = _backFile;
                        if (frontFile == null) return;

                        final frontUrl = await uploadPlayerKycDocument(
                          bytes: await frontFile.readAsBytes(),
                          fileName: frontFile.name,
                          side: 'front',
                        );
                        final backUrl = _requiresBackFile && backFile != null
                            ? await uploadPlayerKycDocument(
                                bytes: await backFile.readAsBytes(),
                                fileName: backFile.name,
                                side: 'back',
                              )
                            : null;

                        await submitPlayerKycRequest(
                          documentType: _documentType,
                          documentFrontUrl: frontUrl,
                          documentBackUrl: backUrl,
                        );
                        ref.invalidate(playerPaymentProfileProvider);
                        if (context.mounted) Navigator.of(context).pop();
                      } finally {
                        if (mounted) setState(() => _saving = false);
                      }
                    },
            ),
          ] else ...[
            const SizedBox(height: 18),
            AppButton(
              text: 'Compris',
              icon: Icons.check_rounded,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickFile({required bool isBack}) async {
    final file = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 86,
      maxWidth: 2200,
    );

    if (file == null || !mounted) return;

    setState(() {
      if (isBack) {
        _backFile = file;
      } else {
        _frontFile = file;
      }
    });
  }
}

class _KycFilePickerTile extends StatelessWidget {
  final String label;
  final String? fileName;
  final bool enabled;
  final VoidCallback onTap;

  const _KycFilePickerTile({
    required this.label,
    required this.fileName,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Row(
          children: [
            Icon(
              fileName == null
                  ? Icons.upload_file_rounded
                  : Icons.check_circle_rounded,
              color: fileName == null ? AppColors.textHint : AppColors.gold,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTextStyles.body),
                  Text(
                    fileName ?? 'Photo lisible depuis ton téléphone',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textHint,
                    ),
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

void _showSavePaymentMethodSheet(
  BuildContext context, {
  PlayerPaymentMethod? method,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SavePaymentMethodSheet(method: method),
  );
}

class _SavePaymentMethodSheet extends ConsumerStatefulWidget {
  final PlayerPaymentMethod? method;

  const _SavePaymentMethodSheet({this.method});

  @override
  ConsumerState<_SavePaymentMethodSheet> createState() =>
      _SavePaymentMethodSheetState();
}

class _SavePaymentMethodSheetState
    extends ConsumerState<_SavePaymentMethodSheet> {
  final _phoneController = TextEditingController();
  String _operatorKey = fallbackPaymentOperatorOptions.first.key;
  String _countryId = fallbackPaymentCountry.id;
  bool _isWhatsapp = false;
  bool _formInitialized = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final method = widget.method;
    if (method != null) {
      _operatorKey = method.operatorKey;
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final countriesAsync = ref.watch(activePaymentCountriesProvider);
    final operatorsAsync = ref.watch(activePaymentOperatorsProvider);

    return operatorsAsync.when(
      loading: () => _PaymentSheetScaffold(
        bottomInset: MediaQuery.viewInsetsOf(context).bottom,
        child: const SizedBox(
          height: 220,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (error, stackTrace) => _buildWithOperators(
        context,
        countriesAsync,
        fallbackPaymentOperatorOptions,
      ),
      data: (operators) => _buildWithOperators(
        context,
        countriesAsync,
        operators.isEmpty ? fallbackPaymentOperatorOptions : operators,
      ),
    );
  }

  Widget _buildWithOperators(
    BuildContext context,
    AsyncValue<List<PaymentCountryOption>> countriesAsync,
    List<PaymentOperatorOption> operators,
  ) {
    return countriesAsync.when(
      loading: () => _PaymentSheetScaffold(
        bottomInset: MediaQuery.viewInsetsOf(context).bottom,
        child: const SizedBox(
          height: 220,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (error, stackTrace) =>
          _buildForm(context, operators, const [fallbackPaymentCountry]),
      data: (countries) => _buildForm(context, operators, countries),
    );
  }

  Widget _buildForm(
    BuildContext context,
    List<PaymentOperatorOption> operators,
    List<PaymentCountryOption> countries,
  ) {
    final availableOperators = operators.isEmpty
        ? fallbackPaymentOperatorOptions
        : operators;
    final availableCountries = countries.isEmpty
        ? const [fallbackPaymentCountry]
        : countries;
    _initializeForm(availableCountries, availableOperators);

    final selectedOperator = availableOperators.firstWhere(
      (operator) => operator.key == _operatorKey,
      orElse: () => availableOperators.first,
    );
    final selectedCountry = availableCountries.firstWhere(
      (country) => country.id == _countryId,
      orElse: () => availableCountries.first,
    );
    final phoneDigits = _phoneDigits;
    final hasValidPhone = phoneDigits.length == selectedCountry.phoneDigits;

    return _PaymentSheetScaffold(
      bottomInset: MediaQuery.viewInsetsOf(context).bottom,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.method == null
                ? 'Ajouter un numéro de réception'
                : 'Modifier ce numéro',
            style: AppTextStyles.h2,
          ),
          const SizedBox(height: 8),
          Text(
            'En enregistrant ce numéro, tu autorises MegaPromo à l’utiliser pour organiser la remise de tes récompenses. Vérifie bien le pays, l’indicatif et le numéro : une erreur peut retarder la remise.',
            style: AppTextStyles.bodySecondary,
          ),
          const SizedBox(height: 16),
          _NativeSelectField(
            label: 'Opérateur',
            value: _operatorKey,
            options: availableOperators
                .map(
                  (operator) => _NativeSelectOption(
                    value: operator.key,
                    label: operator.name,
                  ),
                )
                .toList(),
            enabled: !_saving,
            onChanged: (value) => setState(() => _operatorKey = value),
          ),
          const SizedBox(height: 12),
          _NativeSelectField(
            label: 'Pays / indicatif',
            value: selectedCountry.id,
            options: availableCountries
                .map(
                  (country) => _NativeSelectOption(
                    value: country.id,
                    label: country.label,
                  ),
                )
                .toList(),
            enabled: !_saving,
            onChanged: (value) {
              setState(() {
                _countryId = value;
                final nextCountry = availableCountries.firstWhere(
                  (country) => country.id == value,
                  orElse: () => availableCountries.first,
                );
                _phoneController.text = _formatPhoneDigits(
                  _phoneDigits,
                  nextCountry.phoneDigits,
                );
              });
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              _GroupedPhoneInputFormatter(
                maxDigits: selectedCountry.phoneDigits,
              ),
            ],
            decoration: InputDecoration(
              labelText: 'Numéro de réception',
              prefixText: '${selectedCountry.dialCode} ',
              hintText: _phoneHint(selectedCountry.phoneDigits),
              helperText:
                  '${selectedCountry.phoneDigits} chiffres attendus pour ${selectedCountry.name}.',
            ),
          ),
          const SizedBox(height: 10),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _isWhatsapp,
            onChanged: _saving
                ? null
                : (value) => setState(() => _isWhatsapp = value),
            title: Text(
              'Ce numéro est aussi sur WhatsApp',
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              'MegaPromo pourra l’utiliser pour te contacter si une remise nécessite une vérification.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textHint,
              ),
            ),
            activeThumbColor: AppColors.gold,
          ),
          const SizedBox(height: 18),
          AppButton(
            text: _saving ? 'Enregistrement...' : 'Enregistrer',
            icon: Icons.save_rounded,
            onPressed: _saving || !hasValidPhone
                ? null
                : () async {
                    setState(() => _saving = true);
                    try {
                      await savePlayerPaymentMethod(
                        methodId: widget.method?.id,
                        operatorKey: selectedOperator.key,
                        operatorName: selectedOperator.name,
                        phone: '${selectedCountry.dialCode}$phoneDigits',
                        isWhatsapp: _isWhatsapp,
                      );
                      ref.invalidate(playerPaymentProfileProvider);
                      if (context.mounted) Navigator.of(context).pop();
                    } finally {
                      if (mounted) setState(() => _saving = false);
                    }
                  },
          ),
        ],
      ),
    );
  }

  String get _phoneDigits =>
      _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');

  void _initializeForm(
    List<PaymentCountryOption> countries,
    List<PaymentOperatorOption> operators,
  ) {
    if (_formInitialized) return;

    if (!operators.any((operator) => operator.key == _operatorKey)) {
      _operatorKey = operators.first.key;
    }
    _isWhatsapp = widget.method?.isWhatsapp ?? false;

    final methodPhone = widget.method?.phone ?? '';
    final digits = methodPhone.replaceAll(RegExp(r'[^0-9]'), '');
    PaymentCountryOption selected = countries.first;

    for (final country in countries) {
      final dialDigits = country.dialCode.replaceAll(RegExp(r'[^0-9]'), '');
      if (dialDigits.isNotEmpty && digits.startsWith(dialDigits)) {
        selected = country;
        break;
      }
    }

    _countryId = selected.id;
    final dialDigits = selected.dialCode.replaceAll(RegExp(r'[^0-9]'), '');
    final localDigits = digits.startsWith(dialDigits)
        ? digits.substring(dialDigits.length)
        : digits;
    _phoneController.text = _formatPhoneDigits(
      localDigits,
      selected.phoneDigits,
    );
    _formInitialized = true;
  }
}

class _PaymentSheetScaffold extends StatelessWidget {
  final double bottomInset;
  final Widget child;

  const _PaymentSheetScaffold({required this.bottomInset, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: child,
      ),
    );
  }
}

String _formatPhoneDigits(String value, int maxDigits) {
  final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
  final clipped = digits.length > maxDigits
      ? digits.substring(0, maxDigits)
      : digits;
  final groups = <String>[];

  for (var index = 0; index < clipped.length; index += 2) {
    final end = (index + 2) > clipped.length ? clipped.length : index + 2;
    groups.add(clipped.substring(index, end));
  }

  return groups.join(' ');
}

String _phoneHint(int phoneDigits) {
  final sample = ''.padLeft(phoneDigits, '0');
  return _formatPhoneDigits(sample, phoneDigits);
}

class _GroupedPhoneInputFormatter extends TextInputFormatter {
  final int maxDigits;

  const _GroupedPhoneInputFormatter({required this.maxDigits});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = _formatPhoneDigits(newValue.text, maxDigits);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _NativeSelectOption {
  final String value;
  final String label;

  const _NativeSelectOption({required this.value, required this.label});
}

class _NativeSelectField extends StatelessWidget {
  final String label;
  final String value;
  final List<_NativeSelectOption> options;
  final bool enabled;
  final ValueChanged<String> onChanged;

  const _NativeSelectField({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final selected = options.firstWhere(
      (option) => option.value == value,
      orElse: () => options.first,
    );

    return InkWell(
      onTap: enabled ? () => _showPicker(context, selected) : null,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          enabled: enabled,
          suffixIcon: const Icon(Icons.expand_more_rounded),
        ),
        child: Text(
          selected.label,
          style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
        ),
      ),
    );
  }

  Future<void> _showPicker(
    BuildContext context,
    _NativeSelectOption selected,
  ) async {
    final platform = Theme.of(context).platform;
    if (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS) {
      final initialIndex = options.indexWhere(
        (option) => option.value == selected.value,
      );
      var pendingIndex = initialIndex < 0 ? 0 : initialIndex;
      await showCupertinoModalPopup<void>(
        context: context,
        builder: (popupContext) => Container(
          height: 290,
          color: CupertinoColors.systemBackground.resolveFrom(popupContext),
          child: Column(
            children: [
              SizedBox(
                height: 46,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      onPressed: () {
                        onChanged(options[pendingIndex].value);
                        Navigator.of(popupContext).pop();
                      },
                      child: const Text('OK'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoPicker(
                  itemExtent: 42,
                  scrollController: FixedExtentScrollController(
                    initialItem: pendingIndex,
                  ),
                  onSelectedItemChanged: (index) => pendingIndex = index,
                  children: options
                      .map(
                        (option) => Center(
                          child: Text(
                            option.label,
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }

    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            for (final option in options)
              ListTile(
                title: Text(option.label),
                trailing: option.value == value
                    ? const Icon(Icons.check_rounded, color: AppColors.primary)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(option.value),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (picked != null) onChanged(picked);
  }
}

class _ProfileHeader extends StatelessWidget {
  final ProfileData data;
  final VoidCallback onEdit;

  const _ProfileHeader({required this.data, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final avatar = avatarForId(data.user.avatarUrl);
    final statusLabel = data.user.isPremium ? 'Premium' : 'Standard';
    final showStatusPill =
        data.user.planName.trim().toLowerCase() != statusLabel.toLowerCase();

    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 106,
              height: 106,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: avatar.color.withValues(alpha: 0.18),
                shape: BoxShape.circle,
                border: Border.all(
                  color: avatar.color.withValues(alpha: 0.5),
                  width: 1.4,
                ),
              ),
              child: Icon(avatar.icon, color: avatar.color, size: 48),
            ),
            Positioned(
              right: -4,
              bottom: 4,
              child: Material(
                color: Colors.white,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onEdit,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surfaceBorder),
                    ),
                    child: const Icon(
                      Icons.edit_rounded,
                      color: AppColors.textSecondary,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          data.user.username,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.h1.copyWith(
            color: AppColors.textPrimary,
            fontSize: 25,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          data.user.phone ?? 'Joueur MegaPromo',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySecondary.copyWith(fontSize: 16),
        ),
        const SizedBox(height: 14),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 8,
          children: [
            _ProfileHeaderPill(text: data.user.planName),
            if (showStatusPill) _ProfileHeaderPill(text: statusLabel),
          ],
        ),
      ],
    );
  }
}

class _ProfileHeaderPill extends StatelessWidget {
  final String text;

  const _ProfileHeaderPill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.h3.copyWith(
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _ProfileMenuGroup extends StatelessWidget {
  final List<_ProfileMenuItem> children;

  const _ProfileMenuGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index != children.length - 1)
              Padding(
                padding: const EdgeInsets.only(left: 78, right: 24),
                child: Container(height: 1, color: const Color(0xFFE8E9EE)),
              ),
          ],
        ],
      ),
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailingText;
  final VoidCallback? onTap;
  final bool destructive;

  const _ProfileMenuItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailingText,
    this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = destructive
        ? AppColors.accentRed
        : AppColors.textPrimary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 17, 18, 17),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F1F4),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  icon,
                  color: destructive
                      ? AppColors.accentRed
                      : AppColors.textSecondary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.h3.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w500,
                        fontSize: 19,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailingText != null)
                Text(
                  trailingText!,
                  style: AppTextStyles.h3.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else if (onTap != null)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFC2C4CA),
                  size: 31,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isPremium;

  const _StatusBadge({required this.isPremium});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: (isPremium ? AppColors.gold : AppColors.primaryLight).withValues(
          alpha: 0.16,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: (isPremium ? AppColors.gold : AppColors.primaryLight)
              .withValues(alpha: 0.40),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPremium
                ? Icons.workspace_premium_rounded
                : Icons.verified_user_rounded,
            color: isPremium ? AppColors.gold : AppColors.primaryLight,
            size: 15,
          ),
          const SizedBox(width: 6),
          Text(
            isPremium ? 'Premium' : 'Joueur vérifié',
            style: AppTextStyles.bodySmall.copyWith(
              color: isPremium ? AppColors.gold : AppColors.primaryLight,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsPanel extends StatelessWidget {
  final ProfileData data;

  const _StatsPanel({required this.data});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      child: Row(
        children: [
          Expanded(
            child: _StatTile(
              icon: Icons.bolt_rounded,
              label: 'Points',
              value: '${data.user.pointsTotal}',
            ),
          ),
          const _Divider(),
          Expanded(
            child: _StatTile(
              icon: Icons.confirmation_number_rounded,
              label: 'Participations',
              value: '${data.participations.length}',
            ),
          ),
          const _Divider(),
          Expanded(
            child: _StatTile(
              icon: Icons.card_giftcard_rounded,
              label: 'Récompenses',
              value: '${data.wins.length}',
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primaryLight, size: 20),
        const SizedBox(height: 8),
        Text(value, style: AppTextStyles.price),
        const SizedBox(height: 3),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodySmall,
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 58, color: AppColors.surfaceBorder);
  }
}

class _BadgesSection extends StatelessWidget {
  final List<Map<String, dynamic>> badges;

  const _BadgesSection({required this.badges});

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Mes badges',
      icon: Icons.military_tech_rounded,
      child: SizedBox(
        height: 96,
        child: badges.isEmpty
            ? _EmptyInline(
                icon: Icons.military_tech_rounded,
                text: 'Aucun badge débloqué',
              )
            : ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: badges.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final badge =
                      badges[index]['badges'] as Map<String, dynamic>?;
                  return _BadgeCard(name: badge?['name'] as String? ?? 'Badge');
                },
              ),
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  final String name;

  const _BadgeCard({required this.name});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 112,
      child: AppCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.military_tech_rounded, color: AppColors.gold),
            const SizedBox(height: 8),
            Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivitySection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Map<String, dynamic>> rows;
  final String empty;
  final VoidCallback? onViewAll;

  const _ActivitySection({
    required this.title,
    required this.icon,
    required this.rows,
    required this.empty,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: title,
      icon: icon,
      trailing: rows.isEmpty || onViewAll == null
          ? null
          : TextButton(onPressed: onViewAll, child: const Text('Voir tout')),
      child: rows.isEmpty
          ? _EmptyInline(icon: icon, text: empty)
          : Column(
              children: rows.take(5).map((row) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ActivityRow(row: row, icon: icon),
                );
              }).toList(),
            ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final Map<String, dynamic> row;
  final IconData icon;

  const _ActivityRow({required this.row, required this.icon});

  @override
  Widget build(BuildContext context) {
    final contest = row['contests'] as Map<String, dynamic>?;
    final title =
        contest?['title'] as String? ??
        row['prize_description'] as String? ??
        'MegaPromo';
    final status = row['status'] as String?;
    final score = row['score'] as int?;

    return AppCard(
      padding: const EdgeInsets.all(14),
      borderRadius: 16,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primaryLight, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body,
                ),
                if (score != null || status != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    status ?? '$score points',
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  const _Section({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.primaryLight, size: 20),
            const SizedBox(width: 9),
            Expanded(child: Text(title, style: AppTextStyles.h2)),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _EmptyInline extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmptyInline({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textHint),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: AppTextStyles.bodySecondary)),
        ],
      ),
    );
  }
}

void _showProfileActivitySheet(
  BuildContext context, {
  required String title,
  required IconData icon,
  required Future<List<Map<String, dynamic>>> Function() loader,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.background,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.82,
        minChildSize: 0.45,
        maxChildSize: 0.94,
        builder: (context, scrollController) {
          return FutureBuilder<List<Map<String, dynamic>>>(
            future: loader(),
            builder: (context, snapshot) {
              final rows = snapshot.data ?? const <Map<String, dynamic>>[];

              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
                child: Column(
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
                    Row(
                      children: [
                        Icon(icon, color: AppColors.primaryLight, size: 20),
                        const SizedBox(width: 9),
                        Expanded(child: Text(title, style: AppTextStyles.h2)),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: snapshot.connectionState == ConnectionState.waiting
                          ? const Center(child: CircularProgressIndicator())
                          : rows.isEmpty
                          ? _EmptyInline(
                              icon: icon,
                              text: 'Aucune donnée à afficher',
                            )
                          : ListView.separated(
                              controller: scrollController,
                              itemCount: rows.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                return _ActivityRow(
                                  row: rows[index],
                                  icon: icon,
                                );
                              },
                            ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    },
  );
}

void _showBadgesSheet(BuildContext context, List<Map<String, dynamic>> badges) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.background,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
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
            Row(
              children: [
                const Icon(
                  Icons.military_tech_outlined,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text('Mes badges', style: AppTextStyles.h2)),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (badges.isEmpty)
              const _EmptyInline(
                icon: Icons.military_tech_outlined,
                text: 'Aucun badge débloqué',
              )
            else
              ...badges.map((row) {
                final badge = row['badges'] as Map<String, dynamic>?;
                final name = badge?['name'] as String? ?? 'Badge';
                final description = badge?['description'] as String? ?? '';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ActivityRow(
                    row: {'prize_description': name, 'status': description},
                    icon: Icons.military_tech_outlined,
                  ),
                );
              }),
          ],
        ),
      );
    },
  );
}

void _showEditProfileSheet(
  BuildContext context,
  WidgetRef ref,
  ProfileData data,
) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.background,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return _EditProfileSheet(data: data, ref: ref);
    },
  );
}

class _EditProfileSheet extends StatefulWidget {
  final ProfileData data;
  final WidgetRef ref;

  const _EditProfileSheet({required this.data, required this.ref});

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _usernameController;
  late String _selectedAvatarId;
  bool _isSaving = false;
  String? _error;

  static const _avatarIds = [
    'avatar_1',
    'avatar_2',
    'avatar_3',
    'avatar_4',
    'avatar_5',
    'avatar_6',
    'avatar_7',
    'avatar_8',
    'avatar_9',
    'avatar_10',
    'avatar_11',
    'avatar_12',
  ];

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(
      text: widget.data.user.username,
    );
    _selectedAvatarId = widget.data.user.avatarUrl ?? 'avatar_1';
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  bool _isValidUsername(String value) {
    return RegExp(r'^[A-Za-z0-9_]{3,20}$').hasMatch(value);
  }

  Future<void> _save() async {
    final username = _usernameController.text.trim();

    if (!_isValidUsername(username)) {
      setState(() {
        _error = 'Pseudo invalide : 3 à 20 caractères, lettres, chiffres ou _.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) throw StateError('Utilisateur non connecté.');

      final existing = await supabase
          .from('users')
          .select('id')
          .eq('username', username)
          .neq('id', currentUser.id)
          .maybeSingle();

      if (existing != null) {
        setState(() {
          _error = 'Ce pseudo est déjà pris.';
        });
        return;
      }

      await supabase
          .from('users')
          .update({'username': username, 'avatar_url': _selectedAvatarId})
          .eq('id', currentUser.id);

      widget.ref.invalidate(userProfileProvider);
      widget.ref.invalidate(profileDataProvider);
      clearHomeBootstrapCache(userId: currentUser.id, clearStored: true);
      widget.ref.invalidate(homeBootstrapProvider);

      if (mounted) Navigator.of(context).pop();
    } catch (error, stackTrace) {
      await AppTelemetryService.recordError(
        error,
        stackTrace,
        reason: 'profile_update_failed',
      );
      setState(() {
        _error = AppTelemetryService.userMessageForError(
          error,
          fallback: 'Impossible de modifier le profil.',
        );
      });
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 14, 20, 22 + bottomInset),
      child: SingleChildScrollView(
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
            Row(
              children: [
                Expanded(
                  child: Text('Modifier le profil', style: AppTextStyles.h2),
                ),
                IconButton(
                  onPressed: _isSaving
                      ? null
                      : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _usernameController,
              textInputAction: TextInputAction.done,
              style: AppTextStyles.body,
              decoration: const InputDecoration(
                labelText: 'Pseudo',
                hintText: 'Ex: Cooper_225',
              ),
              onSubmitted: (_) {
                if (!_isSaving) _save();
              },
            ),
            const SizedBox(height: 18),
            Text('Avatar', style: AppTextStyles.h3),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _avatarIds.length,
              itemBuilder: (context, index) {
                final id = _avatarIds[index];
                final avatar = avatarForId(id);
                final isSelected = id == _selectedAvatarId;

                return InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: _isSaving
                      ? null
                      : () => setState(() => _selectedAvatarId = id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      color: avatar.color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.surfaceBorder,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Icon(
                            avatar.icon,
                            color: avatar.color,
                            size: 28,
                          ),
                        ),
                        if (isSelected)
                          const Positioned(
                            right: 6,
                            top: 6,
                            child: Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.primary,
                              size: 18,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.accentRed,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 22),
            AppButton(
              text: 'Enregistrer',
              icon: Icons.check_rounded,
              isLoading: _isSaving,
              onPressed: _isSaving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
