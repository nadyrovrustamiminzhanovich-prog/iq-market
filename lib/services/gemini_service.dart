import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:iqmarket/data/ai_prompts.dart';
import 'package:iqmarket/services/api_keys.dart';

class GeminiService {
  late GenerativeModel _model;
  late GenerativeModel _chatModel;
  late ChatSession _chat;
  String _currentLang = 'RU';

  void init(String lang) {
    _currentLang = lang;
    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: ApiKeys.moderationKey,
    );
    
    _chatModel = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: ApiKeys.assistantKey,
      systemInstruction: Content.system(AiPrompts.getPrompt(lang)),
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