import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:iqmarket/services/telegram_bot_service.dart';
import 'package:iqmarket/services/notification_service.dart';
import 'package:cloud_functions/cloud_functions.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final dynamic _googleSignIn = GoogleSignIn.instance;

  static Future<void> init() async {
    try {
      // Явно прописываем serverClientId для фикса DEVELOPER_ERROR на Xiaomi
      await _googleSignIn.initialize(
        serverClientId: '984873146578-ers7tbn7972bk4g0qoufq28kq3ttsgbn.apps.googleusercontent.com',
      );
      // Он уже содержится в google-services.json (поле client_id → oauth_client type=3),
      // который автоматически читается google-services плагином при сборке.
      // Хранить Client ID в Dart-коде небезопасно: он видим при декомпиляции APK.
      // TODO(security): Рассмотреть перенос serverClientId в Remote Config.
    } catch (e) {
      debugPrint('GoogleSignIn Initialize Error: $e');
    }
  }

  static User? get currentUser => _auth.currentUser;
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ===================== EMAIL & PASSWORD =====================
  
  static Future<UserCredential> registerWithEmail(String email, String password, String name) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    await cred.user?.updateDisplayName(name);
    await cred.user?.sendEmailVerification();
    return cred;
  }

  static Future<UserCredential> loginWithEmail(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  static Future<void> linkEmailAccount(String email, String password) async {
    final credential = EmailAuthProvider.credential(email: email, password: password);
    await _auth.currentUser?.linkWithCredential(credential);
  }

  static Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  static Future<void> updatePassword(String newPassword) async {
    await _auth.currentUser?.updatePassword(newPassword);
  }

  // Firebase считает смену пароля чувствительной операцией и требует "свежий"
  // вход (обычно последние несколько минут). Без явной реаутентификации перед
  // updatePassword() запрос почти всегда падает с requires-recent-login у
  // любого, кто открыл экран не сразу после логина — то есть у подавляющего
  // большинства пользователей.
  static Future<void> reauthenticateWithPassword(String currentPassword) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw FirebaseAuthException(code: 'no-current-user', message: 'Нет активного email-аккаунта');
    }
    final credential = EmailAuthProvider.credential(email: email, password: currentPassword);
    await user.reauthenticateWithCredential(credential);
  }

  // ===================== GOOGLE SIGN IN =====================

  static Future<UserCredential?> signInWithGoogle() async {
    try {
      final dynamic googleUser = await _googleSignIn.authenticate();
      if (googleUser == null) return null;

      final dynamic googleAuth = await googleUser.authentication;
      
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      return await _auth.signInWithCredential(credential);
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      rethrow;
    }
  }

  // ===================== APPLE SIGN IN =====================

  static Future<UserCredential?> signInWithApple() async {
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final OAuthCredential credential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      return await _auth.signInWithCredential(credential);
    } catch (e) {
      debugPrint('Apple Sign-In Error: $e');
      rethrow;
    }
  }

  // ===================== TELEGRAM AUTH =====================

  static Future<String> startTelegramSession({String? phone}) async {
    return await TelegramBotService.startAuthSession(phone: phone);
  }

  static Stream<DocumentSnapshot<Map<String, dynamic>>> watchTelegramSession(String token) {
    return TelegramBotService.watchSession(token);
  }

  // ===================== ACCOUNT LINKING =====================

  static Future<UserCredential?> linkWithGoogle() async {
    try {
      final dynamic googleUser = await _googleSignIn.authenticate();
      if (googleUser == null) return null;

      final dynamic googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      return await _auth.currentUser?.linkWithCredential(credential);
    } catch (e) {
      debugPrint('Link Google Error: $e');
      rethrow;
    }
  }

  static Future<UserCredential?> linkWithEmail(String email, String password) async {
    try {
      final credential = EmailAuthProvider.credential(email: email, password: password);
      return await _auth.currentUser?.linkWithCredential(credential);
    } catch (e) {
      debugPrint('Link Email Error: $e');
      rethrow;
    }
  }

  static Future<UserCredential?> linkWithApple() async {
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final OAuthCredential credential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      return await _auth.currentUser?.linkWithCredential(credential);
    } catch (e) {
      debugPrint('Link Apple Error: $e');
      rethrow;
    }
  }

  // ===================== UTILS =====================

  static Future<void> signOut() async {
    // Отвязываем устройство от аккаунта ДО выхода: после signOut() записи в
    // users/{uid} уже не пройдут по правилам, и fcmToken остался бы навсегда
    // указывать на этот телефон — сервер продолжал бы слать сюда пуши чужого
    // (вышедшего) аккаунта, а обработчики пушей проставляли бы по ним статусы
    // доставки/прочтения от имени того, кто вошёл после.
    await NotificationService.clearTokenOnSignOut();

    // Точечно чистим только ключи завершившейся СЕССИИ/аккаунта, а не весь
    // SharedPreferences: blanket prefs.clear() стирал заодно device-level
    // настройки (язык интерфейса, тема, пуш-тумблер, installId для
    // антифрод-эвристики multiAccountSuspected в DeviceIdentityService) —
    // после выхода + полного перезапуска приложения язык откатывался на
    // русский по умолчанию, самоисправляясь только повторным входом.
    final prefs = await SharedPreferences.getInstance();
    const sessionKeys = [
      // Кэш профиля вошедшего аккаунта (не namespaced по uid)
      'user_phone', 'user_email', 'user_name', 'user_image',
      'account_type', 'is_bio_enabled', 'is_verified', 'taxi_logged_in',
      // Кэш водителя такси, привязанный к аккаунту
      'taxi_verified', 'taxi_verif_status', 'taxi_tg_chat_id', 'taxi_phone',
      'taxi_car', 'taxi_plate', 'taxi_notif',
      // Незавершённые пользовательские флоу текущей сессии
      'ad_draft', 'lost_picker_driver_wizard', 'lost_picker_profile',
    ];
    for (final key in sessionKeys) {
      await prefs.remove(key);
    }

    await _auth.signOut();
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint('Google Sign-Out Error: $e');
    }
  }

  static Future<void> deleteAccount() async {
    await _auth.currentUser?.delete();
  }

  /// Результат входа через Телеграм: сам вход плюс номер, которым пользователь
  /// поделился контактом в боте. Номер приходит от сервера, а не от клиента —
  /// custom-token вход не приносит phoneNumber в Firebase Auth, поэтому без
  /// него аккаунт остался бы вообще без телефона.
  static Future<TelegramSignInResult> verifyOtpAndSignIn(String sessionId, String otp) async {
    final callable = FirebaseFunctions.instance.httpsCallable('verifyTelegramOtp');
    final result = await callable.call({
      'sessionId': sessionId,
      'otp': otp,
    });

    final tokenToUse = result.data['customToken'] as String?;
    if (tokenToUse == null || tokenToUse.split('.').length != 3) {
      throw Exception('Не удалось получить токен авторизации от сервера');
    }

    final credential = await _auth.signInWithCustomToken(tokenToUse);
    return TelegramSignInResult(
      credential: credential,
      verifiedPhone: result.data['verifiedPhone'] as String? ?? '',
      telegramUsername: result.data['telegramUsername'] as String? ?? '',
    );
  }
}

class TelegramSignInResult {
  final UserCredential credential;

  /// Номер в каноническом виде `+7XXXXXXXXXX`, подтверждённый через контакт в
  /// Телеграме. Пустая строка — старая сессия, созданная до перехода на
  /// обязательный обмен контактом.
  final String verifiedPhone;
  final String telegramUsername;

  const TelegramSignInResult({
    required this.credential,
    required this.verifiedPhone,
    required this.telegramUsername,
  });
}
