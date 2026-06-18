import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mega_promo/core/theme/app_colors.dart';

class PromoWatermarkBackground extends StatefulWidget {
  final bool colorful;

  const PromoWatermarkBackground({super.key, this.colorful = false});

  @override
  State<PromoWatermarkBackground> createState() =>
      _PromoWatermarkBackgroundState();
}

class _PromoWatermarkBackgroundState extends State<PromoWatermarkBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              painter: _PromoWatermarkPainter(
                progress: _controller.value,
                colorful: widget.colorful,
              ),
              child: const SizedBox.expand(),
            );
          },
        ),
      ),
    );
  }
}

class _PromoWatermarkPainter extends CustomPainter {
  final double progress;
  final bool colorful;

  const _PromoWatermarkPainter({
    required this.progress,
    required this.colorful,
  });

  static const _labels = [
    'MEGA PROMO',
    '-50%',
    'BON',
    'COUPON',
    '-25%',
    'CADEAU',
    '-70%',
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final strength = colorful ? 1.0 : 0.55;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.08 * strength),
            Colors.white.withValues(alpha: 0),
            AppColors.goldLight.withValues(alpha: 0.12 * strength),
            AppColors.accentGreen.withValues(alpha: 0.07 * strength),
          ],
          stops: const [0, 0.45, 0.78, 1],
        ).createShader(Offset.zero & size),
    );

    _paintBand(
      canvas,
      size,
      y: size.height * 0.12,
      angle: -0.20,
      color: AppColors.primary,
      speed: 28,
    );
    _paintBand(
      canvas,
      size,
      y: size.height * 0.42,
      angle: 0.18,
      color: colorful ? AppColors.accentGreen : AppColors.gold,
      speed: -24,
    );
    _paintBand(
      canvas,
      size,
      y: size.height * 0.78,
      angle: -0.66,
      color: colorful ? const Color(0xFFF97316) : AppColors.primaryDark,
      speed: 22,
    );
    _paintBand(
      canvas,
      size,
      y: size.height * 0.88,
      angle: math.pi / 2,
      color: colorful ? const Color(0xFF38BDF8) : AppColors.accentGreen,
      speed: -18,
    );

    _paintTickets(canvas, size);
  }

  void _paintBand(
    Canvas canvas,
    Size size, {
    required double y,
    required double angle,
    required Color color,
    required double speed,
  }) {
    final longWidth = math.max(size.width, size.height) * 2.2;
    final center = Offset(size.width / 2, y);
    final alphaBase = colorful ? 0.07 : 0.045;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: longWidth, height: 42),
        const Radius.circular(999),
      ),
      Paint()..color = color.withValues(alpha: alphaBase * 0.55),
    );

    var cursor = -longWidth / 2 - 100 + progress * speed;
    var index = 0;
    while (cursor < longWidth / 2 + 140) {
      final label = _labels[index % _labels.length];
      final pulse = 0.5 + 0.5 * math.sin(progress * math.pi * 2 + index);
      final alpha = alphaBase + pulse * (colorful ? 0.07 : 0.04);
      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: color.withValues(alpha: alpha),
            fontSize: label == 'MEGA PROMO' ? 19 : 15,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      if (label == 'BON' || label == 'COUPON') {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(cursor - 10, -17, painter.width + 20, 34),
            const Radius.circular(9),
          ),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.1
            ..color = color.withValues(alpha: alpha * 0.8),
        );
      }

      painter.paint(canvas, Offset(cursor, -painter.height / 2));
      cursor += painter.width + 34;
      index += 1;
    }
    canvas.restore();
  }

  void _paintTickets(Canvas canvas, Size size) {
    final colors = [
      AppColors.primary,
      AppColors.gold,
      AppColors.accentGreen,
      const Color(0xFFF472B6),
    ];
    final items = [
      (Offset(size.width * 0.08, size.height * 0.20), '-30%', -0.38),
      (Offset(size.width * 0.86, size.height * 0.26), 'BON', 0.32),
      (Offset(size.width * 0.16, size.height * 0.82), '-15%', 0.22),
      (Offset(size.width * 0.78, size.height * 0.73), 'VIP', -0.28),
    ];

    for (var index = 0; index < items.length; index += 1) {
      final item = items[index];
      final color = colors[index % colors.length];
      final pulse = 0.5 + 0.5 * math.sin(progress * math.pi * 2 + index * 1.3);
      final alpha = (colorful ? 0.10 : 0.055) + pulse * 0.06;

      canvas.save();
      canvas.translate(item.$1.dx, item.$1.dy);
      canvas.rotate(item.$3);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-35, -18, 70, 36),
          const Radius.circular(10),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = color.withValues(alpha: alpha),
      );
      final painter = TextPainter(
        text: TextSpan(
          text: item.$2,
          style: TextStyle(
            color: color.withValues(alpha: alpha + 0.04),
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _PromoWatermarkPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.colorful != colorful;
  }
}
