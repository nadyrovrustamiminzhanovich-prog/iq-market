import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/taxi_order_model.dart';

/// Репозиторий для работы с заказами пассажиров в Firestore.
/// Коллекция: `taxi_orders`
class TaxiOrderRepository {
  static final _col = FirebaseFirestore.instance.collection('taxi_orders');

  // ─── CREATE ───────────────────────────────────────────────────────────────

  /// Создаёт новый заказ пассажира.
  /// Возвращает id созданного документа, либо null при ошибке.
  static Future<String?> createOrder({
    required String from,
    required String to,
    required String date,
    required String time,
    required int seats,
    required int price,
    required String comment,
    required String firstName,
    required String lastName,
    required String phone,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    try {
      final docRef = _col.doc();
      final data = {
        'id': docRef.id,
        'passengerId': user.uid,
        'passengerName': '$firstName $lastName'.trim().isEmpty
            ? 'Пассажир'
            : '$firstName $lastName'.trim(),
        'passengerPhone': phone,
        'passengerImg': user.photoURL ?? '',
        'from': from,
        'to': to,
        'date': date,
        'time': time,
        'seats': seats,
        'price': price,
        'comment': comment,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      };
      await docRef.set(data);
      return docRef.id;
    } catch (e) {
      debugPrint('TaxiOrderRepository.createOrder error: $e');
      return null;
    }
  }

  // ─── READ ─────────────────────────────────────────────────────────────────

  /// Стрим активных заказов (status == 'active').
  /// Лимит 50 для контроля Firestore-расходов.
  static Stream<List<Map<String, dynamic>>> activeOrdersStream() {
    return _col
        .where('status', isEqualTo: 'active')
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  /// Стрим принятых заказов, где текущий пользователь — пассажир.
  static Stream<List<Map<String, dynamic>>> myAcceptedOrdersAsPassengerStream(
      String userId) {
    return _col
        .where('passengerId', isEqualTo: userId)
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  /// Стрим принятых заказов, где текущий пользователь — водитель.
  static Stream<List<Map<String, dynamic>>> myAcceptedOrdersAsDriverStream(
      String userId) {
    return _col
        .where('driverId', isEqualTo: userId)
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  /// Получает один заказ по id.
  static Future<TaxiOrderModel?> getOrderById(String orderId) async {
    try {
      final doc = await _col.doc(orderId).get();
      if (!doc.exists) return null;
      final data = doc.data()!;
      data['id'] = doc.id;
      return TaxiOrderModel.fromMap(data);
    } catch (e) {
      debugPrint('TaxiOrderRepository.getOrderById error: $e');
      return null;
    }
  }

  // ─── UPDATE ───────────────────────────────────────────────────────────────

  /// Принимает заказ: водитель связывается с пассажиром.
  static Future<bool> acceptOrder({
    required String orderId,
    required String driverId,
    required String driverName,
    required String driverPhone,
    required String driverCar,
    required String driverPlate,
    required String driverImg,
    required bool driverVerified,
  }) async {
    try {
      await _col.doc(orderId).update({
        'status': 'accepted',
        'driverId': driverId,
        'driverName': driverName,
        'driverPhone': driverPhone,
        'driverCar': driverCar,
        'driverPlate': driverPlate,
        'driverImg': driverImg,
        'driverVerified': driverVerified,
        'acceptedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('TaxiOrderRepository.acceptOrder error: $e');
      return false;
    }
  }

  /// Завершает заказ.
  static Future<bool> completeOrder(String orderId) async {
    try {
      await _col.doc(orderId).update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('TaxiOrderRepository.completeOrder error: $e');
      return false;
    }
  }

  /// Отменяет заказ.
  static Future<bool> cancelOrder(String orderId,
      {String reason = ''}) async {
    try {
      await _col.doc(orderId).update({
        'status': 'cancelled',
        'cancelReason': reason,
        'cancelledAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('TaxiOrderRepository.cancelOrder error: $e');
      return false;
    }
  }

  /// Обновляет цену принятого заказа (при торге).
  static Future<bool> updateOrderPrice(String orderId, int newPrice) async {
    try {
      await _col.doc(orderId).update({'price': newPrice});
      return true;
    } catch (e) {
      debugPrint('TaxiOrderRepository.updateOrderPrice error: $e');
      return false;
    }
  }
}
