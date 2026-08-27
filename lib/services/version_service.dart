import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Необязательное обновление: новая версия вышла, но текущая ещё выше
/// минимально допустимой — можно продолжать пользоваться приложением.
class UpdateChangelog {
  final String storeUrl;
  final int latestVersionCode;
  final String latestVersionName;
  final Map<String, dynamic> changelogByLang;

  const UpdateChangelog({
    required this.storeUrl,
    required this.latestVersionCode,
    this.latestVersionName = '',
    required this.changelogByLang,
  });

  /// Список пунктов "что нового" для языка [lang]
  List<String> linesFor(String lang) {
    // 1. Прямой поиск по языку
    final direct = changelogByLang[lang];
    if (direct is List) {
      return direct.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    }
    if (direct is String && direct.trim().isNotEmpty) {
      return direct.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    }

    // 2. Поиск по ключам RU / KK / UG
    String? fallbackRaw;
    if (lang.contains('Қазақ') || lang == 'kk') {
      fallbackRaw = changelogByLang['changelog_kk'] ?? changelogByLang['kk'] ?? changelogByLang['kz'];
    } else if (lang.contains('Уйғур') || lang == 'ug') {
      fallbackRaw = changelogByLang['changelog_ug'] ?? changelogByLang['ug'];
    } else {
      fallbackRaw = changelogByLang['changelog_ru'] ?? changelogByLang['ru'] ?? changelogByLang['Русский'];
    }

    if (fallbackRaw != null && fallbackRaw.trim().isNotEmpty) {
      return fallbackRaw.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    }

    // 3. Резервный список изменений
    if (lang.contains('Қазақ') || lang == 'kk') {
      return const [
        'Жаңа мүмкіндіктер мен дизайн жаңартулары',
        'Тұрақтылық пен қауіпсіздік арттырылды',
        'Жұмыс жылдамдығы оңтайландырылды',
      ];
    } else if (lang.contains('Уйғур') || lang == 'ug') {
      return const [
        'يېڭى ئىقتىدارلار ۋە كۆرۈنمە يۈز يېڭىلاندى',
        'ئەپنىڭ مۇقىملىقى ۋە بىخەتەرلىكى يۇقىرى كۆتۈرۈلدى',
        'ئىشلەش سۈرئىتى ئەلالاشتۇرۇلدى',
      ];
    }

    return const [
      '⚡ Улучшена скорость загрузки и поиска',
      '🛡️ Повышена стабильность и безопасность',
      '📱 Оптимизирована производительность',
    ];
  }
}

class VersionCheckResult {
  /// Не null — версия ниже минимально допустимой, показываем ForceUpdateScreen.
  final String? forceUpdateStoreUrl;

  /// Не null — есть более новая версия, но необязательная к установке.
  final UpdateChangelog? optionalUpdate;

  const VersionCheckResult({this.forceUpdateStoreUrl, this.optionalUpdate});
}

/// Сервис проверки версий приложения и управления обновлениями
class VersionService {
  /// Текущий код сборки приложения
  static const int currentVersionCode = 5;

  /// Текущее имя версии приложения
  static const String currentVersionName = '1.0.2';

  /// Package name приложения
  static const String packageName = 'com.iqmarket.app';

  /// Заполняется при старте приложения для показа мягкого напоминания на главном экране
  static UpdateChangelog? pendingOptionalUpdate;

  /// Проверяет конфигурацию версий в Firestore (одним быстрым запросом с таймаутом)
  static Future<VersionCheckResult> checkVersion({Duration timeout = const Duration(milliseconds: 1500)}) async {
    try {
      // Проверяем документ version_info (или version)
      DocumentSnapshot<Map<String, dynamic>> doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('version_info')
          .get()
          .timeout(timeout);

      if (!doc.exists || doc.data() == null) {
        doc = await FirebaseFirestore.instance
            .collection('app_config')
            .doc('version')
            .get()
            .timeout(timeout);
      }

      if (!doc.exists || doc.data() == null) {
        return const VersionCheckResult();
      }

      final data = doc.data()!;

      int? toInt(dynamic v) {
        if (v is int) return v;
        if (v is double) return v.toInt();
        if (v is String) return int.tryParse(v);
        return null;
      }

      final minVersionCode = toInt(data['min_version_code'] ?? data['min_supported_version_code']);
      final storeUrl = (data['store_url'] as String?) ??
          'https://play.google.com/store/apps/details?id=$packageName';

      // 1. Проверка на принудительное критическое обновление
      if (minVersionCode != null && currentVersionCode < minVersionCode) {
        return VersionCheckResult(forceUpdateStoreUrl: storeUrl);
      }

      // 2. Проверка на мягкое обновление
      final latestVersionCode = toInt(data['latest_version_code']);
      final latestVersionName = (data['latest_version_name'] as String?) ?? '';

      if (latestVersionCode != null && currentVersionCode < latestVersionCode) {
        final changelogRaw = data['changelog'] ?? data;
        Map<String, dynamic> changelogMap = {};
        if (changelogRaw is Map) {
          changelogMap = Map<String, dynamic>.from(changelogRaw);
        }

        return VersionCheckResult(
          optionalUpdate: UpdateChangelog(
            storeUrl: storeUrl,
            latestVersionCode: latestVersionCode,
            latestVersionName: latestVersionName,
            changelogByLang: changelogMap,
          ),
        );
      }
    } catch (e) {
      debugPrint('VersionService non-fatal error: $e');
    }
    return const VersionCheckResult();
  }
}
