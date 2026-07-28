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
    String? profileImage,
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
    final String avatarUrl = (profileImage != null && profileImage.isNotEmpty) ? profileImage : (user.photoURL ?? '');
    
    final newOrder = {
      'id': docRef.id,
      'passengerId': user.uid,
      'passengerName': '$firstName $lastName'.trim().isEmpty ? 'Пассажир' : '$firstName $lastName'.trim(),
      'passengerPhone': safePhone,
      'passengerImg': avatarUrl,
      'from': from,
      'to': to,
      'date': date,
      'time': time,
      'seats': seats,
      'price': price.clamp(0, 1000000),
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
    String? profileImage,
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
    final String avatarUrl = (profileImage != null && profileImage.isNotEmpty) ? profileImage : (user.photoURL ?? '');
    
    final newRide = {
      'id': docRef.id,
      'driverId': user.uid,
      'driverName': '$firstName $lastName'.trim().isEmpty ? 'Водитель' : '$firstName $lastName'.trim(),
      'driverPhone': safePhone,
      'driverCar': driverCar,
      'driverPlate': driverPlate,
      'driverImg': avatarUrl,
      'driverVerified': isVehicleVerified,
      'from': from,
      'to': to,
      'date': date,
      'time': time,
      'seats': seats,
      'price': price.clamp(0, 1000000),
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
    String? profileImage,
    required String driverCar,
    required String driverPlate,
    required bool isVehicleVerified,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final db = FirebaseFirestore.instance;
    final collectionName = targetType == 'order' ? 'taxi_orders' : 'taxi_rides';
    final targetRef = db.collection(collectionName).doc(targetId);

    final safePhone = _sanitizePhone(phone);
    final docId = 'bid_${user.uid}_${DateTime.now().millisecondsSinceEpoch}';
    final String avatarUrl = (profileImage != null && profileImage.isNotEmpty) ? profileImage : (user.photoURL ?? '');

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
        'senderImg': avatarUrl,
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

    NotificationService.saveNotificationToFirestore(
      title: 'Новое предложение по такси 🚕',
      body: 'Поступило предложение на $price ₸',
      type: 'taxi_bid',
      uid: receiverId,
    ).catchError((e) {
      debugPrint('[TAXI_REPOSITORY] Notification sending failed: $e');
    });
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
      final List<Map<String, dynamic>> rejectedBidsData = [];
      for (var doc in otherBids.docs) {
        if (doc.id != bidId) {
          batch.update(doc.reference, {'status': 'rejected'});
          rejectedBidsData.add(doc.data());
        }
      }
      await batch.commit();

      // Notify winner AFTER batch is committed
      final targetType = bidData['targetType'];
      if (targetType == 'order') {
        NotificationService.saveNotificationToFirestore(
          title: 'Предложение принято! 🎉',
          body: 'Пассажир принял вашу ставку на ${bidData['offeredPrice']} ₸. Свяжитесь для выезда!',
          type: 'taxi_bid_accepted',
          uid: bidData['senderId'],
        ).catchError((e) {
          debugPrint('[TAXI_REPOSITORY] Notification sending failed: $e');
        });
      } else {
        NotificationService.saveNotificationToFirestore(
          title: 'Поездка подтверждена! 🚙',
          body: 'Водитель принял вашу ставку на ${bidData['offeredPrice']} ₸. Свяжитесь для выезда!',
          type: 'taxi_bid_accepted',
          uid: bidData['senderId'],
        ).catchError((e) {
          debugPrint('[TAXI_REPOSITORY] Notification sending failed: $e');
        });
      }

      // Notify other bid senders that their bids were rejected
      for (var bid in rejectedBidsData) {
        NotificationService.saveNotificationToFirestore(
          title: 'Предложение отклонено ❌',
          body: 'Ваша ставка на ${bid['offeredPrice']} ₸ была отклонена, так как была выбрана другая.',
          type: 'taxi_bid_rejected',
          uid: bid['senderId'],
        ).catchError((e) {
          debugPrint('[TAXI_REPOSITORY] Notification sending failed: $e');
        });
      }

    } catch (e) {
      debugPrint('Transaction failed: $e');
      rethrow;
    }
  }

  Future<void> rejectBid(String bidId) async {
    final db = FirebaseFirestore.instance;
    final bidRef = db.collection('taxi_bids').doc(bidId);
    
    Map<String, dynamic>? capturedBidData;
    
    // БЕЗОПАСНОСТЬ: Использовать транзакцию, чтобы нельзя было отменить уже принятую ставку
    await db.runTransaction((transaction) async {
      final snap = await transaction.get(bidRef);
      if (!snap.exists) return;
      final data = snap.data()!;
      if (data['status'] != 'pending') return;

      transaction.update(bidRef, {'status': 'rejected'});
      capturedBidData = data;
    });

    if (capturedBidData != null) {
      NotificationService.saveNotificationToFirestore(
        title: 'Предложение отклонено ❌',
        body: 'Ваша ставка на ${capturedBidData!['offeredPrice']} ₸ была отклонена.',
        type: 'taxi_bid_rejected',
        uid: capturedBidData!['senderId'],
      ).catchError((e) {
        debugPrint('[TAXI_REPOSITORY] Notification sending failed: $e');
      });
    }
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

    // Извлекаем все активные ставки (как ожидающие, так и уже принятые),
    // чтобы при отмене заказа освободить всех водителей.
    final bids = await db
        .collection('taxi_bids')
        .where('targetId', isEqualTo: orderId)
        .where('status', whereIn: ['pending', 'accepted'])
        .get();
        
    if (bids.docs.isNotEmpty) {
      final batch = db.batch();
      for (var doc in bids.docs) {
        batch.update(doc.reference, {'status': 'rejected'});
      }
      await batch.commit();
    }
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
      transaction.update(docRef, {'price': newPrice.clamp(0, 1000000)});
    });
  }

  Future<void> submitReview({
    required String targetUserId,
    required double rating,
    required String comment,
    required String firstName,
    required String lastName,
    required String targetRole,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // ✅ BUG-03 FIX: Composite docId ensures ONE review per author→target pair.
    // Using millisecondsSinceEpoch as suffix meant unlimited duplicates.
    // Now re-submitting simply overwrites the existing review (last write wins),
    // which is the intended "edit your review" UX.
    final docId = 'review_${user.uid}_to_${targetUserId}_as_$targetRole';

    final newReview = {
      'id': docId,
      'targetUserId': targetUserId,
      'authorId': user.uid,
      'authorName': '$firstName $lastName'.trim().isEmpty ? 'Пользователь' : '$firstName $lastName'.trim(),
      'authorImg': user.photoURL ?? '',
      'rating': rating,
      'comment': comment,
      'createdAt': FieldValue.serverTimestamp(),
      'targetRole': targetRole,
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

  // ─────────────────────────────────────────────────────────────────────────
  // 📞 DIRECT CALL AGREEMENT — "Вы договорились?"
  // Записывает завершённую поездку, когда пользователи договорились по телефону
  // без использования системы торгов. Аналог механизма InDriver.
  //
  // [targetType]:
  //   'drive'  — я пассажир, позвонил водителю (из списка taxi_rides)
  //   'order'  — я водитель, позвонил пассажиру (из списка taxi_orders)
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> recordDirectCallTrip({
    required String targetId,
    required String targetType,
    required int agreedPrice,
    required String myFirstName,
    required String myLastName,
    required String myPhone,
    required String myCar,
    required String myPlate,
    required bool myVerified,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final db = FirebaseFirestore.instance;
    final safeMyPhone = _sanitizePhone(myPhone);
    final myName = '$myFirstName $myLastName'.trim().isEmpty
        ? (targetType == 'drive' ? 'Пассажир' : 'Водитель')
        : '$myFirstName $myLastName'.trim();
    final myImg = user.photoURL ?? '';

    final String sourceCollection =
        targetType == 'drive' ? 'taxi_rides' : 'taxi_orders';
    final targetRef = db.collection(sourceCollection).doc(targetId);

    final targetSnap = await targetRef.get();
    if (!targetSnap.exists) {
      throw Exception('Поездка не найдена. Возможно, она уже отменена.');
    }

    final targetData = targetSnap.data()!;

    // ── Определяем контрагента по роли ───────────────────────────────────
    final String counterpartId;
    final String counterpartName;
    final String counterpartPhone;
    final String counterpartImg;
    final String counterpartCar;
    final String counterpartPlate;
    final bool counterpartVerified;

    if (targetType == 'drive') {
      // Я пассажир → контрагент водитель
      counterpartId    = targetData['driverId']?.toString() ?? '';
      counterpartName  = targetData['driverName']?.toString() ?? 'Водитель';
      counterpartPhone = targetData['driverPhone']?.toString() ?? targetData['phone']?.toString() ?? '';
      counterpartImg   = targetData['driverImg']?.toString() ?? '';
      counterpartCar   = targetData['driverCar']?.toString() ?? '';
      counterpartPlate = targetData['driverPlate']?.toString() ?? '';
      counterpartVerified = targetData['driverVerified'] == true;
    } else {
      // Я водитель → контрагент пассажир
      counterpartId    = targetData['passengerId']?.toString() ?? targetData['userId']?.toString() ?? '';
      counterpartName  = targetData['passengerName']?.toString() ?? targetData['name']?.toString() ?? 'Пассажир';
      counterpartPhone = targetData['passengerPhone']?.toString() ?? targetData['phone']?.toString() ?? '';
      counterpartImg   = targetData['passengerImg']?.toString() ?? '';
      counterpartCar   = '';
      counterpartPlate = '';
      counterpartVerified = false;
    }

    final String from = targetData['from']?.toString() ?? '';
    final String to   = targetData['to']?.toString() ?? '';
    final String date = targetData['date']?.toString() ?? '';
    final String time = targetData['time']?.toString() ?? '';
    final int finalPrice = agreedPrice > 0
        ? agreedPrice
        : (targetData['price'] as num?)?.toInt() ?? 0;

    final String myRole = targetType == 'drive' ? 'passenger' : 'driver';
    final String counterpartRole = myRole == 'passenger' ? 'driver' : 'passenger';

    // ── Базовые поля, одинаковые для обоих участников ────────────────────
    final Map<String, dynamic> tripBase = {
      'matchedVia': 'direct_call',
      'status': 'completed',
      'from': from,
      'to': to,
      'date': date,
      'time': time,
      'price': finalPrice,
      // Всегда пишем обоих участников
      'driverId':       myRole == 'driver' ? user.uid : counterpartId,
      'driverName':     myRole == 'driver' ? myName : counterpartName,
      'driverPhone':    myRole == 'driver' ? safeMyPhone : counterpartPhone,
      'driverImg':      myRole == 'driver' ? myImg : counterpartImg,
      'driverCar':      myRole == 'driver' ? myCar : counterpartCar,
      'driverPlate':    myRole == 'driver' ? myPlate : counterpartPlate,
      'driverVerified': myRole == 'driver' ? myVerified : counterpartVerified,
      'passengerId':    myRole == 'passenger' ? user.uid : counterpartId,
      'passengerName':  myRole == 'passenger' ? myName : counterpartName,
      'passengerPhone': myRole == 'passenger' ? safeMyPhone : counterpartPhone,
      'passengerImg':   myRole == 'passenger' ? myImg : counterpartImg,
      'createdAt': FieldValue.serverTimestamp(),
    };

    // ── Атомарная запись в taxi_history для обоих ─────────────────────────
    final batchWrite = db.batch();

    // Моя история
    final myRef = db.collection('taxi_history').doc();
    batchWrite.set(myRef, {...tripBase, 'id': myRef.id, 'role': myRole});

    // История контрагента
    if (counterpartId.isNotEmpty) {
      final theirRef = db.collection('taxi_history').doc();
      batchWrite.set(theirRef, {...tripBase, 'id': theirRef.id, 'role': counterpartRole});
    }

    await batchWrite.commit();

    // Push-уведомление контрагенту
    if (counterpartId.isNotEmpty) {
      NotificationService.saveNotificationToFirestore(
        title: 'Поездка подтверждена 🚕',
        body: '$myName подтвердил(а) совместную поездку за $finalPrice ₸',
        type: 'taxi_trip_confirmed',
        uid: counterpartId,
      ).catchError((e) {
        debugPrint('[TAXI_REPOSITORY] Notification sending failed: $e');
      });
    }
  }
}
