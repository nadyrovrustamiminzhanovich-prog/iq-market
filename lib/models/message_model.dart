import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String id;
  final String senderId;
  final String text;
  final String type; // text, voice, image, offer
  final DateTime timestamp;
  final bool isRead;
  final String? mediaUrl;
  final int? duration;
  final String? offerPrice;
  final String? offerStatus; // pending, accepted, rejected

  MessageModel({
    required this.id,
    required this.senderId,
    required this.text,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.mediaUrl,
    this.duration,
    this.offerPrice,
    this.offerStatus,
  });

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'text': text,
      'type': type,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': isRead,
      'mediaUrl': mediaUrl,
      'duration': duration,
      'offerPrice': offerPrice,
      'offerStatus': offerStatus,
    };
  }

  factory MessageModel.fromMap(Map<String, dynamic> map, String id) {
    return MessageModel(
      id: id,
      senderId: map['senderId'] ?? '',
      text: map['text'] ?? '',
      type: map['type'] ?? 'text',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: map['isRead'] ?? false,
      mediaUrl: map['mediaUrl'],
      duration: map['duration'],
      offerPrice: map['offerPrice'],
      offerStatus: map['offerStatus'],
    );
  }
}

