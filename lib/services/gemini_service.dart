import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:iqmarket/data/ai_prompts.dart';
import 'package:iqmarket/services/cloud_function_endpoints.dart';

// 🔒 X10 SECURITY: Custom HTTP Client that intercepts outgoing Gemini calls,
// injects the Firebase Auth ID Token, and redirects them securely to our
// Cloud Function proxy URL to completely hide the API keys on the server.
class SecureHttpClient extends http.BaseClient {
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final user = FirebaseAuth.instance.currentUser;
    final token = user != null ? await user.getIdToken() : '';

    // Reconstruct the request to target our Cloud Function proxy instead of the Google endpoint
    final originalUrl = request.url.toString();
    final newUrl = Uri.parse(
      originalUrl.replaceFirst(
        'https://generativelanguage.googleapis.com',
        CloudFunctionEndpoints.geminiProxyUrl,
      ),
    );

    final newRequest = http.StreamedRequest(request.method, newUrl);
    newRequest.headers.addAll(request.headers);
    newRequest.headers['content-type'] = request.headers['content-type'] ?? 'application/json';
    if (token != null && token.isNotEmpty) {
      newRequest.headers['Authorization'] = 'Bearer $token';
    }

    // Pipe request body stream
    request.finalize().listen(
      newRequest.sink.add,
      onError: newRequest.sink.addError,
      onDone: newRequest.sink.close,
      cancelOnError: true,
    );

    return _inner.send(newRequest);
  }

  void close() {
    _inner.close();
  }
}

class GeminiService {
  late GenerativeModel _model;
  late GenerativeModel _chatModel;
  late ChatSession _chat;

  void init(String lang) {
    
    final secureClient = SecureHttpClient();
    
    // Config model for ad moderation (routes to moderation key on backend)
    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: 'moderation',
      systemInstruction: Content.system(AiPrompts.getModerationPrompt(lang)),
      httpClient: secureClient,
    );
    
    // Config model for chat assistant (routes to assistant key on backend)
    _chatModel = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: 'assistant',
      systemInstruction: Content.system(AiPrompts.getPrompt(lang)),
      httpClient: secureClient,
    );
    _chat = _chatModel.startChat();
  }

  Stream<GenerateContentResponse> sendMessageStream(String text, List<File> files) async* {
    try {
      final List<DataPart> imageParts = [];
      for (final file in files) {
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          imageParts.add(DataPart('image/jpeg', bytes));
        }
      }

      final content = Content.multi([
        TextPart(text),
        ...imageParts,
      ]);

      yield* _chat.sendMessageStream(content);
    } catch (e) {
      debugPrint('Gemini sendMessageStream error: $e');
      rethrow;
    }
  }

  Future<String> checkContent(String title, String description, List<File> images) async {
    try {
      final List<DataPart> imageParts = [];
      for (final file in images) {
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          imageParts.add(DataPart('image/jpeg', bytes));
        }
      }

      final prompt = "Заголовок: $title\nОписание: $description\n\nПроверь это объявление на соответствие правилам.";
      
      final response = await _model.generateContent([
        Content.multi([
          TextPart(prompt),
          ...imageParts,
        ]),
      ]);

      return response.text ?? 'MANUAL_REVIEW';
    } catch (e) {
      debugPrint('Gemini checkContent error: $e');
      return 'MANUAL_REVIEW';
    }
  }

  /// Анализ 2 основных документов водителя (фото авто спереди + техпаспорт) с помощью Gemini Vision
  Future<Map<String, dynamic>> analyzeDriverDocuments({
    File? license,
    required File techPassport,
    File? selfie,
    required File carFront,
    required String driverName,
    required String plate,
    required String carModel,
  }) async {
    try {
      final List<DataPart> imageParts = [];

      if (license != null && await license.exists()) {
        final bytes = await license.readAsBytes();
        imageParts.add(DataPart('image/jpeg', bytes));
      }
      if (await techPassport.exists()) {
        final bytes = await techPassport.readAsBytes();
        imageParts.add(DataPart('image/jpeg', bytes));
      }
      if (selfie != null && await selfie.exists()) {
        final bytes = await selfie.readAsBytes();
        imageParts.add(DataPart('image/jpeg', bytes));
      }
      if (await carFront.exists()) {
        final bytes = await carFront.readAsBytes();
        imageParts.add(DataPart('image/jpeg', bytes));
      }

      final prompt = """
Вы являетесь экспертной системой искусственного интеллекта для верификации водителей такси в IQ-Taxi.
Ваша задача — тщательно проанализировать предоставленные фотографии (Фото автомобиля спереди с читаемым госномером и Техпаспорт автомобиля).

Сравните данные с введенными водителем:
- Имя водителя: $driverName
- Госномер автомобиля: $plate
- Модель автомобиля: $carModel

Проверьте:
1. Госномер на фото автомобиля спереди и в техпаспорте совпадает с "$plate".
2. Модель и цвет автомобиля на фото совпадает с "$carModel".
3. Техпаспорт чёткий, читаемый и действительный.
4. Нет ли признаков сильного размытия или подделки документов (Photoshop, фото экрана, нечитаемый госномер).

Верните строго валидный JSON-ответ без markdown (без ```json), содержащий следующие поля:
{
  "license_valid": true,
  "tech_passport_valid": true/false (техпаспорт четкий и действительный),
  "selfie_valid": true,
  "car_valid": true/false (фото машины соответствует),
  "name_matches": true,
  "plate_matches": true/false (госномер на авто и техпаспорте совпадает),
  "car_model_matches": true/false (марка авто совпадает),
  "blurry_photo_detected": true/false (обнаружено ли сильное размытие или нечитаемый номер),
  "reason": "описание найденных несоответствий на русском языке, либо 'Документы и госномер успешно сверены ИИ'",
  "confidence": "high/medium/low" (уровень уверенности ИИ)
}
""";

      final response = await _model.generateContent([
        Content.multi([
          TextPart(prompt),
          ...imageParts,
        ]),
      ]);

      final text = response.text ?? '';
      // Clean up markdown block if Gemini adds it
      final cleanJson = text
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      
      return jsonDecode(cleanJson) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Gemini analyzeDriverDocuments error: $e');
      return {
        'error': e.toString(),
        'confidence': 'low',
        'reason': 'Ошибка подключения к ИИ-ассистенту'
      };
    }
  }

  void dispose() {
    // Clean up HTTP client resources
  }
}