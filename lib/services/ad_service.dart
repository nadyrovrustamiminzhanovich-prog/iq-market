import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:iqmarket/models/ad_model.dart';
import 'package:iqmarket/services/file_service.dart';

class AdService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static CollectionReference get _adsCollection => _db.collection('ads');

  /// Create a new advertisement in Firestore
  static Future<String?> createAd(AdModel ad) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final docRef = await _adsCollection.add(ad.toMap());
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating ad: $e');
      return null;
    }
  }

  /// Get all active ads stream (Optimized to NOT require composite indices for now)
  static Stream<List<AdModel>> getActiveAdsStream() {
    return _adsCollection
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AdModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .where((ad) => ad.active && ad.status == 'active')
            .toList());
  }

  /// Get active ads paginated for infinite scroll
  static Future<Map<String, dynamic>> getActiveAdsPaginated({DocumentSnapshot? startAfter, int limit = 20}) async {
    try {
      // NOTE: This query requires a Composite Index in Firestore: 
      // Collection: ads | Fields: active (Asc), status (Asc), timestamp (Desc)
      Query query = _adsCollection
          .where('active', isEqualTo: true)
          .where('status', isEqualTo: 'active')
          .orderBy('timestamp', descending: true)
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      final ads = snapshot.docs
          .map((doc) => AdModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
      
      return {
        'ads': ads,
        'lastDocument': snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      };
    } catch (e) {
      debugPrint('Error fetching paginated ads: $e');
      rethrow;
    }
  }

  /// Get pending ads stream for admin review
  static Stream<List<AdModel>> getPendingAdsStream() {
    return _adsCollection
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AdModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .where((ad) => ad.status == 'pending')
            .toList());
  }

  /// Get ads for a specific user
  static Stream<List<AdModel>> getAdsByUserStream(String userId) {
    return _adsCollection
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AdModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .where((ad) => ad.userId == userId && ad.active)
            .toList());
  }

  /// Get current user ads
  static Stream<List<AdModel>> getMyAdsStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);
    return getAdsByUserStream(user.uid);
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

  /// Delete an ad and its associated files
  static Future<void> deleteAd(String adId) async {
    try {
      final doc = await _adsCollection.doc(adId).get();
      if (doc.exists) {
        final ad = AdModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        if (ad.images.isNotEmpty) await FileService.deleteMultipleFiles(ad.images);
        if (ad.videoUrl != null && ad.videoUrl!.isNotEmpty) await FileService.deleteFile(ad.videoUrl!);
      }
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

  /// Extend ad duration by 30 days
  static Future<void> extendAd(String adId) async {
    try {
      await _adsCollection.doc(adId).update({
        'active': true,
        'status': 'active',
        'expiresAt': FieldValue.serverTimestamp(), // Firestore will update this, then we use a Cloud Function, OR we can set exact date:
        // Actually, FieldValue.serverTimestamp doesn't add 30 days. We pass Date directly.
        'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
        'notifiedExpiry': false, // Reset notification flag
      });
    } catch (e) {
      debugPrint('Error extending ad: $e');
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

  /// Get recommended ads
  static Stream<List<AdModel>> getRecommendationsStream() {
    return _adsCollection
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AdModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .where((ad) => ad.active && ad.status == 'active')
            .take(10)
            .toList());
  }

  /// Search ads by query
  static Future<List<AdModel>> searchAds(String query) async {
    final snapshot = await _adsCollection.get();
    return snapshot.docs
        .map((doc) => AdModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .where((ad) => ad.active && ad.status == 'active' && 
               (ad.title.toLowerCase().contains(query.toLowerCase()) || 
                ad.description.toLowerCase().contains(query.toLowerCase())))
        .toList();
  }

  /// Get similar ads by category
  static Stream<List<AdModel>> getSimilarAdsStream(String category, String currentAdId) {
    return _adsCollection
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AdModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .where((ad) => ad.category == category && ad.active && ad.id != currentAdId)
            .take(6)
            .toList());
  }

  /// Get multiple ads by their IDs
  static Future<List<AdModel>> getAdsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    try {
      List<AdModel> allAds = [];
      for (var i = 0; i < ids.length; i += 10) {
        final end = (i + 10 < ids.length) ? i + 10 : ids.length;
        final chunk = ids.sublist(i, end);
        final snapshot = await _adsCollection.where(FieldPath.documentId, whereIn: chunk).get();
        allAds.addAll(snapshot.docs.map((doc) => AdModel.fromMap(doc.data() as Map<String, dynamic>, doc.id)));
      }
      return allAds;
    } catch (e) {
      debugPrint('Error fetching ads by IDs: $e');
      return [];
    }
  }
}
