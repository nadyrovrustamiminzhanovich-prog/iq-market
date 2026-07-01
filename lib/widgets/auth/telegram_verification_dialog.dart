import 'dart:async';
import 'package:iqmarket/services/translation_service.dart';
import 'package:iqmarket/providers/app_config_provider.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:iqmarket/providers/taxi_provider.dart';
import 'package:iqmarket/services/auth_service.dart';
import 'package:iqmarket/services/telegram_bot_service.dart';
import 'package:iqmarket/services/user_service.dart';
import 'package:iqmarket/services/storage_service.dart';
import 'package:iqmarket/theme/taxi_theme.dart';

class TelegramVerificationDialog extends StatefulWidget {
  final TaxiProvider provider;

  const TelegramVerificationDialog({super.key, required this.provider});

  static Future<bool> show(BuildContext context, {required TaxiProvider provider}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) => TelegramVerificationDialog(provider: provider),
    );
    return result ?? false;
  }

  @override
  State<TelegramVerificationDialog> createState() => _TelegramVerificationDialogState();
}

class _TelegramVerificationDialogState extends State<TelegramVerificationDialog> {
  int _step = 0; // 0: Phone Input, 1: Waiting for Bot / OTP code
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _codeCtrl = TextEditingController();
  
  final MaskTextInputFormatter _phoneMask = MaskTextInputFormatter(
    mask: '+7 (###) ###-##-##',
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );

  bool _isWaitingForBot = false;
  bool _isTimerRunning = false;
  int _timerSeconds = 60;
  Timer? _timer;
  
