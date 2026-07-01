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

/// Виджет отслеживания поездки водителем после того,
/// как он принял заказ пассажира.
///
/// Отображает информацию о пассажире, цену, кнопки для связи,
/// а также кнопки завершения или отмены поездки.
class TaxiAssignedPassengerView extends StatefulWidget {
  final TaxiProvider provider;
  final TaxiTheme t;
  final Map<String, dynamic> data;
  final bool isOrder;

  const TaxiAssignedPassengerView({
    super.key,
    required this.provider,
    required this.t,
    required this.data,
    required this.isOrder,
  });

  @override
  State<TaxiAssignedPassengerView> createState() => _TaxiAssignedPassengerViewState();
}

class _TaxiAssignedPassengerViewState extends State<TaxiAssignedPassengerView> {
  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    final t = widget.t;
    final data = widget.data;
    final isOrder = widget.isOrder;

    final docId = data['id'] ?? '';
    final passengerName = data['passengerName'] ?? data['name'] ?? 'Пассажир';
    final passengerPhone = data['passengerPhone'] ?? data['phone'] ?? '';
    final passengerImg = data['passengerImg'] ?? data['img'] ?? '';
    final passengerId = data['passengerId'] ?? data['userId'] ?? 'demo_passenger_id';
    final price = (data['price'] ?? 0) as int;

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
                    Row(
                      children: [
                        Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF4A80F0), shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Text(
                          'АКТИВНЫЙ ЗАКАЗ',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: const Color(0xFF4A80F0), fontSize: 11, letterSpacing: 1),
                        ),
                      ],
                    ),
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
                  '${data['from']} → ${data['to']}',
                  style: GoogleFonts.inter(color: const Color(0xFF4A80F0), fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  'Выезд: ${TaxiProvider.formatTaxiDisplayDate(data, provider.curLang)} в ${data['time']}',
                  style: GoogleFonts.inter(color: const Color(0xFF4A80F0), fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Assigned Passenger Card
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
                      backgroundImage: passengerImg.isNotEmpty ? NetworkImage(passengerImg) : null,
                      child: passengerImg.isEmpty ? const Icon(Icons.person, color: Color(0xFF64748B), size: 28) : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            passengerName,
                            style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16, color: const Color(0xFF1E293B)),
                          ),
                          const SizedBox(height: 4),
                          TaxiRatingWidget(provider: provider, t: t, userId: passengerId, targetRole: 'passenger'),
                        ],
                      ),
                    ),
                  ],
                ),
                if (data['comment'] != null && data['comment'].toString().trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF64748B), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          data['comment'],
                          style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF475569), height: 1.3, fontStyle: FontStyle.italic),
                        ),
                      ),
                    ],
                  ),
                ],
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
                    if (passengerPhone.isNotEmpty) {
                      launchUrl(Uri.parse('tel:$passengerPhone'));
                    } else {
                      NotificationService.notify(context, provider.translate('errorTitle'), provider.translate('errNoPassengerPhone'), isSuccess: false);
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
                      id: 'taxi_chat_$docId',
                      title: '${data['from']} → ${data['to']}',
                      description: 'Чат по поездке',
                      price: price.toDouble(),
                      category: 'Taxi',
                      images: passengerImg.isNotEmpty ? [passengerImg] : [],
                      userId: passengerId,
                      userName: passengerName,
                      userEmail: '',
                      timestamp: DateTime.now(),
                      location: data['from'] ?? '',
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
              if (isOrder) {
                await provider.completeOrder(docId);
              } else {
                await provider.completeRide(docId);
              }
              if (mounted) {
                NotificationService.notify(context, provider.translate('rideCompletedTitle'), provider.translate('thanksForWorkMsg'), isSuccess: true);
                TaxiDialogsController.showFeedbackDialog(context, provider, t, passengerId, passengerName, 'passenger');
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
            onPressed: () async {
              HapticFeedback.heavyImpact();
              final bool? confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: t.bg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  title: Text(provider.translate('cancelRideTitle'), style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: t.text)),
                  content: Text(provider.translate('cancelCurrentRideDesc'), style: GoogleFonts.inter(color: t.sub, fontSize: 13)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(provider.translate('noBtn'), style: GoogleFonts.inter(color: t.sub, fontWeight: FontWeight.bold))),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(provider.translate('yesCancelBtn'), style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                if (isOrder) {
                  await provider.cancelOrder(docId);
                } else {
                  await provider.cancelRide(docId);
                }
                if (mounted) {
                  NotificationService.notify(context, provider.translate('rideCanceledTitle'), provider.translate('connectionCanceledMsg'), isSuccess: false);
                }
              }
            },
            child: Text(
              'Мы не поехали / Отменить',
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
