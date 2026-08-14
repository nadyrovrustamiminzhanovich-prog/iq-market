import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// Кросс-языковой поиск: расширяет слово до всех известных написаний
/// (RU/KZ/UG/EN, синонимы брендов/товаров + детерминированная транслитерация
/// кириллица<->латиница). Не зависит от Firebase — юнит-тестируется напрямую.
///
/// Используется и при индексации объявления (AdService.generateSearchKeywords),
/// и при построении поискового запроса (SearchService) — оба пути обязаны
/// использовать именно этот класс, иначе результаты индексации и поиска
/// разойдутся.
class SearchNormalizer {
  const SearchNormalizer._();

  static const String _assetPath = 'assets/data/search_synonyms.json';

  // variant -> все известные написания того же понятия (включая само слово)
  static Map<String, List<String>>? _variantMap;
  static Future<void>? _loadingFuture;

  static bool get isLoaded => _variantMap != null;

  /// Идемпотентно грузит словарь. Безопасно вызывать многократно —
  /// повторные вызовы возвращают тот же Future, пока загрузка не завершится.
  /// При любой ошибке (файл отсутствует/битый JSON) деградирует в пустой
  /// словарь — expandWord() в этом случае просто не расширяет ничего сверх
  /// исходного слова, поведение эквивалентно "словаря ещё нет".
  static Future<void> ensureLoaded() {
    if (_variantMap != null) return Future.value();
    return _loadingFuture ??= _load();
  }

  static Future<void> _load() async {
    try {
      final raw = await rootBundle.loadString(_assetPath);
      final Map<String, dynamic> data = jsonDecode(raw) as Map<String, dynamic>;
      final Map<String, List<String>> flat = {};

      data.forEach((groupKey, concepts) {
        // "_comment" и подобные служебные ключи — пропускаем; "_global" —
        // обычная группа наравне с категориями, просто не привязана к одной.
        if (groupKey.startsWith('_') && groupKey != '_global') return;
        if (concepts is! Map) return;

        concepts.forEach((_, variants) {
          if (variants is! List) return;
          final normalized = variants
              .map((v) => v.toString().trim().toLowerCase())
              .where((v) => v.isNotEmpty)
              .toSet()
              .toList();
          if (normalized.length < 2) return;

          for (final variant in normalized) {
            final siblings = flat.putIfAbsent(variant, () => <String>[]);
            for (final sibling in normalized) {
              if (sibling != variant && !siblings.contains(sibling)) {
                siblings.add(sibling);
              }
            }
          }
        });
      });

      _variantMap = flat;
    } catch (_) {
      _variantMap = const {};
    }
  }

  /// Возвращает {слово} ∪ синонимы из словаря ∪ транслитерацию (и её
  /// собственные синонимы). Если словарь ещё не загружен — вернёт только
  /// исходное слово (см. ensureLoaded).
  static Set<String> expandWord(String word) {
    final w = word.trim().toLowerCase();
    if (w.isEmpty) return const {};

    final result = <String>{w};

    final siblings = _variantMap?[w];
    if (siblings != null) result.addAll(siblings);

    final translit = transliterate(w);
    if (translit != null && translit.isNotEmpty) {
      result.add(translit);
      final translitSiblings = _variantMap?[translit];
      if (translitSiblings != null) result.addAll(translitSiblings);
    }

    return result;
  }

  static Set<String> expandWords(Iterable<String> words) {
    final result = <String>{};
    for (final word in words) {
      result.addAll(expandWord(word));
    }
    return result;
  }

  // ---- Детерминированная транслитерация (fallback для слов вне словаря) ----
  //
  // Не может угадать фонетические заимствования вроде "iPhone"->"айфон"
  // (это произношение, а не побуквенный перевод) — такие пары живут только
  // в словаре search_synonyms.json. Транслитерация ловит написания вроде
  // "toyota"/"тойота", "noutbuk"/"ноутбук".

  static final RegExp _latinOnly = RegExp(r'^[a-z]+$');
  static final RegExp _cyrillicOnly = RegExp(r'^[а-яёәғқңөұүһіҗ]+$');

