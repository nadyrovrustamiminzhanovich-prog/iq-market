import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:iqmarket/services/notification_service.dart';
import 'package:iqmarket/theme/taxi_theme.dart';
import 'package:provider/provider.dart';
import 'package:iqmarket/providers/taxi_provider.dart';

class TaxiPhoneInputStep extends StatelessWidget {
  final TaxiTheme t;
  final TextEditingController phoneController;
  final MaskTextInputFormatter phoneMask;
  final bool isVerifying;
  final VoidCallback onSendCode;

  const TaxiPhoneInputStep({
    super.key,
    required this.t,
    required this.phoneController,
    required this.phoneMask,
    required this.isVerifying,
    required this.onSendCode,
  });

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TaxiProvider>(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          provider.translate('kz_phone_label'),
          style: GoogleFonts.inter(
            color: t.sub,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: t.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: t.border),
          ),
          child: Row(
            children: [
              const SizedBox(width: 4),
              Icon(Icons.phone_iphone_rounded, color: t.accent, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: phoneController,
                  inputFormatters: [phoneMask],
                  keyboardType: TextInputType.phone,
                  style: GoogleFonts.inter(
                    color: t.text,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                  onChanged: (v) {
                    // Если пользователь вводит «8...» — заменяем на +7
                    if (v.startsWith('8') || v.startsWith('+8')) {
                      String clean = v.replaceAll(RegExp(r'\D'), '');
                      if (clean.startsWith('8')) {
                        clean = '7${clean.substring(1)}';
                      }
                      phoneController.text = phoneMask.maskText(clean);
                      phoneController.selection = TextSelection.fromPosition(
                        TextPosition(offset: phoneController.text.length),
                      );
                    }
                  },
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: '(701) 000-00-00',
                    hintStyle: GoogleFonts.inter(
                      color: t.sub.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),
        GestureDetector(
          onTap: () {
            final cleanNum = phoneMask.getUnmaskedText();
            if (cleanNum.length != 10) {
              NotificationService.notify(
                context,
                provider.translate('err_input_title'),
                provider.translate('enter_full_phone'),
                isSuccess: false,
              );
              return;
            }
            HapticFeedback.mediumImpact();
            onSendCode();
          },
          child: Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  t.accent,
                  t.accent.withValues(alpha: 0.85),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: t.accent.withValues(alpha: 0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: isVerifying
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      provider.translate('send_otp_btn'),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
