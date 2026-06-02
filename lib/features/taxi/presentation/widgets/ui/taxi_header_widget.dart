// ─────────────────────────────────────────────────────────────────────────────
// FILE: lib/features/taxi/presentation/widgets/ui/taxi_header_widget.dart
// STEP: #18 | СЛОЙ: widgets/ui
// ОТВЕЧАЕТ ЗА: баннер «Межгород и между сёлами» с картинкой авто
// ЗАВИСИМОСТИ: только Flutter + google_fonts — нет Provider, нет state
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Баннер-заголовок экрана IQ TAXI.
///
/// Показывает текст «Межгород и между сёлами» слева
/// и изображение автомобиля справа.
/// Полностью stateless, не зависит от Provider.
class TaxiHeaderWidget extends StatelessWidget {
  const TaxiHeaderWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 0, 10),
      child: Stack(
        children: [
          // ── Текстовый блок (55% ширины экрана) ───────────────────────────
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.55,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Межгород и\nмежду сёлами',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1E293B),
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Поездки с комфортом на любые расстояния',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // ── Картинка авто (зеркально) ─────────────────────────────────────
          Positioned(
            right: 25,
            top: 15,
            child: Transform.flip(
              flipX: true,
              child: Image.asset(
                'assets/images/taxi_car.png',
                width: 130,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
