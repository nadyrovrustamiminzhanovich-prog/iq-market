// ─────────────────────────────────────────────────────────────────────────────
// FILE: lib/features/taxi/presentation/widgets/ui/taxi_top_bar_widget.dart
// STEP: #16 | СЛОЙ: widgets/ui
// ОТВЕЧАЕТ ЗА: AppBar экрана IQ TAXI (логотип, кнопка меню, SOS, назад)
// ЗАВИСИМОСТИ: TaxiTheme, google_fonts — нет Provider, нет Firestore, нет state
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iqmarket/theme/taxi_theme.dart';

/// AppBar модуля IQ TAXI.
///
/// Параметры:
/// - [t]           — текущая тема
/// - [onMenuTap]   — открыть боковое меню (Scaffold Drawer)
/// - [onSosTap]    — показать SOS-диалог (логика остаётся в родителе)
/// - [onBackTap]   — навигация назад
class TaxiTopBarWidget extends StatelessWidget implements PreferredSizeWidget {
  final TaxiTheme t;
  final VoidCallback onMenuTap;
  final VoidCallback onSosTap;
  final VoidCallback onBackTap;

  const TaxiTopBarWidget({
    super.key,
    required this.t,
    required this.onMenuTap,
    required this.onSosTap,
    required this.onBackTap,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      // ── Кнопка меню ──────────────────────────────────────────────────────
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: IconButton(
          icon: const Icon(Icons.menu_rounded, size: 22),
          color: const Color(0xFF1E293B),
          onPressed: onMenuTap,
        ),
      ),
      // ── Логотип IQ TAXI ───────────────────────────────────────────────────
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF4A80F0),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4A80F0).withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              'IQ',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'TAXI',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF1E293B),
              letterSpacing: 1,
            ),
          ),
        ],
      ),
      // ── Actions: SOS + назад ──────────────────────────────────────────────
      actions: [
        IconButton(
          icon: const Icon(Icons.gpp_maybe_rounded, color: Colors.red, size: 24),
          tooltip: 'SOS',
          onPressed: onSosTap,
        ),
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: const Color(0xFF1E293B),
          onPressed: onBackTap,
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}
