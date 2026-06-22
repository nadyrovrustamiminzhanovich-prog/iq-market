import 'dart:math' as math;
import 'package:flutter/material.dart';

class VoiceWaveform extends StatefulWidget {
  final double soundLevel; // Normalized between 0.0 and 1.0
  final Color? color;

  const VoiceWaveform({
    super.key,
    required this.soundLevel,
    this.color,
  });

  @override
  State<VoiceWaveform> createState() => _VoiceWaveformState();
}

class _VoiceWaveformState extends State<VoiceWaveform> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = widget.color ?? Theme.of(context).primaryColor;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(double.infinity, 80),
          painter: VoiceWaveformPainter(
            soundLevel: widget.soundLevel,
            animationValue: _controller.value * 2 * math.pi,
            color: themeColor,
          ),
        );
      },
    );
  }
}

class VoiceWaveformPainter extends CustomPainter {
  final double soundLevel;
  final double animationValue;
  final Color color;

  VoiceWaveformPainter({
    required this.soundLevel,
    required this.animationValue,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Use a gradient for a more premium look!
    final rectBounds = Rect.fromLTWH(0, 0, size.width, size.height);
    paint.shader = LinearGradient(
      colors: [
        color.withValues(alpha: 0.5),
        color,
        color.withValues(alpha: 0.5),
      ],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ).createShader(rectBounds);

    const int barCount = 25; // More bars for a smoother look like WhatsApp
    const double barWidth = 4.0;
    const double spacing = 5.0;

    final double totalContentWidth = (barCount * barWidth) + ((barCount - 1) * spacing);
    final double startX = (size.width - totalContentWidth) / 2;
    final double centerY = size.height / 2;

    for (int i = 0; i < barCount; i++) {
      // Dome factor: middle bars bounce higher, outer bars bounce less.
      // i goes from 0 to 24. Center is 12.
      final double distanceFromCenter = (i - 12).abs() / 12.0;
      final double domeFactor = math.cos(distanceFromCenter * math.pi / 2); // 1.0 at center, 0.0 at edges

      // Gentle wave animation for idle state
      final double waveOffset = math.sin(animationValue + i * 0.3);
      final double idleHeight = 8.0 + 6.0 * (waveOffset + 1.0) / 2.0;

      // React to sound level
      final double activeHeight = idleHeight + (size.height - idleHeight) * soundLevel * domeFactor;

      final double x = startX + i * (barWidth + spacing);
      final double y = centerY - (activeHeight / 2);

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, activeHeight),
        const Radius.circular(3.0),
      );
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant VoiceWaveformPainter oldDelegate) {
    return oldDelegate.soundLevel != soundLevel ||
        oldDelegate.animationValue != animationValue ||
        oldDelegate.color != color;
  }
}
