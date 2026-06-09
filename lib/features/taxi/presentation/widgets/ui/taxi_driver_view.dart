import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:iqmarket/providers/taxi_provider.dart';
import 'package:iqmarket/theme/taxi_theme.dart';
import 'package:iqmarket/features/taxi/presentation/widgets/ui/taxi_assigned_passenger_view.dart';
import 'package:iqmarket/features/taxi/presentation/widgets/ui/taxi_active_ride_tracking_view.dart';
import 'package:iqmarket/features/taxi/presentation/widgets/ui/taxi_active_bids_widget.dart';
import 'package:iqmarket/features/taxi/presentation/widgets/ui/taxi_create_ride_button.dart';
import 'package:iqmarket/features/taxi/presentation/widgets/ui/taxi_driver_search_form.dart';
import 'package:iqmarket/widgets/taxi/taxi_order_card.dart';
import 'package:iqmarket/features/taxi/presentation/controllers/taxi_dialogs_controller.dart';

/// Виджет, отображающий интерфейс для водителя.
///
/// Содержит отслеживание активного рейса, кнопки создания рейса,
/// форму поиска заказов и список подходящих заказов пассажиров.
class TaxiDriverView extends StatelessWidget {
  final TaxiProvider provider;
  final TaxiTheme t;
  final Function(Map<String, dynamic> data, {required bool isCall}) onHandleDriverCallOrChat;
  final Function(Map<String, dynamic> data, VoidCallback action) onCheckDriverActionGate;
  final Function(String title) buildSectionHeader;
  
  // Callbacks for search form
  final Widget routeFrom;
  final Widget routeTo;
  final String dateLabel;
  final VoidCallback onDateTap;
  final VoidCallback onSwapTap;
  final VoidCallback onSearchTap;
  
  // Callbacks for actions
  final Function(Map<String, dynamic>) onBidTap;
  final VoidCallback onCreateRideTap;
  final VoidCallback onNavigateToLogin;
  final Function(VoidCallback) onShowPhoneBinding;

  const TaxiDriverView({
    super.key,
    required this.provider,
    required this.t,
    required this.onHandleDriverCallOrChat,
    required this.onCheckDriverActionGate,
    required this.buildSectionHeader,
    required this.routeFrom,
    required this.routeTo,
    required this.dateLabel,
    required this.onDateTap,
    required this.onSwapTap,
    required this.onSearchTap,
    required this.onBidTap,
    required this.onCreateRideTap,
    required this.onNavigateToLogin,
    required this.onShowPhoneBinding,
  });

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final myAssignedOrderAsDriver = provider.allPassengerOrders.firstWhere(
        (o) => o['driverId'] == currentUser.uid && o['status'] == 'accepted',
        orElse: () => <String, dynamic>{},
      );

      final myAssignedRideAsDriver = provider.allDrives.firstWhere(
        (d) => d['driverId'] == currentUser.uid && d['status'] == 'accepted',
        orElse: () => <String, dynamic>{},
      );

