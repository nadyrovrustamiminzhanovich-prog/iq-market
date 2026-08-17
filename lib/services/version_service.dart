import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Необязательное обновление: новая версия вышла, но текущая ещё выше
/// минимально допустимой — можно продолжать пользоваться приложением.
class UpdateChangelog {
  final String storeUrl;
  final int latestVersionCode;
  final Map<String, dynamic> changelogByLang;

  const UpdateChangelog({
    required this.storeUrl,
    required this.latestVersionCode,
    required this.changelogByLang,
  });

  /// Список пунктов "что нового" для языка [lang] — в Firestore это просто
  /// строка с переносами строк (владельцу проще редактировать вручную в
  /// консоли, чем массив), здесь разбивается на строки для UI.
  List<String> linesFor(String lang) {
    final raw = (changelogByLang[lang] as String?) ??
        (changelogByLang['Русский'] as String?) ??
        '';
    return raw
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
  }
}

class VersionCheckResult {
  /// Не null — версия ниже минимально допустимой, показываем ForceUpdateScreen.
  final String? forceUpdateStoreUrl;
  /// Не null — есть более новая версия, но необязательная к установке.
  final UpdateChangelog? optionalUpdate;

  const VersionCheckResult({this.forceUpdateStoreUrl, this.optionalUpdate});
}

/// Service responsible for managing application updates and version validation.
class VersionService {
  /// Current app build version code (must be incremented on release matching pubspec.yaml)
  static const int currentVersionCode = 3;

  /// Заполняется checkVersion() при холодном старте, если найдена
  /// необязательная новая версия. IQMarketHome читает и сразу обнуляет это
  /// поле один раз за запуск приложения — чтобы мягкое напоминание не
  /// всплывало повторно при каждой навигации внутри одной сессии, только
  /// при следующем холодном старте (или когда выйдет ещё более новая версия).
  static UpdateChangelog? pendingOptionalUpdate;

  /// Читает единственный документ конфигурации версий и определяет,
  /// требуется ли принудительное обновление (min_version_code) или доступно
  /// необязательное (latest_version_code) — одним запросом к Firestore.
  static Future<VersionCheckResult> checkVersion() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('version_info')
          .get();

      if (!doc.exists || doc.data() == null) return const VersionCheckResult();
      final data = doc.data()!;

      int? toInt(dynamic v) {
        if (v is int) return v;
        if (v is double) return v.toInt();
        if (v is String) return int.tryParse(v);
        return null;
      }

      final minVersionCode = toInt(data['min_version_code']);
      final storeUrl = (data['store_url'] as String?) ??
          'https://play.google.com/store/apps/details?id=com.iqmarket.app';

      if (minVersionCode != null && currentVersionCode < minVersionCode) {
        return VersionCheckResult(forceUpdateStoreUrl: storeUrl);
      }

      final latestVersionCode = toInt(data['latest_version_code']);
      if (latestVersionCode != null && currentVersionCode < latestVersionCode) {
        final changelogRaw = data['changelog'];
        if (changelogRaw is Map) {
          return VersionCheckResult(
            optionalUpdate: UpdateChangelog(
              storeUrl: storeUrl,
              latestVersionCode: latestVersionCode,
              changelogByLang: Map<String, dynamic>.from(changelogRaw),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error checking app version: $e');
    }
    return const VersionCheckResult();
  }
}
