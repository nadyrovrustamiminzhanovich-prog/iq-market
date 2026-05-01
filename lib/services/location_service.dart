import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/foundation.dart';

class LocationService {
  // Получаем текущий город по GPS
  static Future<String?> getCurrentCity() async {
    try {
      bool serviceEnabled;
      LocationPermission permission;

      // 1. Проверяем, включен ли GPS в телефоне
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      // 2. Проверяем разрешения приложения
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      // 3. Получаем координаты
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      );

      // 4. Переводим координаты в название города
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude, 
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks[0];
        // Если это маленький поселок - берем subLocality или locality
        return place.locality ?? place.subLocality ?? place.administrativeArea;
      }

      return null;
    } catch (e) {
      debugPrint('Ошибка GPS: $e');
      return null;
    }
  }
}
