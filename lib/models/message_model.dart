import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String id;
  final String senderId;
  final String text;
  final String type; // text, voice, image, offer, system
  final DateTime timestamp;
  final bool isRead;
  final bool isDelivered; // ✅ WhatsApp-style: доставлено получателю
  final String? mediaUrl;
  final int? duration;
  final String? offerPrice;
  final String? offerStatus; // pending, accepted, rejected, cancelled
  // id документа offers/{offerId} — источника истины по предложению.
  // null у офферов, созданных до перехода на серверную обработку: для них
  // сервер поднимает документ из самого сообщения (chatId + messageId).
  final String? offerId;
  // Ключ системного сообщения (offer_accepted / offer_rejected). Текст в поле
  // text — русский фолбэк для пуша; в ленте рендерится перевод по ключу, иначе
  // сообщение навсегда останется на языке отправителя.
  final String? systemKey;
  // true, если аплоад медиа (фото/голосовое) окончательно не удался после всех
  // повторов — персистентный (переживает перезапуск приложения) флаг, чтобы
  // UI мог показать "нажмите, чтобы повторить" вместо вечного спиннера.
  final bool uploadFailed;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.text,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.isDelivered = false,
    this.mediaUrl,
    this.duration,
    this.offerPrice,
    this.offerStatus,
    this.offerId,
    this.systemKey,
    this.uploadFailed = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'text': text,
      'type': type,
      'timestamp': Timestamp.now(),
      'isRead': isRead,
      'isDelivered': isDelivered,
      'mediaUrl': mediaUrl,
      'duration': duration,
      'offerPrice': offerPrice,
      'offerStatus': offerStatus,
      'offerId': offerId,
      'systemKey': systemKey,
      'uploadFailed': uploadFailed,
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
      isDelivered: map['isDelivered'] ?? map['isRead'] ?? false, // fallback: если прочитано — значит доставлено
      mediaUrl: map['mediaUrl'],
      duration: map['duration'],
      offerPrice: map['offerPrice']?.toString(),
      offerStatus: map['offerStatus'],
      offerId: map['offerId'],
      systemKey: map['systemKey'],
      uploadFailed: map['uploadFailed'] ?? false,
    );
  }
}

