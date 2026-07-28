import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:iqmarket/theme/taxi_theme.dart';
import 'package:iqmarket/providers/taxi_provider.dart';
import 'package:iqmarket/features/taxi/presentation/widgets/ui/kazakhstan_license_plate.dart';
import 'taxi_history_rating_sheet.dart';

void showTaxiHistoryDetailsSheet(BuildContext context, Map<String, dynamic> trip, TaxiProvider provider, TaxiTheme t) {
  final String from = trip['from'] ?? 'Не указано';
  final String to = trip['to'] ?? 'Не указано';
  final String date = TaxiProvider.formatTaxiDisplayDate(trip, provider.curLang);
  final String time = trip['time'] ?? '';
  final int price = trip['price'] ?? 0;
  final String role = trip['role'] ?? 'passenger';
  final String comment = (trip['comment'] ?? '').toString();

  // Get counterparty info based on role
  final String counterpartName = role == 'driver'
      ? (trip['passengerName'] ?? 'Пассажир')
      : (trip['driverName'] ?? 'Водитель');
  final String counterpartPhone = role == 'driver'
      ? (trip['passengerPhone'] ?? trip['phone'] ?? '')
      : (trip['driverPhone'] ?? trip['phone'] ?? '');
  final String carPlate = trip['driverPlate'] ?? trip['plate'] ?? '';
  final String carModel = trip['driverCar'] ?? trip['car'] ?? '';
  final String targetUserId = role == 'driver'
      ? (trip['passengerId'] ?? '')
      : (trip['driverId'] ?? '');

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(ctx).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: t.bg,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          top: 16,
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
            const SizedBox(height: 20),
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4A80F0), Color(0xFF6366F1)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Детали поездки',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: t.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        role == 'driver' ? 'Вы были водителем' : 'Вы были пассажиром',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: t.sub,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Завершена',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF10B981),
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Route card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: t.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: t.border.withValues(alpha: 0.5)),
              ),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          Container(width: 2, height: 30, color: t.border),
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Color(0xFFEF4444),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              from,
                              style: GoogleFonts.inter(
                                color: t.text,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              to,
                              style: GoogleFonts.inter(
                                color: t.text,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Date, time, price row
            Row(
              children: [
                Expanded(
                  child: _detailTile(Icons.calendar_today_rounded, 'Дата', date.isEmpty ? 'Не указана' : date, t),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _detailTile(Icons.access_time_rounded, 'Время', time.isEmpty ? '—' : time, t),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _detailTile(Icons.payments_rounded, 'Цена', '$price ₸', t),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Counterpart info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: t.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: t.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: const Color(0xFF4A80F0).withValues(alpha: 0.12),
                        child: Text(
                          counterpartName.isNotEmpty ? counterpartName[0].toUpperCase() : '?',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF4A80F0),
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    counterpartName,
                                    style: GoogleFonts.inter(
                                      color: t.text,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: role == 'driver'
                                        ? const Color(0xFF84CC16).withValues(alpha: 0.12)
                                        : const Color(0xFF4A80F0).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    role == 'driver' ? 'Пассажир' : 'Водитель',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: role == 'driver' ? const Color(0xFF4D7C0F) : const Color(0xFF4A80F0),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (counterpartPhone.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.phone_rounded, size: 13, color: t.sub),
                                  const SizedBox(width: 4),
                                  Text(
                                    counterpartPhone,
                                    style: GoogleFonts.inter(
                                      color: t.sub,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (counterpartPhone.isNotEmpty)
                        GestureDetector(
                          onTap: () async {
                            final url = Uri.parse('tel:$counterpartPhone');
                            if (await canLaunchUrl(url)) await launchUrl(url);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4A80F0).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.phone_rounded, color: Color(0xFF4A80F0), size: 20),
                          ),
                        ),
                    ],
                  ),
                  if (carModel.isNotEmpty || carPlate.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Divider(height: 1, color: t.border),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: t.bg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: t.border),
                          ),
                          child: const Icon(Icons.directions_car_rounded, color: Color(0xFF4A80F0), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (carModel.isNotEmpty)
                                Text(
                                  carModel,
                                  style: GoogleFonts.inter(
                                    color: t.text,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              if (carPlate.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                KazakhstanLicensePlate(plate: carPlate, fontSize: 11),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            if (comment.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: t.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: t.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'КОММЕНТАРИЙ',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: t.sub,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      comment,
                      style: GoogleFonts.inter(
                        color: t.text,
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),

            // Action buttons: Rating button
            if (targetUserId.isNotEmpty) ...[
              GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  HapticFeedback.mediumImpact();
                  showTaxiHistoryRatingSheet(
                    context,
                    provider,
                    targetUserId,
                    counterpartName,
                    t,
                    role == 'driver' ? 'passenger' : 'driver',
                  );
                },
                child: Container(
                  width: double.infinity,
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4A80F0), Color(0xFF6366F1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4A80F0).withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '⭐ Оценить поездку',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // WhatsApp Support Card (Harmonious modern style)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: t.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: t.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF25D366).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.help_outline_rounded, color: Color(0xFF25D366), size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Забыли вещи в авто?',
                              style: GoogleFonts.inter(
                                color: t.text,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Напишите в службу поддержки WhatsApp',
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
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final String from = trip['from'] ?? '';
                        final String to = trip['to'] ?? '';
                        final String msg = Uri.encodeComponent('Здравствуйте! Нужна помощь администратора по поездке из $from в $to (ID: ${trip['id'] ?? ''}). Забыли вещи / не могу связаться.');
                        final Uri url = Uri.parse('https://wa.me/77089007030?text=$msg');
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url, mode: LaunchMode.externalApplication);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E293B),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.chat_bubble_rounded, color: Color(0xFF25D366), size: 18),
                      label: Text(
                        'Написать в WhatsApp',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    ),
  );
}

Widget _detailTile(IconData icon, String label, String value, TaxiTheme t) => Container(
  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
  decoration: BoxDecoration(
    color: t.card,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: t.border),
  ),
  child: Column(
    children: [
      Icon(icon, color: const Color(0xFF4A80F0), size: 18),
      const SizedBox(height: 6),
      Text(
        value,
        style: GoogleFonts.inter(
          color: t.text,
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      const SizedBox(height: 2),
      Text(
        label,
        style: GoogleFonts.inter(
          color: t.sub,
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    ],
  ),
);