  String? _tgSessionToken;
  String? _tgCode;
  String? _chatId;
  StreamSubscription? _tgSessionSub;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _prefillPhone();
  }

  void _prefillPhone() {
    final user = FirebaseAuth.instance.currentUser;
    String initialPhone = user?.phoneNumber ?? '';
    if (initialPhone.isEmpty) {
      initialPhone = widget.provider.phone;
    }
    if (initialPhone.isNotEmpty) {
      final digits = initialPhone.replaceAll(RegExp(r'\D'), '');
      String localDigits = digits;
      if (digits.length == 11 && (digits.startsWith('7') || digits.startsWith('8'))) {
        localDigits = digits.substring(1);
      } else if (digits.length > 11) {
        localDigits = digits.substring(digits.length - 10);
      }
      _phoneCtrl.text = _phoneMask.maskText(localDigits);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tgSessionSub?.cancel();
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  void _startTimer() {
    setState(() {
      _timerSeconds = 60;
      _isTimerRunning = true;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerSeconds == 0) {
        setState(() => _isTimerRunning = false);
        timer.cancel();
      } else {
        setState(() => _timerSeconds--);
      }
    });
  }

  bool _validatePhone(String cleanPhone) {
    if (cleanPhone.length != 11) {
      setState(() => _errorText = 'Номер должен состоять из 11 цифр! Пример: +7 (707) 123-45-67');
      return false;
    }
    if (!cleanPhone.startsWith('7')) {
      setState(() => _errorText = 'Номер должен начинаться с +7 или 8!');
      return false;
    }
    final operatorCode = cleanPhone.substring(1, 4);
    final validPrefixes = [
      '700', '701', '702', '703', '704', '705', '706', '707', '708', '709',
      '747', '750', '751', '760', '761', '762', '763', '764',
      '771', '775', '776', '777', '778'
    ];
    if (!validPrefixes.contains(operatorCode)) {
      setState(() => _errorText = 'Неверный код оператора Казахстана: $operatorCode');
      return false;
    }
    return true;
  }

  Future<void> _sendCode() async {
    String cleanPhone = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.startsWith('8') && cleanPhone.length == 11) {
      cleanPhone = '7' + cleanPhone.substring(1);
    } else if (cleanPhone.length == 10) {
      cleanPhone = '7' + cleanPhone;
    }

    if (!_validatePhone(cleanPhone)) return;

    setState(() {
      _isWaitingForBot = true;
      _errorText = null;
    });

    try {
      // 1. Start Telegram Session
      _tgSessionToken = await AuthService.startTelegramSession(phone: cleanPhone);
      
      // Open Telegram immediately
      final botUrl = TelegramBotService.buildBotUrl(_tgSessionToken!);
      await launchUrl(Uri.parse(botUrl), mode: LaunchMode.externalApplication);

      // 2. Watch Telegram session stream
      _tgSessionSub?.cancel();
      _tgSessionSub = AuthService.watchTelegramSession(_tgSessionToken!).listen((snap) {
        if (!snap.exists) return;
        final data = snap.data();
        if (data == null) return;
        
        final String? chatId = data['chat_id'];
        final String? otp = data['otp'];
        
        if (chatId != null && otp != null && otp.isNotEmpty) {
          _tgSessionSub?.cancel();
          setState(() {
            _tgCode = otp;
            _chatId = chatId;
            _isWaitingForBot = false;
            _step = 1;
          });
          _startTimer();
        }
      });
    } catch (e) {
      setState(() {
        _isWaitingForBot = false;
        _errorText = 'Ошибка запуска сессии: $e';
      });
    }
  }

  Future<void> _verifyOtp() async {
    if (_codeCtrl.text.trim() == _tgCode) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          // 1. Update Firestore user doc
          await UserService.updateUserProfile({
            'isVerified': true,
            'phone': _phoneCtrl.text,
            'telegramChatId': _chatId,
          });

          // 2. Sync to local storage
          StorageService.saveProfile(
            widget.provider.firstName + " " + widget.provider.lastName,
            null,
            false,
            widget.provider.verificationStatus,
            isVerified: true,
          );
          await StorageService.setString('user_phone', _phoneCtrl.text);

          // 3. Update Provider state
          if (_chatId != null) {
            widget.provider.setTelegramAuth(_chatId!);
            widget.provider.updateProfile(widget.provider.firstName, widget.provider.lastName, _phoneCtrl.text);
          }
        }
        
        if (mounted) {
          Navigator.pop(context, true);
        }
      } catch (e) {
        setState(() => _errorText = 'Ошибка сохранения: $e');
      }
    } else {
      setState(() {
        _codeCtrl.clear();
        _errorText = 'Неверный код! Проверьте и попробуйте еще раз. ❌';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.provider.theme;
    
    return Container(
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: t.border.withValues(alpha: 0.1), width: 1.5),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24, 
        top: 16, 
        left: 24, 
        right: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40, 
            height: 4, 
            decoration: BoxDecoration(
              color: t.border.withValues(alpha: 0.3), 
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 24),
          
          if (_step == 0) _buildPhoneInputStep(t) else _buildOtpStep(t),
        ],
      ),
    );
  }

  Widget _buildPhoneInputStep(TaxiTheme t) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0088CC).withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.telegram_rounded, color: Color(0xFF0088CC), size: 48),
        ),
        const SizedBox(height: 16),
        Text(
          'Привязка Telegram',
          style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: t.text),
        ),
        const SizedBox(height: 8),
        Text(
          'Для безопасности поездок необходимо подтвердить номер телефона через Telegram-бота.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 13, color: t.sub, height: 1.4),
        ),
        const SizedBox(height: 24),

        // Phone text field
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: t.bg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _errorText != null ? Colors.redAccent : t.border),
          ),
          child: TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            inputFormatters: [_phoneMask],
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: t.text),
            enabled: !_isWaitingForBot,
            decoration: InputDecoration(
              hintText: '+7 (700) 000-00-00',
              hintStyle: TextStyle(color: t.sub.withValues(alpha: 0.4)),
              border: InputBorder.none,
              prefixIcon: Icon(Icons.phone, color: t.accent, size: 20),
            ),
          ),
        ),

        if (_errorText != null) ...[
          const SizedBox(height: 12),
          Text(
            _errorText!,
            style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ],

        if (_isWaitingForBot) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0088CC).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF0088CC).withValues(alpha: 0.15)),
            ),
            child: Column(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Color(0xFF0088CC), strokeWidth: 2.5),
                ),
                const SizedBox(height: 12),
                Text(
                  'Ожидаем запуск бота... 🤖',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: t.text),
                ),
                const SizedBox(height: 6),
                Text(
                  'В Telegram нажмите кнопку «СТАРТ» (запустить) и поделитесь контактом для подтверждения.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 11, color: t.sub, height: 1.4),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _isWaitingForBot ? null : _sendCode,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0088CC),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 0,
            ),
            child: _isWaitingForBot 
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(TranslationService.t('openTelegramBtn', Provider.of<AppConfigProvider>(context, listen: false).language), style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 15)),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(TranslationService.t('cancel', Provider.of<AppConfigProvider>(context, listen: false).language), style: GoogleFonts.inter(color: t.sub, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildOtpStep(TaxiTheme t) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF229ED9), Color(0xFF0088CC)],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.telegram, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text(
                'Код отправлен в Telegram',
                style: GoogleFonts.inter(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Введите 6-значный код:',
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: t.text),
        ),
        const SizedBox(height: 16),

        Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: 0.0,
              child: TextField(
                controller: _codeCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                autofocus: true,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (v) {
                  if (v.length == 6) {
                    _verifyOtp();
                  }
                  setState(() {});
                },
                decoration: const InputDecoration(counterText: ""),
              ),
            ),
            IgnorePointer(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) {
                  String char = "";
                  if (_codeCtrl.text.length > index) {
                    char = _codeCtrl.text[index];
                  }
                  
                  bool isFocused = _codeCtrl.text.length == index;
                  if (_codeCtrl.text.length == 6 && index == 5) {
                    isFocused = true;
                  }
                  
                  return Container(
                    width: 44,
                    height: 52,
                    decoration: BoxDecoration(
                      color: t.bg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isFocused ? const Color(0xFF0088CC) : t.border,
                        width: isFocused ? 2.2 : 1.0,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      char,
                      style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: t.text),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),

        if (_errorText != null) ...[
          const SizedBox(height: 16),
          Text(
            _errorText!,
            style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ],

        const SizedBox(height: 24),
        if (_isTimerRunning)
          Text(
            'Запросить код повторно через $_timerSeconds с',
            style: GoogleFonts.inter(color: t.sub, fontSize: 12, fontWeight: FontWeight.w600),
          )
        else
          TextButton(
            onPressed: () {
              setState(() => _step = 0);
            },
            child: Text(TranslationService.t('requestVerificationCodeAgain', Provider.of<AppConfigProvider>(context, listen: false).language), style: const TextStyle(color: Color(0xFF0088CC), fontWeight: FontWeight.bold)),
          ),
        
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _codeCtrl.text.length == 6 ? _verifyOtp : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0088CC),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 0,
            ),
            child: Text(TranslationService.t('confirmBtnCap', Provider.of<AppConfigProvider>(context, listen: false).language), style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 15)),
          ),
        ),
      ],
    );
  }
}
