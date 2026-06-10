import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

class TaxiPrefsService {
  Future<Map<String, dynamic>> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    
    final fullName = prefs.getString('user_name') ?? "Александр Иванов";
    final nameParts = fullName.split(' ');
    final firstName = nameParts.elementAt(0);
    final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : "";
    
    final imgPath = prefs.getString('user_image');
    final profileImage = (imgPath != null && imgPath.isNotEmpty) ? File(imgPath) : null;

    final savedMainLang = prefs.getString('app_lang');
    String mappedLang = 'ru';
    if (savedMainLang != null) {
      if (savedMainLang == 'Қазақша') mappedLang = 'kz';
      else if (savedMainLang == 'Уйғурчә') mappedLang = 'uyg';
    } else {
      mappedLang = prefs.getString('taxi_lang') ?? 'ru';
    }

    final telegramChatId = prefs.getString('taxi_tg_chat_id');

    return {
      'curLang': mappedLang,
      'isDarkGlobal': false, // FORCE LIGHT MODE
      'isLoggedIn': prefs.getBool('taxi_logged_in') ?? true,
      'firstName': firstName,
      'lastName': lastName,
      'profileImage': profileImage,
      'phone': prefs.getString('taxi_phone') ?? "+7 701 000 11 22",
      'driverCar': prefs.getString('taxi_car') ?? "Toyota Camry 70",
      'driverPlate': prefs.getString('taxi_plate') ?? "777 BBA 05",
      'isVehicleVerified': prefs.getBool('taxi_verified') ?? false,
      'notifEnabled': prefs.getBool('taxi_notif') ?? true,
      'telegramChatId': telegramChatId,
      'isTelegramVerified': telegramChatId != null,
      'verificationStatus': prefs.getString('taxi_verif_status') ?? 'none',
    };
  }

  Future<void> save(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove(key);
    } else {
      if (value is String) await prefs.setString(key, value);
      if (value is bool) await prefs.setBool(key, value);
      if (value is int) await prefs.setInt(key, value);
    }
  }
}
