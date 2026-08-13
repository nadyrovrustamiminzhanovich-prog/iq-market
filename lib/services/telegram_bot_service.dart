import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:iqmarket/services/api_keys.dart';

class TelegramBotService {
  // ─── BOT CONFIG ─────────────────────────────────────────────────────────────
  static const String _botUsername = 'IQ_Taxi_bot'; // YOUR BOT @username
  // Replace with your own Telegram chat_id (get it from @userinfobot)
  static const String _adminChatId = '1910159480';

  static Future<String> _getAdminChatId() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('settings').doc('telegram').get();
      final data = doc.data();
      if (data != null && data['adminChatId'] != null) {
        final idStr = data['adminChatId'].toString().trim();
        if (idStr.isNotEmpty) return idStr;
      }
    } catch (e) {
      debugPrint('[TelegramBotService._getAdminChatId] Error: $e');
    }
    return _adminChatId;
  }

  // ─── HELPERS ────────────────────────────────────────────────────────────────
  static String _randomAlnum(int len) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rand = Random.secure();
    return List.generate(len, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  static String generateOtp() {
    final rand = Random.secure();
    return List.generate(6, (_) => rand.nextInt(10)).join();
  }

  // ─── STEP 1: Create Firebase session (without opening bot) ─────────────────────
  /// Returns sessionToken. Call [buildBotUrl] to get the deep-link, then open
  /// it at the right moment (e.g., after a countdown in the UI).
  static Future<String> startAuthSession({String? phone}) async {
    try {
      final token = _randomAlnum(24);
      final currentUser = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance
          .collection('tg_auth_sessions')
          .doc(token)
          .set({
        'created_at': FieldValue.serverTimestamp(),
        'verified': false,
        'chat_id': null,
        'otp': null,
        if (phone != null) 'phone': phone,
        if (currentUser != null) 'initiatorUid': currentUser.uid,
      });
      // Brief pause to ensure Firestore is synced before the bot reads it
      await Future.delayed(const Duration(milliseconds: 800));
      return token;
    } catch (e) {
      debugPrint('[TelegramBotService.startAuthSession] Error starting auth session: $e');
      rethrow;
    }
  }

  // ─── Build the Telegram deep-link URL for a session token ───────────────────
  static String buildBotUrl(String token) {
    return 'https://t.me/$_botUsername?start=$token';
  }

  // ─── STEP 2: Poll Firestore until bot assigns chat_id ───────────────────────
  static Stream<DocumentSnapshot<Map<String, dynamic>>> watchSession(
      String token) {
    return FirebaseFirestore.instance
        .collection('tg_auth_sessions')
        .doc(token)
        .snapshots();
  }

  // ─── STEP 3: Send OTP to the captured chat_id ───────────────────────────────
  static Future<bool> sendOtp(String chatId, String otp) async {
    // Also write OTP to Firestore for server-side verification if needed
    final text = '🔐 *Ваш код для входа в IQ-Market:*\n\n'
        '`$otp`\n\n'
        '_Код действителен 5 минут. Никому не сообщайте!_';
    return _send(chatId, text);
  }

  // ─── LEGACY: backward-compat sendOtp(phone, code, chatId) ───────────────────
  static Future<bool> sendOtpLegacy(
      String phone, String code, String chatId) async {
    return sendOtp(chatId, code);
  }

  // ─── DRIVER VERIFICATION: notify admin ──────────────────────────────────────
  static Future<void> notifyAdminManualReview({
    required String driverName,
    required String plate,
    required String carModel,
    required String driverChatId,
    required String reviewDocId,
    String reason = 'Фото тусклое или нечёткое',
    String? licF,
    String? licB,
    String? techF,
    String? techB,
    String? selfie,
    String? carFront,
  }) async {
    final adminId = await _getAdminChatId();
    if (adminId.isEmpty || adminId == '5555555555') return;
    
    final StringBuffer sb = StringBuffer();
    sb.writeln('🔍 <b>Требуется ручная проверка водителя!</b>');
    sb.writeln();
    sb.writeln('👤 Имя: <b>$driverName</b>');
    sb.writeln('🚗 Авто: $carModel');
    sb.writeln('🔢 Госномер: <code>$plate</code>');
    sb.writeln('⚠️ Причина: $reason');
    
    if (licF != null || licB != null || techF != null || techB != null || selfie != null || carFront != null) {
      sb.writeln();
      sb.writeln('📂 <b>ДОКУМЕНТЫ И АВТО:</b>');
      if (licF != null) sb.writeln('🪪 <a href="$licF">Права (Лицевая)</a>');
      if (licB != null) sb.writeln('🪪 <a href="$licB">Права (Обратная)</a>');
      if (techF != null) sb.writeln('📄 <a href="$techF">Техпаспорт (Лицевая)</a>');
      if (techB != null) sb.writeln('📄 <a href="$techB">Техпаспорт (Обратная)</a>');
      if (selfie != null) sb.writeln('🤳 <a href="$selfie">Фото селфи</a>');
      if (carFront != null) sb.writeln('🚘 <a href="$carFront">Фото машины</a>');
    }
    
    sb.writeln();
    sb.writeln('Используйте панель: /approve_$reviewDocId или /reject_$reviewDocId');

    await _sendWithKeyboard(
      adminId,
      sb.toString(),
      keyboard: [
        [
          {'text': '✅ Одобрить', 'callback_data': 'approve|$reviewDocId|$driverChatId'},
          {'text': '❌ Отклонить', 'callback_data': 'reject|$reviewDocId|$driverChatId'},
        ]
      ],
    );
  }

  // ─── AD MODERATION: notify admin of new ad requiring manual review ─────────
  static Future<void> notifyAdminNewAd({
    required String adId,
    required String title,
    required String price,
    required String category,
    required String userName,
    required String reason,
    String description = '',
    List<String> imageUrls = const [],
  }) async {
    final adminId = await _getAdminChatId();
    if (adminId.isEmpty || adminId == '5555555555') return;
    
    final StringBuffer sb = StringBuffer();
    sb.writeln('📢 <b>Новое объявление на модерацию!</b>');
    sb.writeln();
    sb.writeln('🏷️ Название: <b>$title</b>');
    sb.writeln('💰 Цена: <b>$price</b>');
    sb.writeln('🗂️ Категория: $category');
    sb.writeln('👤 Автор: $userName');
    if (description.isNotEmpty) {
      sb.writeln('📝 Описание: <i>${_formatDescription(description, isPublished: false, adId: adId)}</i>');
    }
    sb.writeln('⚠️ Статус: $reason');
    
    if (imageUrls.isNotEmpty) {
      sb.writeln();
      sb.writeln('🖼️ <b>Изображения:</b>');
      for (int i = 0; i < min(imageUrls.length, 5); i++) {
        sb.writeln('🔗 <a href="${imageUrls[i]}">Фото ${i + 1}</a>');
      }
    }

    sb.writeln();
    sb.writeln('Используйте панель модерации или кнопки ниже:');
    
    await _sendWithKeyboard(
      adminId,
      sb.toString(),
      keyboard: [
        [
          {'text': '✅ Одобрить', 'callback_data': 'approve_ad|$adId'},
          {'text': '❌ Отклонить', 'callback_data': 'reject_ad|$adId'},
        ]
      ],
    );
  }

  // ─── AD MODERATION: notify admin of new ad auto-approved by AI ─────────────
  static Future<void> notifyAdminAdAutoApproved({
    required String adId,
    required String title,
    required String price,
    required String category,
    required String userName,
    String description = '',
    List<String> imageUrls = const [],
  }) async {
    final adminId = await _getAdminChatId();
    if (adminId.isEmpty || adminId == '5555555555') return;
    
    final StringBuffer sb = StringBuffer();
    sb.writeln('🤖 <b>Объявление АВТО-ОДОБРЕНО ИИ!</b>');
    sb.writeln();
    sb.writeln('🏷️ Название: <b>$title</b>');
    sb.writeln('💰 Цена: <b>$price</b>');
    sb.writeln('🗂️ Категория: $category');
    sb.writeln('👤 Автор: $userName');
    if (description.isNotEmpty) {
      sb.writeln('📝 Описание: <i>${_formatDescription(description, isPublished: true, adId: adId)}</i>');
    }
    sb.writeln('✅ Статус: Опубликовано автоматически');
    
    if (imageUrls.isNotEmpty) {
      sb.writeln();
      sb.writeln('🖼️ <b>Изображения:</b>');
      for (int i = 0; i < min(imageUrls.length, 5); i++) {
        sb.writeln('🔗 <a href="${imageUrls[i]}">Фото ${i + 1}</a>');
      }
    }

    sb.writeln();
    sb.writeln('Вы можете отклонить его при необходимости:');
    
    await _sendWithKeyboard(
      adminId,
      sb.toString(),
      keyboard: [
        [
          {'text': '❌ Отклонить (Снять с публикации)', 'callback_data': 'reject_ad|$adId'},
        ]
      ],
    );
  }

  // ─── DRIVER VERIFICATION: notify driver of result ───────────────────────────
  static Future<void> notifyDriverResult({
    required String driverChatId,
    required bool isApproved,
    String? reason,
  }) async {
    final text = isApproved
        ? '🎉 <b>Поздравляем! Верификация пройдена!</b>\n\n'
            'Ваши документы проверены и одобрены.\n'
            'Теперь вы можете принимать заказы в <b>IQ-Market Taxi</b>.\n'
            '🚀 Удачных поездок!'
        : '❌ <b>Верификация отклонена</b>\n\n'
            '${reason ?? "Документы не соответствуют требованиям."}\n\n'
            'Пожалуйста, загрузите чёткие фотографии и повторите попытку.';
    await _send(driverChatId, text);
  }

  // ─── INTERNAL ────────────────────────────────────────────────────────────────
  static Future<bool> _send(String chatId, String text) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = user != null ? await user.getIdToken() : '';

      final r = await http.post(
        Uri.parse(ApiKeys.telegramProxyUrl),
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'chatId': chatId,
          'text': text,
          'parse_mode': 'HTML',
        }),
      );
      return r.statusCode == 200;
    } catch (e) {
      debugPrint('[TelegramBotService._send] Error: $e');
      return false;
    }
  }

  static Future<void> _sendWithKeyboard(
    String chatId,
    String text, {
    required List<List<Map<String, String>>> keyboard,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = user != null ? await user.getIdToken() : '';

      await http.post(
        Uri.parse(ApiKeys.telegramProxyUrl),
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'chatId': chatId,
          'text': text,
          'parse_mode': 'HTML',
          'reply_markup': {'inline_keyboard': keyboard},
        }),
      );
    } catch (e) { debugPrint('[TelegramBotService._sendWithKeyboard] Error: $e'); }
  }

  static String _formatDescription(String? description, {required bool isPublished, required String adId}) {
    if (description == null || description.isEmpty) return 'нет';
    
    String truncated = description;
    bool isTruncated = false;
    
    // Safely truncate by Unicode code points (runes) instead of UTF-16 code units
    if (truncated.runes.length > 600) {
      truncated = String.fromCharCodes(truncated.runes.take(600));
      isTruncated = true;
    }
    
    // HTML Escape the truncated text
    String escaped = truncated
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
    
    if (isTruncated) {
      escaped += '...';
      // Ссылка на iqmarket.kz/ad/$adId убрана: домен не зарегистрирован
      // (NXDOMAIN), а у iq-market-3dc07.web.app нет страницы /ad/ вообще
      // (404) — ссылка вела в никуда в обоих случаях. Админ видит полный
      // текст объявления в самом приложении (админ-панель).
      if (isPublished && adId.isNotEmpty) escaped += ' (adId: $adId)';
    }
    
    return escaped;
  }
}
