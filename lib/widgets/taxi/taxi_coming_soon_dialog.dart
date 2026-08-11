import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TaxiComingSoonDialog extends StatelessWidget {
  final String lang;

  const TaxiComingSoonDialog({super.key, required this.lang});

  static Future<void> show(BuildContext context, {required String lang}) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) => TaxiComingSoonDialog(lang: lang),
    );
  }

  @override
  Widget build(BuildContext context) {
    String mainTitleLine1;
    String mainTitleLine2;
    String descTextPart1;
    String descTextKeyword1;
    String descTextPart2;
    String descTextKeyword2;
    String descTextPart3;
    String descLaunchText;
    String descLaunchHighlight;
    String btnText;

    if (lang == 'Уйғурчә') {
      mainTitleLine1 = 'Такси хизмити';
      mainTitleLine2 = 'йеқин арида ачилиду!';
      descTextPart1 = 'Биз ';
      descTextKeyword1 = 'район ичида';
      descTextPart2 = ' вә ';
      descTextKeyword2 = 'шәһәрләрара';
      descTextPart3 = ' сәприңизни қолайлиқ вә бихәтәр қилиш үчүн охирқи тәйярлиқларни қиливатимиз.';
      descLaunchText = 'Ишке қошулуш ';
      descLaunchHighlight = 'бек йеқин!';
      btnText = 'Уқтум, күтидим!';
    } else if (lang == 'Қазақша') {
      mainTitleLine1 = 'Такси қызметі';
      mainTitleLine2 = 'жақында ашылады!';
      descTextPart1 = 'Сапарларыңыз ';
      descTextKeyword1 = 'аудан ішінде';
      descTextPart2 = ' және ';
      descTextKeyword2 = 'қалааралық';
      descTextPart3 = ' мейлінше ыңғайлы, қауіпсіз әрі тиімді болуы үшін соңғы дайындықтарды жасап жатырмыз.';
      descLaunchText = 'Іске қосылу ';
      descLaunchHighlight = 'өте жақында!';
      btnText = 'Түсінікті, күтемін!';
    } else {
      mainTitleLine1 = 'Сервис Такси';
      mainTitleLine2 = 'скоро откроется!';
      descTextPart1 = 'Мы завершаем последние приготовления, чтобы поездки ';
      descTextKeyword1 = 'по району';
      descTextPart2 = ' и ';
      descTextKeyword2 = 'межгороду';
      descTextPart3 = ' были максимально комфортными, безопасными и выгодными.';
      descLaunchText = 'Запуск уже ';
      descLaunchHighlight = 'очень скоро!';
      btnText = 'Отлично, жду!';
    }

    final double screenWidth = MediaQuery.of(context).size.width;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      elevation: 0,
      child: Center(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: math.min(screenWidth * 0.9, 380),
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(36),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E3A8A).withValues(alpha: 0.18),
                blurRadius: 36,
                offset: const Offset(0, 16),
                spreadRadius: -4,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(36),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Background Gradient Layer
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFFEFF6FF), // very soft blue top
                          Color(0xFFFFFFFF), // pure white middle
                          Color(0xFFF0F7FF), // soft pastel blue bottom
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                ),

                // Radial Ray Glow Background Effect
                Positioned(
                  top: -60,
                  left: -40,
                  right: -40,
                  height: 300,
                  child: CustomPaint(
                    painter: _SunburstRaysPainter(),
                  ),
                ),

                // Main Content Column
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Top Close Button Header Row
                      Align(
                        alignment: Alignment.topRight,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => Navigator.pop(context),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: const Color(0xFFDBEAFE).withValues(alpha: 0.6),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 4),

                      // Taxi Icon Hero with Rings, Rocket, and Location Pin
                      SizedBox(
                        height: 130,
                        width: double.infinity,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Dashed Arc Path Connecting Pin to Center
                            Positioned(
                              top: 28,
                              right: 50,
                              child: CustomPaint(
                                size: const Size(80, 50),
                                painter: _DashedArcPainter(),
                              ),
                            ),

                            // Outer Glow Ring 2
                            Container(
                              width: 124,
                              height: 124,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF3B82F6).withValues(alpha: 0.06),
                              ),
                            ),

                            // Outer Glow Ring 1
                            Container(
                              width: 104,
                              height: 104,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                                border: Border.all(
                                  color: const Color(0xFF93C5FD).withValues(alpha: 0.3),
                                  width: 1.5,
                                ),
                              ),
                            ),

                            // Main Center Blue Taxi Circle
                            Container(
                              width: 82,
                              height: 82,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF3B82F6),
                                    Color(0xFF1D4ED8),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF2563EB).withValues(alpha: 0.4),
                                    blurRadius: 18,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.local_taxi_rounded,
                                  color: Colors.white,
                                  size: 42,
                                ),
                              ),
                            ),

                            // Floating Location Pin (Right)
                            Positioned(
                              right: 44,
                              top: 18,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.06),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.location_on_rounded,
                                  color: Color(0xFF93C5FD),
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Title: Line 1 (Dark) & Line 2 (Vivid Blue)
                      Text(
                        mainTitleLine1,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0F172A),
                          letterSpacing: -0.5,
                          height: 1.15,
                        ),
                      ),
                      Text(
                        mainTitleLine2,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF2563EB),
                          letterSpacing: -0.5,
                          height: 1.15,
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Decorative Divider Line — • —
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 32,
                            height: 1.5,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF93C5FD).withValues(alpha: 0.0),
                                  const Color(0xFF93C5FD),
                                ],
                              ),
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              color: Color(0xFF2563EB),
                              shape: BoxShape.circle,
                            ),
                          ),
                          Container(
                            width: 32,
                            height: 1.5,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF93C5FD),
                                  const Color(0xFF93C5FD).withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Body RichText Description
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF475569),
                            height: 1.45,
                          ),
                          children: [
                            TextSpan(text: descTextPart1),
                            TextSpan(
                              text: descTextKeyword1,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                            TextSpan(text: descTextPart2),
                            TextSpan(
                              text: descTextKeyword2,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                            TextSpan(text: descTextPart3),
                            const TextSpan(text: '\n\n'),
                            TextSpan(text: descLaunchText),
                            TextSpan(
                              text: descLaunchHighlight,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Bottom Action Button with Circle Badge Icon
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            shadowColor: const Color(0xFF2563EB).withValues(alpha: 0.4),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Spacer(),
                                Text(
                                  btnText,
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const Spacer(),
                              ],
                            ),
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
      ),
    );
  }
}

