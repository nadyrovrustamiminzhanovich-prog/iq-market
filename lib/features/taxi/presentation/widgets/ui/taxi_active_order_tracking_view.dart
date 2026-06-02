import 'package:flutter/material.dart';
import 'package:iqmarket/providers/taxi_provider.dart';
import 'package:iqmarket/theme/taxi_theme.dart';
import 'package:iqmarket/features/taxi/presentation/widgets/ui/active_order_components/taxi_active_order_summary.dart';
import 'package:iqmarket/features/taxi/presentation/widgets/ui/active_order_components/taxi_active_order_price_control.dart';
import 'package:iqmarket/features/taxi/presentation/widgets/ui/active_order_components/taxi_active_order_bids_list.dart';

/// Виджет отслеживания активного заказа пассажира.
///
/// Показывает карточку текущего заказа, управление ценой,
/// а также список предложений (ставок) от водителей.
class TaxiActiveOrderTrackingView extends StatelessWidget {
  final TaxiProvider provider;
  final TaxiTheme t;
  final Map<String, dynamic> order;

  /// Добавлен callback для профиля пользователя
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

  const TaxiActiveOrderTrackingView({
    super.key,
    required this.provider,
    required this.t,
    required this.order,
    required this.onShowUserProfile,
  });

  @override
  Widget build(BuildContext context) {
    final orderId = order['id'] ?? '';
    final currentPrice = (order['price'] ?? 0) as int;
    final bids = provider.activeBids.where((b) => b['targetId'] == orderId).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // Order summary card
          TaxiActiveOrderSummary(
            order: order,
            currentPrice: currentPrice,
            orderId: orderId,
            provider: provider,
            t: t,
          ),
          
          const SizedBox(height: 16),
          
          // Price Control (Stateful)
          TaxiActiveOrderPriceControl(
            currentPrice: currentPrice,
            orderId: orderId,
            provider: provider,
            t: t,
          ),
          
          const SizedBox(height: 24),
          
          // Driver Bids Section
          TaxiActiveOrderBidsList(
            bids: bids,
            provider: provider,
            t: t,
            onShowUserProfile: onShowUserProfile,
          ),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
