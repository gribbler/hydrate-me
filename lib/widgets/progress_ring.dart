import 'dart:math';
import 'package:flutter/material.dart';

class ProgressRing extends StatelessWidget {
  final double progress;         // actual 0.0–1.0
  final double? expectedProgress; // where you should be right now
  final double size;
  final double strokeWidth;
  final String label;
  final String sublabel;

  const ProgressRing({
    super.key,
    required this.progress,
    required this.label,
    required this.sublabel,
    this.expectedProgress,
    this.size = 200,
    this.strokeWidth = 16,
  });

  @override
  Widget build(BuildContext context) {
    final colours = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(
              progress: progress.clamp(0.0, 1.0),
              expectedProgress: expectedProgress?.clamp(0.0, 1.0),
              trackColor: colours.surfaceContainerHighest,
              fillColor: colours.primary,
              tickColor: colours.tertiary,
              strokeWidth: strokeWidth,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colours.onSurface,
                      )),
              Text(sublabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colours.onSurfaceVariant,
                      )),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final double? expectedProgress;
  final Color trackColor;
  final Color fillColor;
  final Color tickColor;
  final double strokeWidth;

  const _RingPainter({
    required this.progress,
    required this.trackColor,
    required this.fillColor,
    required this.tickColor,
    required this.strokeWidth,
    this.expectedProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Track
    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    // Actual progress arc
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: centre, radius: radius),
        -pi / 2,
        2 * pi * progress,
        false,
        Paint()
          ..color = fillColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }

    // Expected progress tick
    final exp = expectedProgress;
    if (exp != null && exp > 0) {
      final angle = -pi / 2 + 2 * pi * exp;
      final innerR = radius - strokeWidth * 0.6;
      final outerR = radius + strokeWidth * 0.6;
      final p1 = Offset(centre.dx + innerR * cos(angle),
          centre.dy + innerR * sin(angle));
      final p2 = Offset(centre.dx + outerR * cos(angle),
          centre.dy + outerR * sin(angle));
      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..color = tickColor
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.expectedProgress != expectedProgress;
}
