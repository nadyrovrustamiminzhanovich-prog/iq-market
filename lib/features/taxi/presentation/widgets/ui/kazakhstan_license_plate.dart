import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Виджет для стильного и реалистичного отображения автомобильного госномера Республики Казахстан (KZ).
///
/// Пример: `677 AEY 05` -> Флаг 🇰🇿 KZ | 677 AEY | 05
class KazakhstanLicensePlate extends StatelessWidget {
  final String plate;
  final double fontSize;

  const KazakhstanLicensePlate({
    super.key,
    required this.plate,
    this.fontSize = 13,
  });

  @override
  Widget build(BuildContext context) {
    final clean = plate.trim().replaceAll(RegExp(r'\s+'), ' ').toUpperCase();
    if (clean.isEmpty || clean == 'Б/Н') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Text(
          'Б/Н',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF64748B),
          ),
        ),
      );
    }

    // Парсим госномер: разделяем основную часть и код региона (последние 2 цифры)
    String mainPart = clean;
    String regionPart = '';

    final regex = RegExp(r'^(\d{3}\s?[A-Z]{2,3})\s?(\d{2})$');
    final match = regex.firstMatch(clean.replaceAll(' ', ''));
    if (match != null) {
      final digitsLetters = match.group(1)!;
      final digits = digitsLetters.substring(0, 3);
      final letters = digitsLetters.substring(3);
      mainPart = '$digits $letters';
      regionPart = match.group(2)!;
    } else {
      final parts = clean.split(' ');
      if (parts.length >= 2 && RegExp(r'^\d{2}$').hasMatch(parts.last)) {
        regionPart = parts.last;
        mainPart = parts.sublist(0, parts.length - 1).join(' ');
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF1E293B), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Левый блок с флагом Казахстана и надписью KZ
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
              color: const Color(0xFF00A3E0), // Лазурный цвет флага РК
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🇰🇿', style: TextStyle(fontSize: 10, height: 1)),
                  const SizedBox(height: 1),
                  Text(
                    'KZ',
                    style: GoogleFonts.inter(
                      fontSize: 7.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.5,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
            Container(width: 1.2, color: const Color(0xFF1E293B)),
            // Основной номер (буквы и цифры)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              child: Text(
                mainPart,
                style: GoogleFonts.firaCode(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                  letterSpacing: 1.1,
                ),
              ),
            ),
            // Код региона (если есть)
            if (regionPart.isNotEmpty) ...[
              Container(width: 1.2, color: const Color(0xFF1E293B)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                child: Text(
                  regionPart,
                  style: GoogleFonts.firaCode(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0F172A),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
