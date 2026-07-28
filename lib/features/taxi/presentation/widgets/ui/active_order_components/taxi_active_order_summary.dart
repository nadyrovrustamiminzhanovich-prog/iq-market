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
    final displayDate = TaxiProvider.formatTaxiDisplayDate(order, provider.curLang);
    final rawTime = order['time'] ?? '';
    final displayTime = (rawTime == 'time' || rawTime.isEmpty) ? '' : rawTime;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEFF6FF), Color(0xFFE0F2FE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          )
        ],
        border: Border.all(
          color: const Color(0xFF2563EB).withValues(alpha: 0.25),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF2563EB),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'АКТИВНЫЙ ЗАКАЗ',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF1E3A8A),
                      fontSize: 10,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    )
                  ],
                ),
                child: Text(
                  '$currentPrice ₸',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${order['from']} → ${order['to']}',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w900,
              color: const Color(0xFF1E3A8A),
              fontSize: 17,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TaxiBlueInfoChip(
                icon: Icons.calendar_today_rounded,
                text: displayDate.isEmpty ? 'Дата' : displayDate,
                color: const Color(0xFF2563EB),
              ),
              TaxiBlueInfoChip(
                icon: Icons.access_time_rounded,
                text: displayTime.isEmpty ? 'Время не указано' : displayTime,
                color: const Color(0xFF2563EB),
              ),
              TaxiBlueInfoChip(
                icon: Icons.group_rounded,
                text: '${order['seats'] ?? 1} мест',
                color: const Color(0xFF2563EB),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    HapticFeedback.heavyImpact();
                    try {
                      await provider.cancelOrder(orderId,
                          reason: 'Изменение параметров заказа');
                      if (context.mounted) {
                        NotificationService.notify(
                          context,
                          'Редактирование',
                          'Параметры сброшены. Введите новые данные поездки!',
                          isSuccess: true,
                        );
                      }
                    } catch (e) {
                      debugPrint('[TAXI] Error modifying order: $e');
                      if (context.mounted) {
                        NotificationService.notify(
                          context,
                          'Ошибка',
                          'Не удалось изменить параметры заказа: $e',
                          isSuccess: false,
                        );
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.edit_rounded,
                            color: Color(0xFF2563EB), size: 14),
                        const SizedBox(width: 6),
                        Text(
                          'ИЗМЕНИТЬ',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF2563EB),
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.heavyImpact();
                    TaxiDialogsController.showCancelSurveyDialog(
                        context, provider, t, orderId);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.close_rounded,
                            color: Colors.red, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          'ОТМЕНИТЬ',
                          style: GoogleFonts.inter(
                            color: Colors.red,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            letterSpacing: 0.5,
                          ),
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
