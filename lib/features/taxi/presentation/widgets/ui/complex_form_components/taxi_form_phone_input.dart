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
      height: 60,
      decoration: BoxDecoration(
        color: hasPhoneError ? const Color(0xFFFFF1F2) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: hasPhoneError ? const Color(0xFFFDA4AF) : const Color(0xFFF1F5F9), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: hasPhoneError ? const Color(0xFFFFE4E6) : const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.phone_iphone_rounded, 
              color: hasPhoneError ? const Color(0xFFE11D48) : const Color(0xFF1E5EE6), 
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: phoneFormatters,
              style: GoogleFonts.inter(color: hasPhoneError ? const Color(0xFFE11D48) : const Color(0xFF1E293B), fontSize: 14, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: '+7 (700) 000-00-00',
                hintStyle: GoogleFonts.inter(color: hasPhoneError ? const Color(0xFFFDA4AF) : const Color(0xFF1E293B), fontSize: 14, fontWeight: FontWeight.w700),
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
