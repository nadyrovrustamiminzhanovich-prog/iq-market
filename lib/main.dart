import 'package:flutter/material.dart';
import 'package:iqmarket/services/translation_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'dart:ui';

import 'screens/home/home_screen.dart';
import 'services/notification_service.dart';
import 'services/analytics_service.dart';
import 'providers/app_config_provider.dart';
import 'theme/app_theme.dart';
import 'widgets/common/offline_wrapper.dart';
import 'screens/splash_screen.dart';


void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
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
                      child: SelectableText(
                        '${details.exception}\n\n${details.stack}',
                        style: GoogleFonts.firaCode(color: Colors.black, fontSize: 10),
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
      navigatorObservers: [AnalyticsService.observer],
      theme: AppTheme.lightTheme,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ru', 'RU'),
        Locale('kk', 'KZ'),
        Locale('ug'),
        Locale('en', 'US'),
      ],
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
