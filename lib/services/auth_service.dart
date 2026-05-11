import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart' as google;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:iqmarket/services/telegram_bot_service.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final google.GoogleSignIn _googleSignIn = google.GoogleSignIn.instance;

  static Future<void> init() async {
    try {
      await _googleSignIn.initialize(
        serverClientId: "984873146578-ers7tbn7972bk4g0qoufq28kq3ttsgbn.apps.googleusercontent.com",
      );
    } catch (e) {
      debugPrint('Google Sign-In Init Error: $e');
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

  static Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  static Future<void> updatePassword(String newPassword) async {
    await _auth.currentUser?.updatePassword(newPassword);
  }

  // ===================== GOOGLE SIGN IN =====================

  static Future<UserCredential?> signInWithGoogle() async {
    try {
      // Используем динамический вызов, чтобы обойти странную ошибку компиляции в данной среде
      // при сохранении работоспособности плагина v7.2.0
      // В v7.2.0 метод signIn() заменен на authenticate()
      // Используем dynamic bypass если компилятор не видит новый метод в данной среде
      final dynamic googleUser = await (_googleSignIn as dynamic).authenticate();
      if (googleUser == null) return null;

      final dynamic googleAuth = await (googleUser as dynamic).authentication;
      
      final credential = GoogleAuthProvider.credential(
        accessToken: (googleAuth as dynamic).accessToken,
        idToken: (googleAuth as dynamic).idToken,
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

  static Future<String> startTelegramSession() async {
    return await TelegramBotService.startAuthSession();
  }

  static Stream<DocumentSnapshot<Map<String, dynamic>>> watchTelegramSession(String token) {
    return TelegramBotService.watchSession(token);
  }

  // ===================== UTILS =====================

  static Future<void> signOut() async {
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
