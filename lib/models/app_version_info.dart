import 'package:flutter/foundation.dart';

/// Модель данных информации о версии приложения из Firestore (app_config/version).
class AppVersionInfo {
  final int latestVersionCode;
  final String latestVersionName;
  final int minSupportedVersionCode;
  final List<String> changelogRu;
  final List<String> changelogKk;
  final List<String> changelogUg;
  final String storeUrl;
  final bool isMaintenanceMode;

  const AppVersionInfo({
    required this.latestVersionCode,
    required this.latestVersionName,
    required this.minSupportedVersionCode,
    this.changelogRu = const [],
    this.changelogKk = const [],
    this.changelogUg = const [],
    this.storeUrl = 'https://play.google.com/store/apps/details?id=com.iqmarket.app',
    this.isMaintenanceMode = false,
  });

  /// Создание модели из Firestore документа с безопасными дефолтными значениями
  factory AppVersionInfo.fromMap(Map<String, dynamic>? data) {
    if (data == null) {
      return const AppVersionInfo(
        latestVersionCode: 5,
        latestVersionName: '1.0.2',
        minSupportedVersionCode: 1,
      );
    }

    List<String> parseList(dynamic raw) {
      if (raw is List) {
        return raw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
      }
      return const [];
    }

    return AppVersionInfo(
      latestVersionCode: (data['latest_version_code'] as num?)?.toInt() ?? 5,
      latestVersionName: data['latest_version_name']?.toString() ?? '1.0.2',
      minSupportedVersionCode: (data['min_supported_version_code'] as num?)?.toInt() ?? 1,
      changelogRu: parseList(data['changelog_ru']),
      changelogKk: parseList(data['changelog_kk']),
      changelogUg: parseList(data['changelog_ug']),
      storeUrl: data['store_url']?.toString() ??
          'https://play.google.com/store/apps/details?id=com.iqmarket.app',
      isMaintenanceMode: data['is_maintenance_mode'] == true,
    );
  }

  /// Получение списка изменений для выбранного языка
  List<String> getChangelogForLanguage(String language) {
    if (language.contains('Қазақ') || language == 'kk') {
      if (changelogKk.isNotEmpty) return changelogKk;
    } else if (language.contains('Уйғур') || language == 'ug') {
      if (changelogUg.isNotEmpty) return changelogUg;
    }
    
    // По умолчанию русский
    if (changelogRu.isNotEmpty) return changelogRu;
    
    // Резервный список изменений мирового уровня
    return const [
      '⚡ Улучшена скорость загрузки объявлений и поиска',
      '🛡️ Повышена стабильность и безопасность',
      '📱 Оптимизирована производительность и память',
    ];
  }

  /// Является ли обновление строго обязательным (Force Update)
  bool isForceUpdate(int currentVersionCode) {
    return currentVersionCode < minSupportedVersionCode;
  }

  /// Доступно ли обновление
  bool hasUpdate(int currentVersionCode) {
    return currentVersionCode < latestVersionCode;
  }
}
