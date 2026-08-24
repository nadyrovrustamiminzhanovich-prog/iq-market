import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:iqmarket/models/ad_model.dart';
import 'package:iqmarket/services/storage_service.dart';

/// Высокопроизводительный сервис кэширования ленты объявлений (Stale-While-Revalidate).
/// Предоставляет мгновенный (0ms) доступ к последним активным объявлениям из RAM и диска,
/// полностью устраняя мерцание и долгое кручение шиммеров/спиннеров при открытии приложения.
class FeedCacheService {
  static const String _storageKey = 'cached_home_feed_v1';
  static const int _maxCachedItems = 30;

  static List<AdModel>? _memoryCache;
  static bool _isLoaded = false;

  /// Инициализация кэша из локального хранилища (вызывается на старте приложения)
  static Future<void> init() async {
    if (_isLoaded && _memoryCache != null) return;
    try {
      final rawJson = StorageService.getString(_storageKey);
      if (rawJson != null && rawJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(rawJson);
        _memoryCache = decoded
            .map((item) => AdModel.fromJsonMap(Map<String, dynamic>.from(item as Map)))
            .where((ad) => ad.active && ad.status == 'active')
            .toList();
      }
    } catch (e) {
      debugPrint('[FeedCacheService] Error reading cached feed from disk: $e');
      _memoryCache = null;
    } finally {
      _isLoaded = true;
    }
  }

  /// Проверка наличия закэшированных объявлений
  static bool get hasCache {
    if (_memoryCache != null && _memoryCache!.isNotEmpty) return true;
    final raw = StorageService.getString(_storageKey);
    return raw != null && raw.isNotEmpty;
  }

  /// Получить кэшированные объявления (0 мс, синхронный доступ из RAM или диска)
  static List<AdModel>? getCachedFeed() {
    if (_memoryCache != null && _memoryCache!.isNotEmpty) {
      return List<AdModel>.from(_memoryCache!);
    }

    try {
      final rawJson = StorageService.getString(_storageKey);
      if (rawJson != null && rawJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(rawJson);
        _memoryCache = decoded
            .map((item) => AdModel.fromJsonMap(Map<String, dynamic>.from(item as Map)))
            .where((ad) => ad.active && ad.status == 'active')
            .toList();
        return _memoryCache != null ? List<AdModel>.from(_memoryCache!) : null;
      }
    } catch (e) {
      debugPrint('[FeedCacheService] Error decoding cache: $e');
    }
    return null;
  }

  /// Сохранить свежую порцию объявлений первой страницы в RAM и на диск
  static Future<void> saveFeed(List<AdModel> ads) async {
    if (ads.isEmpty) return;

    try {
      final itemsToCache = ads.take(_maxCachedItems).toList();
      _memoryCache = List<AdModel>.from(itemsToCache);

      final serializedList = itemsToCache.map((ad) => ad.toJsonMap()).toList();
      final jsonString = jsonEncode(serializedList);
      await StorageService.setString(_storageKey, jsonString);
    } catch (e) {
      debugPrint('[FeedCacheService] Error saving feed to cache: $e');
    }
  }

  /// Точечное обновление объявления в кэше (при редактировании / смене статуса)
  static void updateAdInCache(AdModel updatedAd) {
    if (_memoryCache == null) return;
    final index = _memoryCache!.indexWhere((a) => a.id == updatedAd.id);
    if (index != -1) {
      if (updatedAd.active && updatedAd.status == 'active') {
        _memoryCache![index] = updatedAd;
      } else {
        _memoryCache!.removeAt(index);
      }
      _persistMemoryCacheAsync();
    }
  }

  /// Удаление объявления из кэша (при удалении пользователем или админом)
  static void removeAdFromCache(String adId) {
    if (_memoryCache == null) return;
    final initialLen = _memoryCache!.length;
    _memoryCache!.removeWhere((a) => a.id == adId);
    if (_memoryCache!.length != initialLen) {
      _persistMemoryCacheAsync();
    }
  }

  /// Асинхронное фоновое сохранение памяти на диск без блокировок
  static void _persistMemoryCacheAsync() {
    if (_memoryCache == null) return;
    try {
      final serializedList = _memoryCache!.map((ad) => ad.toJsonMap()).toList();
      final jsonString = jsonEncode(serializedList);
      StorageService.setString(_storageKey, jsonString);
    } catch (e) {
      debugPrint('[FeedCacheService] Error persisting updated cache: $e');
    }
  }

  /// Сброс кэша
  static Future<void> invalidate() async {
    _memoryCache = null;
    try {
      await StorageService.setString(_storageKey, '');
    } catch (_) {}
  }
}
