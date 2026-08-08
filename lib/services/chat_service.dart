import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
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
          // uid читаем на каждом снапшоте, а не при создании стрима: после
          // перелогина под другим аккаунтом фильтр обязан работать по новому
          // пользователю, иначе ему покажутся сообщения, скрытые предыдущим.
          final uid = UserService.currentUid;
          final messages = snapshot.docs
            .map((doc) => MessageModel.fromMap(doc.data(), doc.id))
            // «Удалить у меня»: документ общий на двоих, поэтому персональное
            // удаление — пометка deletedFor, а скрытие происходит на чтении.
            .where((m) => !m.isHiddenFor(uid))
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
      //
      // Весь блок — best-effort и обязан оставаться таким. Это уборка прошлой
      // карточки, а не часть отправки: если чтение или гашение не прошло,
      // предложение всё равно должно уйти. Раньше исключение отсюда улетало
      // наверх и убивало отправку целиком — пользователь получал голое
      // «permission-denied» вместо отправленного предложения.
      try {
        final existingOffer = await offerRef.get();
        final prevData = existingOffer.data();
        if (prevData != null && prevData['status'] == 'pending') {
          final prevMessageId = prevData['messageId'] as String?;
          if (prevMessageId != null && prevMessageId.isNotEmpty) {
            await _db
                .collection('chats')
                .doc(chatId)
                .collection('messages')
                .doc(prevMessageId)
                .update({'offerStatus': 'cancelled'});
          }
        }
      } catch (e) {
        debugPrint('[CHAT_SERVICE] previous offer card not cancelled: $e');
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
    } catch (e, stack) {
      debugPrint('[CHAT_SERVICE] sendOffer ERROR: $e');
      // Раньше отказ правил здесь нигде не фиксировался: пользователь видел
      // сырой текст ошибки, а в аналитике не оставалось следа — понять, на
      // каком шаге отвалилось предложение, было нечем.
      AnalyticsService.logFirestorePermissionError(e, stack, chatId, 'write', 'send_offer');
      rethrow;
    }
  }

  /// id оффера детерминирован — на нём же строятся права в Firestore rules
  /// и защита от двух активных предложений одного покупателя на один товар.
  static String offerIdFor(String adId, String buyerId) => '${adId}_$buyerId';

  /// Принять или отклонить предложение покупателя.
  ///
  /// Решение целиком принимает сервер (Cloud Function `respondToOffer`,
  /// `functions/offers.js`): он атомарной транзакцией меняет статус в
  /// `offers/{offerId}`, зеркалит его в карточку сообщения, пишет системное
  /// сообщение, обновляет сводку чата, уведомляет покупателя отдельным
  /// документом и отклоняет конкурирующие предложения на тот же товар.
  ///
  /// Клиент намеренно НЕ делает ничего из этого сам, и правила ему этого не
  /// позволяют. Причины конкретные, все всплывали в проде:
  ///  • статус, выставленный с устройства, подделывается на рутованном;
  ///  • гонка двух одновременных Accept решается только серверной транзакцией;
  ///  • запрос сразу после локальной транзакции отдаёт устаревший кэш, из-за
  ///    чего покупателю уходило «отклонено» по только что принятому офферу;
  ///  • конкурирующие офферы нельзя найти через чаты: `chatId` строится по
  ///    паре пользователей, а `chats.adId` хранит лишь последний товар.
  ///
  /// NOTE: принятие оффера — договорённость в чате (как на OLX/Avito),
  /// объявление не блокируется и не меняет статус.
  static Future<void> updateOfferStatus(
    String buyerId,
    String messageId,
    String status, {
    String? offerId,
  }) async {
    final uid = UserService.currentUid;
    if (uid == null) return;

    final chatId = activeChatId ?? getChatId(buyerId);

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('respondToOffer');
      final result = await callable.call<Map<String, dynamic>>({
        'action': status == 'accepted' ? 'accept' : 'reject',
        if (offerId != null && offerId.isNotEmpty) 'offerId': offerId,
        // Фолбэк для предложений, созданных до перехода на коллекцию offers:
        // сервер поднимет документ оффера из самого сообщения.
        'chatId': chatId,
        'messageId': messageId,
      });
      debugPrint('[CHAT_SERVICE] respondToOffer $messageId -> ${result.data}');
    } on FirebaseFunctionsException catch (e) {
      // Предложение успели обработать раньше (второй тап, параллельный ответ
      // с другого устройства) — для пользователя это не ошибка.
      if (e.code == 'failed-precondition') {
        debugPrint('[CHAT_SERVICE] respondToOffer skipped: ${e.message}');
        return;
      }
      debugPrint('[CHAT_SERVICE] respondToOffer failed ${e.code}: ${e.message}');
      rethrow;
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
    // 🔒 Прочитать можно только ЧУЖИЕ сообщения. Если sellerId — это я сам,
    // выборка ниже (senderId == sellerId) попадёт на мои собственные сообщения
    // и поставит им isRead: true — отправитель увидит 2 синие галочки сразу
    // после отправки, хотя получатель ничего не открывал. Реальный источник
    // такого вызова: чужой FCM-пуш, прилетевший на это устройство (токен
    // остался у аккаунта, который раньше логинился здесь) — тогда
    // _handleDataMessage звал markAsRead(senderId), где senderId == я.
    // Здесь это обрывается независимо от того, кто и откуда позвал.
    if (sellerId == uid) {
      debugPrint('[ChatService.markAsRead] BLOCKED: попытка пометить прочитанными свои же сообщения');
      return;
    }
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
    // 🔒 Симметрично markAsRead: «доставлено» ставит получатель на сообщения
    // собеседника. senderId == я означает, что обработчик пуша сработал не на
    // том устройстве (чужой пуш) — иначе свои же сообщения получали бы
    // 2 серые галочки в момент отправки.
    //
    // Проверка намеренно НЕ требует uid != null: этот метод вызывается в том
    // числе из фонового FCM-изолята, где firebase_auth не всегда успевает
    // отдать currentUser. Жёсткий выход по null убил бы «доставлено» при
    // закрытом приложении — ровно то, что чинилось в прошлый заход. Когда uid
    // неизвестен, арбитром остаются Firestore rules: правку isDelivered у
    // автора сообщения сервер отклоняет сам.
    final uid = UserService.currentUid;
    if (uid != null && senderId == uid) {
      debugPrint('[ChatService.markAsDelivered] BLOCKED: попытка пометить доставленными свои же сообщения');
      return;
    }
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

  /// «Удалить у всех» — hard delete: документ сообщения физически исчезает,
  /// у собеседника пропадает по стриму, восстановить нельзя.
  ///
  /// Firestore rules позволяют удалять только СВОИ сообщения (senderId == uid),
  /// поэтому чужие id молча пропускаются. Возвращает количество удалённых.
  ///
  /// Порядок операций обратен наивному и важен: сначала коммитим удаление
  /// документов, и только ПОТОМ чистим Storage. Если сначала убить файл, а
  /// затем не суметь удалить документ (сеть, права, оффлайн), в переписке
  /// навсегда остаётся сообщение с битой картинкой — и это уже необратимо.
  /// Осиротевший файл в Storage — несравнимо меньшее зло.
  ///
  /// После самого удаления обязательна уборка следов, иначе «удалил у всех»
  /// остаётся ложью: превью в списке чатов, счётчик непрочитанных и in-app
  /// уведомление живут отдельными полями и сами не обновляются.
  static Future<int> deleteMessages(String sellerId, List<String> messageIds) async {
    final uid = UserService.currentUid;
    if (uid == null) return 0;

    final chatId = activeChatId ?? getChatId(sellerId);
    final chatRef = _db.collection('chats').doc(chatId);
    final messagesRef = chatRef.collection('messages');
    final batch = _db.batch();

    final List<String> mediaUrls = [];
    final List<String> pendingOfferIds = [];
    // Сколько единиц освободить в счётчике непрочитанных у собеседника.
    int unreadFreed = 0;
    int deletedCount = 0;

    // Было ли среди удаляемых самое свежее сообщение чата. Определяем ДО
    // удаления: только в этом случае превью и уведомление указывают на
    // удаляемое сообщение и их нужно (и можно безопасно) перезаписать.
    // Удаление сообщения из середины переписки превью не затрагивает.
    bool wasLatest = false;
    try {
      final tailBefore =
          await messagesRef.orderBy('timestamp', descending: true).limit(1).get();
      wasLatest = tailBefore.docs.isNotEmpty &&
          messageIds.contains(tailBefore.docs.first.id);
    } catch (e) {
      debugPrint('[CHAT_SERVICE] deleteMessages: tail lookup failed: $e');
    }

    for (final id in messageIds) {
      final docRef = messagesRef.doc(id);
      try {
        final doc = await docRef.get();
        if (!doc.exists) continue;
        final data = doc.data();

        // 🔒 Firestore rules: можно удалить только если senderId == uid
        if (data?['senderId'] != uid) {
          debugPrint('[CHAT_SERVICE] Skip delete: message $id not owned by current user');
          continue;
        }

        final String? mediaUrl = data?['mediaUrl'];
        if (mediaUrl != null && mediaUrl.isNotEmpty) mediaUrls.add(mediaUrl);

        // Непрочитанное сообщение забирает с собой единицу из счётчика
        // собеседника — иначе в списке чатов навсегда виснет бейдж «1» без
        // сообщения, которое его вызвало.
        if (data?['isRead'] != true) unreadFreed++;

        // Оффер без карточки в ленте продавец не сможет ни принять, ни
        // отклонить — предложение обязано умереть вместе со сообщением,
        // иначе в offers/ остаётся вечный pending-призрак.
        if (data?['type'] == 'offer' && data?['offerStatus'] == 'pending') {
          final String? offerId = data?['offerId'];
          if (offerId != null && offerId.isNotEmpty) pendingOfferIds.add(offerId);
        }

        batch.delete(docRef);
        deletedCount++;
      } catch (e) {
        debugPrint('[CHAT_SERVICE] Error processing message $id for deletion: $e');
      }
    }

    if (deletedCount == 0) return 0;

    try {
      await batch.commit();
    } catch (e, stack) {
      // Ничего не удалено и медиа не тронуто — пользователь увидит ошибку и
      // сможет повторить, сообщения останутся целыми, а не битыми.
      debugPrint('[CHAT_SERVICE] deleteMessages commit ERROR: $e');
      AnalyticsService.logFirestorePermissionError(e, stack, chatId, 'delete', 'messages');
      return 0;
    }

    // ── Уборка следов ────────────────────────────────────────────────────────
    // Сообщения уже удалены, поэтому ни одна ошибка ниже не должна выглядеть
    // для пользователя как неудачное удаление — только логи.
    await _cancelOffersForDeletedMessages(pendingOfferIds);

    // Собеседника берём из документа чата, а НЕ из sellerId. У uid с
    // подчёркиванием (`telegram_…`) ChatScreen не может вытащить участника из
    // chatId и подставляет ad.userId, который при переходе из пуша бывает
    // заглушкой. Промах здесь означал бы правку счётчика и уведомления
    // постороннего человека, поэтому источник истины — поле users.
    final String? counterpartId = await _resolveCounterpart(chatRef, uid);

    if (counterpartId != null) {
      await _syncChatAfterDelete(
        chatRef: chatRef,
        otherUserId: counterpartId,
        unreadFreed: unreadFreed,
        rewritePreview: wasLatest,
      );
      if (wasLatest) {
        await _neutralizeChatNotification(chatId: chatId, recipientId: counterpartId);
      }
    } else {
      debugPrint('[CHAT_SERVICE] deleteMessages: counterpart not resolved for $chatId');
    }

    for (final url in mediaUrls) {
      try {
        await FirebaseStorage.instance.refFromURL(url).delete();
        debugPrint('[CHAT_SERVICE] Media file deleted from storage: $url');
      } catch (e) {
        debugPrint('[CHAT_SERVICE] Error deleting media from storage: $e');
      }
    }

    return deletedCount;
  }

  /// «Удалить у меня» — персональное скрытие сообщения (в т.ч. чужого).
  ///
  /// Документ сообщения один на двоих, и удалить его физически может только
  /// автор (Firestore rules). Поэтому для получателя единственный корректный
  /// вариант — пометка `deletedFor`, которая фильтруется на чтении в
  /// [getMessagesStreamWithChatId]. Медиа из Storage при этом НЕ удаляется:
  /// файл всё ещё нужен второй стороне.
  ///
  /// Возвращает количество скрытых сообщений (0 — ошибка, UI покажет её).
  static Future<int> hideMessagesForMe(String otherUserId, List<String> messageIds) async {
    final uid = UserService.currentUid;
    if (uid == null || messageIds.isEmpty) return 0;

    final chatId = activeChatId ?? getChatId(otherUserId);
    final messagesRef = _db.collection('chats').doc(chatId).collection('messages');
    final batch = _db.batch();

    for (final id in messageIds) {
      // arrayUnion, а не перезапись массива: оба участника могут скрывать
      // сообщения одновременно, и ни один не должен затирать чужую пометку.
      // Firestore rules проверяют именно результат — deletedFor может только
      // прирасти собственным uid (см. 04_chats.rules, правило #5).
      batch.update(messagesRef.doc(id), {
        'deletedFor': FieldValue.arrayUnion([uid]),
      });
    }

    try {
      await batch.commit();
      // Превью в списке чатов остаётся общим на двоих и намеренно НЕ меняется:
      // сообщение никуда не делось, оно скрыто только у одной стороны.
      return messageIds.length;
    } catch (e, stack) {
      debugPrint('[CHAT_SERVICE] hideMessagesForMe ERROR: $e');
      AnalyticsService.logFirestorePermissionError(e, stack, chatId, 'write', 'messages');
      return 0;
    }
  }

  /// Второй участник чата по документу чата — единственный надёжный источник.
  /// Возвращает null, если чат недоступен или в нём не двое: лучше пропустить
  /// уборку, чем записать что-то в чужой профиль.
  static Future<String?> _resolveCounterpart(
    DocumentReference<Map<String, dynamic>> chatRef,
    String uid,
  ) async {
    try {
      final snap = await chatRef.get();
      final raw = snap.data()?['users'];
      if (raw is! List) return null;
      final others = raw
          .map((e) => e.toString())
          .where((u) => u != uid)
          .toList(growable: false);
      return others.length == 1 ? others.first : null;
    } catch (e) {
      debugPrint('[CHAT_SERVICE] _resolveCounterpart ERROR: $e');
      return null;
    }
  }

  /// Погасить офферы, чьи карточки в чате были удалены.
  /// Покупателю rules разрешают только pending → cancelled — ровно это и надо.
  static Future<void> _cancelOffersForDeletedMessages(List<String> offerIds) async {
    for (final offerId in offerIds) {
      try {
        await _db.collection('offers').doc(offerId).update({
          'status': 'cancelled',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('[CHAT_SERVICE] Offer $offerId not cancelled after message delete: $e');
      }
    }
  }

  /// Привести документ чата в соответствие с реальностью после hard delete:
  /// пересобрать превью и вернуть собеседнику незаслуженные непрочитанные.
  ///
  /// `lastMessage` живёт отдельным полем на документе чата, поэтому раньше
  /// удалённое сообщение продолжало висеть превью в списке чатов у ОБОИХ —
  /// пользователь своими глазами видел текст, который «удалил у всех».
  static Future<void> _syncChatAfterDelete({
    required DocumentReference<Map<String, dynamic>> chatRef,
    required String otherUserId,
    required int unreadFreed,
    required bool rewritePreview,
  }) async {
    if (!rewritePreview && unreadFreed == 0) return;

    try {
      // Запрос по коллекции внутри runTransaction невозможен, поэтому хвост
      // читаем заранее. Гонка (собеседник пишет ровно в этот момент) закрыта
      // тем, что запрос идёт ПОСЛЕ коммита удаления: более свежее сообщение,
      // если оно есть, вернётся этим же запросом и станет превью.
      Map<String, dynamic>? tail;
      if (rewritePreview) {
        final snap = await chatRef
            .collection('messages')
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get();
        tail = snap.docs.isEmpty ? null : snap.docs.first.data();
      }

      await _db.runTransaction((tx) async {
        final chatSnap = await tx.get(chatRef);
        if (!chatSnap.exists) return;
        final chatData = chatSnap.data() ?? {};

        final Map<String, dynamic> update = {};

        if (rewritePreview) {
          if (tail == null) {
            // Переписка опустела. `lastTimestamp` намеренно не трогаем: он
            // задаёт позицию чата в списке, а обнулив его, мы бы утопили
            // только что активный диалог в конец ленты.
            update['lastMessage'] = '';
            update['lastMessageType'] = 'empty';
            update['lastOfferPrice'] = FieldValue.delete();
            update['lastSystemKey'] = FieldValue.delete();
          } else {
            final String type = (tail['type'] as String?) ?? 'text';
            update['lastMessage'] = tail['text'] ?? '';
            update['lastMessageType'] = type;
            update['lastSenderId'] = tail['senderId'] ?? '';
            update['lastTimestamp'] = tail['timestamp'] ?? Timestamp.now();
            update['lastOfferPrice'] =
                type == 'offer' && tail['offerPrice'] != null
                    ? tail['offerPrice']
                    : FieldValue.delete();
            update['lastSystemKey'] =
                type == 'system' && tail['systemKey'] != null
                    ? tail['systemKey']
                    : FieldValue.delete();
          }
        }

        if (unreadFreed > 0) {
          // Явное значение вместо increment(-1): счётчик обязан остаться
          // неотрицательным, иначе в списке чатов отрисуется бейдж «-1».
          final int current =
              (chatData['unreadCount_$otherUserId'] as num?)?.toInt() ?? 0;
          update['unreadCount_$otherUserId'] =
              current > unreadFreed ? current - unreadFreed : 0;
        }

        if (update.isNotEmpty) {
          tx.set(chatRef, update, SetOptions(merge: true));
        }
      });
    } catch (e) {
      debugPrint('[CHAT_SERVICE] _syncChatAfterDelete ERROR: $e');
    }
  }

  /// Обезличить in-app уведомление получателя после «удалить у всех».
  ///
  /// Чат-уведомления апсертятся в один документ `chat_<chatId>`, и его `body`
  /// хранит текст сообщения. Без этой уборки собеседник спокойно читал
  /// «удалённое» в колокольчике. Вызывается только когда удалили последнее
  /// сообщение чата — иначе мы бы затёрли уведомление о более свежем.
  ///
  /// Документ читать нельзя (rules: read только владельцу), поэтому пишем
  /// слепо через merge. Если получатель уже удалил уведомление, merge
  /// превратится в create без обязательного `timestamp` и правила его
  /// отклонят — это желаемый исход, воскрешать уведомление незачем.
  static Future<void> _neutralizeChatNotification({
    required String chatId,
    required String recipientId,
  }) async {
    final uid = UserService.currentUid;
    if (uid == null) return;
    final senderName = StorageService.getString('user_name') ?? 'Пользователь';
    try {
      await _db
          .collection('users')
          .doc(recipientId)
          .collection('notifications')
          .doc('chat_$chatId')
          .set({
        'title': 'Новое сообщение: $senderName',
        'body': 'Сообщение удалено',
        'type': 'chat',
        'senderId': uid,
        // `timestamp` намеренно не обновляем: событие то же самое, всплывать
        // в начало списка ему незачем. merge сохраняет существующее поле, а
        // правила проверяют лишь его наличие в итоговом документе.
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[CHAT_SERVICE] Notification not neutralized after delete: $e');
    }
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
