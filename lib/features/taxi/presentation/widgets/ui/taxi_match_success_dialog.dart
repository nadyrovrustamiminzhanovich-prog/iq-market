import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:iqmarket/providers/taxi_provider.dart';
import 'package:iqmarket/services/notification_service.dart';
import 'package:iqmarket/theme/taxi_theme.dart';
import 'package:iqmarket/features/taxi/presentation/widgets/ui/kazakhstan_license_plate.dart';

void showTaxiMatchSuccessDialog({
  required BuildContext context,
  required TaxiProvider provider,
  required TaxiTheme t,
  required String driverName,
  required String driverPhone,
  required String driverImg,
  required String driverCar,
  required String driverPlate,
  required int price,
  required String bidId,
}) {
  bool isProcessing = false;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (c, ss) => Container(
        decoration: BoxDecoration(
          color: t.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Drag handle & Close Button bar ───────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 40),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: t.border,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: t.sub, size: 24),
                      onPressed: () => Navigator.pop(c),
                      tooltip: 'Закрыть',
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // ── Green Check Icon ────────────────────────────────
                Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(
                    color: Color(0xFF84CC16),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded,
                      color: Colors.white, size: 34),
                ),
                const SizedBox(height: 16),
                Text(
                  'Вы успешно договорились!',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: t.text,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Вы приняли предложение от водителя за $price ₸',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: t.sub,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 20),

                // ── Driver Info Card ────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: t.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: t.border),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundImage:
                            (driverImg.isNotEmpty && driverImg.startsWith('http'))
                                ? NetworkImage(driverImg)
                                : null,
                        child: (driverImg.isEmpty || !driverImg.startsWith('http'))
                            ? const Icon(Icons.person,
                                color: Color(0xFF64748B))
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              driverName,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: t.text,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              driverCar,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: t.sub,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            KazakhstanLicensePlate(plate: driverPlate),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Call Driver Button ──────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      if (isProcessing) return;
                      HapticFeedback.lightImpact();
                      if (driverPhone.isNotEmpty) {
                        launchUrl(Uri.parse('tel:$driverPhone'));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A80F0),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.phone_rounded, size: 20),
                    label: Text(
                      'Позвонить водителю',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Done / Close Button ─────────────────────────────
                isProcessing
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: CircularProgressIndicator(),
                      )
                    : SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () async {
                            if (isProcessing) return;
                            HapticFeedback.mediumImpact();
                            ss(() => isProcessing = true);
                            try {
                              await provider.acceptBid(bidId);
                              if (c.mounted) {
                                NotificationService.notify(
                                  c,
                                  provider.translate('acceptedTitle'),
                                  provider.translate('agreedToPriceMsg').replaceAll('{price}', price.toString()),
                                  isSuccess: true,
                                );
                                Navigator.pop(c);
                              }
                            } catch (e) {
                              if (c.mounted) {
                                NotificationService.notify(
                                  c,
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
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            side: BorderSide(color: t.border, width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: Text(
                            'Готово (Закрыть)',
                            style: GoogleFonts.inter(
                              color: t.sub,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
