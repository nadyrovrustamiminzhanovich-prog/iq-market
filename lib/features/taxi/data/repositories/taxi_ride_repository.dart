import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/taxi_ride_model.dart';

/// Репозиторий для работы с поездками водителей в Firestore.
/// Коллекция: `taxi_rides`
class TaxiRideRepository {
  static final _col = FirebaseFirestore.instance.collection('taxi_rides');

  // ─── CREATE ───────────────────────────────────────────────────────────────

  /// Создаёт новую поездку водителя.
  /// Возвращает id созданного документа, либо null при ошибке.
  static Future<String?> createRide({
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
    required String driverCar,
    required String driverPlate,
    required bool driverVerified,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    try {
      final docRef = _col.doc();
      final data = {
        'id': docRef.id,
        'driverId': user.uid,
        'driverName': '$firstName $lastName'.trim().isEmpty
            ? 'Водитель'
            : '$firstName $lastName'.trim(),
        'driverPhone': phone,
        'driverCar': driverCar,
        'driverPlate': driverPlate,
        'driverImg': user.photoURL ?? '',
        'driverVerified': driverVerified,
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
      debugPrint('TaxiRideRepository.createRide error: $e');
      return null;
    }
  }

  // ─── READ ─────────────────────────────────────────────────────────────────

  /// Стрим активных поездок (status == 'active').
  /// Лимит 50 для контроля Firestore-расходов (критическое исправление аудита).
  static Stream<List<Map<String, dynamic>>> activeRidesStream() {
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

  /// Стрим принятых поездок, где текущий пользователь — водитель.
  static Stream<List<Map<String, dynamic>>> myAcceptedRidesAsDriverStream(
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

  /// Стрим принятых поездок, где текущий пользователь — пассажир.
  static Stream<List<Map<String, dynamic>>> myAcceptedRidesAsPassengerStream(
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

  /// Получает одну поездку по id.
  static Future<TaxiRideModel?> getRideById(String rideId) async {
    try {
      final doc = await _col.doc(rideId).get();
      if (!doc.exists) return null;
      final data = doc.data()!;
      data['id'] = doc.id;
      return TaxiRideModel.fromMap(data);
    } catch (e) {
      debugPrint('TaxiRideRepository.getRideById error: $e');
      return null;
    }
  }

  // ─── UPDATE ───────────────────────────────────────────────────────────────

  /// Принимает пассажира в поездку.
  static Future<bool> acceptPassenger({
    required String rideId,
    required String passengerId,
    required String passengerName,
    required String passengerPhone,
    required String passengerImg,
  }) async {
    try {
      await _col.doc(rideId).update({
        'status': 'accepted',
        'passengerId': passengerId,
        'passengerName': passengerName,
        'passengerPhone': passengerPhone,
        'passengerImg': passengerImg,
        'acceptedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('TaxiRideRepository.acceptPassenger error: $e');
      return false;
    }
  }

  /// Завершает поездку.
  static Future<bool> completeRide(String rideId) async {
    try {
      await _col.doc(rideId).update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('TaxiRideRepository.completeRide error: $e');
      return false;
    }
  }

  /// Отменяет поездку.
  static Future<bool> cancelRide(String rideId, {String reason = ''}) async {
    try {
      await _col.doc(rideId).update({
        'status': 'cancelled',
        'cancelReason': reason,
        'cancelledAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('TaxiRideRepository.cancelRide error: $e');
      return false;
    }
  }

  /// Обновляет цену поездки (при торге).
  static Future<bool> updateRidePrice(String rideId, int newPrice) async {
    try {
      await _col.doc(rideId).update({'price': newPrice});
      return true;
    } catch (e) {
      debugPrint('TaxiRideRepository.updateRidePrice error: $e');
      return false;
    }
  }

  /// История поездок водителя (за последние 50).
  static Future<List<Map<String, dynamic>>> fetchDriverHistory(
      String driverId) async {
    try {
      final snap = await _col
          .where('driverId', isEqualTo: driverId)
          .where('status', isEqualTo: 'completed')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();
      return snap.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('TaxiRideRepository.fetchDriverHistory error: $e');
      return [];
    }
  }
}
