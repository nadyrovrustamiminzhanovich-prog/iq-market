import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iqmarket/providers/taxi_provider.dart';
import 'package:iqmarket/services/notification_service.dart';
import 'package:iqmarket/theme/taxi_theme.dart';

/// Контроллер-делегат для логики завершения поездки.
///
/// Содержит:
/// - [checkAndShowPendingRidesDialog] — сканирует принятые поездки/заказы
///   старше 90 минут и показывает диалог авторезолюции
/// - [showAutoResolutionDialog] — диалог «Поездка состоялась?»
///
/// Совет по использованию:
/// Вызывайте [checkAndShowPendingRidesDialog] из [didChangeDependencies]
/// только когда набор активных поездок реально изменился (сравнивая Set id-шников).
class TaxiTripCompletionController {
  const TaxiTripCompletionController._();

  // ─────────────────────────────────────────────────────────────────────────
  // Public API
  // ─────────────────────────────────────────────────────────────────────────

  /// Проверяет принятые поездки/заказы старше 90 минут.
  /// Если найдены — показывает диалог авторезолюции.
  ///
  /// [shownAutoResolutionRides] — Set id-шников, для которых диалог уже
  /// был показан. Метод сам добавляет туда новые id, чтобы не показывать
  /// один и тот же диалог дважды.
  ///
  /// [onShowFeedback] — колбэк для показа диалога отзыва после завершения.
  static void checkAndShowPendingRidesDialog(
    BuildContext context,
    TaxiProvider provider,
    TaxiTheme t,
    Set<String> shownAutoResolutionRides, {
    required void Function(
      TaxiProvider provider,
      TaxiTheme t,
      String targetUserId,
      String targetUserName,
    ) onShowFeedback,
  }) {
    if (!context.mounted) return;
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // Сканируем принятые заказы
    for (final order in provider.myAcceptedOrders) {
      final orderId = order['id']?.toString();
      if (orderId == null || shownAutoResolutionRides.contains(orderId)) {
        continue;
      }

      final diff = _getAgeMinutes(order['createdAt']);
      if (diff > 90) {
        shownAutoResolutionRides.add(orderId);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          showAutoResolutionDialog(
            context,
            provider,
            t,
            order,
            isOrder: true,
            onShowFeedback: onShowFeedback,
          );
        });
        return; // Показываем по одному
      }
    }

    // Сканируем принятые поездки
    for (final ride in provider.myAcceptedRides) {
      final rideId = ride['id']?.toString();
      if (rideId == null || shownAutoResolutionRides.contains(rideId)) {
        continue;
      }

      final diff = _getAgeMinutes(ride['createdAt']);
      if (diff > 90) {
        shownAutoResolutionRides.add(rideId);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          showAutoResolutionDialog(
            context,
            provider,
            t,
            ride,
            isOrder: false,
            onShowFeedback: onShowFeedback,
          );
        });
        return;
      }
    }
  }

  /// Диалог «Поездка состоялась? 🚙» — принудительное подтверждение.
  ///
  /// [isOrder] = true → это заказ пассажира, false → поездка водителя.
  static void showAutoResolutionDialog(
    BuildContext context,
    TaxiProvider provider,
    TaxiTheme t,
    Map<String, dynamic> data, {
    required bool isOrder,
    required void Function(
      TaxiProvider provider,
      TaxiTheme t,
      String targetUserId,
      String targetUserName,
    ) onShowFeedback,
  }) {
    final docId = data['id']?.toString() ?? '';
    final from = data['from']?.toString() ?? '';
    final to = data['to']?.toString() ?? '';
    final price = data['price'] ?? 0;

    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final isDriverRole = data['driverId'] == currentUid;

    final otherName = isDriverRole
        ? (data['passengerName'] ?? data['name'] ?? 'Пассажир').toString()
        : (data['driverName'] ?? 'Водитель').toString();

    final otherUserId = isDriverRole
        ? (data['passengerId'] ?? '').toString()
        : (data['driverId'] ?? '').toString();

    showDialog(
      context: context,
      barrierDismissible: false, // Обязательный ответ!
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
                child: const Icon(
                  Icons.directions_car_rounded,
                  color: Color(0xFF84CC16),
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Поездка состоялась? 🚙',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  color: t.text,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isDriverRole
                    ? 'Ранее вы связывали заказ из $from в $to с пассажиром '
                        '$otherName за $price ₸.\n\nПодтвердите, доехали ли вы!'
                    : 'Ранее вы связывали поездку из $from в $to с водителем '
                        '$otherName за $price ₸.\n\nПодтвердите, доехали ли вы!',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: t.sub,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),

              // ✅ Да, доехали
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
                    NotificationService.notify(
                      context,
                      'Успешно завершено!',
                      'Спасибо, поездка сохранена в статистике.',
                      isSuccess: true,
                    );
                    onShowFeedback(provider, t, otherUserId, otherName);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF84CC16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  minimumSize: const Size(double.infinity, 50),
                  elevation: 0,
                ),
                child: Text(
                  'Да, мы успешно доехали! ✅',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  HapticFeedback.mediumImpact();
                  try {
                    if (isOrder) {
                      await provider.cancelOrder(docId);
                    } else {
                      await provider.cancelRide(docId);
                    }
                    if (context.mounted) {
                      NotificationService.notify(
                        context,
                        'Поездка отменена',
                        'Связь успешно сброшена.',
                        isSuccess: false,
                      );
                    }
                  } catch (e) {
                    debugPrint('[TAXI] Error completing cancel: $e');
                    if (context.mounted) {
                      NotificationService.notify(
                        context,
                        'Ошибка',
                        'Не удалось сбросить поездку: $e',
                        isSuccess: false,
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.withValues(alpha: 0.1),
                  foregroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  minimumSize: const Size(double.infinity, 50),
                  elevation: 0,
                ),
                child: Text(
                  'Нет, поездка не состоялась ❌',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // 🚙 Ещё едем
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  HapticFeedback.lightImpact();
                },
                child: Text(
                  'Еще едем в пути 🚙',
                  style: GoogleFonts.inter(
                    color: t.sub,
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Private helpers
  // ─────────────────────────────────────────────────────────────────────────

  /// Возвращает количество минут с момента создания документа.
  static int _getAgeMinutes(dynamic createdAt) {
    if (createdAt == null) return 0;
    try {
      DateTime created;
      if (createdAt is Timestamp) {
        created = createdAt.toDate();
      } else if (createdAt is int) {
        created = DateTime.fromMillisecondsSinceEpoch(createdAt);
      } else {
        created = DateTime.tryParse(createdAt.toString()) ?? DateTime.now();
      }
      return DateTime.now().difference(created).inMinutes;
    } catch (e) { debugPrint('[TripCompletion] Age calculation error: $e');
      return 0;
    }
  }
}
