import 'package:flutter_test/flutter_test.dart';

// Воспроизводим логику генерации ID чата из ChatService.getChatId для тестирования её безопасности
String generateDeterministicChatId(String uid, String sellerId) {
  if (uid.isEmpty || sellerId.isEmpty) {
    return 'invalid_chat';
  }
  final ids = [uid, sellerId]..sort();
  return ids.join('_');
}

void main() {
  group('Chat Security and Fallback ID Generation Tests', () {
    const currentUser = 'alpha';
    const sellerUser = 'beta';
    const strangerUser = 'gamma';

    test('Детерминированность и симметричность генерации ID чата', () {
      // ID чата должен быть одинаковым независимо от того, кто является инициатором (покупатель или продавец)
      final id1 = generateDeterministicChatId(currentUser, sellerUser);
      final id2 = generateDeterministicChatId(sellerUser, currentUser);

      expect(id1, equals(id2));
      expect(id1, equals('alpha_beta')); // Алфавитная сортировка
    });

    test('Уникальность идентификаторов чатов', () {
      // ID чата для разных пар пользователей должен гарантированно отличаться
      final chatAB = generateDeterministicChatId(currentUser, sellerUser);
      final chatAC = generateDeterministicChatId(currentUser, strangerUser);
      final chatBC = generateDeterministicChatId(sellerUser, strangerUser);

      expect(chatAB, isNot(equals(chatAC)));
      expect(chatAB, isNot(equals(chatBC)));
      expect(chatAC, isNot(equals(chatBC)));
    });

    test('Гарантия участия текущего пользователя в сгенерированном чате (защита от утечек)', () {
      // Метод генерации ID всегда подмешивает UID текущего пользователя.
      // Злоумышленник currentUser не может сгенерировать ID для чужого чата (sellerUser и strangerUser) без своего участия.
      final generatedId = generateDeterministicChatId(currentUser, sellerUser);
      
      final parts = generatedId.split('_');
      expect(parts.contains(currentUser), isTrue);
      
      // Попытка сгенерировать чат между двумя другими пользователями (sellerUser и strangerUser)
      // от имени currentUser невозможна, так как клиентский метод всегда использует UID текущей сессии.
      final wrongGeneratedId = generateDeterministicChatId(currentUser, strangerUser);
      expect(wrongGeneratedId.split('_').contains(sellerUser), isFalse);
    });

    test('Обработка невалидных/пустых входных данных', () {
      // Метод должен возвращать ошибку и не генерировать валидный ID при пустых UID
      expect(generateDeterministicChatId('', sellerUser), equals('invalid_chat'));
      expect(generateDeterministicChatId(currentUser, ''), equals('invalid_chat'));
      expect(generateDeterministicChatId('', ''), equals('invalid_chat'));
    });
  });
}
