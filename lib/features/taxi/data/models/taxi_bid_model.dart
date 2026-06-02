import 'package:cloud_firestore/cloud_firestore.dart';

/// Тип ставки: на заказ пассажира или на поездку водителя.
enum TaxiBidTargetType { order, ride }

extension TaxiBidTargetTypeExt on TaxiBidTargetType {
  String get value => this == TaxiBidTargetType.order ? 'order' : 'ride';

  static TaxiBidTargetType fromString(String? value) {
    if (value == 'ride') return TaxiBidTargetType.ride;
    return TaxiBidTargetType.order;
  }
}

/// Статус ставки
enum TaxiBidStatus { pending, accepted, rejected }

extension TaxiBidStatusExt on TaxiBidStatus {
  String get value {
    switch (this) {
      case TaxiBidStatus.pending:
        return 'pending';
      case TaxiBidStatus.accepted:
        return 'accepted';
      case TaxiBidStatus.rejected:
        return 'rejected';
    }
  }

  static TaxiBidStatus fromString(String? value) {
    switch (value) {
      case 'accepted':
        return TaxiBidStatus.accepted;
      case 'rejected':
        return TaxiBidStatus.rejected;
      default:
        return TaxiBidStatus.pending;
    }
  }
}

/// Модель ставки (bid) в системе торгов такси.
/// Соответствует коллекции `taxi_bids` в Firestore.
class TaxiBidModel {
  final String id;

  // Цель ставки: к какому заказу/поездке она привязана
  final String targetId;
  final TaxiBidTargetType targetType;

  // Отправитель ставки
  final String senderId;
  final String senderName;
  final String senderImg;
  final String senderPhone;

  // Получатель ставки
  final String receiverId;

  // Предложенная цена
  final int offeredPrice;

  // Текущий статус ставки
  final TaxiBidStatus status;

  final DateTime? createdAt;

  const TaxiBidModel({
    required this.id,
    required this.targetId,
    required this.targetType,
    required this.senderId,
    required this.senderName,
    required this.senderImg,
    required this.senderPhone,
    required this.receiverId,
    required this.offeredPrice,
    required this.status,
    this.createdAt,
  });

  factory TaxiBidModel.fromMap(Map<String, dynamic> map) {
    DateTime? parsedDate;
    final raw = map['createdAt'];
    if (raw is Timestamp) {
      parsedDate = raw.toDate();
    } else if (raw is DateTime) {
      parsedDate = raw;
    }

    return TaxiBidModel(
      id: map['id']?.toString() ?? '',
      targetId: map['targetId']?.toString() ?? '',
      targetType: TaxiBidTargetTypeExt.fromString(map['targetType']?.toString()),
      senderId: map['senderId']?.toString() ?? '',
      senderName: map['senderName']?.toString() ?? 'Пользователь',
      senderImg: map['senderImg']?.toString() ?? '',
      senderPhone: map['senderPhone']?.toString() ?? '',
      receiverId: map['receiverId']?.toString() ?? '',
      offeredPrice: (map['offeredPrice'] as num?)?.toInt() ?? 0,
      status: TaxiBidStatusExt.fromString(map['status']?.toString()),
      createdAt: parsedDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'targetId': targetId,
      'targetType': targetType.value,
      'senderId': senderId,
      'senderName': senderName,
      'senderImg': senderImg,
      'senderPhone': senderPhone,
      'receiverId': receiverId,
      'offeredPrice': offeredPrice,
      'status': status.value,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  TaxiBidModel copyWith({
    String? id,
    String? targetId,
    TaxiBidTargetType? targetType,
    String? senderId,
    String? senderName,
    String? senderImg,
    String? senderPhone,
    String? receiverId,
    int? offeredPrice,
    TaxiBidStatus? status,
    DateTime? createdAt,
  }) {
    return TaxiBidModel(
      id: id ?? this.id,
      targetId: targetId ?? this.targetId,
      targetType: targetType ?? this.targetType,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderImg: senderImg ?? this.senderImg,
      senderPhone: senderPhone ?? this.senderPhone,
      receiverId: receiverId ?? this.receiverId,
      offeredPrice: offeredPrice ?? this.offeredPrice,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get isPending => status == TaxiBidStatus.pending;
  bool get isAccepted => status == TaxiBidStatus.accepted;
  bool get isRejected => status == TaxiBidStatus.rejected;
}
