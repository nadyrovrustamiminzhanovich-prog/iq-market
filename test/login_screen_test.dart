import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:provider/provider.dart';
import 'package:iqmarket/providers/app_config_provider.dart';
import 'package:iqmarket/screens/login_screen.dart';
import 'package:iqmarket/services/storage_service.dart';

final List<int> _kTransparentImage = [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82
];

class _MockHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _MockHttpClient();
}

class _MockHttpClient extends Fake implements HttpClient {
  @override
  bool autoUncompress = false;
  @override
  String? userAgent;
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _MockHttpClientRequest();
}

class _MockHttpHeaders extends Fake implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
}

class _MockHttpClientRequest extends Fake implements HttpClientRequest {
  @override
  final HttpHeaders headers = _MockHttpHeaders();
  @override
  Future<HttpClientResponse> close() async => _MockHttpClientResponse();
}

class _MockHttpClientResponse extends Fake implements HttpClientResponse {
  @override
  int get statusCode => 200;
  @override
  int get contentLength => _kTransparentImage.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable([_kTransparentImage]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
    HttpOverrides.global = _MockHttpOverrides();
    SharedPreferences.setMockInitialValues({});
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    await StorageService.init();
  });

  Widget createTestableWidget({Widget? child}) {
    return ChangeNotifierProvider<AppConfigProvider>(
      create: (_) => AppConfigProvider(),
      child: MaterialApp(
        home: child ?? const LoginScreen(lang: 'Русский'),
      ),
    );
  }

  group('LoginScreen Widget Tests', () {
    testWidgets('Renders choice screen initially without back button', (WidgetTester tester) async {
      await tester.pumpWidget(createTestableWidget());
      await tester.pumpAndSettle();

      // Check title and subtitle
      expect(find.text('Добро пожаловать!'), findsOneWidget);
      expect(find.text('Войдите за несколько секунд'), findsOneWidget);
      expect(find.text('MARKET'), findsOneWidget);

      // Check buttons are present
      expect(find.text('Продолжить с Telegram'), findsOneWidget);
      expect(find.text('Продолжить с Google'), findsOneWidget);
      expect(find.text('Продолжить с Email'), findsOneWidget);
      expect(find.text('Регистрация'), findsOneWidget);

      // Verify the AppBar back button is NOT present on the landing screen
      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsNothing);
    });

    testWidgets('Transitions to Email Form when clicking Продолжить с Email', (WidgetTester tester) async {
      await tester.pumpWidget(createTestableWidget());
      await tester.pumpAndSettle();

      // Scroll to the button to make sure it is in view and clickable
      final emailBtnFinder = find.text('Продолжить с Email');
      await tester.ensureVisible(emailBtnFinder);
      await tester.pumpAndSettle();

      // Tap on Continue with Email
      await tester.tap(emailBtnFinder);
      await tester.pumpAndSettle();

      // Verify it transitions to Email/Password form
      expect(find.text('Email адрес'), findsOneWidget);
      expect(find.text('Пароль'), findsOneWidget);

      // Verify the back button in AppBar is now visible
      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);

      // Tap the back button
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();

      // Verify it returns to the choice screen
      expect(find.text('Продолжить с Email'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsNothing);
    });

    testWidgets('Transitions to registration form when clicking Регистрация on landing screen', (WidgetTester tester) async {
      await tester.pumpWidget(createTestableWidget());
      await tester.pumpAndSettle();

      // Scroll to "Регистрация" link to make sure it is in view
      final regFinder = find.text('Регистрация');
      await tester.ensureVisible(regFinder);
      await tester.pumpAndSettle();

      // Tap "Регистрация" text/button
      await tester.tap(regFinder);
      await tester.pumpAndSettle();

      // Verify registration form is shown (includes "Ваше имя" and "Повторите пароль")
      expect(find.text('Ваше имя'), findsOneWidget);
      expect(find.text('Повторите пароль'), findsOneWidget);
      expect(find.text('Создайте новый аккаунт'), findsOneWidget);

      // Verify the back button in AppBar is visible
      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);

      // Tap back to return to choice screen
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Продолжить с Email'), findsOneWidget);
    });

    testWidgets('Renders choice screen with back button if navigator can pop, and tapping it pops the screen', (WidgetTester tester) async {
      final key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        ChangeNotifierProvider<AppConfigProvider>(
          create: (_) => AppConfigProvider(),
          child: MaterialApp(
            navigatorKey: key,
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LoginScreen(lang: 'Русский'),
                      ),
                    );
                  },
                  child: const Text('Go to Login'),
                ),
              ),
            ),
          ),
        ),
      );

      // Tap Go to Login
      await tester.tap(find.text('Go to Login'));
      await tester.pumpAndSettle();

      // We should be on the choice screen
      expect(find.text('Продолжить с Email'), findsOneWidget);

      // Verify the AppBar back button is visible since Navigator.canPop is true
      final backButtonFinder = find.byIcon(Icons.arrow_back_ios_new_rounded);
      expect(backButtonFinder, findsOneWidget);

      // Tap the back button
      await tester.tap(backButtonFinder);
      await tester.pumpAndSettle();

      // We should be back to the initial screen with "Go to Login"
      expect(find.text('Go to Login'), findsOneWidget);
      expect(find.text('Продолжить с Email'), findsNothing);
    });

    testWidgets('System back button flow: pops choice screen, but only transitions form to choice screen first', (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<AppConfigProvider>(
          create: (_) => AppConfigProvider(),
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen(lang: 'Русский')),
                  ),
                  child: const Text('Go to Login'),
                ),
              ),
            ),
          ),
        ),
      );
      
      // Navigate to Login Screen
      await tester.tap(find.text('Go to Login'));
      await tester.pumpAndSettle();
      
      // Go to Email Form
      final emailBtnFinder = find.text('Продолжить с Email');
      await tester.ensureVisible(emailBtnFinder);
      await tester.pumpAndSettle();
      await tester.tap(emailBtnFinder);
      await tester.pumpAndSettle();
      
      // Verify email form is shown
      expect(find.text('Email адрес'), findsOneWidget);

      // 1. Simulate system back button when showEmailForm == true
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      // Should be back on the choice screen
      expect(find.text('Продолжить с Email'), findsOneWidget);
      expect(find.text('Email адрес'), findsNothing);

      // 2. Simulate system back button when showEmailForm == false
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      // Should have popped the entire LoginScreen
      expect(find.text('Go to Login'), findsOneWidget);
      expect(find.text('Продолжить с Email'), findsNothing);
    });
  });
}
