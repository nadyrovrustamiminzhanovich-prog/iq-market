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
        // Раньше превью в списке чатов хранило и показывало сырой русский
        // текст ('Фото'/'Голосовое сообщение') независимо от языка читающего.
        // lastMessageType позволяет chats_list_screen.dart отрендерить
        // переведённую подпись, оставив lastMessage как fallback для типа
        // 'text' (реальный текст пользователя переводить не нужно и нельзя).
        'lastMessageType': type,
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
        'lastMessageType': 'offer',
        // Цена хранится отдельно (число), чтобы превью в списке чатов могло
        // показать переведённую подпись + цену, не парся строку lastMessage.
        'lastOfferPrice': price,
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

      // ── Документ оффера — источник истины ───────────────────────────────────
      // id детерминированный: два активных предложения одного покупателя на
      // один товар физически невозможны, дедуп-запрос больше не нужен.
      final offerId = offerIdFor(ad.id, uid);
      final offerRef = _db.collection('offers').doc(offerId);

      // Перебиваем собственное прошлое предложение: гасим старую карточку в
      // ленте, чтобы у продавца не висели две активные кнопки Принять.
      final existingOffer = await offerRef.get();
      final prevData = existingOffer.data();
      if (prevData != null && prevData['status'] == 'pending') {
        final prevMessageId = prevData['messageId'] as String?;
        if (prevMessageId != null && prevMessageId.isNotEmpty) {
          try {
            await _db
                .collection('chats')
                .doc(chatId)
                .collection('messages')
                .doc(prevMessageId)
                .update({'offerStatus': 'cancelled'});
          } catch (e) {
            debugPrint('[CHAT_SERVICE] previous offer card not cancelled: $e');
          }
        }
      }

      // id сообщения генерируем заранее: оффер обязан ссылаться на карточку,
      // иначе сервер не сможет обновить её статус после ответа продавца.
      final messageRef = _db.collection('chats').doc(chatId).collection('messages').doc();

      await offerRef.set({
        'adId': ad.id,
        'adTitle': ad.title,
        'price': price,
        'sellerId': ad.userId,
        'buyerId': uid,
        'chatId': chatId,
        'messageId': messageRef.id,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await messageRef.set({
        'senderId': uid,
        'text': text,
        'type': 'offer',
        'offerPrice': price,
        'offerStatus': 'pending',
        'offerId': offerId,
        'timestamp': Timestamp.now(),
        'isRead': false,
        'adId': ad.id,
        'adTitle': ad.title,
      });

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

  /// id оффера детерминирован — на нём же строятся права в Firestore rules
  /// и защита от двух активных предложений одного покупателя на один товар.
  static String offerIdFor(String adId, String buyerId) => '${adId}_$buyerId';

  /// Отклонить предложение покупателя.
  ///
  /// ВРЕМЕННАЯ (промежуточная) реализация. Полноценный сценарий — сервер
  /// (Cloud Function respondToOffer, functions/offers.js) атомарно решает
  /// accept/reject, отклоняет конкурентов на тот же товар и шлёт системное
  /// сообщение. Функция готова и лежит в репозитории, но не задеплоена:
  /// деплой блокирован на стороне Google (403 по биллинг-аккаунту проекта).
  ///
  /// Пока это не решится, Accept вообще недоступен клиенту — ни в этом
  /// методе, ни в Firestore rules (см. 04_chats.rules и 10b_offers.rules):
  /// продавец либо отклоняет предложение, либо договаривается с покупателем
  /// напрямую в чате/по звонку — кнопки под предложением уже ведут туда.
  /// Это не костыль "на глазок": именно Accept был источником прод-бага
  /// (гонка + не по адресу отправленное "отклонено"), и, убрав его из
  /// клиента полностью, этот класс багов физически не может повториться.
  ///
  /// status принимает только 'rejected' — параметр сохранён ради минимальной
  /// правки на вызывающей стороне, когда Accept вернётся через respondToOffer.
  static Future<void> updateOfferStatus(
    String buyerId,
    String messageId,
    String status, {
    String? offerId,
  }) async {
    if (status != 'rejected') {
      throw Exception(
        'Принять предложение сейчас можно только через чат или звонок покупателю',
      );
    }

    final uid = UserService.currentUid;
    if (uid == null) return;

    final chatId = activeChatId ?? getChatId(buyerId);
    final docRef = _db.collection('chats').doc(chatId).collection('messages').doc(messageId);

    late Map<String, dynamic> offerData;

    // Транзакция возвращает bool: её внутренний return прерывает только саму
    // транзакцию, поэтому внешний код не должен ничего писать, если статус
    // фактически не поменялся (второй тап, ответ уже пришёл с другого места).
    final didReject = await _db.runTransaction<bool>((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) return false;

      final data = snap.data()!;
      if ((data['offerStatus'] as String? ?? '') != 'pending') return false;

      tx.update(docRef, {'offerStatus': 'rejected'});
      offerData = data;
      return true;
    });

    if (!didReject) {
      debugPrint('[CHAT_SERVICE] updateOfferStatus SKIPPED: $messageId already resolved');
      return;
    }

    debugPrint('[CHAT_SERVICE] updateOfferStatus: $messageId -> rejected');

    const responseText = 'Предложение отклонено ❌';
    final offerBuyerId = offerData['senderId'] as String?;
    final offerAdTitle = offerData['adTitle'] as String? ?? 'объявлению';
    final resolvedOfferId = offerId ?? offerData['offerId'] as String?;

    await _db.collection('chats').doc(chatId).collection('messages').add({
      'senderId': uid,
      'text': responseText,
      'type': 'text',
      'timestamp': Timestamp.now(),
      'isRead': false,
    });

    final Map<String, dynamic> chatUpdate = {
      'lastMessage': responseText,
      'lastTimestamp': Timestamp.now(),
    };
    if (offerBuyerId != null) {
      chatUpdate['unreadCount_$offerBuyerId'] = FieldValue.increment(1);
    }
    await _db.collection('chats').doc(chatId).update(chatUpdate);

    if (offerBuyerId != null) {
      NotificationService.saveNotificationToFirestore(
        uid: offerBuyerId,
        title: responseText,
        body: 'Продавец ответил на ваше предложение по товару "$offerAdTitle"',
        type: 'chat',
        data: {
          'chatId': chatId,
          'adId': offerData['adId'] ?? '',
          'adTitle': offerAdTitle,
          'senderId': uid,
          'senderName': StorageService.getString('user_name') ?? 'Продавец',
        },
      ).catchError((e) {
        debugPrint('[CHAT_SERVICE] Notification sending failed (non-blocking): $e');
      });
    }

    // Зеркалим статус в offers/{offerId}, если оффер создавался уже новым
    // клиентом. Best-effort: если документа нет (старый оффер) или запись
    // не удалась — на видимый пользователю результат это не влияет.
    if (resolvedOfferId != null && resolvedOfferId.isNotEmpty) {
      try {
        await _db.collection('offers').doc(resolvedOfferId).update({
          'status': 'rejected',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('[CHAT_SERVICE] offers/$resolvedOfferId mirror skipped: $e');
      }
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
  /// ✅ WhatsApp-style: также устанавливает isDelivered: true
  static Future<void> markAsRead(String sellerId, {String? targetChatId}) async {
    final uid = UserService.currentUid;
    if (uid == null) return;
    final chatId = targetChatId ?? ChatService.activeChatId ?? getChatId(sellerId);

    try {
      // Update unread count in main doc
      await _db.collection('chats').doc(chatId).set({
        'unreadCount_$uid': 0,
        'isRead': true,
      }, SetOptions(merge: true));

      // Update individual messages sent by counterpart
      final unreadMessages = await _db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('senderId', isEqualTo: sellerId)
          .where('isRead', isEqualTo: false)
          .get();

      if (unreadMessages.docs.isNotEmpty) {
        final batch = _db.batch();
        for (var doc in unreadMessages.docs) {
          batch.update(doc.reference, {
            'isRead': true,
            'isDelivered': true, // ✅ если прочитано — значит доставлено
            'readAt': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
      }
    } catch (e, stack) {
      debugPrint('[ChatService.markAsRead] Error: $e');
      AnalyticsService.logFirestorePermissionError(e, stack, chatId, 'write', 'mark_as_read');
    }
  }

  /// ✅ WhatsApp-style: помечает сообщения как ДОСТАВЛЕННЫЕ (две серые галочки) без пометки прочитано.
  /// Вызывается когда получатель онлайн (открыл приложение), но не открыл чат.
  static Future<void> markAsDelivered(String senderId, String chatId) async {
    try {
      final undelivered = await _db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('senderId', isEqualTo: senderId)
          .where('isDelivered', isEqualTo: false)
          .get();

      if (undelivered.docs.isNotEmpty) {
        final batch = _db.batch();
        for (var doc in undelivered.docs) {
          batch.update(doc.reference, {'isDelivered': true});
        }
        await batch.commit();
        debugPrint('[ChatService.markAsDelivered] Marked ${undelivered.docs.length} messages as delivered in $chatId');
      }
    } catch (e) {
      debugPrint('[ChatService.markAsDelivered] Error: $e');
    }
  }

  /// Mark all chats as read across all conversations for current user
  static Future<void> markAllChatsAsRead() async {
    final uid = UserService.currentUid;
    if (uid == null) return;
    try {
      final unreadChats = await _db
          .collection('chats')
          .where('users', arrayContains: uid)
          .get();

      for (var chatDoc in unreadChats.docs) {
        await _db.collection('chats').doc(chatDoc.id).set({
          'unreadCount_$uid': 0,
        }, SetOptions(merge: true));

        final unreadMsgs = await chatDoc.reference
            .collection('messages')
            .where('isRead', isEqualTo: false)
            .get();

        if (unreadMsgs.docs.isNotEmpty) {
          final batch = _db.batch();
          for (var msgDoc in unreadMsgs.docs) {
            if (msgDoc.data()['senderId'] != uid) {
              batch.update(msgDoc.reference, {
                'isRead': true,
                'readAt': FieldValue.serverTimestamp(),
              });
            }
          }
          await batch.commit();
        }
      }
    } catch (e) {
      debugPrint('[ChatService.markAllChatsAsRead] Error: $e');
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
      'lastMessageType': 'cleared',
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
