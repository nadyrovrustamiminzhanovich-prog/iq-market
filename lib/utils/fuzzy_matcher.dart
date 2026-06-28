class FuzzyMatcher {
  const FuzzyMatcher._();

  /// Главный метод проверки: соответствует ли текст (например, заголовок + описание)
  /// поисковому запросу с учетом опечаток, окончаний и транслитерации.
  static bool isMatch(String query, String text) {
    if (query.trim().isEmpty) return true;
    if (text.trim().isEmpty) return false;

    final queryWords = _splitIntoNormalizedWords(query);
    if (queryWords.isEmpty) return true;

    final textWords = _splitIntoNormalizedWords(text);
    if (textWords.isEmpty) return false;

    // Для каждого слова из запроса должно найтись хотя бы одно похожее слово в тексте
    return queryWords.every((qWord) {
      return textWords.any((tWord) {
        // 1. Прямое совпадение или подстрока (например, "телевизо" в "телевизор")
        if (tWord.contains(qWord) || qWord.contains(tWord)) {
          return true;
        }

        // 2. Расстояние Левенштейна (опечатки, переставленные буквы вроде "мтарас" -> "матрас")
        final threshold = _getEditDistanceThreshold(qWord.length);
        if (threshold > 0) {
          final distance = _levenshtein(qWord, tWord);
          if (distance <= threshold) {
            return true;
          }
        }

        return false;
      });
    });
  }

  /// Разбивает строку на нормализованные основы слов
  static List<String> _splitIntoNormalizedWords(String input) {
    return input
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9а-яёәғқңөұүһііі]+')) // разбиваем по любым небуквенным символам
        .map((w) => _normalizeAndStem(w))
        .where((w) => w.isNotEmpty)
        .toList();
  }

  /// Нормализует буквы и удаляет окончания (стемминг)
  static String _normalizeAndStem(String word) {
    if (word.isEmpty) return '';

    // 1. Нормализация похожих звуков и букв
    String w = word
        .replaceAll('ё', 'е')
        .replaceAll('ц', 'с') // "матрац" -> "матрас"
        .replaceAll('й', 'и')
        .replaceAll('і', 'и') // казахская мягкая "і" -> "и"
        .replaceAll('ә', 'а')
        .replaceAll('ө', 'о')
        .replaceAll('ү', 'у')
        .replaceAll('ұ', 'у');

    // 2. Усечение окончаний множественного числа (казахский)
    // лар/лер, дар/дер, тар/тер
    final kzPlural = RegExp(r'(лар|лер|дар|дер|тар|тер)$');
    w = w.replaceFirst(kzPlural, '');

    // 3. Усечение падежных окончаний и множественного числа (русский)
    // Окончания прилагательных
    final ruAdj = RegExp(r'(ому|ему|ыми|ими|ого|его|ыми|ое|ее|ая|яя|ых|их|ым|им|ую|юю|ой|ей|ый|ий)$');
    w = w.replaceFirst(ruAdj, '');

    // Окончания существительных (падежи и мн. число)
    final ruNoun = RegExp(r'(ами|ями|ов|ев|ей|ам|ям|ах|ях|ом|ем|ой|ей|ью|а|я|у|ю|е|о|ы|и|ь)$');
    w = w.replaceFirst(ruNoun, '');

    return w;
  }

  /// Возвращает допустимый порог опечаток в зависимости от длины слова
  static int _getEditDistanceThreshold(int wordLength) {
    if (wordLength <= 3) return 0; // Для коротких слов опечатки не допускаются
    if (wordLength <= 5) return 1; // 1 опечатка ("телефон" vs "телефо")
    return 2;                      // 2 опечатки/перестановки ("матрас" vs "мтарас")
  }

  /// Вычисляет редакционное расстояние Левенштейна между двумя словами
  static int _levenshtein(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    final charCodes1 = s1.codeUnits;
    final charCodes2 = s2.codeUnits;

    final len1 = charCodes1.length;
    final len2 = charCodes2.length;

    List<int> prevRow = List<int>.generate(len2 + 1, (i) => i);
    List<int> currRow = List<int>.filled(len2 + 1, 0);

    for (int i = 0; i < len1; i++) {
      currRow[0] = i + 1;
      for (int j = 0; j < len2; j++) {
        final cost = (charCodes1[i] == charCodes2[j]) ? 0 : 1;
        currRow[j + 1] = _min3(
          currRow[j] + 1,
          prevRow[j + 1] + 1,
          prevRow[j] + cost,
        );
      }
      final temp = prevRow;
      prevRow = currRow;
      currRow = temp;
    }

    return prevRow[len2];
  }

  static int _min3(int a, int b, int c) {
    int m = a < b ? a : b;
    return m < c ? m : c;
  }
}
