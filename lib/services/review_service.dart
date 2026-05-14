import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:iqmarket/models/review_model.dart';
import 'package:iqmarket/services/notification_service.dart';

class ReviewService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Add a new review
  static Future<void> addReview(ReviewModel review) async {
    await _db.collection('reviews').add(review.toMap());
    
    // Update user average rating
    await _updateUserRating(review.toUserId);
  }

  /// Get reviews for a specific user (seller)
  static Stream<List<ReviewModel>> getUserReviewsStream(String userId) {
    return _db
        .collection('reviews')
        .where('toUserId', isEqualTo: userId)
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


  /// Check if a user has already reviewed a specific ad
  static Future<bool> hasUserReviewedAd(String userId, String adId) async {
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
      );
    }

    // Пересчитываем рейтинг пользователя после удаления
    await _updateUserRating(toUserId);
  }

  /// Private helper to update the aggregate rating of a user

  static Future<void> _updateUserRating(String userId) async {

    final snapshot = await _db
        .collection('reviews')
        .where('toUserId', isEqualTo: userId)
        .get();
    
    int count = snapshot.docs.length;
    double avgRating = 0;
    
    if (count >= 5) {
      double totalRating = 0;
      for (var doc in snapshot.docs) {
        totalRating += (doc.data()['rating'] ?? 0).toDouble();
      }
      avgRating = totalRating / count;
    }

    await _db.collection('users').doc(userId).set({
      'rating': avgRating,
      'reviewsCount': count,
    }, SetOptions(merge: true));

  }
}
