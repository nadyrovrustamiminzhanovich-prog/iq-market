import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:iqmarket/models/user_model.dart';

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
    String? accountType,
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
          'accountType': accountType ?? 'Личный', // Default account type
          'isVerified': isVerified,
          'registrationDate': FieldValue.serverTimestamp(),
          'reviewsCount': 0,
          'rating': 5.0,
        });
      } else {
        // Update existing user profile
        Map<String, dynamic> updates = {};
        if (photoUrl != null && photoUrl.isNotEmpty) updates['photoUrl'] = photoUrl;
        if (email != null && email.isNotEmpty) updates['email'] = email;
        if (isVerified) updates['isVerified'] = true;
        if (accountType != null) updates['accountType'] = accountType;
        
        if (updates.isNotEmpty) {
          await docRef.update(updates);
        }
      }
    } catch (e) {
      debugPrint('Error syncing user to Firestore: $e');
    }
  }

  /// Get user data stream for real-time updates in UI
  static Stream<UserModel?> getUserStream() {
    final uid = currentUid;
    if (uid == null) {
      return Stream.value(null);
    }
    return users.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    });
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

  /// Get all users (Admin only)
  static Stream<List<UserModel>> getAllUsersStream() {
    return users.orderBy('registrationDate', descending: true).snapshots().map((snapshot) => 
      snapshot.docs.map((doc) => UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList()
    );
  }

  /// Admin: Toggle user verification status
  static Future<void> toggleUserVerification(String uid, bool isVerified) async {
    try {
      await users.doc(uid).update({'isVerified': isVerified});
    } catch (e) {
      debugPrint('Error toggling user verification: $e');
    }
  }

  /// Admin: Toggle user ban status
  static Future<void> toggleUserBan(String uid, bool isBanned) async {
    try {
      await users.doc(uid).update({'status': isBanned ? 'banned' : 'active'});
    } catch (e) {
      debugPrint('Error toggling user ban: $e');
    }
  }

  /// Admin: Toggle Admin role
  static Future<void> toggleUserAdmin(String uid, bool isAdmin) async {
    try {
      await users.doc(uid).update({'accountType': isAdmin ? 'admin' : 'Личный'});
    } catch (e) {
      debugPrint('Error toggling admin role: $e');
    }
  }


  /// Get user by ID (for seller info)
  static Future<UserModel?> getUserById(String uid) async {
    try {
      final doc = await users.doc(uid).get();
      if (!doc.exists) return null;
      return UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    } catch (e) {
      debugPrint('Error getting user by id: $e');
      return null;
    }
  }
}
