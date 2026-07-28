import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:iqmarket/providers/taxi_provider.dart';
import 'package:iqmarket/theme/taxi_theme.dart';
import 'package:iqmarket/features/taxi/presentation/widgets/ui/taxi_active_order_tracking_view.dart';
import 'package:iqmarket/features/taxi/presentation/widgets/ui/taxi_verification_info_dialog.dart';
import 'package:iqmarket/widgets/taxi/taxi_driver_card.dart';
import 'package:iqmarket/features/taxi/presentation/controllers/taxi_dialogs_controller.dart';

/// Виджет, отображающий интерфейс для пассажира.
///
/// Содержит отслеживание активного заказа, назначеного водителя, 
/// форму поиска маршрута и список подходящих водителей в сети.
class TaxiPassengerView extends StatelessWidget {
  final TaxiProvider provider;
  final TaxiTheme t;
  final Function(Map<String, dynamic> data, {required bool isCall}) onHandlePassengerCallOrChat;
  final VoidCallback onNavigateToLogin;
  final Function(VoidCallback) onShowPhoneBinding;
  final Widget complexFormWidget;

  const TaxiPassengerView({
    super.key,
    required this.provider,
    required this.t,
    required this.onHandlePassengerCallOrChat,
    required this.onNavigateToLogin,
    required this.onShowPhoneBinding,
    required this.complexFormWidget,
  });

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    // Гости видят форму и список водителей.
    // При попытке оформить заказ — перенаправляем на логин (через onSubmitTap).

    // Check if the current passenger has an active order (looking for drivers)
    final myActiveOrder = currentUser == null ? <String, dynamic>{} : provider.allPassengerOrders.firstWhere(
      (o) => o['passengerId'] == currentUser.uid && o['status'] == 'active',
      orElse: () => <String, dynamic>{},
    );



