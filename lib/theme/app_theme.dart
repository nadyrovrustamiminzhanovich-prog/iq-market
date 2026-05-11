import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF4A80F0),
        primary: const Color(0xFF4A80F0),
        surface: Colors.white,
        onSurface: const Color(0xFF1E293B),
        surfaceContainerHighest: const Color(0xFFF1F5F9),
      ),
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      textTheme: GoogleFonts.interTextTheme(),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Color(0xFF1E293B)),
      ),
    );
  }

  static Map<String, Map<String, dynamic>> get homeThemes {
    return {
      'Light': {
        'primary': const Color(0xFF4A80F0),
        'background': Colors.white,
        'surface': Colors.white,
        'text': const Color(0xFF1A1D1E),
        'subtext': const Color(0xFF475569),
        'grad': [const Color(0xFF4A80F0), const Color(0xFF1E40AF)]
      },
      'Dark': {
        'primary': const Color(0xFF38BDF8),
        'background': const Color(0xFF0F172A),
        'surface': const Color(0xFF1E293B),
        'text': const Color(0xFFF8FAFC),
        'subtext': const Color(0xFFCBD5E1),
        'grad': [const Color(0xFF0F172A), const Color(0xFF1E293B)]
      },
    };
  }
}
