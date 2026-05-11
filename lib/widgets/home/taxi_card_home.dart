import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Современная карточка-баннер для сервиса IQ Taxi.
/// Соответствует спецификациям: белый фон, скругление 20, тень, 
/// позиционирование через Stack и кастомные элементы управления.
class TaxiCardHome extends StatelessWidget {
  final VoidCallback onTap;

  const TaxiCardHome({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF4A80F0),
              Color(0xFF1E40AF),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4A80F0).withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // ── Декоративные круги ──────────────────
              Positioned(
                right: -20,
                top: -20,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
              ),
              Positioned(
                right: 40,
                bottom: -30,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
              ),

              // ── Изображение автомобиля ─────────────────────────
              Positioned(
                right: 0,
                bottom: 10,
                child: Transform.flip(
                  flipX: true, // Флипаем машину как просил юзер
                  child: Image.asset(
                    'assets/images/taxi_car.png',
                    width: 170,
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
                      'IQ Taxi — Межгород',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Удобные поездки между\nгородами и сёлами',
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
                        _buildFeatureItem(Icons.done_all_rounded, 'Быстро'),
                        const SizedBox(width: 12),
                        _buildFeatureItem(Icons.done_all_rounded, 'Выгодно'),
                      ],
                    ),

                    const Spacer(),
                    // Кнопка
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'ПОЕХАЛИ!',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF4A80F0),
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: 1.5,
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
        Icon(icon, size: 14, color: Colors.white70),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}

