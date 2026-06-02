// ─────────────────────────────────────────────────────────────────────────────
// FILE: lib/features/taxi/presentation/widgets/ui/taxi_role_selector_widget.dart
// STEP: #19 | СЛОЙ: widgets/ui
// ОТВЕЧАЕТ ЗА: переключатель «Пассажир / Водитель» (premium pill selector)
// ЗАВИСИМОСТИ: TaxiTheme, TaxiRoleCard, flutter/services — нет Firestore
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iqmarket/theme/taxi_theme.dart';
import 'package:iqmarket/widgets/taxi/taxi_ui_components.dart';

/// Pill-переключатель вкладок «Пассажир» / «Водитель».
///
/// Параметры:
/// - [t]            — текущая тема
/// - [selectedTab]  — 0 = пассажир, 1 = водитель
/// - [passengerLabel] / [driverLabel] — локализованные подписи
/// - [onTabChanged] — колбек с новым индексом, вся логика setState остаётся
///                    в родительском виджете
class TaxiRoleSelectorWidget extends StatelessWidget {
  final TaxiTheme t;
  final int selectedTab;
  final String passengerLabel;
  final String driverLabel;
  final ValueChanged<int> onTabChanged;

  const TaxiRoleSelectorWidget({
    super.key,
    required this.t,
    required this.selectedTab,
    required this.passengerLabel,
    required this.driverLabel,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          // ── Пассажир ─────────────────────────────────────────────────────
          TaxiRoleCard(
            label: passengerLabel,
            icon: Icons.person_rounded,
            isSelected: selectedTab == 0,
            t: t,
            onTap: () {
              HapticFeedback.selectionClick();
              onTabChanged(0);
            },
          ),
          // ── Водитель ──────────────────────────────────────────────────────
          TaxiRoleCard(
            label: driverLabel,
            icon: Icons.directions_car_rounded,
            isSelected: selectedTab == 1,
            t: t,
            onTap: () {
              HapticFeedback.selectionClick();
              onTabChanged(1);
            },
          ),
        ],
      ),
    );
  }
}
