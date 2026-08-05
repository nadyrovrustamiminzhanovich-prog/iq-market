import 'dart:math';
import 'package:iqmarket/services/storage_service.dart';

/// Анонимный идентификатор установки приложения (не привязан к железу,
/// сбрасывается при переустановке). Используется только для эвристики
/// "объявления с одного устройства под разными аккаунтами" — сервер
/// помечает такие объявления флагом для модератора, не блокирует.
class DeviceIdentityService {
  static const _key = 'device_install_id';
  static String? _cached;

  static Future<String> getInstallId() async {
    if (_cached != null) return _cached!;
    final existing = StorageService.getString(_key);
    if (existing != null && existing.isNotEmpty) {
      _cached = existing;
      return existing;
    }
    final generated = _generateUuidV4();
    await StorageService.setString(_key, generated);
    _cached = generated;
    return generated;
  }

  static String _generateUuidV4() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    bytes[6] = (bytes[6] & 0x0F) | 0x40; // версия 4
    bytes[8] = (bytes[8] & 0x3F) | 0x80; // вариант RFC 4122
    String hex(int start, int end) => bytes
        .sublist(start, end)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
  }
}
