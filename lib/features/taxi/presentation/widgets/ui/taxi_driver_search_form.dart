// ─────────────────────────────────────────────────────────────────────────────
// FILE: lib/features/taxi/presentation/widgets/ui/taxi_driver_search_form.dart
// STEP: #28 | СЛОЙ: widgets/ui
// ОТВЕЧАЕТ ЗА: Форму поиска пассажиров для водителя (Откуда, Куда, Дата, Поиск)
// ЗАВИСИМОСТИ: TaxiTheme, TaxiMiniBtn, TaxiActBtn (чистый UI)
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iqmarket/theme/taxi_theme.dart';
import 'package:provider/provider.dart';
import 'package:iqmarket/providers/taxi_provider.dart';
import 'package:iqmarket/features/taxi/presentation/widgets/ui/taxi_section_header_widget.dart';
import 'package:google_fonts/google_fonts.dart';

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
    final provider = Provider.of<TaxiProvider>(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
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
                        child: const Icon(Icons.swap_vert_rounded, color: Color(0xFF1E5EE6), size: 20),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onDateTap();
            },
            child: Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFF1F5F9),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.calendar_today_rounded,
                      color: Color(0xFF1E5EE6),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          provider.translate('date_time_label'),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          dateLabel,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFF1E293B),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          TaxiActBtn(
            t: t,
            label: provider.translate('search_btn_hint'),
            color: t.accent,
            onTap: onSearchTap,
            height: 56,
            borderRadius: 18,
          ),
        ],
      ),
    );
  }
}
