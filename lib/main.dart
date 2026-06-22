import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/home/home_screen.dart';
import 'services/notification_service.dart';
import 'services/analytics_service.dart';
import 'providers/app_config_provider.dart';
import 'theme/app_theme.dart';
import 'widgets/common/offline_wrapper.dart';
import 'screens/splash_screen.dart';


void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
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
                    'Упс! Что-то пошло не так',
                    style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Мы уже получили отчет и работаем над исправлением.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(color: Colors.grey[600]),
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