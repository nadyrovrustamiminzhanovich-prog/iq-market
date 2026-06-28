import 'package:shared_preferences/shared_preferences.dart';

/// Сервис лимитов для IQ-Поддержки.
/// Лимит 3 общих вопроса за 24 часа (скользящее окно от первого вопроса).
/// Вопросы по теме приложения/такси — безлимитно.
class SupportLimitService {
  static const String _countKey = 'support_general_count';
  static const String _firstQuestionTimeKey = 'support_first_question_ts';
  static const int maxGeneralQuestions = 3;
  static const int _windowHours = 24;

  /// Проверяет, можно ли задать ещё один общий (не по теме) вопрос.
  static Future<bool> canAskGeneral() async {
    final prefs = await SharedPreferences.getInstance();
    final firstTs = prefs.getInt(_firstQuestionTimeKey);

    if (firstTs == null) return true; // Никогда не спрашивал

    final firstTime = DateTime.fromMillisecondsSinceEpoch(firstTs);
    final now = DateTime.now();
    final diff = now.difference(firstTime);

    // Окно 24 часов истекло — сбрасываем
    if (diff.inHours >= _windowHours) {
      await prefs.remove(_countKey);
      await prefs.remove(_firstQuestionTimeKey);
      return true;
    }

    final count = prefs.getInt(_countKey) ?? 0;
    return count < maxGeneralQuestions;
  }

  /// Записывает факт отправки общего вопроса.
  static Future<void> incrementGeneral() async {
    final prefs = await SharedPreferences.getInstance();

    // Если это первый вопрос в текущем окне — фиксируем время
    final firstTs = prefs.getInt(_firstQuestionTimeKey);
    if (firstTs == null) {
      await prefs.setInt(
          _firstQuestionTimeKey, DateTime.now().millisecondsSinceEpoch);
      await prefs.setInt(_countKey, 1);
    } else {
      // Проверяем не истекло ли окно
      final firstTime = DateTime.fromMillisecondsSinceEpoch(firstTs);
      if (DateTime.now().difference(firstTime).inHours >= _windowHours) {
        // Новое окно
        await prefs.setInt(
            _firstQuestionTimeKey, DateTime.now().millisecondsSinceEpoch);
        await prefs.setInt(_countKey, 1);
      } else {
        final count = prefs.getInt(_countKey) ?? 0;
        await prefs.setInt(_countKey, count + 1);
      }
    }
  }

  /// Возвращает оставшееся количество общих вопросов и время сброса.
  static Future<Map<String, dynamic>> getStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final firstTs = prefs.getInt(_firstQuestionTimeKey);

    if (firstTs == null) {
      return {'remaining': maxGeneralQuestions, 'resetsAt': null};
    }

    final firstTime = DateTime.fromMillisecondsSinceEpoch(firstTs);
    final resetAt = firstTime.add(const Duration(hours: _windowHours));
    final now = DateTime.now();

    if (now.isAfter(resetAt)) {
      await prefs.remove(_countKey);
      await prefs.remove(_firstQuestionTimeKey);
      return {'remaining': maxGeneralQuestions, 'resetsAt': null};
    }

    final count = prefs.getInt(_countKey) ?? 0;
    final remaining = (maxGeneralQuestions - count).clamp(0, maxGeneralQuestions);
    return {'remaining': remaining, 'resetsAt': resetAt};
  }
}
