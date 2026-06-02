import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iqmarket/providers/taxi_provider.dart';
import 'package:iqmarket/services/notification_service.dart';
import 'package:iqmarket/theme/taxi_theme.dart';
import 'package:iqmarket/features/taxi/presentation/widgets/ui/taxi_info_chips_widget.dart';
import 'package:iqmarket/features/taxi/presentation/controllers/taxi_dialogs_controller.dart';

class TaxiActiveOrderSummary extends StatelessWidget {
  final Map<String, dynamic> order;
  final int currentPrice;
  final String orderId;
  final TaxiProvider provider;
  final TaxiTheme t;

  const TaxiActiveOrderSummary({
    super.key,
    required this.order,
    required this.currentPrice,
    required this.orderId,
    required this.provider,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    String displayDate = '';
    final rawDate = order['date'] ?? '';
    if (rawDate == 'today') {
      displayDate = 'Сегодня';
    } else if (rawDate == 'tomorrow') {
      displayDate = 'Завтра';
    } else {
      displayDate = rawDate;
    }
    final rawTime = order['time'] ?? '';
    final displayTime = (rawTime == 'time' || rawTime.isEmpty) ? '' : rawTime;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF), // Premium glowing soft blue tint
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 6))
        ],
        border: Border.all(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.35),
            width: 1.5), // Glowing blue border
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'АКТИВНЫЙ ЗАКАЗ',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF4A80F0),
                    fontSize: 10,
                    letterSpacing: 0.8),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A80F0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$currentPrice ₸',
                  style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${order['from']} → ${order['to']}',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF4A80F0),
                fontSize: 16),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TaxiBlueInfoChip(
                  icon: Icons.calendar_today_rounded,
                  text: displayDate.isEmpty ? 'Дата' : displayDate),
              TaxiBlueInfoChip(
                  icon: Icons.access_time_rounded,
                  text: displayTime.isEmpty ? 'Время не указано' : displayTime),
              TaxiInfoChip(
                  icon: Icons.group_rounded,
                  text: '${order['seats'] ?? 1} мест',
                  t: t),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    HapticFeedback.heavyImpact();
                    await provider.cancelOrder(orderId,
                        reason: 'Изменение параметров заказа');
                    if (context.mounted) {
                      NotificationService.notify(
                          context,
                          'Редактирование',
                          'Параметры сброшены. Введите новые данные поездки!',
                          isSuccess: true);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A80F0).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: const Color(0xFF4A80F0).withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.edit_rounded,
                            color: Color(0xFF4A80F0), size: 13),
                        const SizedBox(width: 4),
                        Text(
                          'ИЗМЕНИТЬ',
                          style: GoogleFonts.inter(
                              color: const Color(0xFF4A80F0),
                              fontWeight: FontWeight.w800,
                              fontSize: 10.5,
                              letterSpacing: 0.3),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.heavyImpact();
                    TaxiDialogsController.showCancelSurveyDialog(
                        context, provider, t, orderId);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.red.withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.close_rounded,
                            color: Colors.red, size: 13),
                        const SizedBox(width: 4),
                        Text(
                          'ОТМЕНИТЬ',
                          style: GoogleFonts.inter(
                              color: Colors.red,
                              fontWeight: FontWeight.w800,
                              fontSize: 10.5,
                              letterSpacing: 0.3),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
