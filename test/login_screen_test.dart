import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqmarket/screens/login_screen.dart';

void main() {
  Widget createTestableWidget() {
    return const MaterialApp(
      home: LoginScreen(lang: 'Русский'),
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
        MaterialApp(
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
        MaterialApp(
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
