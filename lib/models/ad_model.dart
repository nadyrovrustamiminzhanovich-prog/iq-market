import 'package:cloud_firestore/cloud_firestore.dart';

class AdModel {
  final String id;
  final String title;
  final String description;
  final double price;
  final String category;
  final List<String> images;
  final String? videoUrl;
  final int? videoDurationSeconds;
  final String userId;
  final String userName;
  final String userEmail;
  final DateTime timestamp;
  final int views;
  final int favoritesCount;
  final String status;
  final bool active;
  final String location;
  final String? userPhone;
  final bool isBargainAllowed;
  final String? condition;
  final bool canExchange;
  final bool hasDelivery;
  final Map<String, dynamic>? extraFields;
  final DateTime? expiresAt;
  final bool notifiedExpiry;
  final String? oldPrice;
  final bool multiAccountSuspected;
  final String? rejectionReason;


  AdModel({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.category,
    required this.images,
    this.videoUrl,
    this.videoDurationSeconds,
    required this.userId,
    required this.userName,
    required this.userEmail,
    this.userPhone,
    required this.timestamp,
    this.views = 0,
    this.favoritesCount = 0,
    this.status = 'active',
    this.active = true,
    this.location = '',
    this.isBargainAllowed = false,
    this.condition,
    this.canExchange = false,
    this.hasDelivery = false,
    this.extraFields,
    this.expiresAt,
    this.notifiedExpiry = false,
    this.oldPrice,
    this.multiAccountSuspected = false,
    this.rejectionReason,
  });


  // Превращаем Map из Firebase в объект AdModel (Безопасно!)
  factory AdModel.fromMap(Map<String, dynamic> map, String docId) {
    return AdModel(
      id: docId,
      title: map['title'] ?? 'Без названия',
      description: map['description'] ?? '',
      price: double.tryParse(map['price'].toString().replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0,
      category: map['category'] ?? 'Другое',
      images: (map['images'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      videoUrl: map['video_url'],
      videoDurationSeconds: map['videoDurationSeconds'] is int ? map['videoDurationSeconds'] as int : null,
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? 'Пользователь',
      userEmail: map['userEmail'] ?? '',
      userPhone: map['userPhone'],
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      views: map['views'] ?? 0,
      favoritesCount: map['favorites'] ?? 0,
      status: map['status'] ?? 'active',
      active: map['active'] ?? true,
      location: map['location'] ?? '',
      isBargainAllowed: map['isBargainAllowed'] ?? false,
      condition: map['condition'],
      canExchange: map['canExchange'] ?? false,
      hasDelivery: map['hasDelivery'] ?? false,
      extraFields: map['extraFields'] != null ? Map<String, dynamic>.from(map['extraFields'] as Map) : null,
      expiresAt: (map['expiresAt'] as Timestamp?)?.toDate(),
      notifiedExpiry: map['notifiedExpiry'] ?? false,
      oldPrice: map['oldPrice'],
      multiAccountSuspected: map['multiAccountSuspected'] ?? false,
      rejectionReason: map['rejectionReason'],
    );

  }

  // Превращаем объект обратно в Map для сохранения в Firebase
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'price': price,
      'category': category,
      'images': images,
      'video_url': videoUrl,
      'videoDurationSeconds': videoDurationSeconds,
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'userPhone': userPhone,
      'timestamp': FieldValue.serverTimestamp(),
      'views': views,
      'favorites': favoritesCount,
      'status': status,
      'active': active,
      'location': location,
      'isBargainAllowed': isBargainAllowed,
      'condition': condition,
      'canExchange': canExchange,
      'hasDelivery': hasDelivery,
      'extraFields': extraFields,
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
      'notifiedExpiry': notifiedExpiry,
      'oldPrice': oldPrice,
      'multiAccountSuspected': multiAccountSuspected,
    };
  }

  /// Сериализация в чистый JSON Map для локального кэширования (диск/память)
  Map<String, dynamic> toJsonMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'price': price,
      'category': category,
      'images': images,
      'video_url': videoUrl,
      'videoDurationSeconds': videoDurationSeconds,
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'userPhone': userPhone,
      'timestamp': timestamp.toIso8601String(),
      'views': views,
      'favorites': favoritesCount,
      'status': status,
      'active': active,
      'location': location,
      'isBargainAllowed': isBargainAllowed,
      'condition': condition,
      'canExchange': canExchange,
      'hasDelivery': hasDelivery,
      'extraFields': extraFields,
      'expiresAt': expiresAt?.toIso8601String(),
      'notifiedExpiry': notifiedExpiry,
      'oldPrice': oldPrice,
      'multiAccountSuspected': multiAccountSuspected,
      'rejectionReason': rejectionReason,
    };
  }

  /// Десериализация из чистого JSON Map локального кэша
  factory AdModel.fromJsonMap(Map<String, dynamic> json) {
    return AdModel(
      id: json['id'] ?? '',
      title: json['title'] ?? 'Без названия',
      description: json['description'] ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      category: json['category'] ?? 'Другое',
      images: (json['images'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      videoUrl: json['video_url'],
      videoDurationSeconds: json['videoDurationSeconds'] is int ? json['videoDurationSeconds'] as int : null,
      userId: json['userId'] ?? '',
      userName: json['userName'] ?? 'Пользователь',
      userEmail: json['userEmail'] ?? '',
      userPhone: json['userPhone'],
      timestamp: json['timestamp'] != null
          ? (DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now())
          : DateTime.now(),
      views: (json['views'] as num?)?.toInt() ?? 0,
      favoritesCount: (json['favorites'] as num?)?.toInt() ?? 0,
      status: json['status'] ?? 'active',
      active: json['active'] ?? true,
      location: json['location'] ?? '',
      isBargainAllowed: json['isBargainAllowed'] ?? false,
      condition: json['condition'],
      canExchange: json['canExchange'] ?? false,
      hasDelivery: json['hasDelivery'] ?? false,
      extraFields: json['extraFields'] != null ? Map<String, dynamic>.from(json['extraFields'] as Map) : null,
      expiresAt: json['expiresAt'] != null ? DateTime.tryParse(json['expiresAt'].toString()) : null,
      notifiedExpiry: json['notifiedExpiry'] ?? false,
      oldPrice: json['oldPrice'],
      multiAccountSuspected: json['multiAccountSuspected'] ?? false,
      rejectionReason: json['rejectionReason'],
    );
  }
}
