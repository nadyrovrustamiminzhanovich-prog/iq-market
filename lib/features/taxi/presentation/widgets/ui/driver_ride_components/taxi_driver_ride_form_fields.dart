import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iqmarket/theme/taxi_theme.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Телефон
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          height: 56,
          decoration: BoxDecoration(
            color: sPhoneError ? const Color(0xFFFFF1F2) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: sPhoneError ? const Color(0xFFFDA4AF) : const Color(0xFFE2E8F0),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 4),
              Icon(
                Icons.phone_iphone_rounded,
                color: sPhoneError ? const Color(0xFFE11D48) : const Color(0xFF4A80F0),
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'ВАШ ТЕЛЕФОН',
                      style: GoogleFonts.inter(
                        fontSize: 8.5,
                        color: sPhoneError ? const Color(0xFFE11D48) : const Color(0xFF64748B),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: phoneC,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [phoneMask],
                        style: GoogleFonts.inter(
                          color: sPhoneError ? const Color(0xFFE11D48) : const Color(0xFF1E293B),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 4),
                          hintText: '+7 (700) 000-00-00',
                          hintStyle: GoogleFonts.inter(
                            color: sPhoneError ? const Color(0xFFFDA4AF) : t.sub.withValues(alpha: 0.5),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
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
        const SizedBox(height: 20),

        // Цена
        Text(
          'ЦЕНА ЗА 1 МЕСТО',
          style: GoogleFonts.inter(
            color: t.sub,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: sPriceError ? const Color(0xFFFFF1F2) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: sPriceError ? const Color(0xFFFDA4AF) : const Color(0xFFE2E8F0),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: onPriceDecrement,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Icon(Icons.remove, color: Color(0xFF1E293B), size: 16),
                ),
              ),
              Container(
                width: 120,
                alignment: Alignment.center,
                child: TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: sPriceError ? const Color(0xFFE11D48) : t.text,
                  ),
                  decoration: InputDecoration(
                    suffixText: ' ₸',
                    suffixStyle: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: sPriceError ? const Color(0xFFE11D48) : t.text,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onChanged: onPriceChanged,
                ),
              ),
              GestureDetector(
                onTap: onPriceIncrement,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Icon(Icons.add, color: Color(0xFF1E293B), size: 16),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Комментарий
        Text(
          'КОММЕНТАРИЙ К ПОЕЗДКЕ',
          style: GoogleFonts.inter(
            color: t.sub,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: commentC,
          maxLength: 200,
          style: GoogleFonts.inter(
            color: t.text,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: Color(0xFF4A80F0), width: 1.5),
            ),
            hintText: 'Например: пустой багажник, выезд с автовокзала...',
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
