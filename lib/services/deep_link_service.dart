import 'dart:async';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:intl/intl.dart';
import 'package:iqmarket/models/ad_model.dart';
import 'package:iqmarket/services/ad_service.dart';
import 'package:iqmarket/services/storage_service.dart';
import 'package:iqmarket/screens/product_details_screen.dart';

/// Сервис глубоких ссылок (Deep Linking & Universal Links) для IQ-Market.
/// Генерирует кликабельные веб-ссылки и мгновенно открывает нужное объявление
/// при переходе из WhatsApp, Telegram, браузера или соцсетей.
class DeepLinkService {
  static const String baseWebUrl = 'https://iq-market-3dc07.web.app';
  static final AppLinks _appLinks = AppLinks();
  static StreamSubscription<Uri>? _linkSubscription;
  static GlobalKey<NavigatorState>? _navigatorKey;
  static String? _lastHandledAdId;
  static DateTime? _lastHandledTime;

  /// Создать прямую веб-ссылку на объявление
  static String createAdShareUrl(String adId) {
    return '$baseWebUrl/ad?id=$adId';
  }

  /// Сформировать красивый текст для отправки в мессенджеры с прямой кликабельной ссылкой
  static String formatShareMessage({required AdModel ad, required String lang}) {
    final String shareUrl = createAdShareUrl(ad.id);
    final String priceFormatted = ad.price > 0
        ? '${NumberFormat.decimalPattern('ru').format(ad.price.toInt())} ₸'
        : (ad.category == 'Отдам даром' ? 'Бесплатно' : 'Договорная');
    final String location = (ad.location.isEmpty || ad.location == 'Шонжы') ? 'Чунджа' : ad.location;

    if (lang == 'Уйғурчә') {
      return '🔥 IQ-Market: ${ad.title}\n'
          '💰 Баһаси: $priceFormatted\n'
          '📍 Шәһәр: $location\n\n'
          '👉 Еланни көрүш үчүн сылтамани бесиң:\n$shareUrl';
    } else if (lang == 'Қазақша') {
      return '🔥 IQ-Market: ${ad.title}\n'
          '💰 Бағасы: $priceFormatted\n'
          '📍 Қала: $location\n\n'
          '👉 Хабарландыруды көру үшін сілтемені басыңыз:\n$shareUrl';
    } else {
      return '🔥 IQ-Market: ${ad.title}\n'
          '💰 Цена: $priceFormatted\n'
          '📍 Город: $location\n\n'
          '👉 Смотреть объявление в IQ-Market:\n$shareUrl';
    }
  }

  /// Инициализация прослушивания входящих ссылок
  static Future<void> init(GlobalKey<NavigatorState> navKey) async {
    _navigatorKey = navKey;

    try {
      // 1. Проверяем ссылку при холодном старте приложения (terminated state)
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        debugPrint('[DeepLinkService] Initial URI received: $initialUri');
        _processUri(initialUri);
      }

      // 2. Слушаем входящие ссылки в реальном времени (из фона / во время работы)
      _linkSubscription?.cancel();
      _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
        debugPrint('[DeepLinkService] Stream URI received: $uri');
        _processUri(uri);
      }, onError: (err) {
        debugPrint('[DeepLinkService] URI stream error: $err');
      });
    } catch (e) {
      debugPrint('[DeepLinkService] Initialization error: $e');
    }
  }

  /// Извлечение ID объявления и открытие экрана товара
  static void _processUri(Uri uri) {
    String? adId;

    // Вариант 1: Query параметр ?id=... (например, https://iq-market-3dc07.web.app/ad?id=XYZ или iqmarket://ad?id=XYZ)
    if (uri.queryParameters.containsKey('id')) {
      adId = uri.queryParameters['id'];
    }
    // Вариант 2: Путь /ad/XYZ (например, https://iq-market-3dc07.web.app/ad/XYZ или iqmarket://ad/XYZ)
    else if (uri.pathSegments.isNotEmpty) {
      final segments = uri.pathSegments;
      final adIndex = segments.indexOf('ad');
      if (adIndex != -1 && adIndex + 1 < segments.length) {
        adId = segments[adIndex + 1];
      } else if (segments.length == 1 && uri.host == 'ad') {
        adId = segments[0];
      }
    }

    if (adId == null || adId.trim().isEmpty) return;

    final cleanId = adId.trim();

    // Защита от дублирующей навигации при многократных ивентах одного и того же URI
    final now = DateTime.now();
    if (_lastHandledAdId == cleanId &&
        _lastHandledTime != null &&
        now.difference(_lastHandledTime!).inSeconds < 2) {
      return;
    }
    _lastHandledAdId = cleanId;
    _lastHandledTime = now;

    _openAdScreen(cleanId);
  }

  /// Загрузка объявления и навигация к ProductDetailsScreen
  static Future<void> _openAdScreen(String adId) async {
    try {
      debugPrint('[DeepLinkService] Fetching ad for deep link: $adId');
      final ad = await AdService.getAdById(adId);
      if (ad == null) {
        debugPrint('[DeepLinkService] Ad $adId not found in Firestore.');
        return;
      }

      final navState = _navigatorKey?.currentState;
      if (navState == null) {
        debugPrint('[DeepLinkService] NavigatorState not ready yet, retrying in 500ms...');
        await Future.delayed(const Duration(milliseconds: 500));
        _openAdScreen(adId);
        return;
      }

      final savedLang = StorageService.getString('app_lang') ?? 'Русский';

      navState.push(
        MaterialPageRoute(
          builder: (_) => ProductDetailsScreen(
            ad: ad,
            lang: savedLang,
            onReport: (_) {},
            heroPrefix: 'deeplink_',
          ),
        ),
      );
    } catch (e) {
      debugPrint('[DeepLinkService] Error navigating to ad $adId: $e');
    }
  }

  static void dispose() {
    _linkSubscription?.cancel();
    _linkSubscription = null;
  }
}
