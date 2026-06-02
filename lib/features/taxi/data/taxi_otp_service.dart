import 'dart:math';

/// Сервис для управления OTP-паролями.
/// 
/// ВАЖНО: В реальном production этот класс должен обращаться 
/// к FirebaseAuth.instance.verifyPhoneNumber, а не генерировать код локально.
/// Мы инкапсулируем эту логику здесь, чтобы UI слой не зависел от реализации.
class TaxiOtpService {
  String _currentOtp = '';

  /// Имитация отправки SMS. Возвращает сгенерированный код.
  Future<String> sendSms(String phoneNumber) async {
    // Симуляция сетевой задержки
    await Future.delayed(const Duration(milliseconds: 800));
    _currentOtp = List.generate(6, (_) => Random().nextInt(10)).join();
    return _currentOtp;
  }

  /// Проверяет, совпадает ли введенный код с отправленным.
  bool verifyOtp(String inputCode) {
    return inputCode == _currentOtp;
  }
}
