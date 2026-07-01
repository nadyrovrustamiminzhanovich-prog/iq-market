import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iqmarket/providers/taxi_provider.dart';
import 'package:iqmarket/services/notification_service.dart';
import 'package:iqmarket/theme/taxi_theme.dart';
import 'package:iqmarket/features/taxi/presentation/widgets/ui/taxi_rating_widget.dart';
import 'package:iqmarket/features/taxi/presentation/widgets/ui/taxi_section_header_widget.dart';
import 'package:iqmarket/features/taxi/presentation/controllers/taxi_dialogs_controller.dart';

class TaxiActiveOrderBidsList extends StatefulWidget {
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
  State<TaxiActiveOrderBidsList> createState() => _TaxiActiveOrderBidsListState();
}

class _TaxiActiveOrderBidsListState extends State<TaxiActiveOrderBidsList> {
  final Set<String> _processingBidIds = {};

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> bids = widget.bids;
    final TaxiProvider provider = widget.provider;
    final TaxiTheme t = widget.t;
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
    }) onShowUserProfile = widget.onShowUserProfile;
    if (bids.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFEFF6FF), Color(0xFFF5F3FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4F46E5).withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF4F46E5), size: 22),
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
                        color: const Color(0xFF1E1B4B)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Водители видят ваш заказ и скоро свяжутся с вами!',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.7),
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
        TaxiSectionHeader(title: widget.provider.translate('offersFromDrivers').replaceAll('{count}', bids.length.toString()), t: t),
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
                border: Border.all(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
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
                                    color: const Color(0xFF1E1B4B)),
                              ),
                              const SizedBox(height: 4),
                              TaxiRatingWidget(
                                  provider: provider, t: t, userId: driverId),
                              const SizedBox(height: 4),
                              Text(
                                'Предлагает: $bidPrice ₸',
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF4F46E5)),
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
                  _processingBidIds.contains(bidId)
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () async {
                                  if (_processingBidIds.contains(bidId)) return;
                                  HapticFeedback.lightImpact();
                                  setState(() => _processingBidIds.add(bidId));
                                  try {
                                    await provider.rejectBid(bidId);
                                    if (context.mounted) {
                                      NotificationService.notify(context, provider.translate('declinedTitle'),
                                          provider.translate('declinedOfferMsg'),
                                          isSuccess: false);
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      NotificationService.notify(context, provider.translate('errorTitle'),
                                          provider.translate('errDeclineOffer'),
                                          isSuccess: false);
                                    }
                                  } finally {
                                    if (mounted) {
                                      setState(() => _processingBidIds.remove(bidId));
                                    }
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
                                onTap: () {
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
                                      Color(0xFF4F46E5),
                                      Color(0xFF6366F1)
                                    ]),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                          color: const Color(0xFF4F46E5)
                                              .withValues(alpha: 0.25),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4))
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Принять',
                                      style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
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
