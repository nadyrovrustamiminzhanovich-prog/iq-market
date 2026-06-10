import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:iqmarket/providers/taxi_provider.dart';
import 'package:iqmarket/theme/taxi_theme.dart';

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
    isDismissible: false,
    enableDrag: false,
    backgroundColor: t.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (c, ss) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: const BoxDecoration(
                color: Color(0xFF84CC16),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded,
                  color: Colors.white, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              'Вы успешно договорились!',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: t.text,
              ),
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
            const SizedBox(height: 24),
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
                          '$driverCar • $driverPlate',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: t.sub,
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
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: () async {
                  if (isProcessing) return;
                  HapticFeedback.lightImpact();
                  if (driverPhone.isNotEmpty) {
                    launchUrl(Uri.parse('tel:$driverPhone'));
                  }
                },
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A80F0),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color:
                            const Color(0xFF4A80F0).withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.phone_rounded,
                            color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Позвонить водителю',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            isProcessing
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : TextButton(
                    onPressed: () async {
                      if (isProcessing) return;
                      HapticFeedback.mediumImpact();
                      ss(() => isProcessing = true);
                      try {
                        await provider.acceptBid(bidId);
                        final orderId = provider.allPassengerOrders.firstWhere(
                          (o) =>
                              o['passengerId'] ==
                                  FirebaseAuth.instance.currentUser?.uid &&
                              o['status'] == 'active',
                          orElse: () => <String, dynamic>{},
                        )['id'];
                        if (orderId != null) {
                          await provider.completeOrder(orderId);
                        }
                        if (c.mounted) {
                          Navigator.pop(c);
                        }
                      } catch (e) {
                        // error handling
                      } finally {
                        if (c.mounted) {
                          ss(() => isProcessing = false);
                        }
                      }
                    },
                    child: Text(
                      'Готово (Закрыть)',
                      style: GoogleFonts.inter(
                        color: t.sub,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    ),
  );
}
