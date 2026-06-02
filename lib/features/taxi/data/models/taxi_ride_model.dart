import 'package:cloud_firestore/cloud_firestore.dart';

/// Модель поездки водителя в такси-сервисе.
/// Соответствует коллекции `taxi_rides` в Firestore.
class TaxiRideModel {
  final String id;
  final String driverId;
  final String driverName;
  final String driverPhone;
  final String driverCar;
  final String driverPlate;
  final String driverImg;
  final bool driverVerified;
  final String from;
  final String to;
  final String date;
  final String time;
  final int seats;
  final int price;
  final String comment;
  final String status; // 'active' | 'accepted' | 'completed' | 'cancelled'
  final DateTime? createdAt;

  // Поля, появляющиеся после принятия пассажира
  final String? passengerId;
  final String? passengerName;
  final String? passengerPhone;
  final String? passengerImg;

  const TaxiRideModel({
    required this.id,
    required this.driverId,
    required this.driverName,
    required this.driverPhone,
    required this.driverCar,
    required this.driverPlate,
    required this.driverImg,
    required this.driverVerified,
    required this.from,
    required this.to,
    required this.date,
    required this.time,
    required this.seats,
    required this.price,
    required this.comment,
    required this.status,
    this.createdAt,
    this.passengerId,
    this.passengerName,
    this.passengerPhone,
    this.passengerImg,
  });

  factory TaxiRideModel.fromMap(Map<String, dynamic> map) {
    DateTime? parsedDate;
    final raw = map['createdAt'];
    if (raw is Timestamp) {
      parsedDate = raw.toDate();
    } else if (raw is DateTime) {
      parsedDate = raw;
    }

    return TaxiRideModel(
      id: map['id']?.toString() ?? '',
      driverId: map['driverId']?.toString() ?? '',
      driverName: map['driverName']?.toString() ?? 'Водитель',
      driverPhone: map['driverPhone']?.toString() ?? '',
      driverCar: map['driverCar']?.toString() ?? '',
      driverPlate: map['driverPlate']?.toString() ?? '',
      driverImg: map['driverImg']?.toString() ?? '',
      driverVerified: map['driverVerified'] as bool? ?? false,
      from: map['from']?.toString() ?? '',
      to: map['to']?.toString() ?? '',
      date: map['date']?.toString() ?? '',
      time: map['time']?.toString() ?? '',
      seats: (map['seats'] as num?)?.toInt() ?? 1,
      price: (map['price'] as num?)?.toInt() ?? 0,
      comment: map['comment']?.toString() ?? '',
      status: map['status']?.toString() ?? 'active',
      createdAt: parsedDate,
      passengerId: map['passengerId']?.toString(),
      passengerName: map['passengerName']?.toString(),
      passengerPhone: map['passengerPhone']?.toString(),
      passengerImg: map['passengerImg']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'driverId': driverId,
      'driverName': driverName,
      'driverPhone': driverPhone,
      'driverCar': driverCar,
      'driverPlate': driverPlate,
      'driverImg': driverImg,
      'driverVerified': driverVerified,
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
      if (passengerId != null) 'passengerId': passengerId,
      if (passengerName != null) 'passengerName': passengerName,
      if (passengerPhone != null) 'passengerPhone': passengerPhone,
      if (passengerImg != null) 'passengerImg': passengerImg,
    };
  }

  TaxiRideModel copyWith({
    String? id,
    String? driverId,
    String? driverName,
    String? driverPhone,
    String? driverCar,
    String? driverPlate,
    String? driverImg,
    bool? driverVerified,
    String? from,
    String? to,
    String? date,
    String? time,
    int? seats,
    int? price,
    String? comment,
    String? status,
    DateTime? createdAt,
    String? passengerId,
    String? passengerName,
    String? passengerPhone,
    String? passengerImg,
  }) {
    return TaxiRideModel(
      id: id ?? this.id,
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      driverPhone: driverPhone ?? this.driverPhone,
      driverCar: driverCar ?? this.driverCar,
      driverPlate: driverPlate ?? this.driverPlate,
      driverImg: driverImg ?? this.driverImg,
      driverVerified: driverVerified ?? this.driverVerified,
      from: from ?? this.from,
      to: to ?? this.to,
      date: date ?? this.date,
      time: time ?? this.time,
      seats: seats ?? this.seats,
      price: price ?? this.price,
      comment: comment ?? this.comment,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      passengerId: passengerId ?? this.passengerId,
      passengerName: passengerName ?? this.passengerName,
      passengerPhone: passengerPhone ?? this.passengerPhone,
      passengerImg: passengerImg ?? this.passengerImg,
    );
  }

  bool get isActive => status == 'active';
  bool get isAccepted => status == 'accepted';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
}
