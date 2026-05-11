import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

import 'screens/home/home_screen.dart';
import 'screens/splash_screen.dart';
import 'services/storage_service.dart';
import 'services/notification_service.dart';
import 'services/analytics_service.dart';
import 'providers/taxi_provider.dart';
import 'providers/app_config_provider.dart';
import 'theme/app_theme.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp();
    
    // 1. ИСПРАВЛЯЕМ СПАМ: Инициализируем аналитику ПЕРЕД использованием
    // Мы вызываем метод init() (если он есть) или логируем открытие
    await AnalyticsService.init(); 

    await AuthService.init();
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    // 2. ИСПРАВЛЯЕМ ОШИБКУ 403: 
    // Добавляем принудительный запуск в режиме отладки для Android
    await FirebaseAppCheck.instance.activate(
      androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
    );

  } catch (e) {
    debugPrint('Firebase Init Error: $e');
  }

  await StorageService.init();
  NotificationService.init();
  
  // Лог открытия теперь пойдет после инициализации
  AnalyticsService.logAppOpen();
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TaxiProvider()),
        ChangeNotifierProvider(create: (_) => AppConfigProvider()),
      ],
      child: MaterialApp(
        title: 'IQ-Market',
        navigatorKey: NotificationService.navigatorKey,
        home: SplashScreen(nextScreen: IQMarketHome()),
        debugShowCheckedModeBanner: false,
        navigatorObservers: [AnalyticsService.observer],
        themeMode: ThemeMode.light,
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
        locale: const Locale('ru', 'RU'),
      ),
    ),
  );
}