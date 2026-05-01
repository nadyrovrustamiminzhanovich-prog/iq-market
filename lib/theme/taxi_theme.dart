import 'package:flutter/material.dart';

class TaxiTheme {
  late Color bg, card, card2, text, sub, border, accent, lime, white, error, shadow;
  late bool isDark;

  // Design tokens — consistent radius values
  static const double radiusCard = 24.0;
  static const double radiusButton = 14.0;
  static const double radiusModal = 28.0;
  static const double radiusChip = 10.0;

  TaxiTheme(this.isDark) {
    white = const Color(0xFFFFFFFF);
    error = const Color(0xFFEF4444); // Red for real errors
    if (isDark) {
      bg     = const Color(0xFF0F172A);
      card   = const Color(0xFF1E293B);
      card2  = const Color(0xFF334155);
      text   = const Color(0xFFF8FAFC);
      sub    = const Color(0xFFCBD5E1);
      border = const Color(0xFF334155);
      accent = const Color(0xFF4A80F0); // Action blue
      lime   = const Color(0xFF10B981); // Success / price green
      shadow = Colors.black.withValues(alpha: 0.5);
    } else {
      bg     = const Color(0xFFFFFFFF);
      card   = const Color(0xFFFFFFFF);
      card2  = const Color(0xFFE0E7FF);
      text   = const Color(0xFF1E293B);
      sub    = const Color(0xFF475569);
      border = const Color(0xFFE2E8F0);
      accent = const Color(0xFF4A80F0); // Action blue
      lime   = const Color(0xFF10B981); // Success / price green
      shadow = const Color(0xFF4A80F0).withValues(alpha: 0.08);
    }
  }

  Color get primary => accent;
  Color get subtext => sub;
}
