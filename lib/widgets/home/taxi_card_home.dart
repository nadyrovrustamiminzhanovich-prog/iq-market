import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:iqmarket/providers/app_config_provider.dart';

/// Современная карточка-баннер для сервиса IQ Taxi.
/// Соответствует спецификациям: белый фон, скругление 24, тень, 
/// позиционирование через Stack, декоративные пины с пунктирной линией и Mercedes.
class TaxiCardHome extends StatelessWidget {
  final VoidCallback onTap;

  const TaxiCardHome({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final config = Provider.of<AppConfigProvider>(context);
    final lang = config.language;

    String titleText = 'IQ Taxi — Межгород';
    String subtitleText = 'Удобные поездки\nмежду городами и сёлами';
    String fastText = 'Быстро';
    String profitableText = 'Выгодно';
    String goText = 'ПОЕХАЛИ!';

    if (lang == 'Қазақша') {
      titleText = 'IQ Taxi — Қалааралық';
      subtitleText = 'Қала мен ауыл арасындағы\nыңғайлы сапарлар';
      fastText = 'Жылдам';
      profitableText = 'Тиімді';
      goText = 'КЕТТІК!';
    } else if (lang == 'Уйғурчә') {
      titleText = 'IQ Taxi — Шәһәрара';
      subtitleText = 'Шәһәр вә йезилар арисидики\nқолайлиқ сәпәрләр';
      fastText = 'Тез';
      profitableText = 'Пайдилиқ';
      goText = 'КӘТТУҚ!';
    }
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF2563EB),
              Color(0xFF1D4ED8),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2563EB).withValues(alpha: 0.35),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // ── Декоративные пины и пунктирная линия маршрута ──────────────────
              // Левый пин
              Positioned(
                right: 90,
                top: 40,
                child: Icon(
                  Icons.location_on_rounded, 
                  color: Colors.white.withValues(alpha: 0.45), 
                  size: 24,
                ),
              ),
              // Правый пин
              Positioned(
                right: 20,
                top: 20,
                child: Icon(
                  Icons.location_on_rounded, 
                  color: Colors.white.withValues(alpha: 0.45), 
                  size: 24,
                ),
              ),
              // Линия маршрута
              Positioned(
                right: 22,
                top: 20,
                width: 70,
                height: 24,
                child: CustomPaint(
                  painter: DashedCurvePainter(),
                ),
              ),

              // ── Изображение автомобиля ─────────────────────────
              Positioned(
                right: 0,
                bottom: 8,
                child: Transform.flip(
                  flipX: true, // Флипаем машину как просил юзер
                  child: Image.asset(
                    'assets/images/taxi_car.png',
                    width: 175,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => 
                        const Icon(Icons.directions_car_rounded, size: 100, color: Colors.white24),
                  ),
                ),
              ),

              // ── Контент ──────────────────────────────
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titleText,
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitleText,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Преимущества
                    Row(
                      children: [
                        _buildFeatureItem(Icons.check_rounded, fastText),
                        const SizedBox(width: 12),
                        _buildFeatureItem(Icons.check_rounded, profitableText),
                      ],
                    ),

                    const Spacer(),
                    // Кнопка
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        goText,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF2563EB),
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.8)),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}

/// Painter для отрисовки изогнутой пунктирной линии маршрута
class DashedCurvePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = Path();
    // Начинаем у левого пина (x=0, y=size.height)
    path.moveTo(0, size.height);
    // Делаем изгиб вверх и ведем к правому пину (x=size.width, y=size.height * 0.3)
    path.quadraticBezierTo(
      size.width * 0.5,
      -size.height * 0.15, 
      size.width,
      size.height * 0.3,
    );

    const dashWidth = 4.0;
    const dashSpace = 4.0;
    double distance = 0.0;

    for (final measurePath in path.computeMetrics()) {
      while (distance < measurePath.length) {
        final extract = measurePath.extractPath(distance, distance + dashWidth);
        canvas.drawPath(extract, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

