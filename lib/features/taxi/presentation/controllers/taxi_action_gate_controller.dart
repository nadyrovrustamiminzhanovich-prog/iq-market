import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iqmarket/providers/taxi_provider.dart';
import 'package:iqmarket/theme/taxi_theme.dart';
import 'package:iqmarket/widgets/auth/telegram_verification_dialog.dart';

/// Контроллер-делегат для проверки права водителя принимать заказ.
///
/// Содержит:
/// - [checkDriverActionGate] — проверяет, может ли водитель принять заказ
///   (верификация + активная поездка по маршруту за последние 24ч)
/// - [showDriverVerificationGateDialog] — диалог «Нужна верификация»
/// - [showCreateDrivePromptSheet] — боттомшит «Создайте поездку для доступа к заказам»
///
/// Все методы принимают [BuildContext] явно, что делает их тестируемыми
/// и не привязанными к конкретному [State].
class TaxiActionGateController {
  const TaxiActionGateController._();

  // ─────────────────────────────────────────────────────────────────────────
  // Public API
  // ─────────────────────────────────────────────────────────────────────────

  /// Проверяет gate перед действием водителя.
  ///
  /// Разрешает [onAuthorized], только если:
  ///   1. Водитель верифицирован
  ///   2. У него есть активная поездка по тому же маршруту за последние 24ч
  ///
  /// Иначе показывает [showCreateDrivePromptSheet].
  static void checkDriverActionGate(
    BuildContext context,
    TaxiProvider provider,
    TaxiTheme t,
    Map<String, dynamic> order,
    VoidCallback onAuthorized, {
    required VoidCallback onNavigateToLogin,
    required void Function(BuildContext, TaxiProvider, TaxiTheme, VoidCallback)
        onShowPhoneBinding,
    required void Function(TaxiProvider, TaxiTheme, {String? customText, VoidCallback? onSuccess})
        onShowVerificationGate,
    required void Function(TaxiProvider, TaxiTheme, String from, String to)
        onShowDriverRideConfirmation,
  }) {
    if (!provider.isLoggedIn) {
      onNavigateToLogin();
      return;
    }

    if (!provider.isVehicleVerified) {
      showDriverVerificationGateDialog(context, provider, t, onSuccess: onAuthorized);
      return;
    }

    final String currentUserId =
        FirebaseAuth.instance.currentUser?.uid ?? '';
    final String orderFrom = order['from'] ?? '';
    final String orderTo = order['to'] ?? '';

    final bool hasActiveRide = provider.allDrives.any((drive) {
      final bool isMyDrive = drive['driverId'] == currentUserId;
      final bool isMatchingRoute =
          drive['from'].toString().trim().toLowerCase() ==
                  orderFrom.trim().toLowerCase() &&
              drive['to'].toString().trim().toLowerCase() ==
                  orderTo.trim().toLowerCase();
      final bool isActive =
          drive['status'] == 'active' || drive['status'] == 'accepted';

      bool isRecent = true;
      final timestamp = drive['createdAt'];
      if (timestamp != null) {
        try {
          DateTime? createdDate;
          if (timestamp is Timestamp) {
            createdDate = timestamp.toDate();
          } else if (timestamp is String) {
            createdDate = DateTime.tryParse(timestamp);
          } else if (timestamp is int) {
            createdDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
          }
          if (createdDate != null) {
            isRecent = DateTime.now().difference(createdDate).inHours <= 24;
          }
        } catch (e) { debugPrint('[TaxiActionGate] Date parse error: $e'); }
      }

      return isMyDrive && isMatchingRoute && isActive && isRecent;
    });

    if (hasActiveRide) {
      onAuthorized();
    } else {
      showCreateDrivePromptSheet(
        context,
        provider,
        t,
        orderFrom,
        orderTo,
        onNavigateToLogin: onNavigateToLogin,
        onShowPhoneBinding: onShowPhoneBinding,
        onShowVerificationGate: onShowVerificationGate,
        onShowDriverRideConfirmation: onShowDriverRideConfirmation,
      );
    }
  }

