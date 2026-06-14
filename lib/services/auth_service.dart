import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:iqmarket/services/telegram_bot_service.dart';

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

  // ===================== UTILS =====================

  static Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

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
}
