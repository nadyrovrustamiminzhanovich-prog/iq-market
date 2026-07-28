import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iqmarket/theme/taxi_theme.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:provider/provider.dart';
import 'package:iqmarket/providers/taxi_provider.dart';

class TaxiDriverRideFormFields extends StatelessWidget {
  final TaxiTheme t;
  final TextEditingController phoneC;
  final TextEditingController priceCtrl;
  final TextEditingController commentC;
  final MaskTextInputFormatter phoneMask;
  final bool sPhoneError;
  final bool sPriceError;
  final VoidCallback onPriceDecrement;
  final VoidCallback onPriceIncrement;
  final ValueChanged<String> onPhoneChanged;
  final ValueChanged<String> onPriceChanged;

  const TaxiDriverRideFormFields({
    super.key,
    required this.t,
    required this.phoneC,
    required this.priceCtrl,
    required this.commentC,
    required this.phoneMask,
    required this.sPhoneError,
    required this.sPriceError,
    required this.onPriceDecrement,
    required this.onPriceIncrement,
    required this.onPhoneChanged,
    required this.onPriceChanged,
  });

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TaxiProvider>(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Phone Input
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          height: 60,
          decoration: BoxDecoration(
            color: sPhoneError ? const Color(0xFFFFF1F2) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: sPhoneError ? const Color(0xFFFDA4AF) : const Color(0xFFE2E8F0),
              width: sPhoneError ? 2.0 : 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: sPhoneError ? const Color(0xFFE11D48).withValues(alpha: 0.1) : const Color(0xFF2563EB).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.phone_iphone_rounded,
                  color: sPhoneError ? const Color(0xFFE11D48) : const Color(0xFF2563EB),
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      provider.translate('your_phone').toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        color: sPhoneError ? const Color(0xFFE11D48) : const Color(0xFF64748B),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Expanded(
                      child: TextField(
                        controller: phoneC,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [phoneMask],
                        style: GoogleFonts.inter(
                          color: sPhoneError ? const Color(0xFFE11D48) : const Color(0xFF0F172A),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 2),
                          hintText: '+7 (700) 000-00-00',
                          hintStyle: GoogleFonts.inter(
                            color: sPhoneError ? const Color(0xFFFDA4AF) : const Color(0xFF94A3B8),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          counterText: '',
                        ),
                        onChanged: onPhoneChanged,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Price Input
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: sPriceError ? const Color(0xFFFFF1F2) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: sPriceError ? const Color(0xFFFDA4AF) : const Color(0xFFE2E8F0),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: Color(0xFF4A80F0), width: 1.5),
            ),
            hintText: provider.translate('comment_placeholder_driver'),
            hintStyle: GoogleFonts.inter(
              color: t.sub.withValues(alpha: 0.4),
              fontSize: 12,
            ),
            counterText: '',
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }
}
