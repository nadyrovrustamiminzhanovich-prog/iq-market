import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iqmarket/providers/taxi_provider.dart';
import 'package:iqmarket/theme/taxi_theme.dart';
import 'package:iqmarket/data/kazakhstan_locations.dart';

/// Боттомшит выбора города (Откуда / Куда).
///
/// Позволяет искать город из списка `KazakhstanLocations.hierarchy`
/// и обновлять нужные поля в провайдере.
///
/// Использование:
/// ```dart
/// await showTaxiLocationPickerSheet(
///   context: context,
///   t: theme,
///   isFrom: true,
///   provider: provider,
///   isDriver: true,
/// );
/// ```
Future<void> showTaxiLocationPickerSheet({
  required BuildContext context,
  required TaxiTheme t,
  required bool isFrom,
  required TaxiProvider provider,
  bool isDriver = false,
}) async {
  String q = '';
  return await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: t.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
    ),
    builder: (_) => StatefulBuilder(
      builder: (ctx, ss) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            const SizedBox(height: 12),
            // Хэндл
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: t.border,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 20),
            
            // Поле поиска
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                onChanged: (v) => ss(() => q = v),
                textInputAction: TextInputAction.search,
                style: GoogleFonts.inter(
                  color: t.text,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: provider.translate('search_hint'),
                  hintStyle: GoogleFonts.inter(
                    color: t.sub.withValues(alpha: 0.5),
                  ),
                  prefixIcon: Icon(Icons.search_rounded, color: t.accent),
                  filled: true,
                  fillColor: t.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),
            const SizedBox(height: 10),
            
            // Список городов
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: () {
                  var all = KazakhstanLocations.hierarchy.entries
                      .expand((e) => e.value)
                      .where((c) =>
                          c.toLowerCase().contains(q.toLowerCase()))
                      .toList();
                  
                  if (q.isEmpty) {
                    all.remove('Чунджа');
                    all.remove('Алматы');
                    all.insert(0, 'Чунджа');
                    all.insert(1, 'Алматы');
                  }
                  
                  return all.map((city) => ListTile(
                    leading: const Icon(
                      Icons.location_on_rounded,
                      size: 20,
                      color: Color(0xFF4A80F0),
                    ),
                    title: Text(
                      city,
                      style: GoogleFonts.inter(
                        color: t.text,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () {
                      if (isDriver) {
                        if (isFrom) {
                          provider.setDriverFrom(city);
                        } else {
                          provider.setDriverTo(city);
                        }
                      } else {
                        if (isFrom) {
                          provider.setFrom(city);
                        } else {
                          provider.setTo(city);
                        }
                      }
                      Navigator.pop(context);
                    },
                  )).toList();
                }(),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
