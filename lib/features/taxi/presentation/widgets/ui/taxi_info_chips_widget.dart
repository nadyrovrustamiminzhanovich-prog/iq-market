// ─────────────────────────────────────────────────────────────────────────────
// FILE: lib/features/taxi/presentation/widgets/ui/taxi_info_chips_widget.dart
// STEP: #23 | СЛОЙ: widgets/ui
// ОТВЕЧАЕТ ЗА: четыре micro-виджета для отображения метаданных поездок:
//   • TaxiInfoChip       — серый чип (иконка + текст)
//   • TaxiBlueInfoChip   — синий акцентный чип
//   • TaxiSummaryItem    — item сводки заказа (иконка + значение)
//   • TaxiCircleBtn      — круглая кнопка-иконка
// ЗАВИСИМОСТИ: TaxiTheme, google_fonts — нет Provider, нет state
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iqmarket/theme/taxi_theme.dart';

// ─── Серый чип ────────────────────────────────────────────────────────────────

/// Нейтральный чип с иконкой и текстом (серый фон).
/// Используется для отображения деталей маршрута, времени и т.п.
class TaxiInfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final TaxiTheme t;

  const TaxiInfoChip({super.key, required this.icon, required this.text, required this.t});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF4A80F0), size: 13),
          const SizedBox(width: 6),
          Text(text, style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ─── Синий акцентный чип ──────────────────────────────────────────────────────

/// Акцентный чип с иконкой и текстом (синий фон с бордером).
/// Используется для статусов, цены, приоритетных меток.
class TaxiBlueInfoChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const TaxiBlueInfoChip({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF4A80F0).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF4A80F0).withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF4A80F0), size: 13),
          const SizedBox(width: 6),
          Text(text, style: GoogleFonts.inter(color: const Color(0xFF4A80F0), fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ─── Summary item ─────────────────────────────────────────────────────────────

/// Элемент сводки заказа/поездки: иконка + значение в рамке темы.
/// Используется в экране подтверждения заказа пассажира.
class TaxiSummaryItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final TaxiTheme t;

  const TaxiSummaryItem({super.key, required this.icon, required this.value, required this.t});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: t.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: t.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF4A80F0)),
          const SizedBox(width: 6),
          Text(value, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: t.text)),
        ],
      ),
    );
  }
}

// ─── Круглая кнопка ───────────────────────────────────────────────────────────

/// Декоративная круглая кнопка-иконка с бордером.
/// Используется в пассажирском и водительском view.
class TaxiCircleBtn extends StatelessWidget {
  final TaxiTheme t;
  final IconData icon;

  const TaxiCircleBtn({super.key, required this.t, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: t.border, width: 2),
      ),
      child: Icon(icon, color: t.lime),
    );
  }
}
