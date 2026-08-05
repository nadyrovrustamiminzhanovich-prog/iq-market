import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:provider/provider.dart';
import 'package:iqmarket/providers/app_config_provider.dart';
import 'package:iqmarket/services/storage_service.dart';
import 'package:iqmarket/services/user_service.dart';

/// Удобный и стильный BottomSheet для ввода номера телефона
/// или отображения предупреждения, если у собеседника не указан номер.
class PhoneRequiredBottomSheet extends StatefulWidget {
  final String? title;
  final String? subtitle;
  final String? confirmText;
  final String? initialPhone;
  final bool isInputMode;
  final String? targetUserName;
  final VoidCallback? onChatTap;

  const PhoneRequiredBottomSheet({
    super.key,
    this.title,
    this.subtitle,
    this.confirmText,
    this.initialPhone,
    this.isInputMode = true,
    this.targetUserName,
    this.onChatTap,
  });

  /// 1. Мягкое всплывающее окно для ВВОДА собственного номера телефона
  static Future<bool> showInput(
    BuildContext context, {
    String? title,
    String? subtitle,
    String? confirmText,
    String? initialPhone,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) => PhoneRequiredBottomSheet(
        title: title,
        subtitle: subtitle,
        confirmText: confirmText,
        initialPhone: initialPhone,
        isInputMode: true,
      ),
    );
    return result ?? false;
  }

  /// 2. Мягкое всплывающее окно, если у СОБЕСЕДНИКА не указан номер телефона
  static Future<void> showMissingNotice(
    BuildContext context, {
    String? targetUserName,
    VoidCallback? onChatTap,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) => PhoneRequiredBottomSheet(
        isInputMode: false,
        targetUserName: targetUserName,
        onChatTap: onChatTap,
      ),
    );
  }

  @override
  State<PhoneRequiredBottomSheet> createState() => _PhoneRequiredBottomSheetState();
}

class _PhoneRequiredBottomSheetState extends State<PhoneRequiredBottomSheet> with SingleTickerProviderStateMixin {
  late final TextEditingController _phoneController;
  late final MaskTextInputFormatter _phoneMask;
  late AnimationController _animController;
  late Animation<double> _pulseAnimation;
  
  bool _isLoading = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _phoneMask = MaskTextInputFormatter(
      mask: '+7 (###) ###-##-##',
      filter: {"#": RegExp(r'[0-9]')},
    );

    String startPhone = widget.initialPhone ?? StorageService.getString('user_phone') ?? '';
    if (startPhone.startsWith('+7')) {
      startPhone = startPhone.substring(2);
    } else if (startPhone.startsWith('7') || startPhone.startsWith('8')) {
      startPhone = startPhone.substring(1);
    }
    
