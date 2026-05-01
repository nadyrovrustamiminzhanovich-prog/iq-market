import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AdService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection reference
  static CollectionReference get _adsCollection => _db.collection('ads');

  /// Create a new advertisement in Firestore
  static Future<String?> createAd(Map<String, dynamic> adData) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final docRef = await _adsCollection.add({
        ...adData,
        'userId': user.uid,
        'userName': user.displayName ?? 'User',
        'userEmail': user.email ?? '',
        'timestamp': FieldValue.serverTimestamp(),
        'views': 0,
        'favorites': 0,
        'status': 'pending', // All new ads start as pending for review
        'active': true,
      });
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating ad: $e');
      return null;
    }
  }

  /// Get all active ads stream
  static Stream<QuerySnapshot> getActiveAdsStream() {
    return _adsCollection
        .where('active', isEqualTo: true)
        .where('status', isEqualTo: 'active')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  /// Get pending ads stream for admin review
  static Stream<QuerySnapshot> getPendingAdsStream() {
    return _adsCollection
        .where('status', isEqualTo: 'pending')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  /// Get ads for a specific user
  static Stream<QuerySnapshot> getMyAdsStream() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _adsCollection
        .where('userId', isEqualTo: user.uid)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  /// Update an existing ad
  static Future<void> updateAd(String adId, Map<String, dynamic> updates) async {
    try {
      await _adsCollection.doc(adId).update(updates);
    } catch (e) {
      debugPrint('Error updating ad: $e');
      rethrow;
    }
  }

  /// Delete an ad
  static Future<void> deleteAd(String adId) async {
    try {
      await _adsCollection.doc(adId).delete();
    } catch (e) {
      debugPrint('Error deleting ad: $e');
      rethrow;
    }
  }

  /// Toggle ad status (active/archived)
  static Future<void> toggleAdStatus(String adId, bool isActive) async {
    try {
      await _adsCollection.doc(adId).update({
        'active': isActive,
        'status': isActive ? 'active' : 'archived',
      });
    } catch (e) {
      debugPrint('Error toggling ad status: $e');
      rethrow;
    }
  }

  /// Approve an ad (for admin)
  static Future<void> approveAd(String adId) async {
    try {
      await _adsCollection.doc(adId).update({
        'status': 'active',
        'active': true,
      });
    } catch (e) {
      debugPrint('Error approving ad: $e');
      rethrow;
    }
  }
}
