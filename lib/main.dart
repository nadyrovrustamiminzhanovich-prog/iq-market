import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import 'dart:async';

import 'screens/home/home_screen.dart';
import 'screens/splash_screen.dart';
import 'services/storage_service.dart';
import 'services/notification_service.dart';
import 'services/analytics_service.dart';
import 'providers/taxi_provider.dart';
import 'providers/app_config_provider.dart';
import 'theme/app_theme.dart';
import 'services/auth_service.dart';
import 'widgets/common/offline_wrapper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  bool isFirebaseReady = false;
  try {
    await Firebase.initializeApp();
    await AnalyticsService.init(); 
    await AuthService.init();
    
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: 104857600, // 100 MB cache limit to prevent memory bloating
    );

    await FirebaseAppCheck.instance.activate(
      androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
    );

    // Pass all uncaught "fatal" errors from the framework to Crashlytics
    FlutterError.onError = (errorDetails) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
    };

    // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

    isFirebaseReady = true;
  } catch (e, stack) {
    debugPrint('Critical Firebase Init Error: $e');
    if (isFirebaseReady) {
      FirebaseCrashlytics.instance.recordError(e, stack, fatal: true);
    }
  }

  await StorageService.init();
  NotificationService.init();
  AnalyticsService.logAppOpen();
  
  // Load saved language
  final savedLang = StorageService.getString('app_lang') ?? 'Русский';
  final localeMap = {
    'Русский': const Locale('ru', 'RU'),
    'Қазақша': const Locale('kk', 'KZ'),
    'Уйғурчә': const Locale('en', 'US'), // Assuming English fallback for Uyghur if not fully supported by system locales
  };
  final initialLocale = localeMap[savedLang] ?? const Locale('ru', 'RU');
  
  if (!isFirebaseReady) {
    runApp(ErrorApp(message: 'Ошибка подключения к серверу. Проверьте интернет.', onRetry: () => main()));
    return;
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TaxiProvider()),
        ChangeNotifierProvider(create: (_) => AppConfigProvider()..setLocale(initialLocale)),
      ],
      child: const MainApp(),
    ),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

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
                    'Упс! Что-то пошло не так',
                    style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Мы уже получили отчет и работаем над исправлением.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const IQMarketHome()),
                      (route) => false,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A80F0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Вернуться на главную', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          );
        };
        return OfflineWrapper(child: child!);
      },
      home: SplashScreen(nextScreen: const IQMarketHome()),
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
                ElevatedButton(onPressed: onRetry, child: const Text('Повторить'))
              ],
            ),
          ),
        ),
      ),
    );
  }
}