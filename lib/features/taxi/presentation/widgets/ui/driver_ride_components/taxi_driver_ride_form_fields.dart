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
        // 1. PHONE CARD
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: sPhoneError ? const Color(0xFFFDA4AF) : const Color(0xFFF1F5F9),
              width: sPhoneError ? 2.0 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: sPhoneError ? const Color(0xFFFFF1F2) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(
                    Icons.call_outlined,
                    color: sPhoneError ? const Color(0xFFE11D48) : const Color(0xFF2563EB),
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      provider.translate('your_phone').toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: sPhoneError ? const Color(0xFFE11D48) : const Color(0xFF94A3B8),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    TextField(
                      controller: phoneC,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [phoneMask],
                      style: GoogleFonts.inter(
                        color: sPhoneError ? const Color(0xFFE11D48) : const Color(0xFF0F172A),
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        hintText: '+7 (708) 900-70-30',
                        hintStyle: GoogleFonts.inter(
                          color: sPhoneError ? const Color(0xFFFDA4AF) : const Color(0xFF94A3B8),
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                        counterText: '',
                      ),
                      onChanged: onPhoneChanged,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF64748B),
                size: 24,
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // 2. PRICE PER SEAT CARD
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: sPriceError ? const Color(0xFFFDA4AF) : const Color(0xFFF1F5F9),
              width: sPriceError ? 2.0 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: sPriceError ? const Color(0xFFFFF1F2) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(
                    Icons.account_balance_wallet_outlined,
                    color: sPriceError ? const Color(0xFFE11D48) : const Color(0xFF2563EB),
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      provider.translate('price_per_seat').toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: sPriceError ? const Color(0xFFE11D48) : const Color(0xFF94A3B8),
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
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                            decoration: InputDecoration(
                              hintText: '2500',
                              hintStyle: GoogleFonts.inter(
                                color: const Color(0xFF94A3B8),
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                              ),
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
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            color: sPriceError ? const Color(0xFFE11D48) : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  InkWell(
                    onTap: onPriceDecrement,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.remove_rounded,
                          color: Color(0xFF2563EB),
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: onPriceIncrement,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // 3. COMMENT CARD
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFF1F5F9),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: Color(0xFF2563EB),
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider.translate('comment_label').toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: const Color(0xFF94A3B8),
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
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: provider.translate('comment_hint'),
                        hintStyle: GoogleFonts.inter(
                          color: const Color(0xFF94A3B8),
                          fontSize: 14,
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

