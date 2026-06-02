import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iqmarket/providers/taxi_provider.dart';
import 'package:iqmarket/services/notification_service.dart';
import 'package:iqmarket/theme/taxi_theme.dart';
import 'package:iqmarket/features/taxi/presentation/widgets/ui/taxi_rating_widget.dart';
import 'package:iqmarket/features/taxi/presentation/widgets/ui/taxi_section_header_widget.dart';
import 'package:iqmarket/features/taxi/presentation/controllers/taxi_dialogs_controller.dart';

class TaxiActiveOrderBidsList extends StatelessWidget {
  final List<Map<String, dynamic>> bids;
  final TaxiProvider provider;
  final TaxiTheme t;
  final void Function(
    TaxiProvider provider,
    TaxiTheme t,
    String name,
    String img,
    String car,
    bool isDriver,
    String targetUserId, {
    bool isVerified,
    String phone,
  }) onShowUserProfile;

  const TaxiActiveOrderBidsList({
    super.key,
    required this.bids,
    required this.provider,
    required this.t,
    required this.onShowUserProfile,
  });

  @override
  Widget build(BuildContext context) {
    if (bids.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFEFF6FF), Color(0xFFF0F9FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF4A80F0).withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF4A80F0).withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 3))
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF4A80F0).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF4A80F0), size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ваша поездка создана! 🎉',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Водители видят ваш заказ и скоро свяжутся с вами!',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        TaxiSectionHeader(title: 'Предложения от водителей (${bids.length})', t: t),
        const SizedBox(height: 12),
        Column(
          children: bids.map((bid) {
            final int bidPrice = bid['offeredPrice'] ?? 0;
            final String driverName = bid['senderName'] ?? 'Водитель';
            final String bidId = bid['id'] ?? '';
            final String driverId = bid['senderId'] ?? '';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFF1F5F9)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onShowUserProfile(
                              provider,
                              t,
                              driverName,
                              bid['senderImg'] ?? '',
                              bid['senderCar'] ?? 'Машина не указана',
                              true,
                              driverId,
                              isVerified: bid['senderVerified'] == true,
                              phone: bid['senderPhone'] ?? '');
                        },
                        child: CircleAvatar(
                          radius: 24,
                          backgroundColor: const Color(0xFFF1F5F9),
                          backgroundImage: bid['senderImg'] != null &&
                                  bid['senderImg'].toString().isNotEmpty
                              ? NetworkImage(bid['senderImg'])
                              : null,
                          child: bid['senderImg'] == null ||
                                  bid['senderImg'].toString().isEmpty
                              ? const Icon(Icons.person,
                                  color: Color(0xFF64748B))
                              : null,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            onShowUserProfile(
                                provider,
                                t,
                                driverName,
                                bid['senderImg'] ?? '',
                                bid['senderCar'] ?? 'Машина не указана',
                                true,
                                driverId,
                                isVerified: bid['senderVerified'] == true,
                                phone: bid['senderPhone'] ?? '');
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                driverName,
                                style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: const Color(0xFF1E293B)),
                              ),
                              const SizedBox(height: 4),
                              TaxiRatingWidget(
                                  provider: provider, t: t, userId: driverId),
                              const SizedBox(height: 4),
                              Text(
                                'Предлагает: $bidPrice ₸',
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF4A80F0)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            HapticFeedback.lightImpact();
                            await provider.rejectBid(bidId);
                            if (context.mounted) {
                              NotificationService.notify(context, 'Отклонено',
                                  'Вы отклонили предложение',
                                  isSuccess: false);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.red.withValues(alpha: 0.15)),
                            ),
                            child: Center(
                              child: Text(
                                'Отклонить',
                                style: GoogleFonts.inter(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            HapticFeedback.mediumImpact();
                            TaxiDialogsController.showMatchSuccessDialog(
                              context: context,
                              driverName: driverName,
                              driverPhone: bid['senderPhone'] ?? '',
                              driverImg: bid['senderImg'] ?? '',
                              driverCar: bid['senderCar'] ?? 'Машина не указана',
                              driverPlate: bid['senderPlate'] ?? 'Б/Н',
                              price: bidPrice,
                              bidId: bidId,
                              provider: provider,
                              t: t,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [
                                Color(0xFF4A80F0),
                                Color(0xFF4A80F0)
                              ]),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                    color: const Color(0xFF4A80F0)
                                        .withValues(alpha: 0.15),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4))
                              ],
                            ),
                            child: Center(
                              child: Text(
                                'Принять',
                                style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
