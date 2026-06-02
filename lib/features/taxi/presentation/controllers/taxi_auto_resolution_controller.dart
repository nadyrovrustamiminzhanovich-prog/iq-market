import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iqmarket/providers/taxi_provider.dart';
import 'package:iqmarket/services/notification_service.dart';
import 'package:iqmarket/theme/taxi_theme.dart';
import 'package:iqmarket/features/taxi/presentation/controllers/taxi_dialogs_controller.dart';

/// Контроллер для автоматического разрешения (auto-resolution) долгих поездок.
///
/// Если поездка висит в статусе "active" более 90 минут, 
/// показывает диалог-опрос: "Поездка состоялась?".
class TaxiAutoResolutionController {
  // Статичный сет для хранения показанных диалогов в рамках сессии,
  // чтобы не спамить пользователя одним и тем же вопросом.
  static final Set<String> _shownAutoResolutionRides = {};

  const TaxiAutoResolutionController._();

  /// Проверяет активные заказы и поездки. Если время превысило 90 минут,
  /// показывает диалог для подтверждения или отмены.
  static void checkAndShowPendingRidesDialog(BuildContext context, TaxiProvider provider, TaxiTheme t) {
    if (!context.mounted) return;
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // Scan accepted orders (пассажир)
    for (var order in provider.myAcceptedOrders) {
      final orderId = order['id'];
      if (orderId == null || _shownAutoResolutionRides.contains(orderId)) continue;

      final createdAt = order['createdAt'];
      if (createdAt != null) {
        DateTime createdDateTime = _parseDateTime(createdAt);
        final diff = DateTime.now().difference(createdDateTime);
        
        if (diff.inMinutes > 90) { // 1.5 hours
          _shownAutoResolutionRides.add(orderId);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            showAutoResolutionDialog(context, provider, t, order, isOrder: true);
          });
          return; // Show one at a time
        }
      }
    }

    // Scan accepted rides (водитель)
    for (var ride in provider.myAcceptedRides) {
      final rideId = ride['id'];
      if (rideId == null || _shownAutoResolutionRides.contains(rideId)) continue;

      final createdAt = ride['createdAt'];
      if (createdAt != null) {
        DateTime createdDateTime = _parseDateTime(createdAt);
        final diff = DateTime.now().difference(createdDateTime);
        
        if (diff.inMinutes > 90) {
          _shownAutoResolutionRides.add(rideId);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            showAutoResolutionDialog(context, provider, t, ride, isOrder: false);
          });
          return;
        }
      }
    }
  }

  static DateTime _parseDateTime(dynamic createdAt) {
    if (createdAt is Timestamp) {
      return createdAt.toDate();
    } else if (createdAt is int) {
      return DateTime.fromMillisecondsSinceEpoch(createdAt);
    } else {
      return DateTime.tryParse(createdAt.toString()) ?? DateTime.now();
    }
  }

  /// Показывает сам диалог с вопросом "Поездка состоялась?".
  static void showAutoResolutionDialog(
    BuildContext context, 
    TaxiProvider provider, 
    TaxiTheme t, 
    Map<String, dynamic> data, 
    {required bool isOrder}
  ) {
    final docId = data['id'] ?? '';
    final from = data['from'] ?? '';
    final to = data['to'] ?? '';
    final price = data['price'] ?? 0;
    
    final isDriverRole = data['driverId'] == FirebaseAuth.instance.currentUser?.uid;
        
    final otherName = isDriverRole
        ? (data['passengerName'] ?? data['name'] ?? 'Пассажир')
        : (data['driverName'] ?? 'Водитель');

    showDialog(
      context: context,
      barrierDismissible: false, // Force them to answer!
      builder: (ctx) => Dialog(
        backgroundColor: t.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF84CC16).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.directions_car_rounded, color: Color(0xFF84CC16), size: 36),
              ),
              const SizedBox(height: 20),
              Text(
                'Поездка состоялась? 🚙',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 20, color: t.text),
              ),
              const SizedBox(height: 12),
              Text(
                isDriverRole
                    ? 'Ранее вы связывали заказ из $from в $to с пассажиром $otherName за $price ₸.\n\nПодтвердите, доехали ли вы, чтобы мы корректно рассчитали вашу статистику!'
                    : 'Ранее вы связывали поездку из $from в $to с водителем $otherName за $price ₸.\n\nПодтвердите, доехали ли вы!',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: t.sub, fontSize: 13, height: 1.45),
              ),
              const SizedBox(height: 24),
              
              // Yes, we completed the trip!
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  HapticFeedback.heavyImpact();
                  if (isOrder) {
                    await provider.completeOrder(docId);
                  } else {
                    await provider.completeRide(docId);
                  }
                  if (context.mounted) {
                    NotificationService.notify(context, 'Успешно завершено!', 'Спасибо, поездка сохранена в статистике.', isSuccess: true);
                    TaxiDialogsController.showFeedbackDialog(
                      context, 
                      provider, 
                      t, 
                      isDriverRole ? (data['passengerId'] ?? 'demo_passenger_id') : (data['driverId'] ?? 'demo_driver_id'), 
                      otherName
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF84CC16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  minimumSize: const Size(double.infinity, 50),
                  elevation: 0,
                ),
                child: Text('Да, мы успешно доехали! ✅', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5)),
              ),
              const SizedBox(height: 10),
              
              // No, we didn't go!
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  HapticFeedback.mediumImpact();
                  if (isOrder) {
                    await provider.cancelOrder(docId);
                  } else {
                    await provider.cancelRide(docId);
                  }
                  if (context.mounted) {
                    NotificationService.notify(context, 'Поездка отменена', 'Связь успешно сброшена.', isSuccess: false);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.withValues(alpha: 0.1),
                  foregroundColor: Colors.red,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  minimumSize: const Size(double.infinity, 50),
                  elevation: 0,
                ),
                child: Text('Нет, поездка не состоялась ❌', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13.5)),
              ),
              const SizedBox(height: 10),
              
              // Still driving (keep active)
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  HapticFeedback.lightImpact();
                },
                child: Text('Еще едем в пути 🚙', style: GoogleFonts.inter(color: t.sub, fontWeight: FontWeight.bold, fontSize: 12.5)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
