import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/agora_colors.dart';
import '../../../core/theme/agora_spacing.dart';
import '../../../core/theme/agora_typography.dart';

/// 14-Day Completion Sparkline widget
///
/// Principles:
/// - Pure Flutter CustomPainter (zero chart package dependencies).
/// - Clean, restrained Aegean Blue line with subtle area fill.
/// - Shows empty state if zero completions recorded in the window.
class PulseSparkline extends StatelessWidget {
  const PulseSparkline({super.key, required this.data, this.height = 70.0});

  final List<int> data;
  final double height;

  @override
  Widget build(BuildContext context) {
    final totalCompleted = data.fold<int>(0, (sum, val) => sum + val);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('14-Day Completion Trend', style: AgoraTypography.titleMedium),
            Text(
              '$totalCompleted completed',
              style: AgoraTypography.labelMedium.copyWith(
                color: AgoraColors.aegean,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: AgoraSpacing.xs),
        SizedBox(
          height: height,
          width: double.infinity,
          child: totalCompleted == 0
              ? Center(
                  child: Text(
                    'No tasks completed in the last 14 days',
                    style: AgoraTypography.bodySmall,
                  ),
                )
              : CustomPaint(painter: _SparklinePainter(data: data)),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('14 days ago', style: AgoraTypography.labelSmall),
            Text('Today', style: AgoraTypography.labelSmall),
          ],
        ),
      ],
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.data});

  final List<int> data;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final maxVal = math.max(1, data.reduce(math.max));
    final width = size.width;
    final height = size.height;

    final dx = width / (data.length - 1);

    final path = Path();
    final fillPath = Path();

    final points = <Offset>[];

    for (int i = 0; i < data.length; i++) {
      final x = i * dx;
      // Invert Y so highest value is at top
      final normalizedY = data[i] / maxVal;
      final y = height - (normalizedY * (height - 12)) - 6;
      points.add(Offset(x, y));

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(width, height);
    fillPath.close();

    // Draw gradient fill under line
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AgoraColors.aegean.withValues(alpha: 0.18),
          AgoraColors.aegean.withValues(alpha: 0.01),
        ],
      ).createShader(Rect.fromLTWH(0, 0, width, height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    // Draw line
    final linePaint = Paint()
      ..color = AgoraColors.aegean
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, linePaint);

    // Draw dots at non-zero points
    final dotPaint = Paint()
      ..color = AgoraColors.aegeanDark
      ..style = PaintingStyle.fill;

    for (int i = 0; i < data.length; i++) {
      if (data[i] > 0) {
        canvas.drawCircle(points[i], 3.0, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return !listEquals(oldDelegate.data, data);
  }
}
