import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:iqmarket/providers/taxi_provider.dart';
import 'package:iqmarket/theme/taxi_theme.dart';
import 'package:iqmarket/screens/login_screen.dart';
import 'package:iqmarket/services/auth_service.dart';

/// Боттомшит «Получите статус проверенного ✅».
///
/// Информирует пользователя о преимуществах верификации и предлагает
/// перейти к прохождению верификации автомобиля.
///
/// Использование:
/// ```dart
/// showTaxiVerificationInfoDialog(context, t);
/// ```
void showTaxiVerificationInfoDialog(
  BuildContext context,
  TaxiTheme t,
) {
  final provider = Provider.of<TaxiProvider>(context, listen: false);
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => Container(
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(TaxiTheme.radiusModal),
          topRight: Radius.circular(TaxiTheme.radiusModal),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Хэндл
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: t.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Иконка
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF38BDF8).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              color: Color(0xFF0284C7),
              size: 40,
            ),
          ),
          const SizedBox(height: 20),

          // Заголовок
          Text(
            provider.translate('verif_status_title'),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: t.text,
            ),
          ),
          const SizedBox(height: 12),

          // Описание
          Text(
            provider.translate('verif_status_desc'),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: t.sub,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 28),

          // Кнопки
          Row(
            children: [
              // Закрыть
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(TaxiTheme.radiusButton),
                      side: BorderSide(color: t.border),
                    ),
                  ),
                  child: Text(
                    provider.translate('close'),
                    style: GoogleFonts.inter(
                      color: t.sub,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Пройти верификацию / Войти через Telegram
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0088CC), Color(0xFF229ED9)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius:
                        BorderRadius.circular(TaxiTheme.radiusButton),
                  ),
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      HapticFeedback.selectionClick();
                      
                      String langName = 'Русский';
                      if (provider.curLang == 'kz') langName = 'Қазақша';
                      else if (provider.curLang == 'uyg') langName = 'Уйғурчә';

                      await AuthService.signOut();
                      provider.setLoginStatus(false);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LoginScreen(
                            lang: langName,
                            autoStartTelegramLogin: true,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(TaxiTheme.radiusButton),
                      ),
                    ),
                    child: Text(
                      provider.curLang == 'kz' 
                          ? 'Telegram арқылы кіру' 
                          : (provider.curLang == 'uyg' ? 'Telegram арқылық кириш' : 'Войти через Telegram'),
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13.0,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
