import 'package:flutter/foundation.dart';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:iqmarket/services/cloud_function_endpoints.dart';

class TelegramAuthService {
  // Токен бота УДАЛЕН ИЗ ПРИЛОЖЕНИЯ ради безопасности.
  // Запросы теперь должны идти на твой сервер (Firebase Cloud Functions).
  static const String _backendUrl = CloudFunctionEndpoints.sendOtpUrl;
  
  // Метод для генерации случайного 4-значного кода
  static String generateCode() {
    var rng = Random();
    return (1000 + rng.nextInt(9000)).toString();
  }

  // Безопасный метод отправки OTP через собственный backend
  static Future<bool> sendOtp(String phone, String code, String chatId) async {
    try {
      final url = Uri.parse(_backendUrl);
      final response = await http.post(
        url, 
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "chat_id": chatId,
          "phone": phone,
          "code": code
        })
      );
      
      // В реальности ждем 200 от нашего сервера.
      // Для режима разработки пока имитируем успех (так как функция еще не загружена)
      if (kDebugMode) {
        debugPrint('Отправка OTP на сервер: код $code для $phone');
        return true; 
      }

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Backend Auth Error: $e');
      // В дебаге разрешаем пройти дальше
      return kDebugMode ? true : false;
    }
  }
}
