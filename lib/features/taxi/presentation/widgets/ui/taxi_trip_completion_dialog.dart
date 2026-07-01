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
  bool isProcessing = false;
  showDialog(
    context: context,
    builder: (dialogCtx) => StatefulBuilder(
      builder: (c, ss) => AlertDialog(
        backgroundColor: t.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: Text(provider.translate('completeRideTitle'), style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: t.text)),
        content: isProcessing
            ? const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              )
            : Text(
                'Вы уже завершили эту поездку? Если поездка состоялась, вы можете закрыть её прямо сейчас.', 
                style: GoogleFonts.inter(color: t.sub)
              ),
        actions: isProcessing
            ? []
            : [
                TextButton(
                  onPressed: () => Navigator.pop(c),
                  child: Text(provider.translate('noStillDrivingBtn'), style: GoogleFonts.inter(color: t.sub, fontWeight: FontWeight.bold)),
                ),
                TextButton(
                  onPressed: () async {
                    HapticFeedback.heavyImpact();
                    ss(() => isProcessing = true);
                    try {
                      if (isOrder) {
                        await provider.completeOrder(docId);
                        if (context.mounted) {
                          NotificationService.notify(context, provider.translate('successTitle'), provider.translate('orderCompletedMsg'), isSuccess: true);
                        }
                      } else {
                        await provider.completeRide(docId);
                        if (context.mounted) {
                          NotificationService.notify(context, provider.translate('successTitle'), provider.translate('rideCompletedMsg'), isSuccess: true);
                        }
                      }
                      if (c.mounted) {
                        Navigator.pop(c);
                      }
                      if (context.mounted) {
                        showFeedbackDialog(provider, t, targetUserId, targetUserName);
                      }
                    } catch (e) {
                      if (context.mounted) {
                        NotificationService.notify(
                          context,
                          provider.translate('error_label'),
                          provider.translate('general_error_desc'),
                          isSuccess: false,
                        );
                      }
                    } finally {
                      if (c.mounted) {
                        ss(() => isProcessing = false);
                      }
                    }
                  },
                  child: Text(provider.translate('yesCompleteBtn'), style: GoogleFonts.inter(color: t.accent, fontWeight: FontWeight.bold)),
                ),
              ],
      ),
    ),
  );
}