    _phoneController = TextEditingController(
      text: startPhone.isNotEmpty ? _phoneMask.maskText(startPhone) : '',
    );

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _submitPhone() async {
    final unmaskedDigits = _phoneMask.getUnmaskedText().trim();
    if (unmaskedDigits.length < 10) {
      setState(() {
        _errorText = _t('error_invalid_phone');
      });
      return;
    }

    final fullPhone = '+7$unmaskedDigits';

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      // Сохраняем номер локально и в Firestore
      await StorageService.saveString('user_phone', fullPhone);
      await UserService.updateUserProfile({'phone': fullPhone});

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorText = 'Ошибка сохранения: $e';
        });
      }
    }
  }

  String _t(String key) {
    final language = Provider.of<AppConfigProvider>(context, listen: false).language;
    final dict = {
      'input_title': {
        'Русский': 'Укажите ваш номер телефона',
        'Қазақша': 'Телефон нөміріңізді көрсетіңіз',
        'Уйғурчә': 'Телефон номуриңизни көрситиң',
      },
      'input_subtitle': {
        'Русский': 'Укажите ваш номер телефона, чтобы продавец мог связаться с вами и обсудить детали.',
        'Қазақша': 'Сатушы сізбен хабарласып, мәліметтерді талқылай алуы үшін телефон нөміріңізді енгізіңіз.',
        'Уйғурчә': 'Сатқучи сиз билан алоқиға чиқип тәфсилатларни муһакимә қилалиши үчүн телефон номуриңизни йезиң.',
      },
      'confirm_btn': {
        'Русский': 'Сохранить и продолжить',
        'Қазақша': 'Сақтау және жалғастыру',
        'Уйғурчә': 'Сақлаш вә давамлаштуруш',
      },
      'missing_title': {
        'Русский': 'Номер телефона не указан',
        'Қазақша': 'Телефон нөмірі көрсетілмеген',
        'Уйғурчә': 'Телефон номури көрситилмигән',
      },
      'missing_subtitle': {
        'Русский': widget.targetUserName != null && widget.targetUserName!.isNotEmpty
            ? 'Пользователь ${widget.targetUserName} пока не добавил номер телефона в свой профиль. Вы можете написать ему в чат.'
            : 'Пользователь пока не добавил номер телефона в свой профиль. Вы можете обсудить детали прямо в чате.',
        'Қазақша': 'Пайдаланушы профиліне телефон нөмірін әлі қоспаған. Чатта хабарлама жаза аласыз.',
        'Уйғурчә': 'Пайдиланғучи профилиға телефон номурини әли қошмиған. Чатта уқтуруш йезалписиз.',
      },
      'open_chat': {
        'Русский': 'Написать в чат',
        'Қазақша': 'Чатқа жазу',
        'Уйғурчә': 'Чатқа йезиш',
      },
      'add_my_phone': {
        'Русский': 'Добавить мой номер в профиль',
        'Қазақша': 'Профильге нөмірімді қосу',
        'Уйғурчә': 'Профильға номуримни қошуш',
      },
      'cancel': {
        'Русский': 'Позже',
        'Қазақша': 'Кейінірек',
        'Уйғурчә': 'Кейинәрәк',
      },
      'error_invalid_phone': {
        'Русский': 'Введите корректный 10-значный номер',
        'Қазақша': 'Дұрыс 10 таңбалы нөмірді енгізіңіз',
        'Уйғурчә': 'Тоғра 10 санлиқ номурни йезиң',
      },
    };

    final entry = dict[key];
    if (entry == null) return key;
    return entry[language] ?? entry['Русский'] ?? key;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 20, 24, bottomInset + 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 20,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Drag handle
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 24),

          // Animated Icon Badge
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: widget.isInputMode
                      ? [const Color(0xFF2563EB), const Color(0xFF3B82F6)]
                      : [const Color(0xFF0F172A), const Color(0xFF334155)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (widget.isInputMode ? const Color(0xFF2563EB) : const Color(0xFF0F172A)).withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(
                widget.isInputMode ? Icons.phone_android_rounded : Icons.phone_disabled_rounded,
                size: 34,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            widget.title ?? (widget.isInputMode ? _t('input_title') : _t('missing_title')),
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F172A),
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),

          // Subtitle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              widget.subtitle ?? (widget.isInputMode ? _t('input_subtitle') : _t('missing_subtitle')),
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),

          // INPUT MODE BODY
          if (widget.isInputMode) ...[
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: [_phoneMask],
              autofocus: true,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
                letterSpacing: 0.5,
              ),
              decoration: InputDecoration(
                hintText: '+7 (700) 000-00-00',
                hintStyle: GoogleFonts.inter(color: Colors.grey[400], fontSize: 16, fontWeight: FontWeight.w500),
                prefixIcon: const Icon(Icons.phone_rounded, color: Color(0xFF2563EB)),
                suffixIcon: _phoneController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 20, color: Colors.grey),
                        onPressed: () {
                          _phoneController.clear();
                          setState(() => _errorText = null);
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                errorText: _errorText,
                errorStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
                ),
              ),
              onChanged: (_) {
                if (_errorText != null) {
                  setState(() => _errorText = null);
                }
              },
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitPhone,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : Text(
                        widget.confirmText ?? _t('confirm_btn'),
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
          ],

          // MISSING NOTICE MODE BODY
          if (!widget.isInputMode) ...[
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  if (widget.onChatTap != null) widget.onChatTap!();
                },
                icon: const Icon(Icons.chat_bubble_rounded, size: 20),
                label: Text(
                  _t('open_chat'),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  await PhoneRequiredBottomSheet.showInput(
                    context,
                    subtitle: _t('input_subtitle'),
                  );
                },
                icon: const Icon(Icons.add_call, size: 18, color: Color(0xFF2563EB)),
                label: Text(
                  _t('add_my_phone'),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF2563EB),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Cancel button
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              _t('cancel'),
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[500],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
