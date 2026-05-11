import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewModel {
  final String id;
  final String adId;
  final String adTitle;
  final String fromUserId;
  final String fromUserName;
  final String toUserId;
  final double rating;
  final String comment;
  final List<String> images;
  final DateTime timestamp;

  ReviewModel({
    required this.id,
    required this.adId,
    required this.adTitle,
    required this.fromUserId,
    required this.fromUserName,
    required this.toUserId,
    required this.rating,
    required this.comment,
    required this.images,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'adId': adId,
      'adTitle': adTitle,
      'fromUserId': fromUserId,
      'fromUserName': fromUserName,
      'toUserId': toUserId,
      'rating': rating,
      'comment': comment,
      'images': images,
      'timestamp': timestamp,
    };
  }

  factory ReviewModel.fromMap(Map<String, dynamic> map, String id) {
    return ReviewModel(
      id: id,
      adId: map['adId'] ?? '',
      adTitle: map['adTitle'] ?? '',
      fromUserId: map['fromUserId'] ?? '',
      fromUserName: map['fromUserName'] ?? '',
      toUserId: map['toUserId'] ?? '',
      rating: (map['rating'] ?? 0).toDouble(),
      comment: map['comment'] ?? '',
      images: List<String>.from(map['images'] ?? []),
      timestamp: (map['timestamp'] as Timestamp).toDate(),
    );
  }
}
