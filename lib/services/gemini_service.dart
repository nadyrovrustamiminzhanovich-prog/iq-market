import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:iqmarket/data/ai_prompts.dart';
import 'package:iqmarket/services/api_keys.dart';

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
        ApiKeys.geminiProxyUrl,
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
}

class GeminiService {
  late GenerativeModel _model;
  late GenerativeModel _chatModel;
  late ChatSession _chat;

  void init(String lang) {
    
    final secureClient = SecureHttpClient();
    
    // Config model for ad moderation (routes to moderation key on backend)
    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: 'moderation',
      httpClient: secureClient,
    );
    
    // Config model for chat assistant (routes to assistant key on backend)
    _chatModel = GenerativeModel(
      model: 'gemini-1.5-flash',
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
        Content.system(AiPrompts.moderationPrompt),
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
}