import 'package:cloud_firestore/cloud_firestore.dart';

/// Модель заказа пассажира в такси-сервисе.
/// Соответствует коллекции `taxi_orders` в Firestore.
class TaxiOrderModel {
  final String id;
  final String passengerId;
  final String passengerName;
  final String passengerPhone;
  final String passengerImg;
  final String from;
  final String to;
  final String date;
  final String time;
  final int seats;
  final int price;
  final String comment;
  final String status; // 'active' | 'accepted' | 'completed' | 'cancelled'
  final DateTime? createdAt;

  // Поля, появляющиеся после принятия заказа водителем
  final String? driverId;
  final String? driverName;
  final String? driverPhone;
  final String? driverCar;
  final String? driverPlate;
  final String? driverImg;
  final bool? driverVerified;

  const TaxiOrderModel({
    required this.id,
    required this.passengerId,
    required this.passengerName,
    required this.passengerPhone,
    required this.passengerImg,
    required this.from,
    required this.to,
    required this.date,
    required this.time,
    required this.seats,
    required this.price,
    required this.comment,
    required this.status,
    this.createdAt,
    this.driverId,
    this.driverName,
    this.driverPhone,
    this.driverCar,
    this.driverPlate,
    this.driverImg,
    this.driverVerified,
  });

  factory TaxiOrderModel.fromMap(Map<String, dynamic> map) {
    DateTime? parsedDate;
    final raw = map['createdAt'];
    if (raw is Timestamp) {
      parsedDate = raw.toDate();
    } else if (raw is DateTime) {
      parsedDate = raw;
    }

    return TaxiOrderModel(
      id: map['id']?.toString() ?? '',
      passengerId: map['passengerId']?.toString() ?? '',
      passengerName: map['passengerName']?.toString() ?? 'Пассажир',
      passengerPhone: map['passengerPhone']?.toString() ?? '',
      passengerImg: map['passengerImg']?.toString() ?? '',
      from: map['from']?.toString() ?? '',
      to: map['to']?.toString() ?? '',
      date: map['date']?.toString() ?? '',
      time: map['time']?.toString() ?? '',
      seats: (map['seats'] as num?)?.toInt() ?? 1,
      price: (map['price'] as num?)?.toInt() ?? 0,
      comment: map['comment']?.toString() ?? '',
      status: map['status']?.toString() ?? 'active',
      createdAt: parsedDate,
      driverId: map['driverId']?.toString(),
      driverName: map['driverName']?.toString(),
      driverPhone: map['driverPhone']?.toString(),
      driverCar: map['driverCar']?.toString(),
      driverPlate: map['driverPlate']?.toString(),
      driverImg: map['driverImg']?.toString(),
      driverVerified: map['driverVerified'] as bool?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'passengerId': passengerId,
      'passengerName': passengerName,
      'passengerPhone': passengerPhone,
      'passengerImg': passengerImg,
      'from': from,
      'to': to,
      'date': date,
      'time': time,
      'seats': seats,
      'price': price,
      'comment': comment,
      'status': status,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      if (driverId != null) 'driverId': driverId,
      if (driverName != null) 'driverName': driverName,
      if (driverPhone != null) 'driverPhone': driverPhone,
      if (driverCar != null) 'driverCar': driverCar,
      if (driverPlate != null) 'driverPlate': driverPlate,
      if (driverImg != null) 'driverImg': driverImg,
      if (driverVerified != null) 'driverVerified': driverVerified,
    };
  }

  TaxiOrderModel copyWith({
    String? id,
    String? passengerId,
    String? passengerName,
    String? passengerPhone,
    String? passengerImg,
    String? from,
    String? to,
    String? date,
    String? time,
    int? seats,
    int? price,
    String? comment,
    String? status,
    DateTime? createdAt,
    String? driverId,
    String? driverName,
    String? driverPhone,
    String? driverCar,
    String? driverPlate,
    String? driverImg,
    bool? driverVerified,
  }) {
    return TaxiOrderModel(
      id: id ?? this.id,
      passengerId: passengerId ?? this.passengerId,
      passengerName: passengerName ?? this.passengerName,
      passengerPhone: passengerPhone ?? this.passengerPhone,
      passengerImg: passengerImg ?? this.passengerImg,
      from: from ?? this.from,
      to: to ?? this.to,
      date: date ?? this.date,
      time: time ?? this.time,
      seats: seats ?? this.seats,
      price: price ?? this.price,
      comment: comment ?? this.comment,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      driverPhone: driverPhone ?? this.driverPhone,
      driverCar: driverCar ?? this.driverCar,
      driverPlate: driverPlate ?? this.driverPlate,
      driverImg: driverImg ?? this.driverImg,
      driverVerified: driverVerified ?? this.driverVerified,
    );
  }

  /// Является ли заказ активным (ожидает водителя)
  bool get isActive => status == 'active';

  /// Заказ принят водителем
  bool get isAccepted => status == 'accepted';

  /// Поездка завершена
  bool get isCompleted => status == 'completed';

  /// Поездка отменена
  bool get isCancelled => status == 'cancelled';
}
