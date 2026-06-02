import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class TaxiFormPhoneInputWidget extends StatelessWidget {
  final TextEditingController phoneController;
  final List<TextInputFormatter> phoneFormatters;
  final bool hasPhoneError;
  final Function(String) onPhoneChanged;

  const TaxiFormPhoneInputWidget({
    super.key,
    required this.phoneController,
    required this.phoneFormatters,
    required this.hasPhoneError,
    required this.onPhoneChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      height: 54,
      decoration: BoxDecoration(
        color: hasPhoneError ? const Color(0xFFFFF1F2) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: hasPhoneError ? const Color(0xFFFDA4AF) : const Color(0xFFF1F5F9), width: 1.5),
      ),
      child: Row(
        children: [
          const SizedBox(width: 4),
          Icon(
            Icons.phone_iphone_rounded, 
            color: hasPhoneError ? const Color(0xFFE11D48) : const Color(0xFF4A80F0), 
            size: 22
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: phoneFormatters,
              style: GoogleFonts.inter(color: hasPhoneError ? const Color(0xFFE11D48) : const Color(0xFF1E293B), fontSize: 14, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: '+7 (700) 000-00-00',
                hintStyle: GoogleFonts.inter(color: hasPhoneError ? const Color(0xFFFDA4AF) : const Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w500),
                counterText: '',
              ),
              onChanged: onPhoneChanged,
            ),
          ),
          if (hasPhoneError) ...[
            const SizedBox(width: 4),
            Text('*', style: GoogleFonts.inter(color: const Color(0xFFE11D48), fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ],
      ),
    );
  }
}
