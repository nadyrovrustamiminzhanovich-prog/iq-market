import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:iqmarket/models/notification_model.dart';
import 'package:iqmarket/services/user_service.dart';
import 'package:iqmarket/services/storage_service.dart';
import 'package:iqmarket/services/chat_service.dart';
import 'package:iqmarket/services/ad_service.dart';
import 'package:iqmarket/models/ad_model.dart';
import 'package:iqmarket/screens/chat_screen.dart';
import 'package:iqmarket/screens/taxi/taxi_service_screen.dart';
import 'package:iqmarket/screens/product_details_screen.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final Set<String> _processedMessageIds = {};
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // P1: Stores notification data from terminated-state launch.
  // Consumed once by [handlePendingNavigation] after the first route is built.
  static Map<String, dynamic>? _pendingNavigationData;

  static Future<void> init() async {
    // 1. Request permissions
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted notification permission ✅');
    }

    // 2. Initialize local notifications
    const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosInit = DarwinInitializationSettings();
    const InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );
    
    await _notificationsPlugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null) {
          debugPrint('Notification payload received: ${response.payload}');
          try {
            final Map<String, dynamic> data = Map<String, dynamic>.from(
              Uri.splitQueryString(response.payload!)
            );
            _navigateToChat(data);
          } catch (e) {
            debugPrint('Error parsing notification payload: $e');
          }
        }
      },
    );

    // 3. Setup message handling
    FirebaseMessaging.onMessage.listen((message) => _onForegroundMessage(message));

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('Notification opened from background: ${message.notification?.title}');
      // Navigator is always ready here (app was backgrounded, not terminated)
      _navigateToChat(message.data);
    });

    // P1 FIX: When app is fully terminated and opened via notification tap,
    // navigatorKey.currentState is null at this point (widget tree not yet built).
    // We store the data and let handlePendingNavigation() consume it after
    // the first route is mounted (called from IQMarketHome.initState).
    final RemoteMessage? initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('[FCM] Terminated-state launch detected');
      if (navigatorKey.currentState != null) {
        debugPrint('[FCM] Navigator is ready, navigating directly');
        _navigateToChat(initialMessage.data);
      } else {
        debugPrint('[FCM] Navigator is null, storing pending nav data');
        _pendingNavigationData = initialMessage.data;
      }
    }

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    // 4. Token management
    _setupTokenSync();
  }

  static void _setupTokenSync() async {
    String? token = await _messaging.getToken();
    if (token != null) _saveTokenToFirestore(token);

    _messaging.onTokenRefresh.listen((newToken) => _saveTokenToFirestore(newToken));
  }

  static Future<void> _saveTokenToFirestore(String token) async {
    final uid = UserService.currentUid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).set({
      'fcmToken': token,
      'lastTokenUpdate': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    debugPrint('FCM Token synced to Firestore ✅');
  }

  static Future<void> _handleDataMessage(RemoteMessage message) async {
    if (message.messageId != null) {
      if (_processedMessageIds.contains(message.messageId)) return;
      _processedMessageIds.add(message.messageId!);
      if (_processedMessageIds.length > 100) _processedMessageIds.remove(_processedMessageIds.first);
    }

    // Don't show local notification if user is already in this chat
    final incomingChatId = message.data['chatId'];
    final senderId = message.data['senderId'];
    if (incomingChatId != null && incomingChatId == ChatService.activeChatId) {
      if (senderId != null) ChatService.markAsRead(senderId);
      return;
    }

    // ✅ NOTE: We do NOT call saveNotificationToFirestore here.
    // Notifications are already saved to Firestore at the time of sending
    // (via ChatService.sendMessage, ChatService.sendOffer, etc.).
    // Calling it here again would cause duplicate notifications.
    // This handler only needs to:
    //   1. Show local system notification (handled in _onForegroundMessage)
    //   2. Process special storage flags below

    if (message.data['type'] == 'driver_verified') {
      await StorageService.setBool('taxi_verified', true);
      await StorageService.setString('taxi_verif_status', 'approved');
    }
    if (message.data['type'] == 'user_verified') {
      await StorageService.setBool('is_verified', true);
    }
  }

  static void _navigateToChat(Map<String, dynamic> data) {
    final String type = data['type'] ?? '';
    if (type == 'taxi_bid' || type == 'taxi_bid_accepted') {
      debugPrint('Navigating to TaxiServiceScreen from notification type: $type');
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const TaxiServiceScreen(lang: 'ru')),
      );
      return;
    }

    if (type == 'review') {
      final adId = data['adId'];
      if (adId != null && adId.isNotEmpty) {
        AdService.getAdById(adId).then((ad) {
          if (ad != null && navigatorKey.currentState != null) {
            navigatorKey.currentState?.push(
              MaterialPageRoute(builder: (_) => ProductDetailsScreen(ad: ad, onReport: (_){}, lang: 'ru')),
            );
          }
        });
      }
      return;
    }


    final adId = data['adId'] ?? '';
    final adTitle = data['adTitle'] ?? 'Объявление';
    final adImage = data['adImage'] ?? '';
    final senderId = data['senderId'] ?? '';
    final senderName = data['senderName'] ?? 'Пользователь';
    final senderPhone = data['senderPhone'] ?? '';

    debugPrint('Navigating to chat with senderId: $senderId, adId: $adId');

    if (senderId.isEmpty) {
      debugPrint('Warning: senderId is empty, cannot navigate to chat');
      return;
    }

    final ad = AdModel(
      id: adId,
      title: adTitle,
      description: '',
      price: 0.0,
      category: '',
      images: adImage.isNotEmpty ? [adImage] : [],
      userId: senderId,
      userName: senderName,
      userEmail: '',
      userPhone: senderPhone.isNotEmpty ? senderPhone : null,
      timestamp: DateTime.now(),
      location: '',
    );

    if (navigatorKey.currentState == null) {
      debugPrint('Error: NavigatorKey state is null');
      return;
    }

    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => ChatScreen(ad: ad)),
    );
  }

  static Future<void> saveNotificationToFirestore({
    required String title,
    required String body,
    String type = 'system',
    Map<String, dynamic>? data,
    String? uid, // Добавили опциональный UID
  }) async {
    try {
      final targetUid = uid ?? UserService.currentUid;
      if (targetUid == null) return;

      // ✅ Для чат-уведомлений используем upsert по chatId
      // чтобы НЕ создавать новый документ при каждом сообщении (спам счётчика)
      final chatId = data?['chatId'];
      if (type == 'chat' && chatId != null) {
        // Обновляем или создаём один документ на чат
        final docId = 'chat_$chatId';
        await _db.collection('users').doc(targetUid).collection('notifications').doc(docId).set({
          'title': title,
          'body': body,
          'timestamp': FieldValue.serverTimestamp(),
          'type': type,
          'isRead': false,
          'data': data,
        }, SetOptions(merge: false)); // merge:false чтобы обновить весь документ
        return;
      }

      // Все остальные типы уведомлений отправляем через Cloud Function
      final callable = FirebaseFunctions.instance.httpsCallable('sendSystemNotification');
      await callable.call({
        'targetUid': targetUid,
        'title': title,
        'body': body,
        'type': type,
        'payload': data,
      });
    } catch (e) {
      debugPrint('[NotificationService] Error saving notification: $e');
    }
  }

  static Stream<List<NotificationModel>> getNotificationsStream() {
    final uid = UserService.currentUid;
    if (uid == null) return Stream.value([]);

    return _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .limit(100) // 🔒 Без лимита — при 1000+ уведомлениях всё скачивается каждый раз
        .snapshots()
        .map((snap) => snap.docs.map((doc) => NotificationModel.fromMap(doc.data(), doc.id)).toList());
  }

  static Stream<int> getUnreadNotificationsCountStream() {
    final uid = UserService.currentUid;
    if (uid == null) return Stream.value(0);

    return _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  static Future<void> markAsRead(String id) async {
    final uid = UserService.currentUid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).collection('notifications').doc(id).update({'isRead': true});
  }

  static Future<void> deleteNotification(String id) async {
    final uid = UserService.currentUid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).collection('notifications').doc(id).delete();
  }

  static Future<void> markAllAsRead() async {
    final uid = UserService.currentUid;
    if (uid == null) return;
    final batch = _db.batch();
    final unread = await _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .get();
    for (var doc in unread.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  static void notify(BuildContext context, String title, String body, {bool isSuccess = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title, 
                style: const TextStyle(
                  fontWeight: FontWeight.w900, 
                  color: Color(0xFF1E293B),
                  fontSize: 14,
                )
              ),
              const SizedBox(height: 2),
              Text(
                body, 
                style: const TextStyle(
                  fontSize: 13, 
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                )
              ),
            ],
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 8,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 70), // Сделали чуть выше для удобства
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.black.withValues(alpha: 0.05), width: 1),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  static Future<void> _onForegroundMessage(RemoteMessage message) async {
    await _handleDataMessage(message);

    final RemoteNotification? notification = message.notification;
    if (notification == null) return; // data-only message — nothing to display

    // Don't show local banner if user is already in this chat
    final incomingChatId = message.data['chatId'];
    if (incomingChatId != null && incomingChatId == ChatService.activeChatId) return;

    // P12 FIX: removed `android != null` guard — iOS foreground also shows local banner
    final String payload = Uri(
      queryParameters: Map<String, String>.from(message.data),
    ).query;

    await _notificationsPlugin.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          channelDescription: 'Important app notifications.',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          // Show heads-up notification (peek)
          fullScreenIntent: false,
          enableVibration: true,
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.active,
        ),
      ),
      payload: payload,
    );
  }

  /// Call this from the first screen's [initState] (after a short delay so the
  /// navigator is fully built) to handle terminated-state notification taps.
  static void handlePendingNavigation() {
    final data = _pendingNavigationData;
    if (data == null) return;
    _pendingNavigationData = null; // consume once
    // Small delay — navigator needs 1 frame to be ready
    Future.delayed(const Duration(milliseconds: 600), () {
      if (navigatorKey.currentState != null) {
        debugPrint('[FCM] Processing pending terminated-state navigation');
        _navigateToChat(data);
      } else {
        debugPrint('[FCM] navigatorKey still null after delay — skipping pending nav');
      }
    });
  }
  
  // ===================== TOPICS =====================

  static Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
    debugPrint('Subscribed to topic: $topic ✅');
  }

  static Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
    debugPrint('Unsubscribed from topic: $topic ❌');
  }

  // ===================== SUBSCRIPTION MANAGER =====================

  static Future<void> toggleCategorySubscription(String category, bool subscribe) async {
    // Normalize category name for topic (no spaces, lowercase)
    final topic = 'cat_${category.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}';
    if (subscribe) {
      await subscribeToTopic(topic);
    } else {
      await unsubscribeFromTopic(topic);
    }
    
    // Save preference to Firestore for persistence across devices
    final uid = UserService.currentUid;
    if (uid != null) {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'subscriptions': {
          category: subscribe,
        }
      }, SetOptions(merge: true));
    }
  }
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Handling background message: ${message.messageId}');
}
