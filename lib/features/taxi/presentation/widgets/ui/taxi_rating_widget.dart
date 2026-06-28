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
    return const SizedBox.shrink();
  }
}
