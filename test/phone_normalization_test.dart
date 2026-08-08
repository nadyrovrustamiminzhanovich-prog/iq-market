import 'package:flutter_test/flutter_test.dart';

/// Копия _normalizePhoneInput из profile_settings_screen. Метод приватный и
/// живёт в State виджета, но правило нормализации — чистая логика, и именно
/// от неё зависит, совпадёт ли сохранённый номер с тем, что пишут
/// PhoneRequiredBottomSheet и таксишный онбординг (+7XXXXXXXXXX).
///
/// null — поле пустое, номер не меняем. '' — введён неполный номер, сохранять
/// нельзя. Иначе канонический +7XXXXXXXXXX.
String? normalizePhoneInput(String raw) {
  var digits = raw.replaceAll(RegExp(r'\D'), '');
  // Маска '+7 (###) …' оставляет в поле литеральный префикс после того как
  // пользователь всё стёр. Одна цифра кода страны — это пустое поле, а не
  // неполный номер: иначе человек без телефона не сможет сохранить даже имя.
  if (digits == '7' || digits == '8') digits = '';
  if (digits.isEmpty) return null;
  final local = digits.length > 10 ? digits.substring(digits.length - 10) : digits;
  if (local.length != 10) return '';
  return '+7$local';
}

void main() {
  group('Нормализация телефона к +7XXXXXXXXXX', () {
    test('маска из поля ввода превращается в канонический вид', () {
      expect(normalizePhoneInput('+7 (700) 123-45-67'), '+77001234567');
    });

    test('10 цифр без кода страны', () {
      expect(normalizePhoneInput('7001234567'), '+77001234567');
    });

    test('11 цифр с ведущей 7 — код страны отбрасывается', () {
      expect(normalizePhoneInput('77001234567'), '+77001234567');
    });

    test('11 цифр с ведущей 8 — тоже приводится к +7', () {
      // Казахстанский формат «8 700…», который часто вводят вручную.
      expect(normalizePhoneInput('87001234567'), '+77001234567');
    });

    test('произвольные разделители не влияют на результат', () {
      expect(normalizePhoneInput('8-700-123 45.67'), '+77001234567');
    });

    test('пустое поле → null: сохранённый номер не затирается', () {
      // Ключевой случай. Пока экран читал телефон не оттуда, куда писал, поле
      // всегда выглядело пустым — и сохранение имени стирало номер в Firestore.
      expect(normalizePhoneInput(''), isNull);
      expect(normalizePhoneInput('   '), isNull);
      // Остаток маски после того как пользователь всё стёр — тоже «пусто»,
      // иначе сохранение профиля упадёт с «введите полный номер».
      expect(normalizePhoneInput('+7 ('), isNull);
      expect(normalizePhoneInput('8'), isNull);
    });

    test('неполный номер → пустая строка: сохранять нельзя', () {
      expect(normalizePhoneInput('+7 (700) 12'), '');
      expect(normalizePhoneInput('700123456'), '');
    });

    test('результат никогда не содержит символов маски', () {
      const inputs = [
        '+7 (700) 123-45-67',
        '8 700 123 45 67',
        '7 (700) 1234567',
      ];
      for (final input in inputs) {
        final result = normalizePhoneInput(input);
        expect(result, isNotNull);
        expect(result, matches(RegExp(r'^\+7\d{10}$')), reason: 'вход: $input');
      }
    });
  });
}
