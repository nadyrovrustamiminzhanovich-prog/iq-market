import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iqmarket/providers/taxi_provider.dart';
import 'package:iqmarket/services/notification_service.dart';
import 'package:iqmarket/theme/taxi_theme.dart';

/// Боттомшит деталей ставки торга.
///
/// Показывает:
/// - Профиль отправителя (тап → открыть профиль через [onShowUserProfile])
/// - Маршрут, дату, время, комментарий целевого заказа/поездки
/// - Исходную и предложенную цену
/// - Кнопки «Принять» / «Отклонить» (или «Отозвать» если текущий юзер — отправитель)
///
/// Использование:
/// ```dart
/// showTaxiBidDetailsSheet(
///   context: context,
///   bid: bidData,
///   provider: provider,
///   t: theme,
///   onShowUserProfile: (name, img, isDriver, uid) { ... },
/// );
/// ```
void showTaxiBidDetailsSheet({
  required BuildContext context,
  required Map<String, dynamic> bid,
  required TaxiProvider provider,
  required TaxiTheme t,
  required void Function(
    String name,
    String img,
    bool isDriver,
    String userId,
  ) onShowUserProfile,
}) {
  final String bidId = bid['id']?.toString() ?? '';
  final String senderId = bid['senderId']?.toString() ?? '';
  final String senderName = bid['senderName']?.toString() ?? 'Пользователь';
  final String senderImg = bid['senderImg']?.toString() ?? '';
  final int offeredPrice = (bid['offeredPrice'] as num?)?.toInt() ?? 0;
  final String targetId = bid['targetId']?.toString() ?? '';
  final String targetType = bid['targetType']?.toString() ?? '';

  // Определяем: текущий юзер — отправитель или получатель ставки
  final bool isSender =
      (targetType == 'order') ? (provider.tab == 1) : (provider.tab == 0);

  // Ищем целевой заказ или поездку для отображения деталей маршрута
  Map<String, dynamic>? target;
  try {
    if (targetType == 'order') {
      target = provider.allPassengerOrders.firstWhere(
        (o) => o['id'] == targetId,
        orElse: () => <String, dynamic>{},
      );
    } else {
      target = provider.allDrives.firstWhere(
        (d) => d['id'] == targetId,
        orElse: () => <String, dynamic>{},
      );
    }
    if (target.isEmpty) target = null;
  } catch (_) {}

  final String from = target?['from']?.toString() ?? 'Неизвестно';
  final String to = target?['to']?.toString() ?? 'Неизвестно';
  final String date = target?['date']?.toString() ?? '';
  final String time = target?['time']?.toString() ?? '';
  final int originalPrice = (target?['price'] as num?)?.toInt() ?? 0;
  final String comment = target?['comment']?.toString() ?? '';

  String displayDate = date;
  if (date == 'today') displayDate = 'Сегодня';
  if (date == 'tomorrow') displayDate = 'Завтра';

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      decoration: BoxDecoration(
        color: t.bg,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(ctx).viewInsets.bottom,
        top: 16,
        left: 24,
        right: 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Хэндл
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

            // ── Профиль отправителя ────────────────────────────────────────
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.pop(ctx);
                onShowUserProfile(
                  senderName,
                  senderImg,
                  targetType == 'order', // если это заказ — отправитель водитель
                  senderId,
                );
              },
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: t.accent.withValues(alpha: 0.1),
                    backgroundImage: senderImg.isNotEmpty
                        ? NetworkImage(senderImg)
                        : null,
                    child: senderImg.isEmpty
                        ? Icon(Icons.person, color: t.accent, size: 24)
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isSender ? 'Ваша ставка' : senderName,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w900,
                            color: t.text,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          isSender
                              ? 'Ожидание ответа'
                              : 'Предлагает торг по поездке',
                          style: GoogleFonts.inter(
                            color: t.sub,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Детали маршрута ────────────────────────────────────────────
            Text(
              'МАРШРУТ И ДЕТАЛИ:',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: t.sub,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: t.card,
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: t.border.withValues(alpha: 0.5)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.location_on_rounded,
                          color: t.accent, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '$from → $to',
                          style: GoogleFonts.inter(
                            color: t.text,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded,
                          color: t.sub, size: 14),
                      const SizedBox(width: 8),
                      Text(
                        displayDate.isEmpty
                            ? 'Дата не указана'
                            : '$displayDate в $time',
                        style: GoogleFonts.inter(
                          color: t.sub,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (comment.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.comment_rounded,
                            color: t.sub, size: 14),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            comment,
                            style: GoogleFonts.inter(
                              color: t.sub,
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Цены ──────────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'ИСХОДНАЯ ЦЕНА',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: t.sub,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$originalPrice ₸',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: t.sub,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                    width: 1,
                    height: 40,
                    color: t.border.withValues(alpha: 0.5)),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'ПРЕДЛОЖЕННАЯ ЦЕНА',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: t.accent,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$offeredPrice ₸',
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: t.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ── Кнопки действий ───────────────────────────────────────────
            if (isSender) ...[
              // Отправитель видит только «Отозвать»
              SizedBox(
                width: double.infinity,
                height: 54,
                child: OutlinedButton(
                  onPressed: () async {
                    HapticFeedback.lightImpact();
                    Navigator.pop(ctx);
                    await provider.rejectBid(bidId);
                    if (context.mounted) {
                      NotificationService.notify(
                        context,
                        'Отменено',
                        'Вы отозвали предложение',
                        isSuccess: false,
                      );
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    'ОТОЗВАТЬ ПРЕДЛОЖЕНИЕ',
                    style: GoogleFonts.inter(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ] else ...[
              // Получатель видит «Отклонить» + «Принять»
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        HapticFeedback.lightImpact();
                        Navigator.pop(ctx);
                        await provider.rejectBid(bidId);
                        if (context.mounted) {
                          NotificationService.notify(
                            context,
                            'Отклонено',
                            'Вы отклонили предложение',
                            isSuccess: false,
                          );
                        }
                      },
                      child: Container(
                        height: 54,
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: Colors.red.withValues(alpha: 0.15)),
                        ),
                        child: Center(
                          child: Text(
                            'ОТКЛОНИТЬ',
                            style: GoogleFonts.inter(
                              color: Colors.red,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        HapticFeedback.heavyImpact();
                        Navigator.pop(ctx);
                        await provider.acceptBid(bidId);
                        if (context.mounted) {
                          NotificationService.notify(
                            context,
                            'Принято',
                            'Вы согласились на предложение за $offeredPrice ₸',
                            isSuccess: true,
                          );
                        }
                      },
                      child: Container(
                        height: 54,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF84CC16),
                              Color(0xFF4D7C0F),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF84CC16)
                                  .withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            'ПРИНЯТЬ',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    ),
  );
}