  static const Map<String, String> _cyrToLat = {
    'а': 'a', 'б': 'b', 'в': 'v', 'г': 'g', 'д': 'd', 'е': 'e', 'ё': 'e',
    'ж': 'zh', 'з': 'z', 'и': 'i', 'й': 'i', 'к': 'k', 'л': 'l', 'м': 'm',
    'н': 'n', 'о': 'o', 'п': 'p', 'р': 'r', 'с': 's', 'т': 't', 'у': 'u',
    'ф': 'f', 'х': 'h', 'ц': 'ts', 'ч': 'ch', 'ш': 'sh', 'щ': 'shch',
    'ъ': '', 'ы': 'y', 'ь': '', 'э': 'e', 'ю': 'yu', 'я': 'ya',
    // казахские/уйгурские дополнительные буквы
    'ә': 'a', 'ғ': 'g', 'қ': 'k', 'ң': 'ng', 'ө': 'o', 'ұ': 'u', 'ү': 'u',
    'һ': 'h', 'і': 'i', 'җ': 'j',
  };

  // Порядок важен: более длинные латинские последовательности проверяются
  // первыми (жадное сопоставление), иначе "sh" в "shch" сработает раньше.
  static const List<MapEntry<String, String>> _latToCyr = [
    MapEntry('shch', 'щ'),
    MapEntry('sh', 'ш'),
    MapEntry('ch', 'ч'),
    MapEntry('zh', 'ж'),
    MapEntry('kh', 'х'),
    MapEntry('ts', 'ц'),
    MapEntry('yu', 'ю'),
    MapEntry('ya', 'я'),
    // Намеренно НЕТ "ng"->"ң": буквосочетание "ng" в реальных словах (samsung,
    // parking) почти всегда означает раздельные н+г, а не казахский ң —
    // ложное срабатывание было бы гораздо чаще полезного. Слова с ң уже
    // покрыты словарём search_synonyms.json напрямую как кириллица.
    MapEntry('a', 'а'), MapEntry('b', 'б'), MapEntry('v', 'в'), MapEntry('g', 'г'),
    MapEntry('d', 'д'), MapEntry('e', 'е'), MapEntry('z', 'з'), MapEntry('i', 'и'),
    MapEntry('j', 'ж'), MapEntry('k', 'к'), MapEntry('l', 'л'), MapEntry('m', 'м'),
    MapEntry('n', 'н'), MapEntry('o', 'о'), MapEntry('p', 'п'), MapEntry('r', 'р'),
    MapEntry('s', 'с'), MapEntry('t', 'т'), MapEntry('u', 'у'), MapEntry('f', 'ф'),
    MapEntry('h', 'х'), MapEntry('y', 'ы'), MapEntry('w', 'в'), MapEntry('x', 'кс'),
    MapEntry('c', 'к'), MapEntry('q', 'к'),
  ];

  /// null для пустых/смешанных/цифровых токенов — транслитерировать нечего.
  static String? transliterate(String word) {
    final w = word.trim().toLowerCase();
    if (w.length < 2) return null;
    if (_latinOnly.hasMatch(w)) return _latinToCyrillic(w);
    if (_cyrillicOnly.hasMatch(w)) return _cyrillicToLatin(w);
    return null;
  }

  static String _cyrillicToLatin(String word) {
    final buf = StringBuffer();
    for (final rune in word.split('')) {
      buf.write(_cyrToLat[rune] ?? rune);
    }
    return buf.toString();
  }

  static String _latinToCyrillic(String word) {
    final buf = StringBuffer();
    int i = 0;
    while (i < word.length) {
      String? outCh;
      int consumed = 1;
      for (final entry in _latToCyr) {
        final key = entry.key;
        if (i + key.length <= word.length && word.substring(i, i + key.length) == key) {
          outCh = entry.value;
          consumed = key.length;
          break;
        }
      }
      buf.write(outCh ?? word[i]);
      i += consumed;
    }
    return buf.toString();
  }
}
