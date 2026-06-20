// ─────────────────────────────────────────────────────────────────────────────
// FILE: lib/features/taxi/presentation/widgets/ui/taxi_section_header_widget.dart
// STEP: #24 | СЛОЙ: widgets/ui
// ОТВЕЧАЕТ ЗА: три UI-компонента навигации и форм:
//   • TaxiSectionHeader — заголовок секции с акцентным маркером
//   • TaxiMiniBtn       — кнопка-поле (дата, время, маршрут) с индикатором ошибки
//   • TaxiActBtn        — главная кнопка действия (градиент + тень)
// ЗАВИСИМОСТИ: TaxiTheme, google_fonts, flutter/services
//              НЕТ Provider, НЕТ Firestore — чистые UI-компоненты
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iqmarket/theme/taxi_theme.dart';

// ─── Заголовок секции ─────────────────────────────────────────────────────────

/// Заголовок секции с вертикальным акцентным маркером слева.
/// Используется над группами карточек, списков, фильтров.
class TaxiSectionHeader extends StatelessWidget {
  final TaxiTheme t;
  final String title;

  const TaxiSectionHeader({super.key, required this.t, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 12),
      child: Row(children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(color: t.accent, borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, color: t.sub, letterSpacing: 0.5),
          ),
        ),
      ]),
    );
  }
}

// ─── Mini-кнопка (поле-кнопка для выбора значения) ────────────────────────────

/// Кнопка-поле для выбора дат, времени, маршрута.
/// Поддерживает визуальное состояние ошибки валидации.
///
/// - [icon]     — иконка слева
/// - [value]    — текущее выбранное значение
/// - [onTap]    — действие при нажатии
/// - [h]        — высота (по умолчанию 44)
/// - [hasError] — показать красное состояние
class TaxiMiniBtn extends StatelessWidget {
  final TaxiTheme t;
  final IconData icon;
  final String value;
  final VoidCallback onTap;
  final double h;
  final bool hasError;

  const TaxiMiniBtn({
    super.key,
    required this.t,
    required this.icon,
    required this.value,
    required this.onTap,
    this.h = 44,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        height: h,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: hasError ? const Color(0xFFFEF2F2) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasError ? Colors.redAccent.withValues(alpha: 0.6) : const Color(0xFFF1F5F9),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Icon(icon, color: hasError ? Colors.redAccent : const Color(0xFF4A80F0), size: 16),
            const SizedBox(width: 8),
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: hasError ? Colors.redAccent : const Color(0xFF1E293B),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  if (hasError) ...[
                    const SizedBox(width: 2),
                    Text('*', style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Главная кнопка действия ──────────────────────────────────────────────────

/// Полноширинная кнопка с градиентом и тенью.
/// Используется для «Найти поездку», «Опубликовать», «Подтвердить».
///
/// - [label]  — текст (выводится заглавными буквами)
/// - [color]  — основной цвет градиента
/// - [onTap]  — действие
class TaxiActBtn extends StatelessWidget {
  final TaxiTheme t;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final double? height;
  final double? borderRadius;

  const TaxiActBtn({
    super.key,
    required this.t,
    required this.label,
    required this.color,
    required this.onTap,
    this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final double btnHeight = height ?? 54;
    final double btnRadius = borderRadius ?? 16;

    return Container(
      width: double.infinity,
      height: btnHeight,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.85)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(btnRadius),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(btnRadius)),
        ),
        child: Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.5),
        ),
      ),
    );
  }
}
