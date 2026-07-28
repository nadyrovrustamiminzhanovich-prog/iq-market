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
              width: sPriceError ? 2.0 : 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: sPriceError ? const Color(0xFFE11D48).withValues(alpha: 0.1) : const Color(0xFF10B981).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.payments_rounded,
                  color: sPriceError ? const Color(0xFFE11D48) : const Color(0xFF10B981),
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider.translate('price_per_seat').toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        color: sPriceError ? const Color(0xFFE11D48) : const Color(0xFF64748B),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        IntrinsicWidth(
                          child: TextField(
                            controller: priceCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            style: GoogleFonts.inter(
                              color: sPriceError ? const Color(0xFFE11D48) : const Color(0xFF0F172A),
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                            decoration: const InputDecoration(
                              hintText: '2500',
                              hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onChanged: onPriceChanged,
                          ),
                        ),
                        Text(
                          ' ₸',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF2563EB),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: onPriceDecrement,
                    icon: const Icon(Icons.remove_circle_outline_rounded, color: Color(0xFF64748B), size: 28),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: onPriceIncrement,
                    icon: const Icon(Icons.add_circle_rounded, color: Color(0xFF2563EB), size: 28),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Comment Input
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: Color(0xFF8B5CF6),
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider.translate('comment_label').toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: commentC,
                      maxLines: 2,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF0F172A),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: provider.translate('comment_hint'),
                        hintStyle: GoogleFonts.inter(
                          color: const Color(0xFF94A3B8),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
