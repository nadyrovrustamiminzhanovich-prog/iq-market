import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:iqmarket/services/api_keys.dart';

class TelegramBotService {
  // ─── BOT CONFIG ─────────────────────────────────────────────────────────────
  static const String _botUsername = 'IQ_Taxi_bot'; // YOUR BOT @username
  // Replace with your own Telegram chat_id (get it from @userinfobot)
  static const String _adminChatId = '1910159480';

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

  // ─── STEP 1: Create Firebase session + open bot with deep link ───────────────
  /// Returns sessionToken that you then poll for chat_id
  static Future<String> startAuthSession({String? phone}) async {
    final token = _randomAlnum(24);
    await FirebaseFirestore.instance
        .collection('tg_auth_sessions')
        .doc(token)
        .set({
      'created_at': FieldValue.serverTimestamp(),
      'verified': false,
      'chat_id': null,
      'otp': null,
      if (phone != null) 'phone': phone,
    });
    // Wait a bit to ensure Firestore is synced before bot accesses it
    await Future.delayed(const Duration(milliseconds: 1000));
    
    // Open bot via Telegram deep link — bot will capture chat_id from /start <token>
    final botUrl = 'https://t.me/$_botUsername?start=$token';
    await launchUrl(Uri.parse(botUrl), mode: LaunchMode.externalApplication);
    return token;
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
    if (_adminChatId.isEmpty || _adminChatId == '5555555555') return;
    
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
      _adminChatId,
      sb.toString(),
      keyboard: [
        [
          {'text': '✅ Одобрить', 'callback_data': 'approve|$reviewDocId|$driverChatId'},
          {'text': '❌ Отклонить', 'callback_data': 'reject|$reviewDocId|$driverChatId'},
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
    } catch (_) {
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
    } catch (_) {}
  }
}