/// Custom painter for soft sunburst / light ray background
class _SunburstRaysPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, 40);
    final paint = Paint()
      ..color = const Color(0xFF3B82F6).withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;

    const int totalRays = 12;
    final double maxRadius = math.max(size.width, size.height) * 1.2;

    for (int i = 0; i < totalRays; i++) {
      if (i % 2 == 0) continue; // Draw alternate rays
      final double startAngle = (i * 2 * math.pi) / totalRays;
      final double sweepAngle = math.pi / (totalRays * 1.5);

      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(
          center.dx + maxRadius * math.cos(startAngle),
          center.dy + maxRadius * math.sin(startAngle),
        )
        ..lineTo(
          center.dx + maxRadius * math.cos(startAngle + sweepAngle),
          center.dy + maxRadius * math.sin(startAngle + sweepAngle),
        )
        ..close();

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Custom painter for curved dashed line connecting location pin to center icon
class _DashedArcPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF93C5FD).withValues(alpha: 0.6)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(size.width, 0);
    path.quadraticBezierTo(
      size.width * 0.4,
      size.height * 0.8,
      0,
      size.height,
    );

    // Draw dashed line along path
    final pathMetrics = path.computeMetrics();
    for (final metric in pathMetrics) {
      double distance = 0.0;
      const double dashWidth = 3.5;
      const double dashSpace = 3.5;

      while (distance < metric.length) {
        final double end = math.min(distance + dashWidth, metric.length);
        canvas.drawPath(
          metric.extractPath(distance, end),
          paint,
        );
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
