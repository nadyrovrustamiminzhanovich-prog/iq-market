// ─────────────────────────────────────────────────────────────────────────────
// FILE: lib/features/taxi/presentation/widgets/ui/taxi_route_row_widget.dart
// STEP: #26 | СЛОЙ: widgets/ui
// ОТВЕЧАЕТ ЗА: Строку ввода маршрута "Откуда" / "Куда" с индикатором
// ЗАВИСИМОСТИ: GoogleFonts, Material Design (чистый stateless UI)
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../../providers/taxi_provider.dart';

/// Виджет для выбора начальной ("Откуда") или конечной ("Куда") точки маршрута.
/// Содержит анимацию индикатора и состояние ошибки.
class TaxiRouteRow extends StatelessWidget {
  final bool isFrom;
  final String value;
  final bool hasError;
  final VoidCallback onTap;

  const TaxiRouteRow({
    super.key,
    required this.isFrom,
    required this.value,
    required this.hasError,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TaxiProvider>(context);
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        color: Colors.transparent,
        child: Row(
          children: [
            // Breathtaking Premium Path Point Indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: hasError
                    ? const Color(0xFFFFF1F2)
                    : isFrom
                        ? const Color(0xFFEFF6FF)
                        : const Color(0xFFF0FDF4),
                shape: BoxShape.circle,
                border: Border.all(
                  color: hasError
                      ? const Color(0xFFFDA4AF)
                      : isFrom
                          ? const Color(0xFF3B82F6)
                          : const Color(0xFF22C55E),
                  width: 2.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (hasError
                            ? const Color(0xFFE11D48)
                            : isFrom
                                ? const Color(0xFF3B82F6)
                                : const Color(0xFF22C55E))
                        .withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: isFrom
                    ? Icon(
                        Icons.circle,
                        color: hasError
                            ? const Color(0xFFE11D48)
                            : const Color(0xFF3B82F6),
                        size: 6.5,
                      )
                    : Icon(
                        Icons.location_on_rounded,
                        color: hasError
                            ? const Color(0xFFE11D48)
                            : const Color(0xFF22C55E),
                        size: 10,
                      ),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: value.isEmpty
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isFrom ? provider.translate('from_hint') : provider.translate('to_hint'),
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: hasError ? const Color(0xFFE11D48) : const Color(0xFF94A3B8),
                            letterSpacing: -0.3,
                          ),
                        ),
                        if (hasError)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF1F2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFFDA4AF), width: 0.8),
                            ),
                            child: Text(
                              provider.translate('specify'),
                              style: GoogleFonts.inter(
                                color: const Color(0xFFE11D48),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isFrom ? provider.translate('from') : provider.translate('to'),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF94A3B8),
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          value,
                          style: GoogleFonts.inter(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1E293B),
                            letterSpacing: -0.4,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
