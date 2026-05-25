import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../services/synced_clock_service.dart';

class ContestTimer extends StatefulWidget {
  final DateTime endsAt;
  final TextStyle? style;

  const ContestTimer({super.key, required this.endsAt, this.style});

  @override
  State<ContestTimer> createState() => _ContestTimerState();
}

class _ContestTimerState extends State<ContestTimer>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  late Duration _remaining;
  late final AnimationController _pulseController;

  bool get _isUrgent =>
      _remaining > Duration.zero && _remaining < const Duration(hours: 1);

  @override
  void initState() {
    super.initState();
    _remaining = _calculateRemaining();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
      lowerBound: 0.92,
      upperBound: 1.04,
    );
    _syncPulse();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remaining = _calculateRemaining());
      _syncPulse();
    });
  }

  @override
  void didUpdateWidget(covariant ContestTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.endsAt != widget.endsAt) {
      setState(() => _remaining = _calculateRemaining());
      _syncPulse();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Duration _calculateRemaining() {
    final remaining = widget.endsAt.difference(SyncedClockService.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  void _syncPulse() {
    if (_isUrgent && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!_isUrgent && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.value = 1;
    }
  }

  String _formatRemaining() {
    if (_remaining == Duration.zero) return 'Terminé';

    final days = _remaining.inDays;
    final hours = _remaining.inHours.remainder(24);
    final minutes = _remaining.inMinutes.remainder(60);
    final seconds = _remaining.inSeconds.remainder(60);

    if (_remaining < const Duration(hours: 1)) {
      return '${minutes}min ${seconds}s';
    }

    if (days > 0) {
      return '${days}j ${hours}h ${minutes}min';
    }

    return '${hours}h ${minutes}min';
  }

  @override
  Widget build(BuildContext context) {
    final text = Text(
      _formatRemaining(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: (widget.style ?? AppTextStyles.bodySmall).copyWith(
        color: _isUrgent ? AppColors.accentRed : AppColors.textSecondary,
        fontWeight: _isUrgent ? FontWeight.w700 : null,
      ),
    );

    if (!_isUrgent) return text;

    return ScaleTransition(scale: _pulseController, child: text);
  }
}