    if (myActiveOrder.isNotEmpty) {
      return Column(
        children: [
          TaxiActiveOrderTrackingView(
            provider: provider, 
            t: t, 
            order: myActiveOrder,
            onShowUserProfile: (p, th, n, img, car, isD, tId, {isVerified = false, phone = ''}) {
              TaxiDialogsController.showUserProfile(
                context, p, th, n, img, car, isD, tId, 
                isVerified: isVerified, phone: phone, 
                onNavigateToLogin: onNavigateToLogin,
              );
            },
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    provider.translate('available_drivers_online'),
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (provider.allDrives.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: Text(
                  provider.translate('no_drivers_online'),
                  style: GoogleFonts.inter(color: t.sub, fontSize: 13),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: provider.allDrives.map((d) => TaxiDriverCard(
                  provider: provider,
                  t: t,
                  driver: d,
                  onShowProfile: () => TaxiDialogsController.showUserProfile(
                    context, provider, t, 
                    d['name'] ?? provider.translate('driver_role'), d['img'] ?? '', d['car'] ?? '', true, d['driverId'] ?? '', 
                    isVerified: d['driverVerified'] == true || d['isVehicleVerified'] == true || d['driverVerified'] == 'true', 
                    phone: d['phone'] ?? '',
                    onNavigateToLogin: onNavigateToLogin,
                  ),
                  onCall: () => onHandlePassengerCallOrChat(d, isCall: true),
                  onChat: () => onHandlePassengerCallOrChat(d, isCall: false),
                  onNegotiate: () {
                    if (!provider.isLoggedIn) {
                      onNavigateToLogin();
                      return;
                    }
                    TaxiDialogsController.showNegotiateDialog(
                      context, provider, t, {
                        'price': d['price'] ?? 0,
                        'name': d['name'] ?? provider.translate('driver_role'),
                        'targetId': d['id'] ?? '',
                        'targetType': 'ride',
                        'receiverId': d['driverId'] ?? '',
                      },
                      onShowPhoneBinding: (ctx, p, th, cb) => onShowPhoneBinding(cb),
                    );
                  },
                )).toList(),
              ),
            ),
          const SizedBox(height: 100),
        ],
      );
    }



    // Default search/create order view
    final hasActiveFilter = provider.from.isNotEmpty || provider.to.isNotEmpty;
    final matchedDrives = provider.filteredDrives;
    final Set<String> matchedIds = matchedDrives.map((d) => (d['id'] ?? '').toString()).toSet();
    final otherDrives = provider.allDrives.where((d) => !matchedIds.contains(d['id'] ?? '')).toList();

    return Column(
      children: [
        // Баннер для гостей
        if (currentUser == null)
          GestureDetector(
            onTap: onNavigateToLogin,
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [t.accent, t.accent.withValues(alpha: 0.85)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: t.accent.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.login_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          provider.translate('login_to_create_order'),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          provider.translate('view_drivers_without_login'),
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 14),
                ],
              ),
            ),
          ),
        complexFormWidget,
        const SizedBox(height: 24),
        // Section header with count badge
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  provider.translate('drivers'),
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B)),
                ),
              ),
              if (provider.isLoggedIn && !provider.isVehicleVerified)
                GestureDetector(
                  onTap: () => showTaxiVerificationInfoDialog(context, t),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.25), width: 1),
                    ),
                    child: const Icon(Icons.verified_user_rounded, color: Color(0xFF0284C7), size: 16),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        if (hasActiveFilter) ...[
          // ── SEARCH RESULTS / MATCHES SECTION ──
          if (matchedDrives.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 12),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
                  const SizedBox(width: 6),
                  Text(
                    '${provider.translate('found_on_route')} (${matchedDrives.length}):',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, color: const Color(0xFF10B981), letterSpacing: 0.3),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: matchedDrives.map((d) => TaxiDriverCard(
                  provider: provider,
                  t: t,
                  driver: d,
                  onShowProfile: () => TaxiDialogsController.showUserProfile(
                    context, provider, t, 
                    d['name'] ?? provider.translate('driver_role'), d['img'] ?? '', d['car'] ?? '', true, d['driverId'] ?? '', 
                    isVerified: d['driverVerified'] == true || d['isVehicleVerified'] == true || d['driverVerified'] == 'true', 
                    phone: d['phone'] ?? '',
                    onNavigateToLogin: onNavigateToLogin,
                  ),
                  onCall: () => onHandlePassengerCallOrChat(d, isCall: true),
                  onChat: () => onHandlePassengerCallOrChat(d, isCall: false),
                  onNegotiate: () {
                    if (!provider.isLoggedIn) {
                      onNavigateToLogin();
                      return;
                    }
                    TaxiDialogsController.showNegotiateDialog(
                      context, provider, t, {
                        'price': d['price'] ?? 0,
                        'name': d['name'] ?? provider.translate('driver_role'),
                        'targetId': d['id'] ?? '',
                        'targetType': 'ride',
                        'receiverId': d['driverId'] ?? '',
                      },
                      onShowPhoneBinding: (ctx, p, th, cb) => onShowPhoneBinding(cb),
                    );
                  },
                )).toList(),
              ),
            ),
          ] else ...[
            // ❌ No matches card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: t.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: t.accent.withValues(alpha: 0.18), width: 1),
                boxShadow: [
                  BoxShadow(color: t.accent.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: t.accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.near_me_rounded, color: t.accent, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          provider.translate('no_drivers_on_route'),
                          style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w700, color: t.text),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          provider.translate('create_order_now_desc'),
                          style: GoogleFonts.inter(fontSize: 11, color: t.sub, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── GENERAL POOL SECTION (FALLBACK CONTINUATION) ──
          if (otherDrives.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 24, bottom: 12),
              child: Row(
                children: [
                  const Icon(Icons.directions_car_rounded, color: Color(0xFF64748B), size: 16),
                  const SizedBox(width: 6),
                  Text(
                    provider.translate('other_drivers_online'),
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, color: const Color(0xFF64748B), letterSpacing: 0.3),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: otherDrives.map((d) => TaxiDriverCard(
                  provider: provider,
                  t: t,
                  driver: d,
                  onShowProfile: () => TaxiDialogsController.showUserProfile(
                    context, provider, t, 
                    d['name'] ?? provider.translate('driver_role'), d['img'] ?? '', d['car'] ?? '', true, d['driverId'] ?? '', 
                    isVerified: d['driverVerified'] == true || d['isVehicleVerified'] == true || d['driverVerified'] == 'true', 
                    phone: d['phone'] ?? '',
                    onNavigateToLogin: onNavigateToLogin,
                  ),
                  onCall: () => onHandlePassengerCallOrChat(d, isCall: true),
                  onChat: () => onHandlePassengerCallOrChat(d, isCall: false),
                  onNegotiate: () {
                    if (!provider.isLoggedIn) {
                      onNavigateToLogin();
                      return;
                    }
                    TaxiDialogsController.showNegotiateDialog(
                      context, provider, t, {
                        'price': d['price'] ?? 0,
                        'name': d['name'] ?? provider.translate('driver_role'),
                        'targetId': d['id'] ?? '',
                        'targetType': 'ride',
                        'receiverId': d['driverId'] ?? '',
                      },
                      onShowPhoneBinding: (ctx, p, th, cb) => onShowPhoneBinding(cb),
                    );
                  },
                )).toList(),
              ),
            ),
          ],
        ] else ...[
          // ── ALL AVAILABLE DRIVERS (NO FILTER ACTIVE) ──
          if (provider.allDrives.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: provider.allDrives.map((d) => TaxiDriverCard(
                  provider: provider,
                  t: t,
                  driver: d,
                  onShowProfile: () => TaxiDialogsController.showUserProfile(
                    context, provider, t, 
                    d['name'] ?? provider.translate('driver_role'), d['img'] ?? '', d['car'] ?? '', true, d['driverId'] ?? '', 
                    isVerified: d['driverVerified'] == true || d['isVehicleVerified'] == true || d['driverVerified'] == 'true', 
                    phone: d['phone'] ?? '',
                    onNavigateToLogin: onNavigateToLogin,
                  ),
                  onCall: () => onHandlePassengerCallOrChat(d, isCall: true),
                  onChat: () => onHandlePassengerCallOrChat(d, isCall: false),
                  onNegotiate: () {
                    if (!provider.isLoggedIn) {
                      onNavigateToLogin();
                      return;
                    }
                    TaxiDialogsController.showNegotiateDialog(
                      context, provider, t, {
                        'price': d['price'] ?? 0,
                        'name': d['name'] ?? provider.translate('driver_role'),
                        'targetId': d['id'] ?? '',
                        'targetType': 'ride',
                        'receiverId': d['driverId'] ?? '',
                      },
                      onShowPhoneBinding: (ctx, p, th, cb) => onShowPhoneBinding(cb),
                    );
                  },
                )).toList(),
              ),
            ),
          ],
        ],
        const SizedBox(height: 100)
      ],
    );
  }
}
