import 'package:flutter/material.dart';

class ChatBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    const spacing = 45.0;
    for (double i = -spacing; i < size.width + spacing; i += spacing) {
      for (double j = -spacing; j < size.height + spacing; j += spacing) {
        // Рисуем паттерн "крестики" или "точки"
        canvas.drawLine(Offset(i - 4, j), Offset(i + 4, j), paint);
        canvas.drawLine(Offset(i, j - 4), Offset(i, j + 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
