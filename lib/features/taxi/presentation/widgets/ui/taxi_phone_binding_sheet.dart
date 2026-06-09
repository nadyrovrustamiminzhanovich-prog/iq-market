import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:iqmarket/providers/taxi_provider.dart';
import 'package:iqmarket/services/notification_service.dart';
import 'package:iqmarket/theme/taxi_theme.dart';
import 'package:iqmarket/features/taxi/data/taxi_otp_service.dart';
import 'package:iqmarket/features/taxi/presentation/widgets/ui/phone_binding_components/taxi_phone_input_step.dart';
import 'package:iqmarket/features/taxi/presentation/widgets/ui/phone_binding_components/taxi_otp_input_step.dart';

/// Боттомшит привязки номера телефона (OTP-верификация).
void showTaxiPhoneBindingSheet(
  BuildContext context,
  TaxiProvider provider,
  TaxiTheme t,
  VoidCallback onSuccess,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _TaxiPhoneBindingSheetContent(
      provider: provider,
      t: t,
      onSuccess: onSuccess,
    ),
  );
}

class _TaxiPhoneBindingSheetContent extends StatefulWidget {
  final TaxiProvider provider;
  final TaxiTheme t;
  final VoidCallback onSuccess;

  const _TaxiPhoneBindingSheetContent({
    required this.provider,
    required this.t,
    required this.onSuccess,
  });

  @override
  State<_TaxiPhoneBindingSheetContent> createState() => _TaxiPhoneBindingSheetContentState();
}

class _TaxiPhoneBindingSheetContentState extends State<_TaxiPhoneBindingSheetContent> {
  final TaxiOtpService _otpService = TaxiOtpService();
  
  late final MaskTextInputFormatter _phoneMask;
  late final TextEditingController _phoneC;
  late final TextEditingController _otpC;
  late final ValueNotifier<int> _secondsLeft;
  
  Timer? _timer;
  
  bool _codeSent = false;
  bool _isVerifying = false;
  bool _isOtpError = false;

  @override
  void initState() {
    super.initState();
    _phoneMask = MaskTextInputFormatter(
      mask: '+7 (###) ###-##-##',
      filter: {'#': RegExp(r'[0-9]')},
      type: MaskAutoCompletionType.lazy,
    );
    _phoneC = TextEditingController();
    _otpC = TextEditingController();
    _secondsLeft = ValueNotifier<int>(60);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _phoneC.dispose();
    _otpC.dispose();
    _secondsLeft.dispose();
    super.dispose();
  }

  void _startTimer() {
    _secondsLeft.value = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (tm) {
      if (_secondsLeft.value > 0) {
        _secondsLeft.value--;
      } else {
        tm.cancel();
      }
    });
  }

  Future<void> _handleSendCode() async {
    setState(() => _isVerifying = true);

    final formattedNum = _phoneMask.getMaskedText();
    final generatedCode = await _otpService.sendSms(formattedNum);

    setState(() {
      _isVerifying = false;
      _codeSent = true;
    });
    
    _startTimer();

    // Показываем код в dev-диалоге (SMS-шлюз)
    if (mounted) {
      showDialog(
        context: context,
        builder: (cx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              const Icon(Icons.sms_rounded, color: Color(0xFF4A80F0), size: 28),
              const SizedBox(width: 12),
              Text(
                widget.provider.translate('sms_gateway_title'),
                style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.provider.translate('sms_sent_to').replaceAll('{phone}', formattedNum),
                style: GoogleFonts.inter(color: Colors.grey[700], fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A80F0).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF4A80F0).withValues(alpha: 0.15)),
                  ),
                  child: Text(
                    generatedCode,
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF4A80F0),
                      letterSpacing: 4,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(cx),
              child: Text(widget.provider.translate('got_it'), style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _handleOtpChanged(String val) async {
    if (val.length == 6) {
      if (_otpService.verifyOtp(val)) {
        _timer?.cancel();
        setState(() => _isVerifying = true);

        final verifiedPhone = _phoneMask.getMaskedText();
        widget.provider.updateProfile(
          widget.provider.firstName,
          widget.provider.lastName,
          verifiedPhone,
        );

        await Future.delayed(const Duration(milliseconds: 600));

        if (mounted) {
          Navigator.pop(context); // закрываем боттомшит
          HapticFeedback.heavyImpact();
          NotificationService.notify(
            context,
            widget.provider.translate('success_title'),
            widget.provider.translate('phone_confirmed_success'),
            isSuccess: true,
          );
          widget.onSuccess();
        }
      } else {
        HapticFeedback.vibrate();
        setState(() {
          _isOtpError = true;
          _otpC.clear();
        });
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) setState(() => _isOtpError = false);
        });
      }
    }
  }

  void _handleResend() {
    setState(() {
      _codeSent = false;
      _otpC.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 24,
        left: 24,
        right: 24,
      ),
      decoration: BoxDecoration(
        color: t.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 25,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: t.border,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: t.accent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.phone_iphone_rounded, color: t.accent, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      !_codeSent ? widget.provider.translate('phone_binding_title') : widget.provider.translate('enter_otp_title'),
                      style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 18, color: t.text),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      !_codeSent ? widget.provider.translate('phone_binding_desc') : widget.provider.translate('otp_sent_desc'),
                      style: GoogleFonts.inter(color: t.sub, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          if (!_codeSent)
            TaxiPhoneInputStep(
              t: t,
              phoneController: _phoneC,
              phoneMask: _phoneMask,
              isVerifying: _isVerifying,
              onSendCode: _handleSendCode,
            )
          else
            TaxiOtpInputStep(
              t: t,
              otpController: _otpC,
              isOtpError: _isOtpError,
              secondsLeft: _secondsLeft,
              onResend: _handleResend,
              onChanged: _handleOtpChanged,
            ),
          const SizedBox(height: 35),
        ],
      ),
    );
  }
}