      if (myAssignedOrderAsDriver.isNotEmpty) {
        return TaxiAssignedPassengerView(provider: provider, t: t, data: myAssignedOrderAsDriver, isOrder: true);
      } else if (myAssignedRideAsDriver.isNotEmpty) {
        return TaxiAssignedPassengerView(provider: provider, t: t, data: myAssignedRideAsDriver, isOrder: false);
      }
    }

    final orders = provider.filteredOrders;
    
    final otherOrders = provider.allPassengerOrders.where((o) {
      if (o['status'] != 'active') return false;
      final bool isCurrentMatch = orders.any((element) => element['id'] == o['id']);
      return !isCurrentMatch;
    }).toList();
    
    Map<String, dynamic> myActiveRide = <String, dynamic>{};
    if (currentUser != null) {
      myActiveRide = provider.allDrives.firstWhere(
        (d) => d['driverId'] == currentUser.uid && d['status'] == 'active',
        orElse: () => <String, dynamic>{},
      );
    }

    return Column(
      children: [
        if (myActiveRide.isNotEmpty)
          TaxiActiveRideTrackingView(provider: provider, t: t, ride: myActiveRide),
        
        TaxiActiveBidsWidget(provider: provider, t: t, onBidTap: onBidTap),
        
        // _activeTripBanner is intentionally omitted
        
        TaxiCreateRideButton(onTap: onCreateRideTap),
        const SizedBox(height: 16),
        TaxiDriverSearchForm(
          t: t,
          routeFrom: routeFrom,
          routeTo: routeTo,
          dateLabel: dateLabel,
          onDateTap: onDateTap,
          onSwapTap: onSwapTap,
          onSearchTap: onSearchTap,
        ),
        const SizedBox(height: 16),

        buildSectionHeader('${provider.translate('orders')} 📦'),
        const SizedBox(height: 8),
        
        if (orders.isEmpty) ...[
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: t.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF4A80F0).withValues(alpha: 0.18), width: 1),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4A80F0).withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A80F0).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.info_outline_rounded, color: Color(0xFF4A80F0), size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    provider.translate('no_orders_on_route'),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: t.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          ...orders.map((o) => TaxiOrderCard(
                provider: provider,
                t: t,
                name: o['passengerName'] ?? o['name'] ?? provider.translate('passenger_role'),
                from: o['from'] ?? '',
                to: o['to'] ?? '',
                price: o['price'] ?? 0,
                seats: o['seats'] ?? 1,
                comment: o['comment'] ?? '',
                isNegotiated: o['isNegotiated'] ?? false,
                created: '${(o['date'] == 'today' || o['date'] == 'tomorrow' || o['date'] == 'yesterday') ? provider.translate(o['date'] ?? '') : (o['date'] ?? '')}${o['time'] == null || o['time'] == 'time' || o['time'].isEmpty ? '' : ', ' + o['time']}',
                img: o['passengerImg'] ?? o['img'] ?? '',
                phone: o['passengerPhone'] ?? o['phone'] ?? '',
                passengerId: o['passengerId'] ?? o['userId'] ?? '',
                onShowProfile: () => TaxiDialogsController.showUserProfile(
                  context, provider, t, 
                  o['passengerName'] ?? o['name'] ?? provider.translate('passenger_role'), 
                  o['passengerImg'] ?? o['img'] ?? '', 
                  '', false, 
                  o['passengerId'] ?? o['userId'] ?? '', 
                  phone: o['passengerPhone'] ?? o['phone'] ?? '',
                  onNavigateToLogin: onNavigateToLogin,
                ),
                onNegotiate: () {
                  onCheckDriverActionGate(o, () {
                    TaxiDialogsController.showNegotiateDialog(
                      context, provider, t, {
                        'price': o['price'] ?? 0,
                        'name': o['passengerName'] ?? o['name'] ?? provider.translate('passenger_role'),
                        'targetId': o['id'] ?? '',
                        'targetType': 'order',
                        'receiverId': o['passengerId'] ?? o['userId'] ?? '',
                      },
                      onShowPhoneBinding: (ctx, p, th, cb) => onShowPhoneBinding(cb),
                    );
                  });
                },
                onCall: () {
                  onCheckDriverActionGate(o, () {
                    onHandleDriverCallOrChat(o, isCall: true);
                  });
                },
                onChat: () {
                  onCheckDriverActionGate(o, () {
                    onHandleDriverCallOrChat(o, isCall: false);
                  });
                },
              )),
        ],

        // Always show other active orders from other cities/villages below!
        if (otherOrders.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 24, bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    provider.translate('other_active_orders'),
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: const Color(0xFF64748B), letterSpacing: 0.5),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF64748B).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${otherOrders.length}',
                    style: GoogleFonts.inter(color: const Color(0xFF64748B), fontWeight: FontWeight.bold, fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
          ...otherOrders.take(10).map((o) => TaxiOrderCard(
                provider: provider,
                t: t,
                name: o['passengerName'] ?? o['name'] ?? provider.translate('passenger_role'),
                from: o['from'] ?? '',
                to: o['to'] ?? '',
                price: o['price'] ?? 0,
                seats: o['seats'] ?? 1,
                comment: o['comment'] ?? '',
                isNegotiated: o['isNegotiated'] ?? false,
                created: '${(o['date'] == 'today' || o['date'] == 'tomorrow' || o['date'] == 'yesterday') ? provider.translate(o['date'] ?? '') : (o['date'] ?? '')}${o['time'] == null || o['time'] == 'time' || o['time'].isEmpty ? '' : ', ' + o['time']}',
                img: o['passengerImg'] ?? o['img'] ?? '',
                phone: o['passengerPhone'] ?? o['phone'] ?? '',
                passengerId: o['passengerId'] ?? o['userId'] ?? '',
                onShowProfile: () => TaxiDialogsController.showUserProfile(
                  context, provider, t, 
                  o['passengerName'] ?? o['name'] ?? provider.translate('passenger_role'), 
                  o['passengerImg'] ?? o['img'] ?? '', 
                  '', false, 
                  o['passengerId'] ?? o['userId'] ?? '', 
                  phone: o['passengerPhone'] ?? o['phone'] ?? '',
                  onNavigateToLogin: onNavigateToLogin,
                ),
                onNegotiate: () {
                  onCheckDriverActionGate(o, () {
                    TaxiDialogsController.showNegotiateDialog(
                      context, provider, t, {
                        'price': o['price'] ?? 0,
                        'name': o['passengerName'] ?? o['name'] ?? provider.translate('passenger_role'),
                        'targetId': o['id'] ?? '',
                        'targetType': 'order',
                        'receiverId': o['passengerId'] ?? o['userId'] ?? '',
                      },
                      onShowPhoneBinding: (ctx, p, th, cb) => onShowPhoneBinding(cb),
                    );
                  });
                },
                onCall: () {
                  onCheckDriverActionGate(o, () {
                    onHandleDriverCallOrChat(o, isCall: true);
                  });
                },
                onChat: () {
                  onCheckDriverActionGate(o, () {
                    onHandleDriverCallOrChat(o, isCall: false);
                  });
                },
              )),
        ],
        const SizedBox(height: 100)
      ],
    );
  }
}
