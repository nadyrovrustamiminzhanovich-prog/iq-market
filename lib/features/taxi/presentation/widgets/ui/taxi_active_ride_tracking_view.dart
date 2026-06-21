import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iqmarket/providers/taxi_provider.dart';
import 'package:iqmarket/services/notification_service.dart';
import 'package:iqmarket/theme/taxi_theme.dart';
import 'package:iqmarket/features/taxi/presentation/widgets/ui/taxi_info_chips_widget.dart';
import 'package:iqmarket/features/taxi/presentation/widgets/ui/taxi_driver_ride_confirmation_sheet.dart';
import 'package:iqmarket/features/taxi/presentation/widgets/ui/taxi_location_picker_sheet.dart';

/// Виджет отслеживания активного рейса водителя.
///
/// Отображает созданный рейс (откуда, куда, время, места)
/// и дает возможность изменить или отменить его.
class TaxiActiveRideTrackingView extends StatefulWidget {
  final TaxiProvider provider;
  final TaxiTheme t;
  final Map<String, dynamic> ride;

  const TaxiActiveRideTrackingView({
    super.key,
    required this.provider,
    required this.t,
    required this.ride,
  });

  @override
  State<TaxiActiveRideTrackingView> createState() => _TaxiActiveRideTrackingViewState();
}

class _TaxiActiveRideTrackingViewState extends State<TaxiActiveRideTrackingView> {
  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    final t = widget.t;
    final ride = widget.ride;

    final rideId = ride['id'] ?? '';
    final currentPrice = (ride['price'] ?? 0) as int;

    // Format date nicely
    String displayDate = '';
    final rawDate = ride['date'] ?? '';
    if (rawDate == 'today') {
      displayDate = 'Сегодня';
    } else if (rawDate == 'tomorrow') {
      displayDate = 'Завтра';
    } else {
      displayDate = rawDate;
    }
    final rawTime = ride['time'] ?? '';
    final displayTime = (rawTime == 'time' || rawTime.isEmpty) ? '' : rawTime;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFECFDF5), Color(0xFFE0F2FE)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            )
          ],
          border: Border.all(
            color: const Color(0xFF10B981).withValues(alpha: 0.25),
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
                        color: Color(0xFF10B981), // Green dot
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'АКТИВНЫЙ РЕЙС ВОДИТЕЛЯ',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF047857),
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
                      colors: [Color(0xFF10B981), Color(0xFF0D9488)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withValues(alpha: 0.25),
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
              '${ride['from']} → ${ride['to']}',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w900,
                color: const Color(0xFF064E3B),
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
                  color: const Color(0xFF0D9488),
                ),
                TaxiBlueInfoChip(
                  icon: Icons.access_time_rounded,
                  text: displayTime.isEmpty ? 'Время' : displayTime,
                  color: const Color(0xFF0D9488),
                ),
                TaxiBlueInfoChip(
                  icon: Icons.airline_seat_recline_normal_rounded,
                  text: '${ride['seats'] ?? 4} мест',
                  color: const Color(0xFF0D9488),
                ),
              ],
            ),
            if (ride['comment'] != null && (ride['comment'] as String).isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Комментарий: ${ride['comment']}',
                style: GoogleFonts.inter(color: t.sub, fontSize: 11, fontStyle: FontStyle.italic),
              ),
            ],
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      HapticFeedback.heavyImpact();
                      // Cancel current ride and reopen with parameters
                      await provider.cancelRide(rideId);
                      if (mounted) {
                        showTaxiDriverRideConfirmationSheet(
                          context: context, 
                          provider: provider, 
                          t: t, 
                          initialFrom: ride['from'], 
                          initialTo: ride['to'],
                          initialDate: ride['date'],
                          initialTime: ride['time'],
                          initialPrice: currentPrice,
                          initialSeats: ride['seats'] ?? 4,
                          initialComment: ride['comment'],
                          onOpenPicker: (isFrom, isDriver) async {
                            await showTaxiLocationPickerSheet(
                              context: context,
                              t: t,
                              isFrom: isFrom,
                              provider: provider,
                              isDriver: isDriver,
                            );
                          },
                        );
                        NotificationService.notify(
                          context, 
                          'Редактирование', 
                          'Рейс отменен для редактирования. Заполните новые параметры!', 
                          isSuccess: true
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.edit_rounded, color: Color(0xFF10B981), size: 14),
                          const SizedBox(width: 6),
                          Text(
                            'ИЗМЕНИТЬ',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF047857), 
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
                    onTap: () async {
                      HapticFeedback.heavyImpact();
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: t.bg,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          title: Text('Отменить поездку?', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: t.text)),
                          content: Text('Вы действительно хотите удалить ваш активный рейс?', style: GoogleFonts.inter(color: t.sub)),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Нет', style: GoogleFonts.inter(color: t.sub))),
                            TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Да, отменить', style: GoogleFonts.inter(color: Colors.red))),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await provider.cancelRide(rideId);
                        if (mounted) {
                          NotificationService.notify(
                            context, 
                            'Рейс отменен', 
                            'Ваш активный рейс успешно удален!', 
                            isSuccess: true
                          );
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.close_rounded, color: Colors.red, size: 14),
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
      ),
    );
  }
}
