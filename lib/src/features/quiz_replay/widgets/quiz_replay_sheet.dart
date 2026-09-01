import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mega_promo/core/theme/app_colors.dart';
import 'package:mega_promo/core/theme/app_text_styles.dart';
import 'package:mega_promo/core/utils/currency_formatter.dart';
import 'package:mega_promo/core/widgets/app_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../contests/models/contest.dart';
import '../providers/quiz_replay_provider.dart';

class QuizReplaySheet extends ConsumerStatefulWidget {
  final Contest contest;
  final VoidCallback? onSubmitted;

  const QuizReplaySheet({super.key, required this.contest, this.onSubmitted});

  @override
  ConsumerState<QuizReplaySheet> createState() => _QuizReplaySheetState();
}

class _QuizReplaySheetState extends ConsumerState<QuizReplaySheet> {
  final _picker = ImagePicker();
  bool _isSubmitting = false;
  XFile? _proofFile;
  Uint8List? _proofBytes;

  Future<void> _copyPaymentTarget(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Information de paiement copiée.')),
    );
  }

  Future<void> _openPaymentUrl(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _pickProof() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1600,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _proofFile = file;
      _proofBytes = bytes;
    });
  }

  Future<void> _submitProof() async {
    final proofFile = _proofFile;
    final proofBytes = _proofBytes;
    if (proofFile == null || proofBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoute la photo de ta preuve.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final proofUrl = await uploadQuizReplayProof(
        contestId: widget.contest.id,
        bytes: proofBytes,
        fileName: proofFile.name,
      );
      await submitQuizReplayProof(
        contestId: widget.contest.id,
        proofImageUrl: proofUrl,
      );
      ref.invalidate(quizReplayStatusProvider(widget.contest.id));
      widget.onSubmitted?.call();
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preuve envoyée. Traitement sous 5 minutes max.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_formatSubmitError(error))));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final replayStatus = ref.watch(quizReplayStatusProvider(widget.contest.id));

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 18,
          bottom: 18 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: replayStatus.when(
          data: _buildContent,
          loading: () => const SizedBox(
            height: 180,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => _ReplayUnavailable(
            onRetry: () {
              ref.invalidate(quizReplayStatusProvider(widget.contest.id));
            },
          ),
        ),
      ),
    );
  }

  Widget _buildContent(QuizReplayStatus status) {
    final target = status.paymentTarget.trim();
    final paymentUrl = status.paymentUrl.trim();
    final instructions = status.instructions.trim();

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.replay_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Rejouer ce JCQ', style: AppTextStyles.h3),
                    const SizedBox(height: 3),
                    Text(
                      widget.contest.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (!status.replayEnabled)
            const _ReplayNotice(
              icon: Icons.lock_rounded,
              title: 'Rejeu indisponible',
              body: 'Ce JCQ ne peut pas encore être rejoué.',
            )
          else ...[
            if (status.canStartReplay) ...[
              _ReplayNotice(
                icon: Icons.check_circle_rounded,
                title: 'Autorisation validée',
                body:
                    'Tu peux fermer cette fenêtre et appuyer sur Commencer le replay. Tu peux aussi payer encore si tu veux réserver un autre replay.',
                color: AppColors.accentGreen,
              ),
              const SizedBox(height: 12),
            ],
            _PaymentInfo(
              amount: status.amount,
              paymentTarget: target,
              paymentUrl: paymentUrl,
              instructions: instructions,
              onCopy: target.isEmpty ? null : () => _copyPaymentTarget(target),
              onOpenUrl: paymentUrl.isEmpty
                  ? null
                  : () => _openPaymentUrl(paymentUrl),
            ),
            const SizedBox(height: 12),
            if (status.status == QuizReplayRequestStatus.pending)
              const _ReplayNotice(
                icon: Icons.hourglass_top_rounded,
                title: 'Preuve en attente',
                body:
                    'Ton dernier paiement est en cours de vérification. Tu peux soumettre une autre preuve si tu viens de payer un nouveau replay.',
                color: AppColors.gold,
              )
            else if (status.status == QuizReplayRequestStatus.rejected)
              _ReplayNotice(
                icon: Icons.info_rounded,
                title: 'Demande refusée',
                body: status.rejectionReason?.trim().isNotEmpty == true
                    ? status.rejectionReason!.trim()
                    : 'Tu peux renvoyer une preuve lisible après paiement.',
              ),
            if (status.canSubmitProof) ...[
              if (status.status == QuizReplayRequestStatus.pending ||
                  status.status == QuizReplayRequestStatus.rejected)
                const SizedBox(height: 12),
              _ProofPicker(
                fileName: _proofFile?.name,
                hasProof: _proofBytes != null,
                onPick: _isSubmitting ? null : _pickProof,
              ),
            ],
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  text: 'Fermer',
                  isOutlined: true,
                  height: 48,
                  onPressed: _isSubmitting
                      ? null
                      : () => Navigator.of(context).pop(),
                ),
              ),
              if (status.canSubmitProof) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: AppButton(
                    text: 'Soumettre',
                    icon: Icons.cloud_upload_rounded,
                    height: 48,
                    isLoading: _isSubmitting,
                    onPressed: _submitProof,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentInfo extends StatelessWidget {
  final int amount;
  final String paymentTarget;
  final String paymentUrl;
  final String instructions;
  final VoidCallback? onCopy;
  final VoidCallback? onOpenUrl;

  const _PaymentInfo({
    required this.amount,
    required this.paymentTarget,
    required this.paymentUrl,
    required this.instructions,
    required this.onCopy,
    required this.onOpenUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Paiement du replay', style: AppTextStyles.h3),
          const SizedBox(height: 8),
          Text(
            'Montant : ${formatCurrencyAmount(amount)}',
            style: AppTextStyles.price.copyWith(fontSize: 19),
          ),
          const SizedBox(height: 8),
          Text(
            instructions.isEmpty
                ? 'Effectue le paiement, garde une capture claire, puis soumets ta preuve. Validation sous 5 minutes max.'
                : instructions,
            style: AppTextStyles.bodySecondary,
          ),
          if (paymentTarget.isNotEmpty) ...[
            const SizedBox(height: 12),
            _PaymentAction(
              icon: Icons.phone_android_rounded,
              label: paymentTarget,
              actionLabel: 'Copier',
              onPressed: onCopy,
            ),
          ],
          if (paymentUrl.isNotEmpty) ...[
            const SizedBox(height: 8),
            _PaymentAction(
              icon: Icons.open_in_new_rounded,
              label: 'Lien de paiement',
              actionLabel: 'Ouvrir',
              onPressed: onOpenUrl,
            ),
          ],
        ],
      ),
    );
  }
}

