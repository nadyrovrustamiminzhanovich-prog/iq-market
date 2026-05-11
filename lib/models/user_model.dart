import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String photoUrl;
  final String accountType;
  final bool isVerified;
  final DateTime registrationDate;
  final int reviewsCount;
  final double rating;
  final String location;
  final String status; // 'active' or 'banned'

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.photoUrl,
    required this.accountType,
    this.isVerified = false,
    required this.registrationDate,
    this.reviewsCount = 0,
    this.rating = 5.0,
    this.location = 'Чунджа',
    this.status = 'active',
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      uid: id,
      name: map['name'] ?? 'Пользователь',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      photoUrl: map['photoUrl'] ?? '',
      accountType: map['accountType'] ?? 'Личный',
      isVerified: map['isVerified'] ?? false,
      registrationDate: (map['registrationDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reviewsCount: map['reviewsCount'] ?? 0,
      rating: (map['rating'] as num?)?.toDouble() ?? 5.0,
      location: map['location'] ?? 'Чунджа',
      status: map['status'] ?? 'active',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'photoUrl': photoUrl,
      'accountType': accountType,
      'isVerified': isVerified,
      'registrationDate': registrationDate,
      'reviewsCount': reviewsCount,
      'rating': rating,
      'location': location,
      'status': status,
    };
  }
}
