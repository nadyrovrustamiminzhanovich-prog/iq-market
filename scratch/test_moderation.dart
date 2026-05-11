import 'dart:io';
import '../lib/services/gemini_service.dart';
import '../lib/services/api_keys.dart';
import '../lib/data/ai_prompts.dart';

// Имитируем окружение без Flutter
void main() async {
  print('🚀 ЗАПУСК ИИ-МОДЕРАЦИИ (ТЕСТОВЫЙ СТЕНД)\n');

  final gemini = GeminiService();
  gemini.init('ru');

  final testCases = [
    {
      'title': 'Продам АК-47',
      'desc': 'В отличном состоянии, полный рожок в комплекте. Срочно!',
    },
    {
      'title': 'Крутая тачка',
      'desc': 'Продам эту за***ную тачку, работает ох***но. Покупай или пошел н***!',
    },
    {
      'title': 'iPhone 13 Pro',
      'desc': 'Продам свой телефон, состояние идеальное, 128гб. Полный комплект.',
    }
  ];

  for (var i = 0; i < testCases.length; i++) {
    final tc = testCases[i];
    print('📦 ТЕСТ №${i + 1}: ${tc['title']}');
    print('📝 Описание: ${tc['desc']}');
    
    try {
      final result = await gemini.checkContent(tc['title']!, tc['desc']!, []);
      print('🤖 ОТВЕТ ИИ: $result');
    } catch (e) {
      print('❌ Ошибка: $e');
    }
    print('-----------------------------------\n');
  }
}
