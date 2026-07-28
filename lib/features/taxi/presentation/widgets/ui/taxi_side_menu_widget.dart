// ─────────────────────────────────────────────────────────────────────────────
// FILE: lib/features/taxi/presentation/widgets/ui/taxi_side_menu_widget.dart
// STEP: #20 | СЛОЙ: widgets/ui
// ОТВЕЧАЕТ ЗА: боковое меню (Drawer) — шапка с аватаром + пункты навигации
// ЗАВИСИМОСТИ: TaxiTheme, TaxiProvider (только данные: имя, фото, телефон)
//              Навигация делегируется через колбеки — нет прямого Navigator
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:line_icons/line_icons.dart';
import 'package:iqmarket/theme/taxi_theme.dart';

/// Модель одного пункта бокового меню.
class TaxiDrawerItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const TaxiDrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });
}

/// Боковое меню (Drawer) экрана IQ TAXI.
///
/// Параметры:
/// - [t]          — текущая тема
/// - [firstName], [lastName], [phone] — данные профиля
/// - [profileImage] — локальный файл фото (может быть null)
/// - [items]      — список пунктов меню (навигация через колбеки в родителе)
class TaxiSideMenuWidget extends StatelessWidget {
  final TaxiTheme t;
  final String firstName;
  final String lastName;
  final String phone;
  final String? profileImage;
  final List<TaxiDrawerItem> items;

  const TaxiSideMenuWidget({
    super.key,
    required this.t,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.profileImage,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: t.bg,
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              children: [
                for (int i = 0; i < items.length; i++) ...[
                  if (i == items.length - 1) const Divider(),
                  _buildItem(items[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Шапка Drawer ──────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 70, 24, 30),
      decoration: BoxDecoration(
        color: t.card,
        border: Border(bottom: BorderSide(color: t.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Аватар
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: t.accent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: t.accent, width: 2),
                ),
                child: ClipOval(
                  child: (profileImage != null && profileImage!.isNotEmpty)
                      ? (profileImage!.startsWith('http')
                          ? Image.network(profileImage!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Center(child: Icon(LineIcons.user, color: t.accent, size: 30)))
                          : Image.file(File(profileImage!), fit: BoxFit.cover, errorBuilder: (_, __, ___) => Center(child: Icon(LineIcons.user, color: t.accent, size: 30))))
                      : Center(child: Icon(LineIcons.user, color: t.accent, size: 30)),
                ),
              ),
              const SizedBox(width: 16),
              // Имя + телефон
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$firstName $lastName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: t.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      phone,
                      style: GoogleFonts.inter(
                        color: t.sub,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Пункт меню ────────────────────────────────────────────────────────────
  Widget _buildItem(TaxiDrawerItem item) {
    return ListTile(
      leading: Icon(item.icon, color: item.color ?? t.accent),
      title: Text(
        item.label,
        style: GoogleFonts.inter(
          color: item.color ?? t.text,
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: item.onTap,
    );
  }
}
