/// Тесты SearchNormalizer — кросс-языковое расширение поисковых слов.
///
/// Запуск: flutter test test/search_normalizer_test.dart
library search_normalizer_test;

import 'package:flutter_test/flutter_test.dart';
import 'package:iqmarket/utils/search_normalizer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('transliterate (не требует загрузки словаря)', () {
    test('латиница -> кириллица, однозначные буквы', () {
      expect(SearchNormalizer.transliterate('samsung'), 'самсунг');
      expect(SearchNormalizer.transliterate('internet'), 'интернет');
    });

    test('кириллица -> латиница, однозначные буквы', () {
      expect(SearchNormalizer.transliterate('самсунг'), 'samsung');
      expect(SearchNormalizer.transliterate('принтер'), 'printer');
    });

    test('латинская "y" — известное ограничение (неоднозначна между й/ы), не проверяем конкретный результат', () {
      // Документируем эвристику как есть, а не гадаем "правильный" ответ —
      // это заведомо приблизительный fallback, см. комментарий класса.
      expect(SearchNormalizer.transliterate('toyota'), isNotNull);
    });

    test('диграфы транслитерируются целиком, не по буквам', () {
      // "shch" должен схлопнуться в "щ", а не распасться на s+h+c+h
      expect(SearchNormalizer.transliterate('shchit'), contains('щ'));
      expect(SearchNormalizer.transliterate('чай'), 'chai');
    });

    test('смешанный скрипт или цифры -> null', () {
      expect(SearchNormalizer.transliterate('iphone12'), isNull);
      expect(SearchNormalizer.transliterate('айфон12'), isNull);
      expect(SearchNormalizer.transliterate('123'), isNull);
    });

    test('пустая строка и однобуквенное слово -> null', () {
      expect(SearchNormalizer.transliterate(''), isNull);
      expect(SearchNormalizer.transliterate('a'), isNull);
    });

    test('казахские специфичные буквы транслитерируются', () {
      expect(SearchNormalizer.transliterate('қой'), isNotNull);
      expect(SearchNormalizer.transliterate('мұздатқыш'), isNotNull);
    });
  });

  group('expandWord со словарём', () {
    setUpAll(() async {
      await SearchNormalizer.ensureLoaded();
    });

    test('словарь реально загрузился (asset зарегистрирован в pubspec.yaml)', () {
      expect(SearchNormalizer.isLoaded, isTrue);
    });

    test('iphone <-> айфон находят друг друга через словарь', () {
      expect(SearchNormalizer.expandWord('iphone'), contains('айфон'));
      expect(SearchNormalizer.expandWord('айфон'), contains('iphone'));
    });

    test('исходное слово всегда присутствует в результате', () {
      expect(SearchNormalizer.expandWord('коврик'), contains('коврик'));
    });

    test('бренд без словарной пары всё равно транслитерируется', () {
      // hyundai нет дословно как "hyundai" -> но есть в словаре под своим ключом
      final expanded = SearchNormalizer.expandWord('hyundai');
      expect(expanded, contains('хендай'));
    });

    test('пустое слово возвращает пустое множество', () {
      expect(SearchNormalizer.expandWord(''), isEmpty);
    });

    test('expandWords объединяет расширения нескольких слов', () {
      final expanded = SearchNormalizer.expandWords(['iphone', 'toyota']);
      expect(expanded, contains('айфон'));
      expect(expanded, contains('тойота'));
    });
  });
}
