import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:iqmarket/services/translation_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'dart:ui';

import 'screens/home/home_screen.dart';
import 'services/notification_service.dart';
import 'services/analytics_service.dart';
import 'providers/app_config_provider.dart';
import 'theme/app_theme.dart';
import 'widgets/common/offline_wrapper.dart';
import 'screens/splash_screen.dart';


/// Включает системный Android Photo Picker.
///
/// Без него image_picker открывает старый ACTION_GET_CONTENT, который параметр
/// `limit` просто ВЫБРАСЫВАЕТ (см. ImagePickerDelegate.launchMultiPickImage-
/// FromGalleryIntent — ветка else вообще его не использует). Из-за этого в
/// галерее можно было отметить сколько угодно фото, а ограничение срабатывало
/// только после «Готово»: лишние молча отрезались уже в приложении. Photo
/// Picker гасит выбор прямо в галерее, когда набран максимум.
///
/// Флаг есть только у Android-реализации, поэтому проверяем тип: на остальных
/// платформах вызов ничего не делает (на iOS PHPicker соблюдает limit сам).
void _enableAndroidPhotoPicker() {
  final ImagePickerPlatform picker = ImagePickerPlatform.instance;
  if (picker is ImagePickerAndroid) {
    picker.useAndroidPhotoPicker = true;
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  _enableAndroidPhotoPicker();

  // Pass all uncaught "fatal" errors from the framework to Crashlytics
  FlutterError.onError = (FlutterErrorDetails details) {
    FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  };

  // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
  
  // Launch AppBootstrap instantly to dismiss the native OS splash screen and show
  // the premium pulsing custom preloader screen.
  runApp(const AppBootstrap());
}


class MainApp extends StatelessWidget {
  final Widget home;
  const MainApp({super.key, required this.home});

  @override
  Widget build(BuildContext context) {
    final config = Provider.of<AppConfigProvider>(context);
    
    return MaterialApp(
      title: 'IQ-Market',
      navigatorKey: NotificationService.navigatorKey,
      builder: (context, child) {
        // Global Error Boundary - World Class Professional approach
        ErrorWidget.builder = (FlutterErrorDetails details) {
          return Material(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'ОШИБКА ВИДЖЕТА:',
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.red),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      // В релизе Flutter по умолчанию рисует нейтральный серый
                      // блок именно потому, что details.exception/stack могут
                      // содержать имена классов и внутренние пути — этот
                      // кастомный ErrorWidget показывал их пользователю
                      // безусловно, включая релизные сборки.
                      child: kDebugMode
                          ? SelectableText(
                              '${details.exception}\n\n${details.stack}',
                              style: GoogleFonts.firaCode(color: Colors.black, fontSize: 10),
                            )
                          : Text(
                              TranslationService.t('unexpectedErrorMsg', Provider.of<AppConfigProvider>(context, listen: false).language),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(color: Colors.black87, fontSize: 14),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => NotificationService.navigatorKey.currentState?.pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const IQMarketHome()),
                      (route) => false,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A80F0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(TranslationService.t('returnToHome', Provider.of<AppConfigProvider>(context, listen: false).language), style: const TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          );
        };
        return OfflineWrapper(child: child!);
      },
      home: home,
      debugShowCheckedModeBanner: false,
      navigatorObservers: [AnalyticsService.observer, AnalyticsService.routeObserver],
      theme: AppTheme.lightTheme,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // ✅ 'ug' (уйгурский) не поддерживается GlobalMaterialLocalizations,
      // поэтому Flutter сам сделает fallback на ближайший поддерживаемый locale.
      // localeResolutionCallback ниже гарантирует безопасный fallback на 'ru'.
      supportedLocales: const [
        Locale('ru', 'RU'),
        Locale('kk', 'KZ'),
        Locale('en', 'US'),
      ],
      localeResolutionCallback: (locale, supportedLocales) {
        // Уйгурский (`ug`) и любой другой неподдерживаемый язык
        // безопасно фоллбэчится на русский.
        for (final supported in supportedLocales) {
          if (supported.languageCode == (locale?.languageCode ?? 'ru')) {
            return supported;
          }
        }
        return const Locale('ru', 'RU');
      },
      locale: config.locale,
    );
  }
}

class ErrorApp extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ErrorApp({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 80, color: Colors.redAccent),
                const SizedBox(height: 24),
                Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 24),
                ElevatedButton(onPressed: onRetry, child: Text(TranslationService.t('retryBtn', Provider.of<AppConfigProvider>(context, listen: false).language)))
              ],
            ),
          ),
        ),
      ),
    );
  }
}
