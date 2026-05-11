import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static late SharedPreferences _prefs;

  // Инициализация (вызовем в main)
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Общие методы сохранения
  static Future<void> setString(String key, String value) async => await _prefs.setString(key, value);
  static String? getString(String key) => _prefs.getString(key);

  static Future<void> setBool(String key, bool value) async => await _prefs.setBool(key, value);
  static bool getBool(String key, {bool defaultValue = false}) => _prefs.getBool(key) ?? defaultValue;

  static Future<void> setInt(String key, int value) async => await _prefs.setInt(key, value);
  static int? getInt(String key) => _prefs.getInt(key);

  static Future<bool> setStringList(String key, List<String> value) {
    return _prefs.setStringList(key, value);
  }

  static List<String>? getStringList(String key) {
    return _prefs.getStringList(key);
  }

  // Специальные методы для профиля
  static Future<void> saveProfile(String name, String? imagePath, bool isBioEnabled, String accType, {bool isVerified = false}) async {
    await _prefs.setString('user_name', name);
    if (imagePath != null) await _prefs.setString('user_image', imagePath);
    await _prefs.setBool('is_bio_enabled', isBioEnabled);
    await _prefs.setString('account_type', accType);
    await _prefs.setBool('is_verified', isVerified);
  }

  static bool get isVerified => _prefs.getBool('is_verified') ?? false;

  static Future<void> clearAll() async {
    await _prefs.clear();
  }
}
