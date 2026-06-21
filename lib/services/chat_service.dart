import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:iqmarket/models/message_model.dart';
import 'package:iqmarket/models/ad_model.dart';
import 'package:iqmarket/services/user_service.dart';
import 'package:iqmarket/services/storage_service.dart';
import 'package:iqmarket/services/notification_service.dart';
import 'package:flutter/foundation.dart';

import 'package:firebase_storage/firebase_storage.dart';

class ChatService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
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
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          final messages = snapshot.docs
            .map((doc) => MessageModel.fromMap(doc.data(), doc.id))
            .toList();
          return messages;
        });
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
  }) async {
    final sellerId = ad.userId;
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
        'users': [uid, sellerId],
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
      );

      return docRef.id;
    } catch (e) {
      debugPrint('[CHAT_SERVICE] sendMessage ERROR: $e');
      return null;
    }
  }

  /// Отправить предложение цены. Бросает исключение при ошибке для обработки в UI.
  static Future<void> sendOffer({
    required AdModel ad,
    required double price,
  }) async {
    final uid = UserService.currentUid;
    if (uid == null) throw Exception('Вы не авторизованы');

    // 🔒 Защита от торга с самим собой
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
      // Update last message in chat summary (creates chat doc first to satisfy rules)
      final summaryData = {
        'lastMessage': text,
        'lastTimestamp': Timestamp.now(),
        'lastSenderId': uid,
        'isRead': false,
        'users': [uid, ad.userId],
        'unreadCount_${ad.userId}': FieldValue.increment(1),
        'name_$uid': actualSenderName,
        'name_${ad.userId}': ad.userName,
        'adId': ad.id,
        'adTitle': ad.title,
        'adImage': ad.images.isNotEmpty ? ad.images.first : '',
      };
      await _db.collection('chats').doc(chatId).set(summaryData, SetOptions(merge: true));

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

      // Send push notification trigger
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
        }
      );
    } catch (e) {
      debugPrint('[CHAT_SERVICE] sendOffer ERROR: $e');
      rethrow;
    }
  }

  static Future<void> updateOfferStatus(String sellerId, String messageId, String status) async {
    final chatId = getChatId(sellerId);
    final docRef = _db.collection('chats').doc(chatId).collection('messages').doc(messageId);
    
    await docRef.update({'offerStatus': status});

    // Send a response message automatically
    final adDoc = await docRef.get();
    final adData = adDoc.data();
    if (adData != null) {
      final responseText = status == 'accepted' 
          ? 'Предложение принято! ✅' 
          : 'Предложение отклонено ❌';
      
      final senderId = UserService.currentUid;
      if (senderId == null) return;

      await _db.collection('chats').doc(chatId).collection('messages').add({
        'senderId': senderId,
        'text': responseText,
        'type': 'text',
        'timestamp': Timestamp.now(),
        'isRead': false,
      });

      await _db.collection('chats').doc(chatId).update({
        'lastMessage': responseText,
        'lastTimestamp': Timestamp.now(),
      });

      // Notify the recipient about offer status change
      // We need to find who sent the offer originally. 
      // It's the 'senderId' of the message with messageId.
      final offerSenderId = adData['senderId'];
      if (offerSenderId != null) {
        NotificationService.saveNotificationToFirestore(
          uid: offerSenderId,
          title: status == 'accepted' ? 'Предложение принято! ✅' : 'Предложение отклонено ❌',
          body: 'Продавец ответил на ваше предложение по товару "${adData['adTitle'] ?? 'объявлению'}"',
          type: 'chat',
          data: {
            'chatId': chatId,
            'adId': adData['adId'] ?? '',
          },
        );
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
  static Future<void> markAsRead(String sellerId) async {
    final uid = UserService.currentUid;
    if (uid == null) return;
    final chatId = getChatId(sellerId);

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
    }, SetOptions(merge: true));
  }

  static Stream<bool> getTypingStatusStream(String sellerId) {
    final chatId = getChatId(sellerId);
    return _db.collection('chats').doc(chatId).snapshots().map((doc) {
      if (!doc.exists) return false;
      final data = doc.data() as Map<String, dynamic>;
      return data['typing_$sellerId'] ?? false;
    });
  }

  /// Установка статуса Online в чате и обновление lastActive
  static Future<void> updateOnlineStatus(String sellerId, bool isOnline) async {
    final uid = UserService.currentUid;
    if (uid == null) return;
    
    // Обновляем онлайн статус в чате
    final chatId = getChatId(sellerId);
    try {
      await _db.collection('chats').doc(chatId).set({
        'online_$uid': isOnline,
      }, SetOptions(merge: true));
    } catch (e) { debugPrint('[ChatService.updateOnlineStatus] Chat not created yet: $e'); }

    // Обновляем lastActive в глобальном профиле
    if (!isOnline) {
      try {
        await _db.collection('users').doc(uid).update({
          'lastActive': FieldValue.serverTimestamp(),
        });
      } catch (e) { debugPrint('[ChatService.updateOnlineStatus] lastActive update error: $e'); }
    }
  }

  /// Get list of chats for the current user
  static Stream<List<Map<String, dynamic>>> getChatListStream() {
    final uid = UserService.currentUid;
    if (uid == null) return Stream.value([]);

    return _db
        .collection('chats')
        .where('users', arrayContains: uid)
        .limit(50) // 🔒 КРИТИЧНО: без limit() у продавца с 500+ чатами = 500+ Reads каждый рефреш
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
      'users': [UserService.currentUid, otherUserId],
      'unreadCount_${UserService.currentUid}': 3,
      'name_$otherUserId': 'Иван (Тест)',
      'adTitle': 'iPhone 13',
      'adImage': 'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?q=80&w=100',
    }, SetOptions(merge: true));
  }
}
