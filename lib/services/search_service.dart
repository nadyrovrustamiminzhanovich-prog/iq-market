import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:iqmarket/models/ad_model.dart';
import 'package:iqmarket/services/analytics_service.dart';
import 'package:iqmarket/services/network_service.dart';
import 'package:iqmarket/utils/fuzzy_matcher.dart';
import 'package:iqmarket/utils/search_normalizer.dart';

/// Кросс-языковой поиск объявлений (RU/KZ/UG/EN + транслитерация + опечатки).
///
/// Отдельный от [AdService.getActiveAdsPaginated] путь — тот остаётся
/// нетронутым как постоянная страховочная сетка на случай ошибки здесь
/// (см. wiring в home_screen.dart: try/catch + [SearchService.enabled]).
class SearchService {
  const SearchService._();

  /// Ручной аварийный выключатель — при подозрении на проблему можно
  /// откатиться на старое поведение поиска без отката остального диффа.
  static bool enabled = true;

  static CollectionReference get _adsCollection =>
      FirebaseFirestore.instance.collection('ads');

  static final RegExp _wordSplitRegExp =
      RegExp(r'[^a-z0-9а-яёәғқңөұүһіҗ]+');

  static Future<List<AdModel>> search({
    required String query,
    String? category,
    String? city,
    int limit = 100,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    // Аналитика — уже существующий, ранее ни разу не вызывавшийся метод,
    // ошибку здесь намеренно проглатываем, чтобы телеметрия никогда не
    // могла сломать сам поиск.
    unawaited(AnalyticsService.logSearch(cleanQuery));

    await SearchNormalizer.ensureLoaded();

    final isOffline = await NetworkService.isOffline();
    final queryTokens = _buildQueryTokens(cleanQuery);
    final Map<String, AdModel> candidatesMap = {};

    if (queryTokens.isNotEmpty) {
      try {
        Query indexedQuery = _adsCollection
            .where('active', isEqualTo: true)
            .where('status', isEqualTo: 'active');
        if (category != null && category.isNotEmpty) {
          indexedQuery = indexedQuery.where('category', isEqualTo: category);
        }
        if (city != null && city.isNotEmpty) {
          indexedQuery = indexedQuery.where('location', isEqualTo: city);
        }
        indexedQuery = indexedQuery.where('searchKeywords', arrayContainsAny: queryTokens);

        final snap = await indexedQuery.limit(200).get(
              GetOptions(source: isOffline ? Source.cache : Source.serverAndCache),
            );
        for (final doc in snap.docs) {
          final ad = AdModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
          candidatesMap[ad.id] = ad;
        }
      } catch (e) {
        debugPrint('[SearchService] searchKeywords query failed (index still building?): $e');
      }
    }

    // Фолбэк: мало совпадений по индексу (старое объявление без
    // расширенных ключевых слов, либо индекс ещё строится) — добираем из
    // последних активных объявлений и полагаемся на FuzzyMatcher ниже.
    if (candidatesMap.length < 20) {
      try {
        Query recentQuery = _adsCollection
            .where('active', isEqualTo: true)
            .where('status', isEqualTo: 'active');
        if (category != null && category.isNotEmpty) {
          recentQuery = recentQuery.where('category', isEqualTo: category);
        }
        if (city != null && city.isNotEmpty) {
          recentQuery = recentQuery.where('location', isEqualTo: city);
        }
        recentQuery = recentQuery.orderBy('timestamp', descending: true);

        final snap = await recentQuery.limit(200).get(
              GetOptions(source: isOffline ? Source.cache : Source.serverAndCache),
            );
        for (final doc in snap.docs) {
          final ad = AdModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
          candidatesMap[ad.id] = ad;
        }
      } catch (e) {
        debugPrint('[SearchService] fallback recent-ads scan failed: $e');
      }
    }

    final List<AdModel> results = [];
    for (final ad in candidatesMap.values) {
      final haystack = '${ad.title} ${ad.description} ${ad.category} ${ad.location}';
      if (FuzzyMatcher.isMatch(cleanQuery, haystack)) {
        results.add(ad);
      }
    }

    _rankByRelevance(results, cleanQuery);
    return results.take(limit).toList();
  }

  /// Строит ≤10 токенов для Firestore arrayContainsAny (жёсткий лимит
  /// Firestore). Раздаёт бюджет "по кругу" — сперва по одному токену на
  /// каждое слово запроса, и только затем добирает синонимы/транслитерацию,
  /// чтобы многословный запрос не тратил весь лимит на первое слово.
  static List<String> _buildQueryTokens(String query) {
    final words = query
        .toLowerCase()
        .split(_wordSplitRegExp)
        .where((w) => w.length >= 2)
        .toSet()
        .toList();
    if (words.isEmpty) return const [];

    final Map<String, List<String>> expansions = {
      for (final w in words) w: SearchNormalizer.expandWord(w).toList(),
    };

    final List<String> result = [];
    int round = 0;
    bool anyRemaining = true;
    while (result.length < 10 && anyRemaining) {
      anyRemaining = false;
      for (final w in words) {
        final variants = expansions[w]!;
        if (round < variants.length) {
          anyRemaining = true;
          final token = variants[round];
          if (!result.contains(token)) {
            result.add(token);
            if (result.length == 10) break;
          }
        }
      }
      round++;
    }
    return result;
  }

  /// Точное совпадение заголовка > префикс > просто содержит > свежее.
  static void _rankByRelevance(List<AdModel> results, String query) {
    final qLower = query.toLowerCase();
    results.sort((a, b) {
      final aTitle = a.title.toLowerCase();
      final bTitle = b.title.toLowerCase();

      final aExact = aTitle == qLower;
      final bExact = bTitle == qLower;
      if (aExact != bExact) return aExact ? -1 : 1;

      final aPrefix = aTitle.startsWith(qLower);
      final bPrefix = bTitle.startsWith(qLower);
      if (aPrefix != bPrefix) return aPrefix ? -1 : 1;

      final aContains = aTitle.contains(qLower);
      final bContains = bTitle.contains(qLower);
      if (aContains != bContains) return aContains ? -1 : 1;

      return b.timestamp.compareTo(a.timestamp);
    });
  }
}
