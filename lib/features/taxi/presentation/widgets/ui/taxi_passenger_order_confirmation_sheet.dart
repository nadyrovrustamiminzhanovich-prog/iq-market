import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iqmarket/providers/taxi_provider.dart';
import 'package:iqmarket/services/notification_service.dart';
import 'package:iqmarket/theme/taxi_theme.dart';

/// Боттомшит подтверждения заказа для пассажира.
///
/// Показывает детали маршрута, дату, время, количество мест, цену и комментарий,
/// а также кнопку «Опубликовать заказ».
///
/// Использование:
/// ```dart
/// showTaxiPassengerOrderConfirmationSheet(
///   context: context,
///   provider: provider,
///   theme: theme,
///   price: price,
///   comment: comment,
///   phone: phone,
/// );
/// ```
void showTaxiPassengerOrderConfirmationSheet({
  required BuildContext context,
  required TaxiProvider provider,
  required TaxiTheme theme,
  required int price,
  required String comment,
  required String phone,
}) {
  final int seats = provider.passCnt;
  bool isPublishing = false;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: theme.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (c, ss) => SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(c).viewInsets.bottom,
          top: 20,
          left: 24,
          right: 24,
        ),
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
                  color: theme.border,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              provider.translate('confirm_order_details'),
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w900,
                color: theme.text,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              provider.translate('make_sure_correct'),
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w500,
                color: theme.sub,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 20),

            // Карточка с деталями заказа (Premium Receipt Card)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: theme.border, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Маршрут
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.circle_rounded,
                          color: Color(0xFF4A80F0), size: 12),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${provider.from} → ${provider.to}',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w900,
                            color: theme.text,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFFF1F5F9), height: 1),
                  const SizedBox(height: 16),

                  // Дата & Время & Места
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _summaryItem(
                        Icons.calendar_today_rounded,
                        provider.selDate == 'today'
                            ? provider.translate('today')
                            : (provider.selDate == 'tomorrow'
                                ? provider.translate('tomorrow')
                                : provider.selDate),
                        theme,
                      ),
                      _summaryItem(
                        Icons.access_time_rounded,
                        provider.selTime == 'time'
                            ? provider.translate('time_not_specified')
                            : provider.selTime,
                        theme,
                      ),
                      _summaryItem(
                        Icons.group_rounded,
                        provider.translate('seats_count').replaceAll('{cnt}', '$seats'),
                        theme,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFFF1F5F9), height: 1),
                  const SizedBox(height: 16),

                  // Цена & Телефон
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            provider.translate('price_label'),
                            style: GoogleFonts.inter(
                              color: theme.sub,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$price ₸',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF4A80F0),
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            provider.translate('your_phone'),
                            style: GoogleFonts.inter(
                              color: theme.sub,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            phone,
                            style: GoogleFonts.inter(
                              color: theme.text,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  if (comment.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Divider(color: Color(0xFFF1F5F9), height: 1),
                    const SizedBox(height: 16),
                    Text(
                      provider.translate('comment_label_receipt'),
                      style: GoogleFonts.inter(
                        color: theme.sub,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.bg.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: theme.border),
                      ),
                      child: Text(
                        comment,
                        style: GoogleFonts.inter(
                          color: theme.text,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontStyle: FontStyle.italic,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),

            isPublishing
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : _actBtn(
                    theme,
                    provider.translate('publish_order_btn'),
                    const Color(0xFF4A80F0),
                    () async {
                      if (isPublishing) return;
                      HapticFeedback.heavyImpact();
                      ss(() => isPublishing = true);
                      if (price < 100) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text(
                              provider.translate('invalid_price_err'),
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold),
                            ),
                            backgroundColor: const Color(0xFFEF4444),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        );
                        ss(() => isPublishing = false);
                        return;
                      }
                      try {
                        await provider.createPassengerOrder(
                          from: provider.from,
                          to: provider.to,
                          date: provider.selDate,
                          time: provider.selTime,
                          seats: seats,
                          price: price,
                          comment: comment,
                        );
                        if (c.mounted) {
                          NotificationService.notify(
                            c,
                            provider.translate('order_published_success'),
                            provider.translate('order_published_desc'),
                            isSuccess: true,
                          );
                          Navigator.pop(ctx);
                        }
                      } catch (e) {
                        if (c.mounted) {
                          NotificationService.notify(
                            c,
                            provider.translate('error_label'),
                            provider.translate('order_create_err'),
                            isSuccess: false,
                          );
                          ss(() => isPublishing = false);
                        }
                      }
                    },
                  ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    ),
  );
}

Widget _summaryItem(IconData icon, String value, TaxiTheme t) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: t.bg,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: t.border),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: const Color(0xFF4A80F0)),
        const SizedBox(width: 6),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: t.text,
          ),
        ),
      ],
    ),
  );
}

Widget _actBtn(TaxiTheme t, String l, Color c, VoidCallback onTap) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [c, c.withValues(alpha: 0.85)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: c.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            l,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
