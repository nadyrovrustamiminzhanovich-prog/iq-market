import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:iqmarket/models/app_version_info.dart';
import 'package:iqmarket/providers/app_config_provider.dart';
import 'package:iqmarket/services/storage_service.dart';
import 'package:iqmarket/widgets/common/update_dialog.dart';

/// Сервис проверки обновлений приложения и показа вежливого диалога
class UpdateService {
  /// Текущий код версии приложения (соответствует versionCode в pubspec / build.gradle)
  static const int currentVersionCode = 5;

  /// Текущее имя версии приложения
  static const String currentVersionName = '1.0.2';

  /// Package Name приложения для Google Play
  static const String packageName = 'com.iqmarket.app';

  /// Защитный флаг от повторного одновременного показа диалога в одной сессии
  static bool _isDialogShown = false;

  /// Проверяет наличие обновления в Firestore и при необходимости показывает диалог
  static Future<void> checkForUpdates(BuildContext context) async {
    if (_isDialogShown) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('version')
          .get()
          .timeout(const Duration(seconds: 5));

      if (!doc.exists || doc.data() == null) {
        debugPrint('UpdateService: app_config/version document does not exist.');
        return;
      }

      final versionInfo = AppVersionInfo.fromMap(doc.data()!);

      // Если нет обновлений — ничего не делаем
      if (!versionInfo.hasUpdate(currentVersionCode)) {
        debugPrint('UpdateService: App is up to date (v$currentVersionCode).');
        return;
      }

      final isForceUpdate = versionInfo.isForceUpdate(currentVersionCode);

      // Для мягкого (гибкого) обновления проверяем, не нажимал ли пользователь "Позже" сегодня
      if (!isForceUpdate) {
        final lastDismissedCode = StorageService.getInt('last_dismissed_version_code');
        final lastDismissedTime = StorageService.getInt('last_dismissed_version_time');

        if (lastDismissedCode == versionInfo.latestVersionCode && lastDismissedTime != null) {
          final difference = DateTime.now().millisecondsSinceEpoch - lastDismissedTime;
          // 24 часа = 86 400 000 миллисекунд
          if (difference < 86400000) {
            debugPrint('UpdateService: Update v${versionInfo.latestVersionCode} was dismissed recently.');
            return;
          }
        }
      }

      if (!context.mounted) return;

      _isDialogShown = true;
      final language = Provider.of<AppConfigProvider>(context, listen: false).language;

      await showDialog<void>(
        context: context,
        barrierDismissible: !isForceUpdate,
        builder: (dialogContext) {
          return UpdateDialog(
            versionInfo: versionInfo,
            language: language,
            isForceUpdate: isForceUpdate,
            onDismiss: () {
              // Запоминаем отказ на 24 часа
              StorageService.setInt('last_dismissed_version_code', versionInfo.latestVersionCode);
              StorageService.setInt(
                'last_dismissed_version_time',
                DateTime.now().millisecondsSinceEpoch,
              );
              Navigator.of(dialogContext).pop();
            },
            onUpdate: () async {
              await launchStore(versionInfo.storeUrl);
            },
          );
        },
      );
    } catch (e) {
      debugPrint('UpdateService.checkForUpdates error (graceful fallback): $e');
    } finally {
      _isDialogShown = false;
    }
  }

  /// Открытие страницы приложения в Google Play Store
  static Future<void> launchStore([String? customUrl]) async {
    final marketUri = Uri.parse('market://details?id=$packageName');
    final webUri = Uri.parse(
      customUrl ?? 'https://play.google.com/store/apps/details?id=$packageName',
    );

    try {
      // 1. Сначала пытаемся открыть нативное приложение Play Store
      if (await canLaunchUrl(marketUri)) {
        await launchUrl(marketUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (e) {
      debugPrint('UpdateService: Failed to open market URI: $e');
    }

    try {
      // 2. Резервный переход через веб-браузер
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('UpdateService: Failed to open web URI: $e');
    }
  }
}
