import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:iqmarket/providers/taxi_provider.dart';
import 'package:iqmarket/services/notification_service.dart';
import 'package:iqmarket/theme/taxi_theme.dart';

void showTaxiTripCompletionDialog(
  BuildContext context,
  TaxiProvider provider,
  TaxiTheme t,
  String docId,
  bool isOrder,
  String targetUserId,
  String targetUserName,
  Function(TaxiProvider, TaxiTheme, String, String) showFeedbackDialog,
) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: t.bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      title: Text('ЗАВЕРШЕНИЕ ПОЕЗДКИ', style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: t.text)),
      content: Text(
        'Вы уже завершили эту поездку? Если поездка состоялась, вы можете закрыть её прямо сейчас.', 
        style: GoogleFonts.inter(color: t.sub)
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('НЕТ, ЕЩЕ ЕДЕМ', style: GoogleFonts.inter(color: t.sub, fontWeight: FontWeight.bold)),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(context);
            HapticFeedback.heavyImpact();
            if (isOrder) {
              await provider.completeOrder(docId);
              if (context.mounted) {
                NotificationService.notify(context, 'Успешно', 'Заказ успешно завершен!', isSuccess: true);
                showFeedbackDialog(provider, t, targetUserId, targetUserName);
              }
            } else {
              await provider.completeRide(docId);
              if (context.mounted) {
                NotificationService.notify(context, 'Успешно', 'Рейс успешно завершен!', isSuccess: true);
                showFeedbackDialog(provider, t, targetUserId, targetUserName);
              }
            }
          },
          child: Text('ДА, ЗАВЕРШИТЬ', style: GoogleFonts.inter(color: t.accent, fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}
