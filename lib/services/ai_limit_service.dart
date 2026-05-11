import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class AiLimitService {
  static const String _countKey = 'ai_requests_count';
  static const String _dateKey = 'ai_requests_date';
  static const int maxFreeRequests = 3;

  /// Проверяет, можно ли сделать еще один запрос к ИИ
  static Future<bool> canMakeRequest() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final lastDate = prefs.getString(_dateKey) ?? '';

    if (lastDate != today) {
      // Новый день — сбрасываем счетчик
      await prefs.setString(_dateKey, today);
      await prefs.setInt(_countKey, 0);
      return true;
    }

    final count = prefs.getInt(_countKey) ?? 0;
    return count < maxFreeRequests;
  }

  /// Увеличивает счетчик запросов
  static Future<void> incrementRequestCount() async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt(_countKey) ?? 0;
    await prefs.setInt(_countKey, count + 1);
  }

  /// Возвращает количество оставшихся запросов на сегодня
  static Future<int> getRemainingRequests() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final lastDate = prefs.getString(_dateKey) ?? '';

    if (lastDate != today) return maxFreeRequests;

    final count = prefs.getInt(_countKey) ?? 0;
    final remaining = maxFreeRequests - count;
    return remaining < 0 ? 0 : remaining;
  }
}
