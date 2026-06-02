// ─────────────────────────────────────────────────────────────────────────────
// FILE: lib/features/taxi/presentation/widgets/ui/taxi_driver_search_form.dart
// STEP: #28 | СЛОЙ: widgets/ui
// ОТВЕЧАЕТ ЗА: Форму поиска пассажиров для водителя (Откуда, Куда, Дата, Поиск)
// ЗАВИСИМОСТИ: TaxiTheme, TaxiMiniBtn, TaxiActBtn (чистый UI)
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iqmarket/theme/taxi_theme.dart';
import 'package:iqmarket/features/taxi/presentation/widgets/ui/taxi_section_header_widget.dart';

/// Форма поиска пассажиров для водителя.
///
/// Содержит слоты для строк маршрута [routeFrom], [routeTo] и 
/// элементы управления [dateLabel], [onDateTap], [onSwapTap], [onSearchTap].
class TaxiDriverSearchForm extends StatelessWidget {
  final TaxiTheme t;
  final Widget routeFrom;
  final Widget routeTo;
  final String dateLabel;
  final VoidCallback onDateTap;
  final VoidCallback onSwapTap;
  final VoidCallback onSearchTap;

  const TaxiDriverSearchForm({
    super.key,
    required this.t,
    required this.routeFrom,
    required this.routeTo,
    required this.dateLabel,
    required this.onDateTap,
    required this.onSwapTap,
    required this.onSearchTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 20, offset: const Offset(0, 10))
        ],
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.6),
      ),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 21,
                  top: 30,
                  bottom: 30,
                  child: Container(
                    width: 1.5,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A80F0).withValues(alpha: 0.3),
                    ),
                  ),
                ),
                Column(children: [
                  routeFrom,
                  const Padding(
                    padding: EdgeInsets.only(left: 50, right: 10),
                    child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                  ),
                  routeTo,
                ]),
                Positioned(
                  right: 15,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onSwapTap();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFF1F5F9)),
                        ),
                        child: const Icon(Icons.swap_vert_rounded, color: Color(0xFF4A80F0), size: 20),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TaxiMiniBtn(
            t: t,
            icon: Icons.calendar_today_rounded,
            value: dateLabel,
            onTap: onDateTap,
          ),
          const SizedBox(height: 24),
          TaxiActBtn(
            t: t,
            label: 'ПОИСК 🔍',
            color: const Color(0xFF4A80F0),
            onTap: onSearchTap,
          ),
        ],
      ),
    );
  }
}