class _PaymentAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final String actionLabel;
  final VoidCallback? onPressed;

  const _PaymentAction({
    required this.icon,
    required this.label,
    required this.actionLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        TextButton(onPressed: onPressed, child: Text(actionLabel)),
      ],
    );
  }
}

class _ProofPicker extends StatelessWidget {
  final String? fileName;
  final bool hasProof;
  final VoidCallback? onPick;

  const _ProofPicker({
    required this.fileName,
    required this.hasProof,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPick,
      icon: Icon(
        hasProof ? Icons.check_circle_rounded : Icons.photo_camera_rounded,
      ),
      label: Text(
        hasProof ? fileName ?? 'Preuve ajoutée' : 'Soumettre ma preuve photo',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _ReplayNotice extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Color color;

  const _ReplayNotice({
    required this.icon,
    required this.title,
    required this.body,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(body, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReplayUnavailable extends ConsumerWidget {
  final VoidCallback onRetry;

  const _ReplayUnavailable({required this.onRetry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _ReplayNotice(
          icon: Icons.wifi_off_rounded,
          title: 'Impossible de charger',
          body: 'Vérifie ta connexion puis réessaie.',
        ),
        const SizedBox(height: 14),
        AppButton(text: 'Réessayer', onPressed: onRetry),
      ],
    );
  }
}

String _formatSubmitError(Object error) {
  if (error is PostgrestException) return error.message;
  return 'Impossible d’envoyer la preuve pour le moment.';
}
