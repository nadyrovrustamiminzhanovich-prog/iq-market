import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart' as fln;
import 'package:iqmarket/services/storage_service.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final fln.FlutterLocalNotificationsPlugin _localNotifications = fln.FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    // 1. Request permissions (especially for iOS)
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted notification permission ✅');
    }

    // 2. Initialize local notifications for foreground alerts
    const fln.AndroidInitializationSettings androidInit = fln.AndroidInitializationSettings('@mipmap/ic_launcher');
    const fln.DarwinInitializationSettings iosInit = fln.DarwinInitializationSettings();
    const fln.InitializationSettings initSettings = fln.InitializationSettings(android: androidInit, iOS: iosInit);
    
    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (fln.NotificationResponse response) {
        debugPrint('Notification tapped: ${response.payload}');
      },
    );

    // 3. Setup message handling
    // Foreground
    FirebaseMessaging.onMessage.listen((message) => _onForegroundMessage(message));
    
    // Background (but app not terminated)
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('Notification opened from background: ${message.notification?.title}');
      _handleDataMessage(message);
    });

    // Terminated state
    RemoteMessage? initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('App launched from notification: ${initialMessage.notification?.title}');
      _handleDataMessage(initialMessage);
    }

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    // 4. Get FCM Token
    String? token = await _messaging.getToken();
    debugPrint('FCM Token: $token');
  }

  static Future<void> _handleDataMessage(RemoteMessage message) async {
    if (message.data['type'] == 'driver_verified') {
      await StorageService.setBool('taxi_verified', true);
      await StorageService.setString('taxi_verif_status', 'approved');
      debugPrint('Driver verification status updated via FCM ✅');
    }
    if (message.data['type'] == 'user_verified') {
      await StorageService.setBool('is_verified', true);
      debugPrint('User verification status updated via FCM ✅');
    }
  }

  static void show(BuildContext context, String title, String body, {bool isSuccess = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(body, style: const TextStyle(fontSize: 12)),
          ],
        ),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }

  static Future<void> _onForegroundMessage(RemoteMessage message) async {
    debugPrint('Received foreground message: ${message.notification?.title}');
    
    // Handle data-only messages or messages with data
    await _handleDataMessage(message);

    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null) {
      await _localNotifications.show(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: const fln.NotificationDetails(
          android: fln.AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            channelDescription: 'This channel is used for important notifications.',
            importance: fln.Importance.max,
            priority: fln.Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: fln.DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
    }
  }
}

// Global background handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Handling background message: ${message.messageId}');
}
