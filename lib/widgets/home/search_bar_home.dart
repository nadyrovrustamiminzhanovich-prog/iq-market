import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SearchBarHome extends StatelessWidget {
  final TextEditingController controller;
  final Function(String) onChanged;
  final VoidCallback onMicTap;
  final VoidCallback onFilterTap;

  const SearchBarHome({
    super.key, 
    required this.controller,
    required this.onChanged,
    required this.onMicTap,
    required this.onFilterTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02), 
            blurRadius: 10, 
            offset: const Offset(0, 4)
          ),
        ],

      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: Color(0xFF94A3B8), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF1E293B)),
              decoration: InputDecoration(
                hintText: 'Поиск товаров, услуг и объявлений',
                hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13),
                border: InputBorder.none,
                isDense: true,
              ),
              onChanged: onChanged,
            ),
          ),
          IconButton(
            onPressed: onMicTap,
            icon: Icon(
              Icons.mic_none_rounded, 
              color: const Color(0xFF4A80F0).withValues(alpha: 0.7), 
              size: 20
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 4), // Меньше отступ
          IconButton(
            onPressed: onFilterTap,
            icon: const Icon(Icons.tune_rounded, color: Color(0xFF4A80F0), size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 4), // Отступ от края
        ],
      ),
    );

  }
}
