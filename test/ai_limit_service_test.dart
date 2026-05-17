import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:iqmarket/services/ai_limit_service.dart';

void main() {
  group('AiLimitService Business Logic Tests', () {
    setUp(() {
      // Очищаем SharedPreferences перед каждым тестом
      SharedPreferences.setMockInitialValues({});
    });

    test('X10: Новый пользователь имеет 3 доступных запроса', () async {
      final canRequest = await AiLimitService.canMakeRequest();
      final remaining = await AiLimitService.getRemainingRequests();

      expect(canRequest, isTrue);
      expect(remaining, 3);
    });

    test('X10: Счетчик правильно уменьшается после вызова', () async {
      await AiLimitService.incrementRequestCount();
      
      final remaining = await AiLimitService.getRemainingRequests();
      expect(remaining, 2);
    });

    test('X10: Лимит исчерпан после 3 вызовов', () async {
      await AiLimitService.incrementRequestCount();
      await AiLimitService.incrementRequestCount();
      await AiLimitService.incrementRequestCount();
      
      final canRequest = await AiLimitService.canMakeRequest();
      final remaining = await AiLimitService.getRemainingRequests();

      expect(canRequest, isFalse);
      expect(remaining, 0);
    });

    test('X10: Счетчик сбрасывается на следующий день', () async {
      // Эмулируем, что пользователь потратил все лимиты вчера
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yesterdayStr = DateFormat('yyyy-MM-dd').format(yesterday);
      
      SharedPreferences.setMockInitialValues({
        'ai_requests_date': yesterdayStr,
        'ai_requests_count': 3,
      });

      // Сегодня он должен снова получить 3 запроса
      final canRequest = await AiLimitService.canMakeRequest();
      final remaining = await AiLimitService.getRemainingRequests();

      expect(canRequest, isTrue);
      expect(remaining, 3);
    });
  });
}
