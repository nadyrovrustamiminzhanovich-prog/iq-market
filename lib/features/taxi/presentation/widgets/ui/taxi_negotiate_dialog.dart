import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iqmarket/providers/taxi_provider.dart';
import 'package:iqmarket/services/notification_service.dart';
import 'package:iqmarket/theme/taxi_theme.dart';

void showTaxiNegotiateDialog(
  BuildContext context,
  TaxiProvider provider,
  TaxiTheme t,
  Map<String, dynamic> d, {
  required void Function(BuildContext, TaxiProvider, TaxiTheme, VoidCallback)
      onShowPhoneBinding,
}) {
  final hasPhone = provider.phone.isNotEmpty &&
      provider.phone != '+7 701 000 11 22' &&
      provider.phone != '87010001122';

  if (!hasPhone) {
    onShowPhoneBinding(context, provider, t, () {
      showTaxiNegotiateDialog(context, provider, t, d,
          onShowPhoneBinding: onShowPhoneBinding);
    });
    return;
  }

  int myPrice = (d['price'] as num?)?.toInt() ?? 0;
  final priceCtrl = TextEditingController(text: myPrice.toString());

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
          top: 20,
          left: 24,
          right: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: t.border,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              provider.translate('suggest_price'),
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w900,
                color: t.text,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${provider.translate('driver_asks')} ${d['price']} ₸',
              style: GoogleFonts.inter(color: t.sub, fontSize: 13),
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Минус
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    if (myPrice > 100) {
                      ss(() {
                        myPrice -= 100;
                        priceCtrl.text = myPrice.toString();
                      });
                    }
                  },
                  child: _circleBtn(t, Icons.remove),
                ),
                const SizedBox(width: 20),
                SizedBox(
                  width: 140,
                  child: TextField(
                    controller: priceCtrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: t.text,
                    ),
                    decoration: InputDecoration(
                      suffixText: ' ₸',
                      suffixStyle: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: t.text,
                      ),
                      border: InputBorder.none,
                    ),
                    onChanged: (val) {
                      final clean = val.replaceAll(RegExp(r'\D'), '');
                      myPrice = clean.isNotEmpty
                          ? (int.tryParse(clean) ?? 0)
                          : 0;
                    },
                  ),
                ),
                const SizedBox(width: 20),
                // Плюс
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    ss(() {
                      myPrice += 100;
                      priceCtrl.text = myPrice.toString();
                    });
                  },
                  child: _circleBtn(t, Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 40),
            GestureDetector(
              onTap: () async {
                if (myPrice < 100) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Укажите корректную стоимость (минимум 100 ₸)! 💰',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                      backgroundColor: const Color(0xFFEF4444),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  );
                  return;
                }
                Navigator.pop(context);
                final targetId = d['targetId']?.toString() ?? '';
                final targetType = d['targetType']?.toString() ?? '';
                final receiverId = d['receiverId']?.toString() ?? '';
                if (targetId.isNotEmpty && receiverId.isNotEmpty) {
                  NotificationService.notify(
                    context,
                    'Предложение отправлено',
                    '${provider.translate('offer_sent')} ($myPrice ₸)',
                    isSuccess: true,
                  );
                  await provider.sendBid(
                    targetId: targetId,
                    targetType: targetType,
                    receiverId: receiverId,
                    price: myPrice,
                  );
                }
              },
              child: Container(
                width: double.infinity,
                height: 60,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF84CC16), Color(0xFF4D7C0F)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color:
                          const Color(0xFF84CC16).withValues(alpha: 0.4),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    provider.translate('send_offer').toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
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
  ).whenComplete(() => priceCtrl.dispose());
}

Widget _circleBtn(TaxiTheme t, IconData icon) => Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: t.border, width: 2),
      ),
      child: Icon(icon, color: t.lime),
    );
