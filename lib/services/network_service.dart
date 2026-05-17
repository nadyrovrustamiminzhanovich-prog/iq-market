import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkService {
  /// Быстрая проверка, есть ли интернет прямо сейчас
  static Future<bool> isOffline() async {
    final results = await Connectivity().checkConnectivity();
    return results.isEmpty || results.every((r) => r == ConnectivityResult.none);
  }
}
