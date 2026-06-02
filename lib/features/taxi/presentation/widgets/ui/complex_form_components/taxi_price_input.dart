import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class TaxiPriceInputWidget extends StatelessWidget {
  final TextEditingController priceController;
  final bool hasPriceError;
  final Function(String) onPriceChanged;
  final VoidCallback onPriceClear;
  final bool showPriceClear;

  const TaxiPriceInputWidget({
    super.key,
    required this.priceController,
    required this.hasPriceError,
    required this.onPriceChanged,
    required this.onPriceClear,
    required this.showPriceClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      height: 64, // slightly taller
      decoration: BoxDecoration(
        color: hasPriceError ? const Color(0xFFFFF1F2) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: hasPriceError ? const Color(0xFFFDA4AF) : const Color(0xFFF1F5F9), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: hasPriceError ? const Color(0xFFFFE4E6) : const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '₸',
              style: GoogleFonts.inter(
                color: hasPriceError ? const Color(0xFFE11D48) : const Color(0xFF4A80F0),
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              style: GoogleFonts.inter(color: hasPriceError ? const Color(0xFFE11D48) : const Color(0xFF1E293B), fontWeight: FontWeight.w800, fontSize: 16),
              onChanged: onPriceChanged,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Сумма',
                hintStyle: GoogleFonts.inter(color: hasPriceError ? const Color(0xFFFDA4AF) : const Color(0xFF94A3B8), fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          if (hasPriceError) ...[
            const SizedBox(width: 4),
            Text('*', style: GoogleFonts.inter(color: const Color(0xFFE11D48), fontWeight: FontWeight.bold, fontSize: 16)),
          ] else if (showPriceClear)
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                onPriceClear();
              },
              child: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 18),
            ),
        ],
      ),
    );
  }
}
