// ─────────────────────────────────────────────────────────────────────────────
// FILE: lib/features/taxi/presentation/widgets/ui/taxi_rating_widget.dart
// STEP: #25 | СЛОЙ: widgets/ui
// ОТВЕЧАЕТ ЗА: отображение рейтинга пользователя (звёзды + кол-во отзывов)
// ЗАВИСИМОСТИ: TaxiTheme, TaxiProvider (getUserRating/getUserReviewCount)
//              НЕТ Firestore, НЕТ setState — чистый display-виджет
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iqmarket/theme/taxi_theme.dart';
import 'package:iqmarket/providers/taxi_provider.dart';

/// Виджет рейтинга пользователя такси.
///
/// До 5 отзывов — показывает «Новичок» с tooltip.
/// После 5 — полноценный рейтинг: ★ 4.8 (12 отзывов).
///
/// Параметры:
/// - [userId] — UID пользователя чей рейтинг отображаем
/// - [size]   — базовый размер шрифта/иконки (по умолчанию 12)
class TaxiRatingWidget extends StatelessWidget {
  final TaxiProvider provider;
  final TaxiTheme t;
  final String userId;
  final double size;
  final String targetRole;

  const TaxiRatingWidget({
    super.key,
    required this.provider,
    required this.t,
    required this.userId,
    this.size = 12,
    this.targetRole = 'driver',
  });

  @override
  Widget build(BuildContext context) {
    final int count = targetRole == 'passenger'
        ? provider.getUserReviewCountAsPassenger(userId)
        : provider.getUserReviewCountAsDriver(userId);
    final double rating = targetRole == 'passenger'
        ? provider.getUserRatingAsPassenger(userId)
        : provider.getUserRatingAsDriver(userId);

    // ── Меньше 5 отзывов — статус «Новичок» ──────────────────────────────
    if (count < 5) {
      return Tooltip(
        message: 'Рейтинг формируется после 5 оценок от других пользователей',
        preferBelow: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_rounded, color: Colors.amber.withValues(alpha: 0.35), size: size + 2),
            const SizedBox(width: 4),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Новичок',
                    style: GoogleFonts.inter(fontSize: size - 1, color: t.sub, fontWeight: FontWeight.w600)),
                Text('Рейтинг после 5 оценок',
                    style: GoogleFonts.inter(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
      );
    }

    // ── 5+ отзывов — полноценный рейтинг ─────────────────────────────────
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star_rounded, color: Colors.amber, size: size + 2),
        const SizedBox(width: 4),
        Text('$rating',
            style: GoogleFonts.inter(fontSize: size, fontWeight: FontWeight.bold, color: t.text)),
        const SizedBox(width: 6),
        Text('($count отзывов)',
            style: GoogleFonts.inter(fontSize: size - 1, color: t.sub, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
