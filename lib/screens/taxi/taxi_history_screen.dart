import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:line_icons/line_icons.dart';
import 'package:iqmarket/theme/taxi_theme.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:iqmarket/providers/taxi_provider.dart';

class TaxiHistoryScreen extends StatelessWidget {
  final TaxiTheme t;
  const TaxiHistoryScreen({super.key, required this.t});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TaxiProvider>(context);
    
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.card,
        elevation: 0,
        title: Text(provider.translate('history_full'), style: GoogleFonts.inter(color: t.text)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: t.text),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _buildBody(context, provider),
    );
  }

  Widget _buildBody(BuildContext context, TaxiProvider provider) {
    final trips = provider.historyTrips;

    if (trips.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LineIcons.history, size: 72, color: t.sub.withValues(alpha: 0.3)),
            const SizedBox(height: 24),
            Text(
              provider.translate('no_history'),
              style: GoogleFonts.inter(color: t.sub, fontSize: 16, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'История ваших поездок пуста',
              style: GoogleFonts.inter(color: t.sub.withValues(alpha: 0.6), fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: trips.map((trip) {
        final String from = trip['from'] ?? '';
        final String to = trip['to'] ?? '';
        final String priceStr = '${trip['price'] ?? 0} ₸';
        final String date = trip['date'] == 'today' 
            ? 'Сегодня' 
            : (trip['date'] == 'tomorrow' ? 'Завтра' : (trip['date'] ?? ''));
        final String role = trip['role'] == 'driver' ? 'Водитель' : 'Пассажир';
        final String phone = (trip['role'] == 'driver' ? (trip['passengerPhone'] ?? trip['phone'] ?? '') : (trip['driverPhone'] ?? trip['phone'] ?? '')).toString();
        final String comment = (trip['comment'] ?? '').toString();

        return _hItem(
          context,
          '$date ($role)', 
          from, 
          to, 
          priceStr, 
          provider.translate('completed'), 
          phone,
          comment,
          provider,
          trip,
        );
      }).toList(),
    );
  }

  Widget _hItem(BuildContext context, String d, String f, String to, String p, String s, String phone, String comment, TaxiProvider provider, Map<String, dynamic> trip) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        _showTripDetails(context, trip, provider);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(d, style: GoogleFonts.inter(color: t.sub, fontSize: 12))),
                const SizedBox(width: 8),
                Text(s, style: GoogleFonts.inter(color: t.lime, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, color: t.sub.withValues(alpha: 0.4), size: 18),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(LineIcons.mapMarker, color: t.lime, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text('$f → $to', style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.bold))),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(provider.translate('cost'), style: GoogleFonts.inter(color: t.sub)),
                Text(p, style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.w900)),
              ],
            ),
            if (comment.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 8),
              Text(
                'Комментарий: $comment',
                style: GoogleFonts.inter(color: t.sub, fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
            if (phone.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final url = Uri.parse('tel:$phone');
                  if (await canLaunchUrl(url)) await launchUrl(url);
                },
                child: Row(
                  children: [
                    Icon(Icons.phone_rounded, color: t.lime, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      phone,
                      style: GoogleFonts.inter(
                        color: t.lime,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '(Позвонить)',
                      style: GoogleFonts.inter(color: t.sub, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );

  void _showTripDetails(BuildContext context, Map<String, dynamic> trip, TaxiProvider provider) {
    final String from = trip['from'] ?? 'Не указано';
    final String to = trip['to'] ?? 'Не указано';
    final String date = trip['date'] == 'today'
        ? 'Сегодня'
        : (trip['date'] == 'tomorrow' ? 'Завтра' : (trip['date'] ?? 'Не указана'));
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
          maxHeight: MediaQuery.of(ctx).size.height * 0.85,
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
                    child: _detailTile(Icons.calendar_today_rounded, 'Дата', date.isEmpty ? 'Не указана' : date),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _detailTile(Icons.access_time_rounded, 'Время', time.isEmpty ? '—' : time),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _detailTile(Icons.payments_rounded, 'Цена', '$price ₸'),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Counterpart info
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: t.card,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: t.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      role == 'driver' ? 'ПАССАЖИР' : 'ВОДИТЕЛЬ',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: t.sub,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: const Color(0xFF4A80F0).withValues(alpha: 0.1),
                          child: Text(
                            counterpartName.isNotEmpty ? counterpartName[0].toUpperCase() : '?',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF4A80F0),
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                counterpartName,
                                style: GoogleFonts.inter(
                                  color: t.text,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              if (counterpartPhone.isNotEmpty)
                                Text(
                                  counterpartPhone,
                                  style: GoogleFonts.inter(
                                    color: t.sub,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
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
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.phone_rounded, color: Color(0xFF10B981), size: 18),
                            ),
                          ),
                      ],
                    ),
                    // Car info (only show for passenger role or if data exists)
                    if (carModel.isNotEmpty || carPlate.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Divider(height: 1, color: t.border),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(Icons.directions_car_rounded, color: t.sub, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            carModel.isNotEmpty ? carModel : 'Машина',
                            style: GoogleFonts.inter(
                              color: t.text,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (carPlate.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: t.bg,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: t.border),
                              ),
                              child: Text(
                                carPlate,
                                style: GoogleFonts.inter(
                                  color: t.text,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
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

              // Action buttons
              if (targetUserId.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    HapticFeedback.mediumImpact();
                    _showRatingDialog(context, provider, targetUserId, counterpartName);
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
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () async {
                  final url = Uri.parse('https://t.me/iqmarket_support');
                  if (await canLaunchUrl(url)) await launchUrl(url);
                },
                child: Container(
                  width: double.infinity,
                  height: 48,
                  decoration: BoxDecoration(
                    color: t.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: t.border),
                  ),
                  child: Center(
                    child: Text(
                      '📞 Написать в поддержку',
                      style: GoogleFonts.inter(
                        color: t.sub,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailTile(IconData icon, String label, String value) => Container(
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

  void _showRatingDialog(BuildContext context, TaxiProvider provider, String targetUserId, String targetUserName) {
    double selectedRating = 5.0;
    final List<String> tags = ['Чистое авто 🚗', 'Вежливый 😊', 'Быстро ⚡', 'Комфортно 🛋️', 'Безопасно 🛡️'];
    final List<String> selectedTags = [];
    final TextEditingController commentController = TextEditingController();

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
            bottom: MediaQuery.of(c).viewInsets.bottom + 24,
            top: 24,
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
                'Как прошла поездка с',
                style: GoogleFonts.inter(fontSize: 14, color: t.sub, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Text(
                targetUserName,
                style: GoogleFonts.inter(fontSize: 22, color: t.text, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 24),
              // Star rating
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final double starVal = index + 1.0;
                  final bool isSelected = starVal <= selectedRating;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      ss(() => selectedRating = starVal);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: isSelected ? Colors.amber : t.border,
                        size: 48,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),
              Text(
                'Что вам понравилось?',
                style: GoogleFonts.inter(fontSize: 13, color: t.sub, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              // Tag chips with premium gradient
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: tags.map((tag) {
                  final bool isChipSelected = selectedTags.contains(tag);
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      ss(() {
                        if (isChipSelected) {
                          selectedTags.remove(tag);
                        } else {
                          selectedTags.add(tag);
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                      decoration: BoxDecoration(
                        gradient: isChipSelected
                            ? const LinearGradient(
                                colors: [Color(0xFF4A80F0), Color(0xFF6366F1)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: isChipSelected ? null : t.card,
                        borderRadius: BorderRadius.circular(20),
                        border: isChipSelected ? null : Border.all(color: t.border),
                        boxShadow: isChipSelected
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF4A80F0).withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        tag,
                        style: GoogleFonts.inter(
                          color: isChipSelected ? Colors.white : t.text,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              // Comment field
              TextField(
                controller: commentController,
                maxLines: 3,
                style: GoogleFonts.inter(color: t.text),
                decoration: InputDecoration(
                  hintText: 'Напишите ваш комментарий...',
                  hintStyle: GoogleFonts.inter(color: t.sub),
                  filled: true,
                  fillColor: t.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: t.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: Color(0xFF4A80F0)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Submit button
              GestureDetector(
                onTap: () async {
                  Navigator.pop(ctx);
                  HapticFeedback.heavyImpact();

                  final String reviewComment = [
                    if (selectedTags.isNotEmpty) '[${selectedTags.join(", ")}]',
                    commentController.text.trim()
                  ].join(' ').trim();

                  await provider.submitReview(
                    targetUserId: targetUserId,
                    rating: selectedRating,
                    comment: reviewComment.isEmpty ? 'Без комментариев' : reviewComment,
                  );

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Отзыв отправлен! Спасибо за вашу оценку ⭐',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        ),
                        backgroundColor: const Color(0xFF10B981),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    );
                  }
                },
                child: Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF059669)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withValues(alpha: 0.35),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      'ОТПРАВИТЬ ОТЗЫВ',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