  /// Диалог «Верификация водителя требуется».
  static Future<bool> showDriverVerificationGateDialog(
    BuildContext context,
    TaxiProvider provider,
    TaxiTheme t, {
    String? customText,
    VoidCallback? onSuccess,
  }) async {
    String titleText = 'Подтверждение Telegram';
    String contentText = customText ?? 'Для получения доступа к поездкам и заказам водителя необходимо подтвердить номер через Telegram. Подтвердить сейчас?';
    String confirmText = 'ПОДТВЕРДИТЬ';
    String cancelText = 'ОТМЕНА';

    if (provider.curLang == 'kz') {
      titleText = 'Растау Telegram';
      contentText = customText ?? 'Жүргізуші функцияларына қол жеткізу үшін телефонды Telegram арқылы растау қажет. Қазір растағыңыз келе ме?';
      confirmText = 'РАСТАУ';
      cancelText = 'БАС ТАРТУ';
    } else if (provider.curLang == 'uyg') {
      titleText = 'Тәсдиқләш Telegram';
      contentText = customText ?? 'Шопур функциялириға еришиш үчүн телефонни Telegram арқылық тәсдиқләш зөрүр. Ҳазир тәсдиқлимәкчимусыз?';
      confirmText = 'ТӘСДИҚЛӘШ';
      cancelText = 'ЯҚ';
    }

    final bool? result = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: t.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Красивая круглая иконка Telegram
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF24A1DE).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.telegram_rounded,
                  color: Color(0xFF24A1DE),
                  size: 44,
                ),
              ),
              const SizedBox(height: 18),
              // Заголовок без переноса букв
              Text(
                titleText,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w900,
                  fontSize: 19,
                  color: t.text,
                ),
              ),
              const SizedBox(height: 12),
              // Текст
              Text(
                contentText,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  color: t.sub,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              // Кнопки
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        side: BorderSide(color: t.sub.withValues(alpha: 0.2)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        cancelText,
                        style: GoogleFonts.plusJakartaSans(
                          color: t.sub,
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF24A1DE),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        confirmText,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w900,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (result == true && context.mounted) {
      final bool verified = await TelegramVerificationDialog.show(context, provider: provider);
      if (verified && onSuccess != null) {
        onSuccess();
      }
      return verified;
    }
    return false;
  }

  /// Боттомшит «Создайте поездку для доступа к заказам по маршруту».
  static void showCreateDrivePromptSheet(
    BuildContext context,
    TaxiProvider provider,
    TaxiTheme t,
    String from,
    String to, {
    required VoidCallback onNavigateToLogin,
    required void Function(BuildContext, TaxiProvider, TaxiTheme, VoidCallback)
        onShowPhoneBinding,
    required void Function(TaxiProvider, TaxiTheme, {String? customText, VoidCallback? onSuccess})
        onShowVerificationGate,
    required void Function(TaxiProvider, TaxiTheme, String from, String to)
        onShowDriverRideConfirmation,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 25,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: t.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFEFF6FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_outline_rounded,
                  color: Color(0xFF4A80F0), size: 40),
            ),
            const SizedBox(height: 20),
            Text(
              'Доступ ограничен 🔒',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: t.text,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Создайте поездку — вы получите доступ к заказам по этому '
              'маршруту на 24ч',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14.5,
                color: t.sub,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 28),
            Center(
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        if (!provider.isLoggedIn) {
                          onNavigateToLogin();
                          return;
                        }
                        final isTelegramUser = provider.isTelegramVerified || FirebaseAuth.instance.currentUser?.uid.startsWith('telegram_') == true;
                        final hasPhone = isTelegramUser || provider.phone.isNotEmpty;
                        if (!hasPhone) {
                          onShowPhoneBinding(context, provider, t, () {
                            if (!provider.isVehicleVerified) {
                              onShowVerificationGate(provider, t,
                                  customText:
                                      'Для создания собственных поездок необходимо '
                                      'пройти верификацию вашего автомобиля.',
                                  onSuccess: () {
                                    onShowDriverRideConfirmation(
                                        provider, t, from, to);
                                  });
                            } else {
                              onShowDriverRideConfirmation(
                                  provider, t, from, to);
                            }
                          });
                        } else if (!provider.isVehicleVerified) {
                          onShowVerificationGate(provider, t,
                              customText:
                                  'Для создания собственных поездок необходимо '
                                  'пройти верификацию вашего автомобиля.',
                              onSuccess: () {
                                onShowDriverRideConfirmation(provider, t, from, to);
                              });
                        } else {
                          onShowDriverRideConfirmation(provider, t, from, to);
                        }
                      },
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4A80F0), Color(0xFF4A80F0)],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  const Color(0xFF4A80F0).withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.add_road_rounded,
                                  color: Colors.white, size: 20),
                              const SizedBox(width: 10),
                              Text(
                                'Создать поездку',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: t.border),
                        ),
                      ),
                      child: Text(
                        'Назад',
                        style: GoogleFonts.inter(
                          color: t.sub,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
