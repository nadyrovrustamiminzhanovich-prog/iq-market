import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iqmarket/providers/taxi_provider.dart';
import 'package:iqmarket/services/notification_service.dart';
import 'package:iqmarket/theme/taxi_theme.dart';

void showTaxiCancelSurveyDialog(
  BuildContext context,
  TaxiProvider provider,
  TaxiTheme t,
  String orderId,
) {
  String? selectedReason;
  final reasons = [
    'Договорился с водителем',
    'Передумал ехать',
    'Не нашел водителя',
    'Другая причина',
  ];

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: t.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (c, ss) => SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(c).viewInsets.bottom,
          top: 24,
          left: 24,
          right: 24,
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
            Text(
              'Укажите причину отмены',
              style: GoogleFonts.inter(
                fontSize: 20,
                color: t.text,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ваш отзыв помогает нам улучшать качество поездок',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: t.sub,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            ...reasons.map((reason) {
              final isSelected = selectedReason == reason;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  ss(() => selectedReason = reason);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? t.accent.withValues(alpha: 0.08)
                        : t.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? t.accent : t.border,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          reason,
                          style: GoogleFonts.inter(
                            color: t.text,
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? t.accent
                                : t.sub.withValues(alpha: 0.3),
                            width: 2,
                          ),
                          color: isSelected
                              ? t.accent
                              : Colors.transparent,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check_rounded,
                                color: Colors.white, size: 14)
                            : null,
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: selectedReason == null
                  ? null
                  : () async {
                      Navigator.pop(ctx);
                      HapticFeedback.heavyImpact();
                      await provider.cancelOrder(orderId,
                          reason: selectedReason);
                      if (context.mounted) {
                        NotificationService.notify(
                          context,
                          'Заказ отменен',
                          'Ваш заказ успешно удален',
                          isSuccess: false,
                        );
                      }
                    },
              child: Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  color: selectedReason == null ? t.border : Colors.red,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: selectedReason == null
                      ? null
                      : [
                          BoxShadow(
                            color: Colors.red.withValues(alpha: 0.25),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                ),
                child: Center(
                  child: Text(
                    'ПОДТВЕРДИТЬ ОТМЕНУ',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: selectedReason == null ? t.sub : Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    ),
  );
}
