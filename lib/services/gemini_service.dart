import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'firebase_options.dart';

// Импорты твоих сервисов (проверь пути, если они отличаются)
import 'services/gemini_service.dart';
import 'services/api_keys.dart';

void main() async {
  // 1. Обязательная инициализация привязок Flutter
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Инициализация Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 3. Настройка App Check (Тот самый замок для базы данных)
  // Это позволит твоему ПК получать данные из Firebase
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
  );

  // 4. Инициализация твоего ИИ Gemini
  // Я закомментировал AnalyticsService.init(), чтобы не было ошибки при сборке
  // await AnalyticsService.init(); 

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IQ Market',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MyHomePage(), // Замени на свой стартовый экран
    );
  }
}

// Заглушка главного экрана (замени на свой, если он в другом файле)
class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('IQ Market')),
      body: const Center(child: Text('Добро пожаловать в IQ Market!')),
    );
  }
}