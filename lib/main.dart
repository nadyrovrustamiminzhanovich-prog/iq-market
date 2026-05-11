import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
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
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
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
  
  if (!isFirebaseReady) {
    runApp(ErrorApp(message: 'Ошибка подключения к серверу. Проверьте интернет.', onRetry: () => main()));
    return;
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TaxiProvider()),
        ChangeNotifierProvider(create: (_) => AppConfigProvider()),
      ],
      child: const OfflineWrapper(child: MainApp()),
    ),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IQ-Market',
      navigatorKey: NotificationService.navigatorKey,
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
      locale: const Locale('ru', 'RU'),
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