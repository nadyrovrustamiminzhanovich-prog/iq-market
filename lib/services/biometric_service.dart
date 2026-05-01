import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  // Проверка: поддерживает ли устройство биометрию?
  static Future<bool> canAuthenticate() async {
    final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
    final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
    return canAuthenticate;
  }

  // Сама аутентификация
  static Future<bool> authenticate() async {
    try {
      // В local_auth 3.0.x API изменился: аргументы теперь передаются напрямую в authenticate,
      // а параметр 'options' (AuthenticationOptions) больше не используется во внешнем API.
      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: 'Пожалуйста, подтвердите личность для входа в профиль',
        biometricOnly: true,
      );
      return didAuthenticate;
    } on PlatformException catch (e) {
      debugPrint('Ошибка биометрии: $e');
      return false;
    }
  }

  // Получение списка доступных методов
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    return await _auth.getAvailableBiometrics();
  }
}
