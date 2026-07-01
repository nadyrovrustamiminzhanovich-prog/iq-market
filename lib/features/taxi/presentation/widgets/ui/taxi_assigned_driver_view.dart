import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:iqmarket/providers/taxi_provider.dart';
import 'package:iqmarket/services/notification_service.dart';
import 'package:iqmarket/theme/taxi_theme.dart';
import 'package:iqmarket/screens/chat_screen.dart';
import 'package:iqmarket/models/ad_model.dart';
import 'package:iqmarket/features/taxi/presentation/widgets/ui/taxi_rating_widget.dart';
import 'package:iqmarket/features/taxi/presentation/controllers/taxi_dialogs_controller.dart';

/// Виджет отслеживания поездки пассажиром после того,
/// как он был назначен (совпал с водителем).
///
/// Отображает информацию о водителе, машине, цену и кнопки
/// для связи с водителем (позвонить, написать) или отмены/завершения.
class TaxiAssignedDriverView extends StatefulWidget {
  final TaxiProvider provider;
  final TaxiTheme t;
  final Map<String, dynamic> order;

  const TaxiAssignedDriverView({
    super.key,
    required this.provider,
    required this.t,
    required this.order,
  });

  @override
  State<TaxiAssignedDriverView> createState() => _TaxiAssignedDriverViewState();
}

class _TaxiAssignedDriverViewState extends State<TaxiAssignedDriverView> {
  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    final t = widget.t;
    final order = widget.order;

    final orderId = order['id'] ?? '';
    final driverId = order['driverId'] ?? 'demo_driver_id';
    final driverName = order['driverName'] ?? 'Водитель';
    final driverPhone = order['driverPhone'] ?? '';
    final driverCar = order['driverCar'] ?? 'Машина не указана';
    final driverPlate = order['driverPlate'] ?? 'Б/Н';
    final driverImg = order['driverImg'] ?? '';
    final price = (order['price'] ?? 0) as int;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // Visual trip header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: t.card,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: t.accent.withValues(alpha: 0.15), width: 1.5),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 15, offset: const Offset(0, 5))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF4A80F0), shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'ПОЕЗДКА ПРИНЯТА',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: const Color(0xFF4A80F0), fontSize: 11, letterSpacing: 1),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4A80F0),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$price ₸',
                        style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '${order['from']} → ${order['to']}',
                  style: GoogleFonts.inter(color: const Color(0xFF4A80F0), fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  'Выезд: ${TaxiProvider.formatTaxiDisplayDate(order, provider.curLang)} в ${order['time']}',
                  style: GoogleFonts.inter(color: const Color(0xFF4A80F0), fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Assigned Driver Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFFF1F5F9)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 15, offset: const Offset(0, 5))
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: const Color(0xFFF1F5F9),
                      backgroundImage: driverImg.isNotEmpty ? NetworkImage(driverImg) : null,
                      child: driverImg.isEmpty ? const Icon(Icons.person, color: Color(0xFF64748B), size: 28) : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                driverName,
                                style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16, color: const Color(0xFF1E293B)),
                              ),
                              if (order['driverVerified'] == true) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.verified_user_rounded, color: Color(0xFF4A80F0), size: 16),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          TaxiRatingWidget(provider: provider, t: t, userId: driverId),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                const Divider(color: Color(0xFFF1F5F9)),
                const SizedBox(height: 20),
                
                // Vehicle detail row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4A80F0).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.directions_car_rounded, color: Color(0xFF4A80F0), size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            driverCar,
                            style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14, color: const Color(0xFF1E293B)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Гос. номер: $driverPlate',
                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Action buttons: Call and Chat
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    if (driverPhone.isNotEmpty) {
                      launchUrl(Uri.parse('tel:$driverPhone'));
                    } else {
                      NotificationService.notify(context, provider.translate('errorTitle'), provider.translate('errNoDriverPhone'), isSuccess: false);
                    }
                  },
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))
                      ],
                    ),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.phone_rounded, color: Color(0xFF4A80F0), size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Позвонить',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF4A80F0),
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(ad: AdModel(
                      id: 'taxi_chat_$orderId',
                      title: '${order['from']} → ${order['to']}',
                      description: 'Чат по поездке',
                      price: price.toDouble(),
                      category: 'Taxi',
                      images: driverImg.isNotEmpty ? [driverImg] : [],
                      userId: driverId,
                      userName: driverName,
                      userEmail: '',
                      timestamp: DateTime.now(),
                      location: order['from'] ?? '',
                    ))));
                  },
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))
                      ],
                    ),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF4A80F0), size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Написать',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF4A80F0),
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          
          // Complete ride button
          GestureDetector(
            onTap: () async {
              HapticFeedback.heavyImpact();
              await provider.completeOrder(orderId);
              if (mounted) {
                NotificationService.notify(context, provider.translate('rideCompletedTitle'), provider.translate('thanksForChoosingMsg'), isSuccess: true);
                TaxiDialogsController.showFeedbackDialog(context, provider, t, driverId, driverName, 'driver');
              }
            },
            child: Container(
              width: double.infinity,
              height: 60,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF84CC16), Color(0xFF4D7C0F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF84CC16).withValues(alpha: 0.4), blurRadius: 15, offset: const Offset(0, 8))
                ],
              ),
              child: Center(
                child: Text(
                  'ЗАВЕРШИТЬ ПОЕЗДКУ',
                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              HapticFeedback.heavyImpact();
              TaxiDialogsController.showCancelSurveyDialog(context, provider, t, orderId);
            },
            child: Text(
              'Отменить заказ',
              style: GoogleFonts.inter(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}
