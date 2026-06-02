import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

/// Mixin для управления подпиской на изменения интернет-соединения.
///
/// Использование:
/// ```dart
/// class _MyScreenState extends State<MyScreen> with TaxiConnectivityMixin {
///   @override
///   void initState() {
///     super.initState();
///     initConnectivity();
///   }
///
///   @override
///   void dispose() {
///     disposeConnectivity();
///     super.dispose();
///   }
/// }
/// ```
mixin TaxiConnectivityMixin<T extends StatefulWidget> on State<T> {
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool isOffline = false;

  /// Инициализирует проверку и подписку на изменения соединения.
  /// Вызывать в `initState()`.
  void initConnectivity() {
    _checkConnectivity();
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);
  }

  /// Отменяет подписку. Вызывать в `dispose()`.
  void disposeConnectivity() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final offline = results.isEmpty ||
        results.every((r) => r == ConnectivityResult.none);
    if (mounted && isOffline != offline) {
      setState(() => isOffline = offline);
    }
  }

  Future<void> _checkConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    if (mounted) {
      setState(() {
        isOffline = results.isEmpty ||
            results.every((r) => r == ConnectivityResult.none);
      });
    }
  }
}
