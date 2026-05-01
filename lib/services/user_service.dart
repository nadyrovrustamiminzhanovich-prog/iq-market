import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class UserService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection reference
  static CollectionReference get users => _db.collection('users');

  /// Check if the user is authenticated
  static bool get isLoggedIn => _auth.currentUser != null;
  static String? get currentUid => _auth.currentUser?.uid;

  /// Creates or updates a user document in Firestore after login/registration
  static Future<void> syncUserAfterLogin({
    required String name,
    String? email,
    String? photoUrl,
    String? phone,
    bool isVerified = false,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final docRef = users.doc(user.uid);
      final docSnap = await docRef.get();

      if (!docSnap.exists) {
        // Create new user profile
        await docRef.set({
          'uid': user.uid,
          'name': name,
          'email': email ?? user.email ?? '',
          'phone': phone ?? user.phoneNumber ?? '',
          'photoUrl': photoUrl ?? user.photoURL ?? '',
          'accountType': 'Личный', // Default account type
          'isVerified': isVerified,
          'registrationDate': FieldValue.serverTimestamp(),
          'reviewsCount': 0,
          'rating': 5.0,
        });
      } else {
        // Update existing user profile with fresh data from provider (e.g., Google/Apple)
        // We only update non-destructive fields to not overwrite user edits
        Map<String, dynamic> updates = {};
        if (photoUrl != null && photoUrl.isNotEmpty) updates['photoUrl'] = photoUrl;
        if (email != null && email.isNotEmpty) updates['email'] = email;
        if (updates.isNotEmpty) {
          await docRef.update(updates);
        }
      }
    } catch (e) {
      debugPrint('Error syncing user to Firestore: $e');
    }
  }

  /// Get user data stream for real-time updates in UI
  static Stream<DocumentSnapshot> getUserStream() {
    final uid = currentUid;
    if (uid == null) {
      return const Stream.empty();
    }
    return users.doc(uid).snapshots();
  }

  /// Update specific fields in user profile
  static Future<void> updateUserProfile(Map<String, dynamic> data) async {
    final uid = currentUid;
    if (uid == null) return;
    
    try {
      await users.doc(uid).update(data);
    } catch (e) {
      debugPrint('Error updating user profile: $e');
      rethrow;
    }
  }
}
