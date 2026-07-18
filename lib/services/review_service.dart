import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:iqmarket/models/review_model.dart';
import 'package:iqmarket/services/notification_service.dart';

class ReviewService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Test hooks to override database operations
  static Future<void> Function(ReviewModel review)? mockAddReview;
  static Future<bool> Function(String userId, String adId)? mockHasUserReviewedAd;

  /// Add a new review
  static Future<void> addReview(ReviewModel review) async {
    if (mockAddReview != null) {
      await mockAddReview!(review);
      return;
    }
    await _db.collection('reviews').add(review.toMap());
    
    // Notify the seller
    NotificationService.saveNotificationToFirestore(
      uid: review.toUserId,
      title: 'Новый отзыв! ⭐️',
      body: '${review.fromUserName} оставил(а) отзыв на ваше объявление "${review.adTitle}"',
      type: 'review',
      data: {'adId': review.adId},
    ).catchError((e) {
      debugPrint('[REVIEW_SERVICE] addReview notification failed: $e');
    });
  }

  /// Get reviews for a specific user (seller)
  static Stream<List<ReviewModel>> getUserReviewsStream(String userId) {
    return _db
        .collection('reviews')
        .where('toUserId', isEqualTo: userId)
        .limit(50) // 🔒 Без limit: 500 отзывов = 500 Reads × 3 экрана × каждый просмотр
        .snapshots()
        .map((snapshot) {
          final reviews = snapshot.docs
            .map((doc) => ReviewModel.fromMap(doc.data(), doc.id))
            .toList();
          
          // Сортируем на стороне клиента, чтобы не зависеть от индексов Firestore
          reviews.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return reviews;
        });
  }

  /// Get reviews strictly for a specific Ad
  static Stream<List<ReviewModel>> getAdReviewsStream(String adId) {
    return _db
        .collection('reviews')
        .where('adId', isEqualTo: adId)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          final reviews = snapshot.docs
            .map((doc) => ReviewModel.fromMap(doc.data(), doc.id))
            .toList();
          
          reviews.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return reviews;
        });
  }


  /// Check if a user has already reviewed a specific ad
  static Future<bool> hasUserReviewedAd(String userId, String adId) async {
    if (mockHasUserReviewedAd != null) {
      return mockHasUserReviewedAd!(userId, adId);
    }
    final snapshot = await _db
        .collection('reviews')
        .where('fromUserId', isEqualTo: userId)
        .where('adId', isEqualTo: adId)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  /// Delete a review
  static Future<void> deleteReview(String reviewId, String toUserId, {String? reason}) async {
    await _db.collection('reviews').doc(reviewId).delete();
    
    if (reason != null) {
      NotificationService.saveNotificationToFirestore(
        uid: toUserId,
        title: 'Отзыв удален 🗑️',
        body: 'Один из ваших отзывов был удален модератором. Причина: $reason',
        type: 'ad_rejected',
      ).catchError((e) {
        debugPrint('[REVIEW_SERVICE] deleteReview notification failed: $e');
      });
    }
  }
}
