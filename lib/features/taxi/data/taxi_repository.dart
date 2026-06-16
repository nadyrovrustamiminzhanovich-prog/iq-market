import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:iqmarket/services/notification_service.dart';

class TaxiRepository {
  /// БЕЗОПАСНОСТЬ: Строгая нормализация телефона на уровне сервера (Backend-like).
  /// Убирает все лишние символы. Спасает от кривой вставки из буфера обмена.
  String _sanitizePhone(String phone) {
    String clean = phone.replaceAll(RegExp(r'\D'), '');
    if (clean.length == 10) return '+7$clean';
    if (clean.length == 11 && clean.startsWith('8')) return '+7${clean.substring(1)}';
    if (clean.length == 11 && clean.startsWith('7')) return '+$clean';
    return phone.isNotEmpty ? phone : '';
  }

  Future<void> createPassengerOrder({
    required String firstName,
    required String lastName,
    required String phone,
    required String from,
    required String to,
    required String date,
    required String time,
    required int seats,
    required int price,
    required String comment,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final safePhone = _sanitizePhone(phone);
    final docRef = FirebaseFirestore.instance.collection('taxi_orders').doc();
    
    final newOrder = {
      'id': docRef.id,
      'passengerId': user.uid,
      'passengerName': '$firstName $lastName'.trim().isEmpty ? 'Пассажир' : '$firstName $lastName'.trim(),
      'passengerPhone': safePhone,
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

    await docRef.set(newOrder);
  }

  Future<void> createDriverRide({
    required String firstName,
    required String lastName,
    required String phone,
    required String driverCar,
    required String driverPlate,
    required bool isVehicleVerified,
    required String from,
    required String to,
    required String date,
    required String time,
    required int seats,
    required int price,
    required String comment,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final safePhone = _sanitizePhone(phone);
    final docRef = FirebaseFirestore.instance.collection('taxi_rides').doc();
    
    final newRide = {
      'id': docRef.id,
      'driverId': user.uid,
      'driverName': '$firstName $lastName'.trim().isEmpty ? 'Водитель' : '$firstName $lastName'.trim(),
      'driverPhone': safePhone,
      'driverCar': driverCar,
      'driverPlate': driverPlate,
      'driverImg': user.photoURL ?? '',
      'driverVerified': isVehicleVerified,
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

    await docRef.set(newRide);
  }

  Future<void> sendBid({
    required String targetId,
    required String targetType,
    required String receiverId,
    required int price,
    required String firstName,
    required String lastName,
    required String phone,
    required String driverCar,
    required String driverPlate,
    required bool isVehicleVerified,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // БЕЗОПАСНОСТЬ: Транзакция для проверки, актуален ли заказ перед отправкой ставки
    final db = FirebaseFirestore.instance;
    final collectionName = targetType == 'order' ? 'taxi_orders' : 'taxi_rides';
    final targetRef = db.collection(collectionName).doc(targetId);

    final safePhone = _sanitizePhone(phone);
    final docId = 'bid_${user.uid}_${DateTime.now().millisecondsSinceEpoch}';

    await db.runTransaction((transaction) async {
      final snap = await transaction.get(targetRef);
      if (!snap.exists) throw Exception('Поездка не найдена');
      if (snap.data()!['status'] != 'active') {
        throw Exception('Этот заказ уже недоступен для торга.');
      }

      final newBid = {
        'id': docId,
        'targetId': targetId,
        'targetType': targetType,
        'senderId': user.uid,
        'senderName': '$firstName $lastName'.trim().isEmpty ? 'Пользователь' : '$firstName $lastName'.trim(),
        'senderImg': user.photoURL ?? '',
        'senderPhone': safePhone,
        'senderCar': driverCar,
        'senderPlate': driverPlate,
        'senderVerified': isVehicleVerified,
        'receiverId': receiverId,
        'offeredPrice': price,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      };

      transaction.set(db.collection('taxi_bids').doc(docId), newBid);
    });

    await NotificationService.saveNotificationToFirestore(
      title: 'Новое предложение по такси 🚕',
      body: 'Поступило предложение на $price ₸',
      type: 'taxi_bid',
      uid: receiverId,
    );
  }

  Future<void> acceptBid(String bidId) async {
    final db = FirebaseFirestore.instance;
    final bidRef = db.collection('taxi_bids').doc(bidId);

    // Capture bid data from within the transaction — no second .get() needed
    Map<String, dynamic>? capturedBidData;

    try {
      await db.runTransaction((transaction) async {
        final bidSnap = await transaction.get(bidRef);
        if (!bidSnap.exists) throw Exception('Bid not found');

        final bidData = bidSnap.data()!;
        if (bidData['status'] != 'pending') {
          throw Exception('Это предложение уже было обработано.');
        }

        final targetId = bidData['targetId'];
        final targetType = bidData['targetType'];
        final collectionName = targetType == 'order' ? 'taxi_orders' : 'taxi_rides';
        final targetRef = db.collection(collectionName).doc(targetId);

        final targetSnap = await transaction.get(targetRef);
        if (!targetSnap.exists) throw Exception('Target not found');

        final targetData = targetSnap.data()!;
        if (targetData['status'] != 'active') {
          throw Exception('Извините, этот заказ уже принят другим пользователем.');
        }

        transaction.update(bidRef, {'status': 'accepted'});

        if (targetType == 'order') {
          transaction.update(targetRef, {
            'status': 'accepted',
            'driverId': bidData['senderId'],
            'driverName': bidData['senderName'],
            'driverPhone': bidData['senderPhone'],
            'driverImg': bidData['senderImg'],
            'driverCar': bidData['senderCar'] ?? 'Машина не указана',
            'driverPlate': bidData['senderPlate'] ?? 'Б/Н',
            'driverVerified': bidData['senderVerified'] ?? false,
            'price': bidData['offeredPrice'],
          });
        } else if (targetType == 'ride') {
          transaction.update(targetRef, {
            'status': 'accepted',
            'passengerId': bidData['senderId'],
            'passengerName': bidData['senderName'],
            'passengerPhone': bidData['senderPhone'],
            'passengerImg': bidData['senderImg'],
            'price': bidData['offeredPrice'],
          });
        }

        // ✅ BUG-01 FIX: Capture bid data inside transaction — no second .get() race
        capturedBidData = Map<String, dynamic>.from(bidData);
      });

      final bidData = capturedBidData!;
      final targetId = bidData['targetId'];

      // ✅ ISSUE-03 FIX: Batch-reject ALL other pending bids FIRST, then notify.
      // Previously: notify winner → then reject others.
      // If batch failed, others stayed pending. Now order is correct.
      final otherBids = await db
          .collection('taxi_bids')
          .where('targetId', isEqualTo: targetId)
          .where('status', isEqualTo: 'pending')
          .get();

      final batch = db.batch();
      for (var doc in otherBids.docs) {
        if (doc.id != bidId) {
          batch.update(doc.reference, {'status': 'rejected'});
        }
      }
      await batch.commit();

      // Notify winner AFTER batch is committed
      final targetType = bidData['targetType'];
      if (targetType == 'order') {
        await NotificationService.saveNotificationToFirestore(
          title: 'Предложение принято! 🎉',
          body: 'Пассажир принял вашу ставку на ${bidData['offeredPrice']} ₸. Свяжитесь для выезда!',
          type: 'taxi_bid_accepted',
          uid: bidData['senderId'],
        );
      } else {
        await NotificationService.saveNotificationToFirestore(
          title: 'Поездка подтверждена! 🚙',
          body: 'Водитель принял вашу ставку на ${bidData['offeredPrice']} ₸. Свяжитесь для выезда!',
          type: 'taxi_bid_accepted',
          uid: bidData['senderId'],
        );
      }

    } catch (e) {
      debugPrint('Transaction failed: $e');
      rethrow;
    }
  }

  Future<void> rejectBid(String bidId) async {
    final db = FirebaseFirestore.instance;
    final bidRef = db.collection('taxi_bids').doc(bidId);
    
    // БЕЗОПАСНОСТЬ: Использовать транзакцию, чтобы нельзя было отменить уже принятую ставку
    await db.runTransaction((transaction) async {
      final snap = await transaction.get(bidRef);
      if (!snap.exists) return;
      if (snap.data()!['status'] != 'pending') return;

      transaction.update(bidRef, {'status': 'rejected'});
    });
  }

  Future<void> cancelOrder(String orderId, {String? reason}) async {
    final db = FirebaseFirestore.instance;
    final docRef = db.collection('taxi_orders').doc(orderId);

    // БЕЗОПАСНОСТЬ: Предотвращение Race Condition при отмене.
    await db.runTransaction((transaction) async {
      final snap = await transaction.get(docRef);
      if (!snap.exists) throw Exception('Заказ не найден');
      
      final status = snap.data()!['status'];
      if (status == 'completed' || status == 'cancelled') {
        throw Exception('Невозможно отменить заказ в текущем статусе ($status).');
      }

      transaction.update(docRef, {
        'status': 'cancelled',
        if (reason != null) 'cancellationReason': reason,
      });
    });

    final bids = await db
        .collection('taxi_bids')
        .where('targetId', isEqualTo: orderId)
        .where('status', isEqualTo: 'pending')
        .get();
        
    final batch = db.batch();
    for (var doc in bids.docs) {
      batch.update(doc.reference, {'status': 'rejected'});
    }
    await batch.commit();
  }

  Future<void> updateOrderPrice(String orderId, int newPrice) async {
    final db = FirebaseFirestore.instance;
    final docRef = db.collection('taxi_orders').doc(orderId);

    // БЕЗОПАСНОСТЬ: Нельзя изменить цену принятого заказа
    await db.runTransaction((transaction) async {
      final snap = await transaction.get(docRef);
      if (!snap.exists) return;
      if (snap.data()!['status'] != 'active') {
        throw Exception('Нельзя изменить цену, так как заказ уже обрабатывается.');
      }
      transaction.update(docRef, {'price': newPrice});
    });
  }

  Future<void> submitReview({
    required String targetUserId,
    required double rating,
    required String comment,
    required String firstName,
    required String lastName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // ✅ BUG-03 FIX: Composite docId ensures ONE review per author→target pair.
    // Using millisecondsSinceEpoch as suffix meant unlimited duplicates.
    // Now re-submitting simply overwrites the existing review (last write wins),
    // which is the intended "edit your review" UX.
    final docId = 'review_${user.uid}_to_$targetUserId';

    final newReview = {
      'id': docId,
      'targetUserId': targetUserId,
      'authorId': user.uid,
      'authorName': '$firstName $lastName'.trim().isEmpty ? 'Пользователь' : '$firstName $lastName'.trim(),
      'authorImg': user.photoURL ?? '',
      'rating': rating,
      'comment': comment,
      'createdAt': FieldValue.serverTimestamp(),
    };

    await FirebaseFirestore.instance
        .collection('taxi_reviews')
        .doc(docId)
        .set(newReview);
  }

  Future<void> completeRide(String rideId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final db = FirebaseFirestore.instance;
    final docRef = db.collection('taxi_rides').doc(rideId);

    await db.runTransaction((transaction) async {
      final snap = await transaction.get(docRef);
      if (!snap.exists) return;
      final data = snap.data()!;
      if (data['status'] != 'accepted') return;

      final passengerId = data['passengerId'];
      final driverId = data['driverId'];
      if (user.uid != passengerId && user.uid != driverId) {
        throw Exception('Вы не являетесь участником этой поездки');
      }

      transaction.update(docRef, {'status': 'completed'});
    });
  }

  Future<void> cancelRide(String rideId) async {
    final db = FirebaseFirestore.instance;
    final docRef = db.collection('taxi_rides').doc(rideId);

    await db.runTransaction((transaction) async {
      final snap = await transaction.get(docRef);
      if (!snap.exists) return;
      if (snap.data()!['status'] == 'completed') throw Exception('Уже завершено');
      transaction.update(docRef, {'status': 'cancelled'});
    });

    // ✅ BUG-04 FIX: Reject all pending bids when a ride is cancelled.
    // cancelOrder already did this correctly. Now cancelRide matches.
    final bids = await db
        .collection('taxi_bids')
        .where('targetId', isEqualTo: rideId)
        .where('status', isEqualTo: 'pending')
        .get();

    if (bids.docs.isNotEmpty) {
      final batch = db.batch();
      for (var doc in bids.docs) {
        batch.update(doc.reference, {'status': 'rejected'});
      }
      await batch.commit();
    }
  }

  Future<void> completeOrder(String orderId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final db = FirebaseFirestore.instance;
    final docRef = db.collection('taxi_orders').doc(orderId);

    await db.runTransaction((transaction) async {
      final snap = await transaction.get(docRef);
      if (!snap.exists) return;
      final data = snap.data()!;
      if (data['status'] != 'accepted') return;

      final passengerId = data['passengerId'];
      final driverId = data['driverId'];
      if (user.uid != passengerId && user.uid != driverId) {
        throw Exception('Вы не являетесь участником этого заказа');
      }

      transaction.update(docRef, {'status': 'completed'});
    });
  }

  Future<void> linkDirectCallMatch({
    required String orderId,
    required String passengerId,
    required int price,
    required String firstName,
    required String lastName,
    required String phone,
    required String driverCar,
    required String driverPlate,
    required bool isVehicleVerified,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final db = FirebaseFirestore.instance;
    final orderRef = db.collection('taxi_orders').doc(orderId);
    final safePhone = _sanitizePhone(phone);
    final docId = 'bid_direct_${user.uid}_${DateTime.now().millisecondsSinceEpoch}';

    await db.runTransaction((transaction) async {
      final orderSnap = await transaction.get(orderRef);
      if (!orderSnap.exists) throw Exception('Заказ не найден');
      if (orderSnap.data()!['status'] != 'active') {
        throw Exception('Заказ уже недоступен.');
      }

      final newBid = {
        'id': docId,
        'targetId': orderId,
        'targetType': 'order',
        'senderId': user.uid,
        'senderName': '$firstName $lastName'.trim().isEmpty ? 'Водитель' : '$firstName $lastName'.trim(),
        'senderImg': user.photoURL ?? '',
        'senderPhone': safePhone,
        'senderCar': driverCar,
        'senderPlate': driverPlate,
        'senderVerified': isVehicleVerified,
        'receiverId': passengerId,
        'offeredPrice': price,
        'status': 'accepted', 
        'createdAt': FieldValue.serverTimestamp(),
      };

      transaction.set(db.collection('taxi_bids').doc(docId), newBid);
      
      transaction.update(orderRef, {
        'status': 'accepted',
        'driverId': user.uid,
        'driverName': newBid['senderName'],
        'driverPhone': safePhone,
        'driverImg': newBid['senderImg'],
        'driverCar': driverCar,
        'driverPlate': driverPlate,
        'driverVerified': isVehicleVerified,
        'price': price,
      });
    });
    
    final otherBids = await db
        .collection('taxi_bids')
        .where('targetId', isEqualTo: orderId)
        .where('status', isEqualTo: 'pending')
        .get();
        
    final batch = db.batch();
    for (var doc in otherBids.docs) {
      if (doc.id != docId) batch.update(doc.reference, {'status': 'rejected'});
    }
    await batch.commit();
  }
}
