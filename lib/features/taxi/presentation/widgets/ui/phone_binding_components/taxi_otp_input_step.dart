import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iqmarket/theme/taxi_theme.dart';
import 'package:provider/provider.dart';
import 'package:iqmarket/providers/taxi_provider.dart';

class TaxiOtpInputStep extends StatelessWidget {
  final TaxiTheme t;
  final TextEditingController otpController;
  final bool isOtpError;
  final ValueNotifier<int> secondsLeft;
  final VoidCallback onResend;
  final Function(String) onChanged;

  const TaxiOtpInputStep({
    super.key,
    required this.t,
    required this.otpController,
    required this.isOtpError,
    required this.secondsLeft,
    required this.onResend,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TaxiProvider>(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          provider.translate('otp_confirm_label'),
          style: GoogleFonts.inter(
            color: t.sub,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: otpController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          style: GoogleFonts.inter(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            letterSpacing: 8,
            color: isOtpError ? Colors.red : t.text,
          ),
          decoration: InputDecoration(
            counterText: '',
            hintText: '••••••',
            hintStyle: GoogleFonts.inter(
              color: t.sub.withValues(alpha: 0.2),
              fontSize: 32,
            ),
            border: InputBorder.none,
          ),
          onChanged: onChanged,
        ),
        const SizedBox(height: 16),
        if (isOtpError)
          Center(
            child: Text(
              provider.translate('invalid_otp_err'),
              style: GoogleFonts.inter(
                color: Colors.redAccent,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        const SizedBox(height: 20),
        Center(
          child: ValueListenableBuilder<int>(
            valueListenable: secondsLeft,
            builder: (context, seconds, child) {
              if (seconds > 0) {
                return Text(
                  provider.translate('resend_code_in').replaceAll('{sec}', '$seconds'),
                  style: GoogleFonts.inter(
                    color: t.sub,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                );
              } else {
                return TextButton(
                  onPressed: onResend,
                  child: Text(
                    provider.translate('resend_code_btn'),
                    style: GoogleFonts.inter(
                      color: t.accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                );
              }
            },
          ),
        ),
      ],
    );
  }
}
