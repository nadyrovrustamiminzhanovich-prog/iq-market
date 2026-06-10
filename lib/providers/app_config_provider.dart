import 'package:flutter/material.dart';
import 'package:iqmarket/services/storage_service.dart';
import 'package:iqmarket/services/user_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AppConfigProvider with ChangeNotifier {
  String _language = StorageService.getString('app_lang') ?? 'Русский';
  String _city = StorageService.getString('user_location') ?? 'Все';
  Set<String> _favoriteIds = Set<String>.from(StorageService.getStringList('favorites') ?? []);
  Locale _locale = const Locale('ru', 'RU');
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  void Function(String)? onLanguageChanged;

  AppConfigProvider() {
    _loadFavoritesFromFirestore();
  }

  Locale get locale => _locale;

  void setLocale(Locale loc) {
    _locale = loc;
    notifyListeners();
  }

  String get language => _language;
  String get city => _city;
  Set<String> get favoriteIds => _favoriteIds;
  bool get isDarkMode => StorageService.getString('theme') == 'Dark';

  void setLanguage(String lang) {
    if (_language == lang) return;
    _language = lang;
    StorageService.setString('app_lang', lang);
    
    final localeMap = {
      'Русский': const Locale('ru', 'RU'),
      'Қазақша': const Locale('kk', 'KZ'),
      'Уйғурчә': const Locale('en', 'US'),
    };
    _locale = localeMap[lang] ?? const Locale('ru', 'RU');
    
    notifyListeners();
    _syncToFirestore({'language': lang});
    onLanguageChanged?.call(lang);
  }

  void setCity(String city) {
    _city = city;
    StorageService.setString('user_location', city);
    notifyListeners();
    _syncToFirestore({'location': city});
  }

  Future<void> _syncToFirestore(Map<String, dynamic> data) async {
    final uid = UserService.currentUid;
    if (uid != null) {
      try {
        await _db.collection('users').doc(uid).set(data, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Error syncing config to Firestore: $e');
      }
    }
  }

  Future<void> _loadFavoritesFromFirestore() async {
    final uid = UserService.currentUid;
    if (uid == null) return;

    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        
        // Sync favorites
        final List<dynamic>? firestoreFavorites = data['favoriteIds'];
        if (firestoreFavorites != null) {
          _favoriteIds.addAll(firestoreFavorites.map((e) => e.toString()));
          StorageService.setStringList('favorites', _favoriteIds.toList());
        }

        // Sync location
        final String? firestoreLocation = data['location'];
        if (firestoreLocation != null && firestoreLocation.isNotEmpty) {
          _city = firestoreLocation;
          StorageService.setString('user_location', firestoreLocation);
        }

        // Sync language
        final String? firestoreLanguage = data['language'];
        if (firestoreLanguage != null && firestoreLanguage.isNotEmpty) {
          if (_language != firestoreLanguage) {
            _language = firestoreLanguage;
            StorageService.setString('app_lang', firestoreLanguage);
            final localeMap = {
              'Русский': const Locale('ru', 'RU'),
              'Қазақша': const Locale('kk', 'KZ'),
              'Уйғурчә': const Locale('en', 'US'),
            };
            _locale = localeMap[firestoreLanguage] ?? const Locale('ru', 'RU');
            onLanguageChanged?.call(firestoreLanguage);
          }
        }

        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading favorites/config from Firestore: $e');
    }
  }

  void toggleFavorite(String id) async {
    if (_favoriteIds.contains(id)) {
      _favoriteIds.remove(id);
    } else {
      _favoriteIds.add(id);
    }
    
    // Save locally
    StorageService.setStringList('favorites', _favoriteIds.toList());
    notifyListeners();

    // Sync to Firestore if logged in
    final uid = UserService.currentUid;
    if (uid != null) {
      try {
        await _db.collection('users').doc(uid).set({
          'favoriteIds': _favoriteIds.toList(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Error syncing favorites to Firestore: $e');
      }
    }
  }

  bool isFavorite(String id) => _favoriteIds.contains(id);
}
