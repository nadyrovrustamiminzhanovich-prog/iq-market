import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:iqmarket/models/message_model.dart';
import 'package:iqmarket/models/ad_model.dart';
import 'package:iqmarket/services/user_service.dart';
import 'package:iqmarket/services/storage_service.dart';
import 'package:iqmarket/services/notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:iqmarket/services/analytics_service.dart';

class ChatService {
  static FirebaseFirestore? dbOverride;
  static FirebaseFirestore get _db => dbOverride ?? FirebaseFirestore.instance;
  static String? activeChatId;

  static String getChatId(String sellerId) {
    final uid = UserService.currentUid;
    if (uid == null || sellerId.isEmpty) {
      debugPrint('[CHAT_SERVICE] WARNING: uid or sellerId is null/empty! uid: $uid, sellerId: $sellerId');
      return 'invalid_chat';
    }
    final ids = [uid, sellerId]..sort();
    final chatId = ids.join('_');
    return chatId;
  }

  static Stream<List<MessageModel>> getMessagesStream(String sellerId) {
    final chatId = getChatId(sellerId);
    return getMessagesStreamWithChatId(chatId);
  }

  static Stream<List<MessageModel>> getMessagesStreamWithChatId(String chatId) {
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          final messages = snapshot.docs
            .map((doc) => MessageModel.fromMap(doc.data(), doc.id))
            .toList();
          // 🔒 X10 Fix: Sort explicitly in Dart to keep local pending writes (which initially have a null/mock timestamp)
          // properly sorted as the newest messages at index 0, preventing chat jumps.
          messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return messages;
        })
        .handleError((error, stackTrace) {
          AnalyticsService.logFirestorePermissionError(error, stackTrace, chatId, 'read', 'messages');
        });
  }

  static Future<void> createChatIfNeeded(AdModel ad, {String? recipientId}) async {
    final sellerId = recipientId ?? ad.userId;
    final uid = UserService.currentUid;
    if (uid == null) return;
    final chatId = getChatId(sellerId);

    try {
      await _db.runTransaction((transaction) async {
        final docRef = _db.collection('chats').doc(chatId);
        final docSnap = await transaction.get(docRef);
        if (!docSnap.exists) {
          String actualSenderName = StorageService.getString('user_name') ?? 'Пользователь';
          final summaryData = {
            'lastMessage': '',
            'lastTimestamp': Timestamp.now(),
            'lastSenderId': '',
            'isRead': false,
            'users': [uid, sellerId]..sort(),
            'name_$uid': actualSenderName,
            'name_$sellerId': ad.userName,
            'adId': ad.id,
            'adTitle': ad.title,
            'adImage': ad.images.isNotEmpty ? ad.images.first : '',
          };
          transaction.set(docRef, summaryData);
          debugPrint('[CHAT_SERVICE] createChatIfNeeded: Chat document created via transaction for $chatId');
        }
      });
    } catch (e) {
      debugPrint('[CHAT_SERVICE] createChatIfNeeded transaction ERROR: $e');
    }
  }

  /// Отправить текстовое/медиа/голосовое сообщение.
  /// Возвращает ID документа или null при ошибке.
  static Future<String?> sendMessage({
    required AdModel ad,
    required String text,
    String type = 'text',
    String? mediaUrl,
    int? duration,
    String? senderName,
    String? recipientId,
  }) async {
    final sellerId = recipientId ?? ad.userId;
    final uid = UserService.currentUid;
    if (uid == null) return null;

    // 🔒 Защита от отправки самому себе
    if (uid == sellerId) {
      debugPrint('[CHAT_SERVICE] BLOCKED: attempt to send message to self (uid=$uid)');
      return null;
    }

    final chatId = getChatId(sellerId);
    
    // Fetch sender name if not provided
    String actualSenderName = senderName ?? StorageService.getString('user_name') ?? 'Пользователь';
    // P6 FIX: include senderPhone so notification-tap navigation can show phone call button
    final String senderPhone = StorageService.getString('user_phone') ?? '';

    try {
      // Update last message in chat summary (creates chat doc first to satisfy rules)
      final summaryData = {
        'lastMessage': text,
        'lastTimestamp': Timestamp.now(),
        'lastSenderId': uid,
        'isRead': false,
        'users': [uid, sellerId]..sort(),
        'unreadCount_$sellerId': FieldValue.increment(1),
        'name_$uid': actualSenderName,
        'name_$sellerId': ad.userName,
        'adId': ad.id,
        'adTitle': ad.title,
        'adImage': ad.images.isNotEmpty ? ad.images.first : '',
      };
      await _db.collection('chats').doc(chatId).set(summaryData, SetOptions(merge: true));

      final messageData = {
        'senderId': uid,
        'text': text,
        'type': type,
        'timestamp': Timestamp.now(),
        'isRead': false,
        'mediaUrl': mediaUrl,
        'duration': duration,
      };

      final docRef = await _db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add(messageData);

      // ad.userId в ChatScreen всегда = «другой пользователь» → он же recipient
      NotificationService.saveNotificationToFirestore(
        uid: sellerId,
        title: 'Новое сообщение: $actualSenderName',
        body: text,
        type: 'chat',
        data: {
          'chatId': chatId,
          'adId': ad.id,
          'adTitle': ad.title,
          'adImage': ad.images.isNotEmpty ? ad.images.first : '',
          'senderId': uid,
          'senderName': actualSenderName,
          'senderPhone': senderPhone,
        }
      ).catchError((e) {
        debugPrint('[CHAT_SERVICE] Notification sending failed (non-blocking): $e');
      });

      return docRef.id;
    } catch (e, stack) {
      debugPrint('[CHAT_SERVICE] sendMessage ERROR: $e');
      AnalyticsService.logFirestorePermissionError(e, stack, chatId, 'write', 'messages');
      FirebaseCrashlytics.instance.recordError(
        e,
        stack,
        reason: 'Error sending message',
        information: ['chatId: $chatId'],
      );
      return null;
    }
  }

  /// Отправить предложение цены. Бросает исключение при ошибке для обработки в UI.
  /// FIX: добавлена дедупликация — если уже есть pending-предложение на тот же adId,
  /// создаётся новое (старое остаётся как история). Это ожидаемое поведение UX.
  static Future<void> sendOffer({
    required AdModel ad,
    required double price,
  }) async {
    final uid = UserService.currentUid;
    if (uid == null) throw Exception('Вы не авторизованы');

    // 🔒 Защита от торга с самим собой (дублирует Firestore rule)
    if (uid == ad.userId) {
      debugPrint('[CHAT_SERVICE] BLOCKED: attempt to send offer to self');
      throw Exception('Нельзя отправить предложение самому себе');
    }

    final chatId = getChatId(ad.userId);
    final text = 'Предложение цены: ${price.toInt()} ₸';

    // Fetch sender details
    final actualSenderName = StorageService.getString('user_name') ?? 'Пользователь';
    final senderPhone = StorageService.getString('user_phone') ?? '';

    try {
      // ── Обновляем/создаём сводку чата ПЕРВЫМ ───────────────────────────────
      // CRITICAL: Чат-документ ОБЯЗАН существовать ДО любых запросов к messages,
      // потому что Firestore rules для read messages проверяют
      // get(.../chats/chatId).data.users — без документа → permission-denied.
      final summaryData = {
        'lastMessage': text,
        'lastTimestamp': Timestamp.now(),
        'lastSenderId': uid,
        'isRead': false,
        'users': [uid, ad.userId]..sort(),
        'unreadCount_${ad.userId}': FieldValue.increment(1),
        'name_$uid': actualSenderName,
        'name_${ad.userId}': ad.userName,
        'adId': ad.id,
        'adTitle': ad.title,
        'adImage': ad.images.isNotEmpty ? ad.images.first : '',
      };
      await _db.collection('chats').doc(chatId).set(summaryData, SetOptions(merge: true));

      // ── Дедупликация: автоматически отменяем предыдущее pending-предложение ──
      // Если покупатель отправляет новое предложение — старое становится 'cancelled'.
      // NOTE: Этот запрос теперь безопасен, т.к. чат-документ уже существует.
      final existingPending = await _db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('senderId', isEqualTo: uid)
          .where('type', isEqualTo: 'offer')
          .where('offerStatus', isEqualTo: 'pending')
          .where('adId', isEqualTo: ad.id)
          .limit(5)
          .get();

      if (existingPending.docs.isNotEmpty) {
        debugPrint('[CHAT_SERVICE] Found ${existingPending.docs.length} existing pending offer(s) — cancelling them');
        // FIX (P.4): Use individual transactions instead of plain batch to
        // prevent overwriting an offer that the seller just accepted concurrently.
        for (final doc in existingPending.docs) {
          try {
            await _db.runTransaction((tx) async {
              final fresh = await tx.get(doc.reference);
              if (!fresh.exists) return;
              // Only cancel if still pending — do NOT overwrite accepted/rejected
              if (fresh.data()!['offerStatus'] == 'pending') {
                tx.update(doc.reference, {'offerStatus': 'cancelled'});
              }
            });
          } catch (e) {
            debugPrint('[CHAT_SERVICE] dedup cancel skipped for ${doc.id}: $e');
          }
        }
      }

      final messageData = {
        'senderId': uid,
        'text': text,
        'type': 'offer',
        'offerPrice': price,
        'offerStatus': 'pending',
        'timestamp': Timestamp.now(),
        'isRead': false,
        'adId': ad.id,
        'adTitle': ad.title,
      };

      await _db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add(messageData);

      debugPrint('[CHAT_SERVICE] sendOffer SUCCESS: ${price.toInt()} ₸ for ad=${ad.id}');

      // ── Уведомление продавцу (сумма + товар) ────────────────────────────────
      NotificationService.saveNotificationToFirestore(
        uid: ad.userId,
        title: 'Предложение цены: $actualSenderName',
        body: 'Предлагает ${price.toInt()} ₸ за "${ad.title}"',
        type: 'chat',
        data: {
          'chatId': chatId,
          'adId': ad.id,
          'adTitle': ad.title,
          'senderId': uid,
          'senderName': actualSenderName,
          'senderPhone': senderPhone,
        },
      ).catchError((e) {
        debugPrint('[CHAT_SERVICE] Notification sending failed (non-blocking): $e');
      });
    } catch (e) {
      debugPrint('[CHAT_SERVICE] sendOffer ERROR: $e');
      rethrow;
    }
  }

  /// Принять или отклонить предложение покупателя.
  ///
  /// FIX (Race condition): используется Firestore Transaction — проверяем что
  /// offerStatus == 'pending' ВНУТРИ транзакции перед записью. Если продавец
  /// успел нажать Accept дважды (два разных предложения одновременно),
  /// второй Accept получит ошибку и будет проигнорирован.
  ///
  /// FIX (Другие покупатели): при Accept автоматически reject-им все остальные
  /// pending-предложения от других покупателей на тот же adId.
  static Future<void> updateOfferStatus(String sellerId, String messageId, String status) async {
    final uid = UserService.currentUid;
    if (uid == null) return;

    final chatId = activeChatId ?? getChatId(sellerId);
    final docRef = _db.collection('chats').doc(chatId).collection('messages').doc(messageId);

    late Map<String, dynamic> offerData;

    // ── Transaction: атомарная проверка + обновление статуса ─────────────────
    try {
      await _db.runTransaction((transaction) async {
        final snap = await transaction.get(docRef);
        if (!snap.exists) throw Exception('Offer message not found');

        final data = snap.data()!;
        final currentStatus = data['offerStatus'] as String? ?? '';
        final offerAdId = data['adId'] as String? ?? '';

        if (currentStatus != 'pending') {
          // Уже обработано — тихо выходим (защита от race condition)
          debugPrint('[CHAT_SERVICE] updateOfferStatus SKIPPED: already $currentStatus');
          throw Exception('ALREADY_RESOLVED');
        }

        // Parent resource lock (P.1): read and lock the ad document to serialize
        // concurrent accepts on different offers for the same ad.
        if (offerAdId.isNotEmpty && status == 'accepted') {
          final adRef = _db.collection('ads').doc(offerAdId);
          final adSnap = await transaction.get(adRef);
          if (adSnap.exists) {
            final adData = adSnap.data()!;
            final adStatus = adData['status'] as String? ?? 'active';
            if (adStatus == 'reserved' || adStatus == 'sold') {
              debugPrint('[CHAT_SERVICE] updateOfferStatus SKIPPED: ad already reserved/sold');
              throw Exception('ALREADY_RESOLVED');
            }
            // Mark ad as reserved in the same transaction
            transaction.update(adRef, {
              'status': 'reserved',
              'acceptedOfferId': messageId,
            });
          }
        }

        // Атомарно меняем статус офера
        transaction.update(docRef, {'offerStatus': status});
        offerData = data;
      });
    } on Exception catch (e) {
      if (e.toString().contains('ALREADY_RESOLVED')) return;
      debugPrint('[CHAT_SERVICE] updateOfferStatus transaction error: $e');
      rethrow;
    }

    debugPrint('[CHAT_SERVICE] updateOfferStatus: $messageId → $status');

    final responseText = status == 'accepted'
        ? 'Предложение принято! ✅'
        : 'Предложение отклонено ❌';

    final offerBuyerId  = offerData['senderId'] as String?;
    final offerAdId     = offerData['adId']     as String? ?? '';
    final offerAdTitle  = offerData['adTitle']  as String? ?? 'объявлению';

    // ── Текстовый ответ в чат ────────────────────────────────────────────────
    await _db.collection('chats').doc(chatId).collection('messages').add({
      'senderId': uid,
      'text': responseText,
      'type': 'text',
      'timestamp': Timestamp.now(),
      'isRead': false,
    });

    // ── Обновить сводку чата ─────────────────────────────────────────────────
    final Map<String, dynamic> chatUpdate = {
      'lastMessage': responseText,
      'lastTimestamp': Timestamp.now(),
    };
    if (offerBuyerId != null) {
      chatUpdate['unreadCount_$offerBuyerId'] = FieldValue.increment(1);
    }
    await _db.collection('chats').doc(chatId).update(chatUpdate);

    // ── Уведомление покупателю (принято / отклонено) ─────────────────────────
    if (offerBuyerId != null) {
      NotificationService.saveNotificationToFirestore(
        uid: offerBuyerId,
        title: status == 'accepted' ? 'Предложение принято! ✅' : 'Предложение отклонено ❌',
        body: 'Продавец ответил на ваше предложение по товару "$offerAdTitle"',
        type: 'chat',
        data: {
          'chatId': chatId,
          'adId': offerAdId,
        },
      ).catchError((e) {
        debugPrint('[CHAT_SERVICE] Notification sending failed (non-blocking): $e');
      });
    }

    // ── При ACCEPT: автоматически отклоняем все другие pending-предложения ───
    // от ДРУГИХ покупателей на тот же adId (во всех чатах продавца).
    // FIX (P.3): awaited — prevents a second concurrent Accept on a different
    // messageId from succeeding before the first rejects the competition.
    if (status == 'accepted' && offerAdId.isNotEmpty) {
      await _rejectOtherPendingOffers(
        sellerChatId: chatId,
        acceptedMessageId: messageId,
        adId: offerAdId,
        adTitle: offerAdTitle,
        sellerId: uid,
      );
    }
  }

  /// Внутренний метод: находит все чаты продавца и отклоняет там pending-офферы
  /// на тот же товар (кроме только что принятого).
  static Future<void> _rejectOtherPendingOffers({
    required String sellerChatId,
    required String acceptedMessageId,
    required String adId,
    required String adTitle,
    required String sellerId,
  }) async {
    try {
      debugPrint('[CHAT_SERVICE] _rejectOtherPendingOffers: adId=$adId');

      // Получаем все чаты продавца
      final chats = await _db
          .collection('chats')
          .where('users', arrayContains: sellerId)
          .where('adId', isEqualTo: adId)
          .get();

      for (final chatDoc in chats.docs) {
        // pending-офферы в каждом чате на этот adId
        final pendingOffers = await chatDoc.reference
            .collection('messages')
            .where('type', isEqualTo: 'offer')
            .where('offerStatus', isEqualTo: 'pending')
            .where('adId', isEqualTo: adId)
            .get();

        for (final offerDoc in pendingOffers.docs) {
          // Не трогаем тот offer, который только что был принят
          if (chatDoc.id == sellerChatId && offerDoc.id == acceptedMessageId) continue;

          final buyerId = offerDoc.data()['senderId'] as String?;

          // Атомарно отклоняем через transaction
          try {
            await _db.runTransaction((tx) async {
              final freshSnap = await tx.get(offerDoc.reference);
              if (!freshSnap.exists) return;
              if (freshSnap.data()!['offerStatus'] != 'pending') return;
              tx.update(offerDoc.reference, {'offerStatus': 'rejected'});
            });

            debugPrint('[CHAT_SERVICE] Auto-rejected offer ${offerDoc.id} in chat ${chatDoc.id}');

            // Уведомляем покупателя об автоотклонении
            if (buyerId != null) {
              await _db
                  .collection('chats')
                  .doc(chatDoc.id)
                  .collection('messages')
                  .add({
                    'senderId': sellerId,
                    'text': 'Предложение отклонено ❌',
                    'type': 'text',
                    'timestamp': Timestamp.now(),
                    'isRead': false,
                  });

              NotificationService.saveNotificationToFirestore(
                uid: buyerId,
                title: 'Предложение отклонено ❌',
                body: 'Предложение по товару "$adTitle" отклонено.',
                type: 'chat',
                data: {
                  'chatId': chatDoc.id,
                  'adId': adId,
                },
              ).catchError((e) {
                debugPrint('[CHAT_SERVICE] Notification sending failed (non-blocking): $e');
              });
            }
          } catch (e) {
            debugPrint('[CHAT_SERVICE] Error auto-rejecting offer ${offerDoc.id}: $e');
          }
        }
      }
    } catch (e) {
      // Не критично — основная операция Accept уже прошла
      debugPrint('[CHAT_SERVICE] _rejectOtherPendingOffers ERROR (non-fatal): $e');
    }
  }


  /// Update message (e.g., set media URL after upload)
  static Future<void> updateMessage(String sellerId, String messageId, Map<String, dynamic> data) async {
    final chatId = getChatId(sellerId);
    await _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .update(data);
  }

  /// Mark all messages as read for current user
  static Future<void> markAsRead(String sellerId) async {
    final uid = UserService.currentUid;
    if (uid == null) return;
    final chatId = getChatId(sellerId);

    try {
      // Update unread count in main doc
      await _db.collection('chats').doc(chatId).set({
        'unreadCount_$uid': 0,
        'isRead': true,
      }, SetOptions(merge: true));

      // Update individual messages
      final unreadMessages = await _db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('senderId', isEqualTo: sellerId)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _db.batch();
      for (var doc in unreadMessages.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e, stack) {
      debugPrint('[ChatService.markAsRead] Error: $e');
      AnalyticsService.logFirestorePermissionError(e, stack, chatId, 'write', 'mark_as_read');
    }
  }

  /// Delete specific messages (including media files from Storage).
  /// Firestore rules позволяют удалять только СВОИ сообщения (senderId == uid).
  /// Возвращает количество успешно удалённых сообщений.
  static Future<int> deleteMessages(String sellerId, List<String> messageIds) async {
    final uid = UserService.currentUid;
    if (uid == null) return 0;
    
    final chatId = getChatId(sellerId);
    final batch = _db.batch();
    int deletedCount = 0;
    
    for (var id in messageIds) {
      final docRef = _db.collection('chats').doc(chatId).collection('messages').doc(id);
      
      try {
        final doc = await docRef.get();
        if (!doc.exists) continue;
        final data = doc.data();
        
        // 🔒 Firestore rules: можно удалить только если senderId == uid
        if (data?['senderId'] != uid) {
          debugPrint('[CHAT_SERVICE] Skip delete: message $id not owned by current user');
          continue;
        }
        
        // Удаляем медиа из Storage если есть
        final String? mediaUrl = data?['mediaUrl'];
        if (mediaUrl != null && mediaUrl.isNotEmpty) {
          try {
            await FirebaseStorage.instance.refFromURL(mediaUrl).delete();
            debugPrint('[CHAT_SERVICE] Media file deleted from storage: $mediaUrl');
          } catch (e) {
            debugPrint('[CHAT_SERVICE] Error deleting media from storage: $e');
          }
        }

        batch.delete(docRef);
        deletedCount++;
      } catch (e) {
        debugPrint('[CHAT_SERVICE] Error processing message $id for deletion: $e');
      }
    }
    
    if (deletedCount > 0) {
      await batch.commit();
    }
    return deletedCount;
  }

  /// Clear entire chat (including all media files from Storage)
  static Future<void> clearChat(String sellerId) async {
    final chatId = getChatId(sellerId);
    final messages = await _db.collection('chats').doc(chatId).collection('messages').get();
    final batch = _db.batch();
    
    for (var doc in messages.docs) {
      final data = doc.data();
      final String? mediaUrl = data['mediaUrl'];
      
      if (mediaUrl != null && mediaUrl.isNotEmpty) {
        try {
          await FirebaseStorage.instance.refFromURL(mediaUrl).delete();
        } catch (e) {
          debugPrint('[CHAT_SERVICE] Error deleting media during clearChat: $e');
        }
      }
      
      batch.delete(doc.reference);
    }
    
    batch.update(_db.collection('chats').doc(chatId), {
      'lastMessage': 'Чат очищен',
      'unreadCount_${UserService.currentUid}': 0,
      'lastTimestamp': Timestamp.now(),
    });
    
    await batch.commit();
  }

  /// Typing status
  static Future<void> updateTypingStatus(String sellerId, bool isTyping) async {
    final uid = UserService.currentUid;
    if (uid == null) return;
    final chatId = getChatId(sellerId);
    await _db.collection('chats').doc(chatId).set({
      'typing_$uid': isTyping,
      'typing_last_update_$uid': isTyping ? FieldValue.serverTimestamp() : null,
    }, SetOptions(merge: true));
  }

  static Stream<bool> getTypingStatusStream(String sellerId) {
    final chatId = getChatId(sellerId);
    StreamController<bool>? controller;
    StreamSubscription? sub;
    Timer? timer;
    Map<String, dynamic>? lastData;

    void checkStatus() {
      if (controller == null || controller.isClosed) return;
      if (lastData == null) {
        controller.add(false);
        return;
      }
      final isTyping = lastData!['typing_$sellerId'] ?? false;
      if (!isTyping) {
        controller.add(false);
        return;
      }
      final lastUpdateStamp = lastData!['typing_last_update_$sellerId'] as Timestamp?;
      if (lastUpdateStamp != null) {
        final lastUpdate = lastUpdateStamp.toDate();
        final now = DateTime.now();
        if (now.difference(lastUpdate).inSeconds > 10) {
          controller.add(false);
          return;
        }
      } else {
        controller.add(false);
        return;
      }
      controller.add(true);
    }

    controller = StreamController<bool>(
      onListen: () {
        sub = _db.collection('chats').doc(chatId).snapshots().listen((snap) {
          lastData = snap.data();
          checkStatus();
        });
        timer = Timer.periodic(const Duration(seconds: 2), (t) {
          checkStatus();
        });
      },
      onCancel: () {
        sub?.cancel();
        timer?.cancel();
      },
    );

    return controller.stream;
  }

  /// Get list of chats for the current user
  static Stream<List<Map<String, dynamic>>> getChatListStream() {
    final uid = UserService.currentUid;
    if (uid == null) return Stream.value([]);

    return _db
        .collection('chats')
        .where('users', arrayContains: uid)
        .snapshots()
        .map((snapshot) {
          final chats = snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();
          
          // Сортируем по времени последнего сообщения
          chats.sort((a, b) {
            final tsA = a['lastTimestamp'] as Timestamp?;
            final tsB = b['lastTimestamp'] as Timestamp?;
            if (tsA == null && tsB == null) return 0;
            if (tsA == null) return -1; // Новые сообщения (pending writes) наверх
            if (tsB == null) return 1;
            return tsB.compareTo(tsA); // По убыванию
          });
          
          return chats;
        });
  }

  static Stream<int> getUnreadMessagesCountStream() {
    final uid = UserService.currentUid;
    if (uid == null) return Stream.value(0);

    return _db
        .collection('chats')
        .where('users', arrayContains: uid)
        .snapshots()
        .map((snapshot) {
          int count = 0;
          for (var doc in snapshot.docs) {
            final data = doc.data();
            final unread = data['unreadCount_$uid'];
            if (unread != null && unread is int) {
              count += unread;
            }
          }
          return count;
        });
  }

  static Future<void> markAllChatsAsRead() async {
    final uid = UserService.currentUid;
    if (uid == null) return;
    
    try {
      final chats = await _db
          .collection('chats')
          .where('users', arrayContains: uid)
          .get();

      final batch = _db.batch();
      for (var doc in chats.docs) {
        final data = doc.data();
        final unreadCount = data['unreadCount_$uid'] ?? 0;
        if (unreadCount > 0) {
          batch.set(doc.reference, {
            'unreadCount_$uid': 0,
            'isRead': true,
          }, SetOptions(merge: true));
          
          final unreadMessages = await doc.reference
              .collection('messages')
              .where('isRead', isEqualTo: false)
              .get();
          for (var msgDoc in unreadMessages.docs) {
            if (msgDoc.data()['senderId'] != uid) {
              batch.update(msgDoc.reference, {'isRead': true});
            }
          }
        }
      }
      await batch.commit();
    } catch (e) {
      debugPrint('[ChatService.markAllChatsAsRead] Error: $e');
    }
  }

  /// Seed test data for UI testing
  static Future<void> seedTestData(String otherUserId) async {
    final chatId = getChatId(otherUserId);
    final messages = _db.collection('chats').doc(chatId).collection('messages');
    
    // Check if messages already exist
    final existing = await messages.limit(1).get();
    if (existing.docs.isNotEmpty) return;

    final now = DateTime.now();

    await messages.add({
      'senderId': otherUserId,
      'text': 'Привет! Это тестовое сообщение для проверки дизайна.',
      'type': 'text',
      'timestamp': now.subtract(const Duration(minutes: 5)),
      'isRead': false,
    });

    await messages.add({
      'senderId': otherUserId,
      'text': 'Посмотри, как круто выглядят картинки в нашем чате!',
      'type': 'image',
      'mediaUrl': 'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?q=80&w=500',
      'timestamp': now.subtract(const Duration(minutes: 4)),
      'isRead': false,
    });

    await messages.add({
      'senderId': otherUserId,
      'text': 'Голосовое сообщение',
      'type': 'audio',
      'mediaUrl': 'https://actions.google.com/sounds/v1/alarms/beep_short.ogg',
      'duration': 2,
      'timestamp': now.subtract(const Duration(minutes: 3)),
      'isRead': false,
    });

    // Update summary
    await _db.collection('chats').doc(chatId).set({
      'lastMessage': 'Голосовое сообщение',
      'lastTimestamp': Timestamp.now(),
      'users': [UserService.currentUid ?? '', otherUserId]..sort(),
      'unreadCount_${UserService.currentUid}': 3,
      'name_$otherUserId': 'Иван (Тест)',
      'adTitle': 'iPhone 13',
      'adImage': 'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?q=80&w=100',
    }, SetOptions(merge: true));
  }
}
