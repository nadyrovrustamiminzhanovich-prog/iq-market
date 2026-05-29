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
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
            .map((doc) => MessageModel.fromMap(doc.data(), doc.id))
            .toList();
        });
  }

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

    final chatId = getChatId(sellerId);
    final messageData = {
      'senderId': uid,
      'text': text,
      'type': type,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      'mediaUrl': mediaUrl,
      'duration': duration,
    };

    final docRef = await _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add(messageData);
    
    // Fetch sender name if not provided
    String actualSenderName = senderName ?? StorageService.getString('user_name') ?? 'Пользователь';

    // Update last message in chat summary
    final summaryData = {
      'lastMessage': text,
      'lastTimestamp': FieldValue.serverTimestamp(),
      'lastSenderId': uid,
      'isRead': false,
      'users': [uid, sellerId],
      'unreadCount_$sellerId': FieldValue.increment(1),
      'name_$uid': actualSenderName,
      'adId': ad.id,
      'adTitle': ad.title,
      'adImage': ad.images.isNotEmpty ? ad.images.first : '',
    };
    
    await _db.collection('chats').doc(chatId).set(summaryData, SetOptions(merge: true));

    // Identify the recipient correctly
    // If the sender is the one in ad.userId, we need the other person from the chat.
    // In our app, ChatScreen always ensures ad.userId is the 'other' person.
    // But for robustness, we should ideally fetch the chat summary or pass recipientId.
    final recipientId = sellerId; // Based on ChatScreen's current implementation

    NotificationService.saveNotificationToFirestore(
      uid: recipientId,
      title: 'Новое сообщение: $actualSenderName',
      body: text,
      type: 'chat',
      data: {
        'chatId': chatId,
        'adId': ad.id,
        'adTitle': ad.title,
        'senderId': uid,
        'senderName': actualSenderName,
      }
    );
    
    return docRef.id;
  }

  static Future<void> sendOffer({
    required AdModel ad,
    required double price,
  }) async {
    final uid = UserService.currentUid;
    if (uid == null) return;

    final chatId = getChatId(ad.userId);
    final text = 'Предложение цены: ${price.toInt()} ₸';
    
    final messageData = {
      'senderId': uid,
      'text': text,
      'type': 'offer',
      'offerPrice': price,
      'offerStatus': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      'adId': ad.id,
      'adTitle': ad.title,
    };

    await _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add(messageData);

    // Fetch sender details
    final actualSenderName = StorageService.getString('user_name') ?? 'Пользователь';
    final senderPhone = StorageService.getString('user_phone') ?? '';

    // Update last message in chat summary
    final summaryData = {
      'lastMessage': text,
      'lastTimestamp': FieldValue.serverTimestamp(),
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
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      await _db.collection('chats').doc(chatId).update({
        'lastMessage': responseText,
        'lastTimestamp': FieldValue.serverTimestamp(),
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

  /// Delete specific messages (including media files from Storage)
  static Future<void> deleteMessages(String sellerId, List<String> messageIds) async {
    final chatId = getChatId(sellerId);
    final batch = _db.batch();
    
    for (var id in messageIds) {
      final docRef = _db.collection('chats').doc(chatId).collection('messages').doc(id);
      
      // Сначала пробуем удалить файл из Storage, если он есть
      try {
        final doc = await docRef.get();
        if (doc.exists) {
          final data = doc.data();
          final String? mediaUrl = data?['mediaUrl'];
          if (mediaUrl != null && mediaUrl.isNotEmpty) {
            await FirebaseStorage.instance.refFromURL(mediaUrl).delete();
            debugPrint('[CHAT_SERVICE] Media file deleted from storage: $mediaUrl');
          }
        }
      } catch (e) {
        debugPrint('[CHAT_SERVICE] Error deleting media from storage: $e');
      }

      batch.delete(docRef);
    }
    await batch.commit();
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
      'lastTimestamp': FieldValue.serverTimestamp(),
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
    } catch (_) {} // Игнорируем, если чат еще не создан

    // Обновляем lastActive в глобальном профиле
    if (!isOnline) {
      try {
        await _db.collection('users').doc(uid).update({
          'lastActive': FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    }
  }

  /// Get list of chats for the current user
  static Stream<List<Map<String, dynamic>>> getChatListStream() {
    final uid = UserService.currentUid;
    if (uid == null) return Stream.value([]);

    return _db
        .collection('chats')
        .where('users', arrayContains: uid)
        // Убрали orderBy, чтобы чаты не пропадали без индексов
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
      'lastTimestamp': FieldValue.serverTimestamp(),
      'users': [UserService.currentUid, otherUserId],
      'unreadCount_${UserService.currentUid}': 3,
      'name_$otherUserId': 'Иван (Тест)',
      'adTitle': 'iPhone 13',
      'adImage': 'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?q=80&w=100',
    }, SetOptions(merge: true));
  }
}
