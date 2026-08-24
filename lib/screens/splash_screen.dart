import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import '../main.dart';
import 'home/home_screen.dart';
import '../services/analytics_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../providers/taxi_provider.dart';
import '../providers/app_config_provider.dart';
import '../services/version_service.dart';
import 'force_update_screen.dart';

import '../services/feed_cache_service.dart';
import '../services/deep_link_service.dart';

/// AppBootstrap manages the background initialization of Firebase, App Check,
/// FCM notifications, and auth services. It displays a premium loader and 
/// handles error recovery on startup.
class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}
class _AppBootstrapState extends State<AppBootstrap> {
  bool _initialized = false;
  String? _error;
  String? _updateStoreUrl;
  late TaxiProvider _taxiProvider;
  late AppConfigProvider _appConfigProvider;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    try {
      // 1. Parallel high-speed core initialization (Firebase + Storage)
      await Future.wait([
        Firebase.initializeApp(),
        StorageService.init(),
      ]);

      // 2. Set Firestore cache/offline settings immediately
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: 104857600, // 100 MB cache limit
      );

      // 3. Pre-initialize in-memory feed cache for 0ms home feed rendering
      await FeedCacheService.init();

      // 4. Initialize lightweight providers immediately
      _taxiProvider = TaxiProvider();
      _appConfigProvider = AppConfigProvider();

      // Load saved language for initial locale
      final savedLang = StorageService.getString('app_lang') ?? 'Русский';
      final localeMap = {
        'Русский': const Locale('ru', 'RU'),
        'Қазақша': const Locale('kk', 'KZ'),
        'Уйғурчә': const Locale('ug'),
      };
      final initialLocale = localeMap[savedLang] ?? const Locale('ru', 'RU');
      _appConfigProvider.setLocale(initialLocale);

      // 5. Bind language synchronization events
      _appConfigProvider.onLanguageChanged = (lang) {
        _taxiProvider.setLanguage(lang);
      };
      _taxiProvider.onLanguageChanged = (lang) {
        _appConfigProvider.setLanguage(lang);
      };

      // 6. Fast non-blocking version check with timeout (avoids freeze on bad mobile network)
      VersionService.checkVersion(timeout: const Duration(milliseconds: 1000)).then((versionResult) {
        if (versionResult.forceUpdateStoreUrl != null && mounted) {
          setState(() {
            _updateStoreUrl = versionResult.forceUpdateStoreUrl;
          });
        } else if (versionResult.optionalUpdate != null) {
          VersionService.pendingOptionalUpdate = versionResult.optionalUpdate;
        }
      }).catchError((e) {
        debugPrint('[AppBootstrap] Version check non-fatal error: $e');
      });

      // 7. Render UI INSTANTLY (< 300ms Cold Start!)
      if (mounted) {
        setState(() {
          _initialized = true;
        });
      }

      // 8. Initialize AppCheck and background services concurrently without blocking UI
      _initServicesInBackground();
    } catch (e, stack) {
      debugPrint('Initialization error: $e');
      if (mounted) {
        setState(() {
          _error = 'Ошибка подключения к серверу. Проверьте интернет-соединение.';
        });
      }
      try {
        FirebaseCrashlytics.instance.recordError(e, stack, fatal: true);
      } catch (_) {}
    }
  }

  Future<void> _initServicesInBackground() async {
    try {
      // 1. App Check activation in background (does not block UI thread)
      FirebaseAppCheck.instance.activate(
        providerAndroid: kDebugMode ? const AndroidDebugProvider() : const AndroidPlayIntegrityProvider(),
        providerApple: kDebugMode ? const AppleDebugProvider() : const AppleDeviceCheckProvider(),
      ).catchError((e) {
        debugPrint('[AppBootstrap] AppCheck background activation error: $e');
      });

      // 2. Initialize secondary services in parallel
      await Future.wait([
        AnalyticsService.init(),
        AuthService.init(),
        NotificationService.init(),
      ]);

      // 3. Initialize Deep Linking listener
      DeepLinkService.init(NotificationService.navigatorKey);

      // 4. Set global error tracking handlers
      FlutterError.onError = (errorDetails) {
        FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };

      AnalyticsService.logAppOpen();
    } catch (e, stack) {
      debugPrint('Background services initialization error: $e');
      try {
        FirebaseCrashlytics.instance.recordError(e, stack, fatal: false);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return MaterialApp(
        home: _error != null
            ? ErrorScreen(
                message: _error!,
                onRetry: () {
                  setState(() {
                    _error = null;
                  });
                  _initApp();
                },
              )
            : const PreloadSplashScreen(),
        theme: ThemeData(scaffoldBackgroundColor: Colors.white),
        debugShowCheckedModeBanner: false,
      );
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _taxiProvider),
        ChangeNotifierProvider.value(value: _appConfigProvider),
      ],
      child: _updateStoreUrl != null
          ? ForceUpdateScreen(storeUrl: _updateStoreUrl!)
          : MainApp(
              home: const IQMarketHome(),
            ),
    );
  }
}

/// Premium custom loader screen with a soft pulsing logo animation and clean linear indicator.
class PreloadSplashScreen extends StatefulWidget {
  const PreloadSplashScreen({super.key});

  @override
  State<PreloadSplashScreen> createState() => _PreloadSplashScreenState();
}

class _PreloadSplashScreenState extends State<PreloadSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();

    // Set transparent status bar overlay styled for startup
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _scale = Tween<double>(begin: 0.94, end: 1.04).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutSine),
    );
    _opacity = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (_, child) => Opacity(
                  opacity: _opacity.value,
                  child: Transform.scale(
                    scale: _scale.value,
                    child: child,
                  ),
                ),
                child: Image.asset(
                  'assets/logo.png',
                  width: 150,
                  height: 150,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              bottom: 60,
              left: 40,
              right: 40,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4A80F0)),
                      strokeWidth: 2.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Загрузка IQ-Market...',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF94A3B8),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Styled Error Screen to gracefully recover if internet/Firebase initializations fail.
class ErrorScreen extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ErrorScreen({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Icon(
                  Icons.wifi_off_rounded,
                  size: 48,
                  color: Colors.redAccent,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Ошибка подключения',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF64748B),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: onRetry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A80F0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Повторить попытку',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
