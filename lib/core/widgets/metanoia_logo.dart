import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Logo METANOIA — Vẽ vector trực tiếp tương ứng component MetanoiaLogo trong Frontend
class MetanoiaLogo extends StatelessWidget {
  final double size;
  final bool withWordmark;

  const MetanoiaLogo({
    super.key,
    this.size = 36,
    this.withWordmark = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CustomPaint(
          size: Size(size, size),
          painter: _MetanoiaLogoPainter(),
        ),
        if (withWordmark) ...[
          const SizedBox(width: 10),
          const Text(
            'METANOIA',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ],
    );
  }
}

class _MetanoiaLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 40.0;
    canvas.save();
    canvas.scale(scale, scale);

    final center = const Offset(18, 20);
    const radius = 14.0;

    // Gradient stroke cho vòng cung
    final rect = Rect.fromCircle(center: center, radius: radius);
    final gradient = const SweepGradient(
      startAngle: 0.0,
      endAngle: math.pi * 2,
      colors: [
        AppColors.voltagentPrimary,
        AppColors.voltagentPrimarySoft,
        AppColors.voltagentPrimaryDeep,
        AppColors.voltagentPrimary,
      ],
    ).createShader(rect);

    final arcPaint = Paint()
      ..shader = gradient
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    // Vẽ vòng hở (khoảng 290 độ)
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 1.62,
      false,
      arcPaint,
    );

    // Vẽ mũi tên tiến hóa ở đầu vòng
    final arrowPaint = Paint()
      ..color = AppColors.voltagentPrimary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final arrowPath = Path()
      ..moveTo(30, 14)
      ..lineTo(36, 12)
      ..lineTo(34, 18);

    canvas.drawPath(arrowPath, arrowPaint);

    // Vẽ chấm tâm (core consciousness)
    final dotPaint = Paint()
      ..color = AppColors.voltagentPrimary
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, 3.0, dotPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
