import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:iqmarket/models/user_model.dart';
import 'package:iqmarket/services/ad_service.dart';
import 'package:iqmarket/services/notification_service.dart';

class UserService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static String? mockUid;

  // Collection reference
  static CollectionReference get users => _db.collection('users');

  /// Check if the user is authenticated
  static bool get isLoggedIn => _auth.currentUser != null;
  static String? get currentUid => mockUid ?? _auth.currentUser?.uid;

  /// Creates or updates a user document in Firestore after login/registration
  static Future<bool> syncUserAfterLogin({
    required String name,
    String? email,
    String? photoUrl,
    String? phone,
    bool isVerified = false,
    String? accountType,
    String? language,
    bool isLanguageManuallyChanged = false,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final docRef = users.doc(user.uid);
      final docSnap = await docRef.get();

      if (!docSnap.exists) {
        // Create new user profile
        await docRef.set({
          'uid': user.uid,
          'name': name,
          'photoUrl': photoUrl ?? user.photoURL ?? '',
          'accountType': accountType ?? 'user', // Standardized
          'isVerified': isVerified,
          'status': 'active',
          'registrationDate': FieldValue.serverTimestamp(),
          'reviewsCount': 0,
          'rating': 5.0, // Стартовый рейтинг — держится/снижается по факту реальных отзывов
          'language': language ?? 'Русский',
        });

        // Save sensitive contact fields to the private subcollection
        await docRef.collection('private').doc('contact').set({
          'phone': phone ?? user.phoneNumber ?? '',
          'email': email ?? user.email ?? '',
          'updated_at': FieldValue.serverTimestamp(),
        });
        return isVerified;
      } else {
        final existingData = docSnap.data() as Map<String, dynamic>?;
        final bool existingVerified = existingData?['isVerified'] == true;

        // Update existing user profile
        Map<String, dynamic> updates = {};
        if (photoUrl != null && photoUrl.isNotEmpty) updates['photoUrl'] = photoUrl;
        if (isVerified && !existingVerified) updates['isVerified'] = true;
        if (accountType != null) updates['accountType'] = accountType;
        if (isLanguageManuallyChanged && language != null) {
          updates['language'] = language;
        }
        
        if (updates.isNotEmpty) {
          await docRef.update(updates);
        }

        // Update contact info if email is provided
        if (email != null && email.isNotEmpty) {
          await docRef.collection('private').doc('contact').set({
            'email': email,
            'updated_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
        return existingVerified || isVerified;
      }
    } catch (e) {
      debugPrint('Error syncing user after login: $e');
      return isVerified;
    }
  }

  /// Get user data stream for real-time updates in UI
  static Stream<UserModel?> getUserStream() {
    final uid = currentUid;
    if (uid == null) {
      return Stream.value(null);
    }
    
    // Combine main document stream with private contact document stream
    return users.doc(uid).snapshots().asyncMap((mainSnap) async {
      if (!mainSnap.exists) return null;
      final mainData = Map<String, dynamic>.from(mainSnap.data() as Map);

      try {
        final contactSnap = await users.doc(uid).collection('private').doc('contact').get();
        if (contactSnap.exists) {
          final contactData = contactSnap.data() as Map<String, dynamic>;
          mainData['phone'] = contactData['phone'] ?? '';
          mainData['email'] = contactData['email'] ?? '';
        }
      } catch (e) {
        debugPrint('[UserService] getUserStream: Accessing contact info failed: $e');
      }

      return UserModel.fromMap(mainData, mainSnap.id);
    });
  }

  /// Контактные поля пользователя (phone/email/telegram) из приватного
  /// документа `users/{uid}/private/contact`.
  ///
  /// Отдельный геттер существует потому, что в основном документе этих полей
  /// НЕТ и быть не может: Firestore rules запрещают владельцу писать
  /// 'phone'/'email' в `users/{uid}` (02_users.rules), поэтому
  /// [updateUserProfile] раскладывает их сюда. Любой экран, читающий телефон
  /// напрямую из основного документа, всегда получит пусто — так и потерялся
  /// номер в «Личных данных». Читать контакты только отсюда.
  ///
  /// Возвращает пустую карту, если документа нет или доступ закрыт (чужой uid).
  static Future<Map<String, dynamic>> getPrivateContact({String? uid}) async {
    final targetUid = uid ?? currentUid;
    if (targetUid == null) return {};
    try {
      final snap =
          await users.doc(targetUid).collection('private').doc('contact').get();
      return snap.data() ?? {};
    } catch (e) {
      debugPrint('[UserService] getPrivateContact failed for $targetUid: $e');
      return {};
    }
  }

  /// Пометить номер как подтверждённый через контакт в Телеграме.
  ///
  /// `verified_phone` живёт в ОСНОВНОМ документе (разрешённое правилами
  /// исключение) — на нём стоит защита от угона номера (`users where
  /// verified_phone == ...`) и его видит админ в карточке пользователя.
  /// Сам телефон дополнительно кладётся в `private/contact` для отображения
  /// в «Личных данных».
  ///
  /// Только цифры: `verified_phone` сравнивается запросами на равенство, поэтому
  /// формат обязан быть единым (без '+' и символов маски).
  static Future<void> markPhoneVerifiedViaTelegram({
    required String phone,
    String telegramUsername = '',
  }) async {
    final uid = currentUid;
    if (uid == null) return;
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return;
    try {
      await users.doc(uid).set({
        'verified_phone': digits,
        'isTelegramVerified': true,
        if (telegramUsername.isNotEmpty) 'telegram_username': telegramUsername,
      }, SetOptions(merge: true));
      await updateUserProfile({'phone': phone});
    } catch (e) {
      debugPrint('[UserService] markPhoneVerifiedViaTelegram failed: $e');
    }
  }

  /// Update specific fields in user profile
  static Future<void> updateUserProfile(Map<String, dynamic> data) async {
    final uid = currentUid;
    if (uid == null) return;
    
    try {
      // Split public and private contact fields
      final Map<String, dynamic> publicData = {};
      final Map<String, dynamic> contactData = {};
      
      final contactFields = ['phone', 'email', 'telegram_chat_id', 'telegramChatId'];
      
      data.forEach((key, value) {
        if (contactFields.contains(key)) {
          contactData[key] = value;
        } else {
          publicData[key] = value;
        }
      });
      
      if (publicData.isNotEmpty) {
        await users.doc(uid).update(publicData);
        if (publicData.containsKey('name') || publicData.containsKey('photoUrl')) {
          _syncProfileToChats(uid, name: publicData['name'], photoUrl: publicData['photoUrl']);
        }
      }
      
      if (contactData.isNotEmpty) {
        contactData['updated_at'] = FieldValue.serverTimestamp();
        await users.doc(uid).collection('private').doc('contact').set(
          contactData,
          SetOptions(merge: true),
        );
      }
    } catch (e) {
      debugPrint('Error updating user profile: $e');
      rethrow;
    }
  }

  /// Синхронизация нового имени/аватарки по всем диалогам пользователя
  static Future<void> _syncProfileToChats(String uid, {String? name, String? photoUrl}) async {
    try {
      final chatsSnap = await _db.collection('chats').where('users', arrayContains: uid).get();
      if (chatsSnap.docs.isEmpty) return;

      final batch = _db.batch();
      for (var doc in chatsSnap.docs) {
        final Map<String, dynamic> updates = {};
        if (name != null) updates['name_$uid'] = name;
        if (photoUrl != null) updates['avatar_$uid'] = photoUrl;
        if (updates.isNotEmpty) {
          batch.update(doc.reference, updates);
        }
      }
      await batch.commit();
      debugPrint('[UserService] Synced updated profile to ${chatsSnap.docs.length} active chats ✅');
    } catch (e) {
      debugPrint('[UserService] Error syncing profile to chats: $e');
    }
  }

  /// Get all users (Admin only)
  static Stream<List<UserModel>> getAllUsersStream() {
    return users.snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
      list.sort((a, b) => b.registrationDate.compareTo(a.registrationDate));
      return list;
    });
  }

  /// Admin: Toggle user verification status
  static Future<void> toggleUserVerification(String uid, bool isVerified) async {
    try {
      await users.doc(uid).update({'isVerified': isVerified});
      
      // Notify user about verification status
      NotificationService.saveNotificationToFirestore(
        uid: uid,
        title: isVerified ? 'Профиль подтвержден! ✅' : 'Статус подтверждения изменен',
        body: isVerified 
          ? 'Поздравляем! Ваш профиль успешно прошел проверку и получил статус подтвержденного.' 
          : 'Ваш статус верификации был обновлен администратором.',
        type: 'driver_verified', // Using this type for icon/color
      ).catchError((e) {
        debugPrint('[USER_SERVICE] toggleUserVerification notification failed: $e');
      });
    } catch (e) {
      debugPrint('Error toggling user verification: $e');
    }
  }

  /// Admin: Toggle user ban status
  static Future<void> toggleUserBan(String uid, bool isBanned) async {
    try {
      await users.doc(uid).update({'status': isBanned ? 'banned' : 'active'});
      
      if (isBanned) {
        NotificationService.saveNotificationToFirestore(
          uid: uid,
          title: 'Ваш аккаунт заблокирован ❌',
          body: 'Ваш профиль был заблокирован администратором за нарушение правил сообщества.',
          type: 'ad_rejected',
        ).catchError((e) {
          debugPrint('[USER_SERVICE] toggleUserBan notification failed: $e');
        });
      }
    } catch (e) {
      debugPrint('Error toggling user ban: $e');
    }
  }

  /// Admin: Toggle Admin role
  static Future<void> toggleUserAdmin(String uid, bool isAdmin) async {
    try {
      await users.doc(uid).update({'accountType': isAdmin ? 'admin' : 'user'});
    } catch (e) {
      debugPrint('Error toggling admin role: $e');
    }
  }


  /// Get user by ID (for seller info)
  static Future<UserModel?> getUserById(String uid) async {
    if (uid.isEmpty) return null;
    try {
      final doc = await users.doc(uid).get();
      if (!doc.exists) return null;
      final mainData = Map<String, dynamic>.from(doc.data() as Map);

      String phone = '';
      String email = '';

      try {
        final contactSnap = await users.doc(uid).collection('private').doc('contact').get();
        if (contactSnap.exists) {
          final contactData = contactSnap.data() as Map<String, dynamic>;
          phone = contactData['phone'] ?? '';
          email = contactData['email'] ?? '';
        }
      } catch (e) {
        debugPrint('[UserService] Contact info access restricted for uid: $uid');
      }

      mainData['phone'] = phone;
      mainData['email'] = email;

      return UserModel.fromMap(mainData, doc.id);
    } catch (e) {
      debugPrint('Error getting user by id: $e');
      return null;
    }
  }

  /// Delete user data (for compliance/deletion)
  static Future<void> deleteUserData() async {
    final uid = currentUid;
    if (uid == null) return;
    try {
      // 1. Delete all ads, images and videos first
      await AdService.deleteUserAds(uid);
      
      // 2. Delete the user profile doc
      await users.doc(uid).delete();
      
      debugPrint('User data and ads deleted for $uid ✅');
    } catch (e) {
      debugPrint('Error deleting user data: $e');
    }
  }
}
