import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:iqmarket/theme/taxi_theme.dart';
import 'package:iqmarket/translations/taxi_strings.dart';
import 'package:iqmarket/features/taxi/data/taxi_prefs_service.dart';
import 'package:iqmarket/features/taxi/data/taxi_repository.dart';
import 'package:iqmarket/features/taxi/data/taxi_sync_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:intl/intl.dart';
import 'package:iqmarket/services/storage_service.dart';

class TaxiProvider extends ChangeNotifier {
  late final TaxiPrefsService _prefs;
  late final TaxiRepository _repo;
  late final TaxiSyncService _sync;
  void Function(String)? onLanguageChanged;
  StreamSubscription<User?>? _authSub;

  // 🔒 Такси-модуль сейчас закрыт от обычных пользователей (TaxiComingSoonDialog),
  // но TaxiProvider всё равно создаётся при каждом запуске приложения в
  // AppBootstrap._initApp() — в том же try/catch, что и базовая инициализация
  // Firebase/AppConfigProvider. Любое необработанное исключение здесь раньше
  // могло помешать загрузиться ВСЕМУ приложению, включая маркетплейс, а не
  // только такси. Конструктор и loadPreferences() теперь сами ловят свои
  // ошибки — сбой в такси-коде остаётся сбоем только такси-модуля.
  TaxiProvider() {
    _prefs = TaxiPrefsService();
    _repo = TaxiRepository();
    _sync = TaxiSyncService(notifyListeners);
    try {
      loadPreferences();
      _authSub = FirebaseAuth.instance.authStateChanges().listen((_) {
        loadPreferences();
      });
    } catch (e, stack) {
      debugPrint('[TaxiProvider] init error (non-fatal, taxi module stays inert): $e');
      FirebaseCrashlytics.instance.recordError(e, stack, reason: 'TaxiProvider init failed', fatal: false);
    }
  }

  // ─── UI & Filter State ───
  int _tab = 0;
  String _from = '';
  String _to = '';
  String _driverFrom = '';
  String _driverTo = '';
  bool _loading = false;
  String _selDate = 'date';
  String _selTime = 'time';
  int _passCnt = 1;
  int _maxPrice = 0; 
  String _comment = "";
  bool _isDriverOnline = true;
  File? _techPassportPhoto;
  String _verificationStatus = 'none';

  // ─── Preferences State ───
  String _curLang = 'ru';
  bool _isDarkGlobal = false;
  bool _isLoggedIn = true;
  String _firstName = "User";
  String _lastName = "IQ";
  String? _profileImage;
  String _phone = "";
  String _driverCar = "Toyota Camry 70";
  String _driverPlate = "777 BBA 05";
  bool _isVehicleVerified = false;
  bool _notifEnabled = true;
  String? _telegramChatId;
  String? _telegramUsername;
  String? _telegramFirstName;
  String? _telegramLastName;
  bool _isTelegramVerified = false;

  // ─── Getters ───
  int get tab => _tab;
  String get from => _from;
  String get to => _to;
  String get driverFrom => _driverFrom;
  String get driverTo => _driverTo;
  bool get loading => _loading;
  bool get isLoggedIn => _isLoggedIn;
  String get selDate => _selDate;
  String get selTime => _selTime;
  int get passCnt => _passCnt;
  String get curLang => _curLang;
  bool get isDarkGlobal => _isDarkGlobal;
  String? get profileImage => _profileImage;
  String get firstName => _firstName;
  String get lastName => _lastName;
  String get phone => _phone;
  bool get notifEnabled => _notifEnabled;
  int get maxPrice => _maxPrice;
  String? get telegramChatId => _telegramChatId;
  String? get telegramUsername => _telegramUsername;
  String? get telegramFirstName => _telegramFirstName;
  String? get telegramLastName => _telegramLastName;
  bool get isTelegramVerified => _isTelegramVerified;

  /// Helper for formatted @username (e.g. '@username')
  String get formattedTelegramUsername {
    if (_telegramUsername == null || _telegramUsername!.trim().isEmpty) return '';
    final trimmed = _telegramUsername!.trim();
    return trimmed.startsWith('@') ? trimmed : '@$trimmed';
  }

  /// ✅ ISSUE-07 FIX: Single source of truth for full Telegram verification.
  /// Previously this check was duplicated 4+ times in taxi_service_screen.dart.
  /// Use this getter everywhere instead of the inline check.
  bool get isFullyTelegramVerified =>
      _isTelegramVerified ||
      (FirebaseAuth.instance.currentUser?.uid.startsWith('telegram_') == true);

  String get comment => _comment;
  String get driverCar => _driverCar;
  String get driverPlate => _driverPlate;
  bool get isVehicleVerified => isFullyTelegramVerified || _isVehicleVerified || _sync.verificationStatus == 'approved' || _sync.verificationStatus == 'approved_by_ai';
  File? get techPassportPhoto => _techPassportPhoto;
  bool get isDriverOnline => _isDriverOnline;
  String get verificationStatus => _verificationStatus;

  TaxiTheme get theme => TaxiTheme(_isDarkGlobal);

  // ─── Sync Service Getters ───
  List<Map<String, dynamic>> get myAcceptedOrders => _sync.myAcceptedOrders;
  List<Map<String, dynamic>> get myAcceptedRides => _sync.myAcceptedRides;
  List<Map<String, dynamic>> get allPassengerOrders => [..._sync.passengerOrders, ..._sync.myAcceptedOrders];
  List<Map<String, dynamic>> get allDrives => [..._sync.drives, ..._sync.myAcceptedRides];
  List<Map<String, dynamic>> get activeBids => _sync.activeBids;
  List<Map<String, dynamic>> get historyTrips => _sync.historyTrips;
  int get driverTripsCount => _sync.driverTripsCount;
  int get passengerTripsCount => _sync.passengerTripsCount;

  double getUserRating(String userId) => _sync.getUserRating(userId);
  int getUserReviewCount(String userId) => _sync.getUserReviewCount(userId);

  double getUserRatingAsDriver(String userId) => _sync.getUserRatingAsDriver(userId);
  int getUserReviewCountAsDriver(String userId) => _sync.getUserReviewCountAsDriver(userId);
  double getUserRatingAsPassenger(String userId) => _sync.getUserRatingAsPassenger(userId);
  int getUserReviewCountAsPassenger(String userId) => _sync.getUserReviewCountAsPassenger(userId);

  List<Map<String, dynamic>> get filteredDrives {
    return _sync.drives.where((d) {
      final bool matchF = _from.isEmpty || d['from'].toString().toLowerCase().contains(_from.toLowerCase());
      final bool matchT = _to.isEmpty || d['to'].toString().toLowerCase().contains(_to.toLowerCase());
      final bool matchD = _selDate == 'date' || _selDate == 'time' || _selDate.isEmpty || d['date'] == _selDate;
      final int price = (d['price'] as num).toInt();
      final bool matchP = _maxPrice == 0 || price <= _maxPrice;
      return matchF && matchT && matchD && matchP;
    }).toList()..sort((a, b) => (a['price'] as num).compareTo(b['price'] as num));
  }

  List<Map<String, dynamic>> get filteredOrders {
    return _sync.passengerOrders.where((o) {
      final bool matchF = _driverFrom.isEmpty || o['from'].toString().toLowerCase().contains(_driverFrom.toLowerCase());
      final bool matchT = _driverTo.isEmpty || o['to'].toString().toLowerCase().contains(_driverTo.toLowerCase());
      final bool matchD = _selDate == 'date' || _selDate == 'time' || _selDate.isEmpty || o['date'] == _selDate;
      final int price = (o['price'] as num).toInt();
      final bool matchP = _maxPrice == 0 || price <= _maxPrice;
      return matchF && matchT && matchD && matchP;
    }).toList()..sort((a, b) => (a['price'] as num).compareTo(b['price'] as num));
  }

  String translate(String? key) {
    if (key == null) return "";
    return (taxiStrings[_curLang]?[key] ?? key).toString();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _sync.dispose();
    super.dispose();
  }

  // ─── Setters & Preferences ───
  Future<void> loadPreferences() async {
    try {
      final data = await _prefs.loadPreferences();
      _curLang = data['curLang'];
      _isDarkGlobal = data['isDarkGlobal'];
      _isLoggedIn = data['isLoggedIn'];
      _firstName = data['firstName'];
      _lastName = data['lastName'];
      _profileImage = data['profileImage'];
      _phone = data['phone'];
      _driverCar = data['driverCar'];
      _driverPlate = data['driverPlate'];
      _isVehicleVerified = data['isVehicleVerified'];
      _notifEnabled = data['notifEnabled'];
      _telegramChatId = data['telegramChatId'];
      _isTelegramVerified = data['isTelegramVerified'];
      _verificationStatus = data['verificationStatus'];
      notifyListeners();
    } catch (e, stack) {
      debugPrint('[TaxiProvider] loadPreferences error (non-fatal): $e');
      FirebaseCrashlytics.instance.recordError(e, stack, reason: 'TaxiProvider.loadPreferences failed', fatal: false);
    }
  }

  void setTab(int index) { _tab = index; notifyListeners(); }
  void setFrom(String city) { _from = city; notifyListeners(); }
  void setTo(String city) { _to = city; notifyListeners(); }
  void setDriverFrom(String city) { _driverFrom = city; notifyListeners(); }
  void setDriverTo(String city) { _driverTo = city; notifyListeners(); }
  void setDate(String date) { _selDate = date; notifyListeners(); }
  void setTime(String time) { _selTime = time; notifyListeners(); }
  void setPassCnt(int cnt) { _passCnt = cnt; notifyListeners(); }
  void setMaxPrice(int price) { _maxPrice = price.clamp(0, 1000000); notifyListeners(); }
  void setLoading(bool val) { _loading = val; notifyListeners(); }
  void setDriverOnline(bool v) { _isDriverOnline = v; notifyListeners(); }
  void setComment(String v) { _comment = v; notifyListeners(); }

  void setLanguage(String lang) {
    String isoLang;
    if (lang == 'Русский') isoLang = 'ru';
    else if (lang == 'Қазақша') isoLang = 'kz';
    else if (lang == 'Уйғурчә') isoLang = 'uyg';
    else isoLang = lang;
    
    if (_curLang == isoLang) return;
    _curLang = isoLang;
    _prefs.save('taxi_lang', _curLang);
    notifyListeners();

    String mainLang = 'Русский';
    if (isoLang == 'ru') mainLang = 'Русский';
    else if (isoLang == 'kz') mainLang = 'Қазақша';
    else if (isoLang == 'uyg') mainLang = 'Уйғурчә';
    onLanguageChanged?.call(mainLang);
  }

  void toggleTheme() {
    _isDarkGlobal = !_isDarkGlobal;
    _prefs.save('taxi_theme', _isDarkGlobal);
    notifyListeners();
  }

  void setLoginStatus(bool status) {
    _isLoggedIn = status;
    if (!status) {
      _telegramChatId = null;
      _isTelegramVerified = false;
      _prefs.save('taxi_tg_chat_id', null);
    }
    _prefs.save('taxi_logged_in', _isLoggedIn);
    // 🔒 Такси-модуль закрыт от обычных пользователей (см. home_screen.dart _navToTaxi),
    // но setLoginStatus(true) вызывается при КАЖДОМ обычном входе в маркетплейс
    // (login_screen.dart), не только при заходе в такси. Без этой проверки
    // TaxiSyncService открывал бы 8 постоянных Firestore-стримов (taxi_rides,
    // taxi_orders, taxi_bids...) для всех пользователей маркетплейса впустую.
    final isAdmin = StorageService.getString('account_type') == 'admin';
    if (_isLoggedIn && isAdmin) _sync.startSync();
    notifyListeners();
  }

  void setProfileImage(String? imagePath) {
    _profileImage = imagePath;
    _prefs.save('user_image', imagePath);
    notifyListeners();
  }

  void updateProfile(String fn, String ln, String ph) {
    _firstName = fn; _lastName = ln; _phone = ph;
    _prefs.save('taxi_fname', fn);
    _prefs.save('taxi_lname', ln);
    _prefs.save('taxi_phone', ph);
    _prefs.save('user_name', '$fn $ln'.trim());
    notifyListeners();
  }

  void setNotifEnabled(bool val) {
    _notifEnabled = val;
    _prefs.save('taxi_notif', val);
    notifyListeners();
  }

  void setTelegramAuth(String chatId, {String? username, String? firstName, String? lastName}) {
    _telegramChatId = chatId;
    if (username != null && username.isNotEmpty) _telegramUsername = username;
    if (firstName != null && firstName.isNotEmpty) _telegramFirstName = firstName;
    if (lastName != null && lastName.isNotEmpty) _telegramLastName = lastName;
    _isTelegramVerified = true;
    _isLoggedIn = true;
    _prefs.save('taxi_tg_chat_id', chatId);
    if (_telegramUsername != null) _prefs.save('taxi_tg_username', _telegramUsername);
    _prefs.save('taxi_logged_in', true);
    notifyListeners();
  }

  Future<bool> checkUserTelegramVerification() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    if (user.uid.startsWith('telegram_')) {
      _isTelegramVerified = true;
      notifyListeners();
      return true;
    }
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data();
        final verified = data?['isVerified'] == true || data?['isTelegramVerified'] == true;
        _telegramUsername = data?['telegram_username'] ?? data?['telegramUsername'] ?? _telegramUsername;
        _telegramFirstName = data?['telegram_first_name'] ?? _telegramFirstName;
        _telegramLastName = data?['telegram_last_name'] ?? _telegramLastName;
        _telegramChatId = data?['telegramChatId'] ?? data?['telegram_chat_id'] ?? _telegramChatId;
        
        if (verified != _isTelegramVerified) {
          _isTelegramVerified = verified;
          notifyListeners();
        }
        return verified;
      }
    } catch (e) {
      debugPrint('Error checking user telegram verification: $e');
    }
    return _isTelegramVerified;
  }

  void updateCarInfo(String car, String plate) {
    _driverCar = car; _driverPlate = plate; _isVehicleVerified = false;
    _prefs.save('taxi_car', car);
    _prefs.save('taxi_plate', plate);
    _prefs.save('taxi_verified', false);
    notifyListeners();
  }

  void setTechPassport(File? img) {
    _techPassportPhoto = img;
    notifyListeners();
  }

  void setVehicleVerified(bool v) {
    _isVehicleVerified = v;
    _prefs.save('taxi_verified', v);
    notifyListeners();
  }

  void submitForManualReview({required String driverName, required String plate, required String car}) {
    _verificationStatus = 'pending';
    _prefs.save('taxi_verif_status', 'pending');
    notifyListeners();
  }

  void setVerificationStatus(String status) {
    _verificationStatus = status;
    _prefs.save('taxi_verif_status', status);
    if (status == 'approved' || status == 'approved_by_ai') {
      _isVehicleVerified = true;
      _prefs.save('taxi_verified', true);
    }
    notifyListeners();
  }

  // ─── Firebase Facade ───

  void resumeFirebaseSync() => _sync.startSync();
  void pauseFirebaseSync() => _sync.pauseSync();

  /// Сброс и принудительное обновление данных такси (pull-to-refresh)
  Future<void> refreshData() async {
    await checkUserTelegramVerification();
    _sync.pauseSync();
    _sync.startSync();
    await Future.delayed(const Duration(milliseconds: 600));
    notifyListeners();
  }

  Future<void> createPassengerOrder({
    required String from, required String to, required String date, 
    required String time, required int seats, required int price, required String comment,
  }) async {
    await _repo.createPassengerOrder(
      firstName: _firstName, lastName: _lastName, phone: _phone, profileImage: _profileImage,
      from: from, to: to, date: date, time: time, seats: seats, price: price, comment: comment,
    );
  }

  Future<void> createDriverRide({
    required String from, required String to, required String date, 
    required String time, required int seats, required int price, required String comment,
  }) async {
    await _repo.createDriverRide(
      firstName: _firstName, lastName: _lastName, phone: _phone, profileImage: _profileImage,
      driverCar: _driverCar, driverPlate: _driverPlate, isVehicleVerified: _isVehicleVerified,
      from: from, to: to, date: date, time: time, seats: seats, price: price, comment: comment,
    );
  }

  Future<void> sendBid({
    required String targetId, required String targetType, required String receiverId, required int price,
  }) async {
    await _repo.sendBid(
      targetId: targetId, targetType: targetType, receiverId: receiverId, price: price,
      firstName: _firstName, lastName: _lastName, phone: _phone, profileImage: _profileImage,
      driverCar: _driverCar, driverPlate: _driverPlate, isVehicleVerified: _isVehicleVerified,
    );
  }

  Future<void> acceptBid(String bidId) => _repo.acceptBid(bidId);
  Future<void> rejectBid(String bidId) => _repo.rejectBid(bidId);
  Future<void> cancelOrder(String orderId, {String? reason}) => _repo.cancelOrder(orderId, reason: reason);
  Future<void> updateOrderPrice(String orderId, int newPrice) => _repo.updateOrderPrice(orderId, newPrice);
  
  Future<void> submitReview({
    required String targetUserId,
    required double rating,
    required String comment,
    required String targetRole,
  }) async {
    await _repo.submitReview(
      targetUserId: targetUserId,
      rating: rating,
      comment: comment,
      firstName: _firstName,
      lastName: _lastName,
      targetRole: targetRole,
    );
    // ✅ Force-evict cache so the new score is fetched immediately, not after TTL
    _sync.forceInvalidateRatingCache(targetUserId);
    await _sync.fetchUserRatingsBatch([targetUserId]);
  }

  Future<void> completeRide(String rideId) async {
    await _repo.completeRide(rideId);
    await _sync.fetchDriverTripsCount();
    await _sync.fetchPassengerTripsCount();
    await _sync.fetchHistoryTrips();
  }

  Future<void> cancelRide(String rideId) => _repo.cancelRide(rideId);
  
  Future<void> completeOrder(String orderId) async {
    await _repo.completeOrder(orderId);
    await _sync.fetchDriverTripsCount();
    await _sync.fetchPassengerTripsCount();
    await _sync.fetchHistoryTrips();
  }

  Future<void> linkDirectCallMatch({required String orderId, required String passengerId, required int price}) async {
    await _repo.linkDirectCallMatch(
      orderId: orderId, passengerId: passengerId, price: price,
      firstName: _firstName, lastName: _lastName, phone: _phone,
      driverCar: _driverCar, driverPlate: _driverPlate, isVehicleVerified: _isVehicleVerified,
    );
  }

  /// 📞 Записывает поездку, о которой договорились по прямому звонку (без торгов).
  /// Оба участника получат запись в своей истории поездок.
  Future<void> recordDirectCallTrip({
    required String targetId,
    required String targetType,
    required int agreedPrice,
  }) async {
    await _repo.recordDirectCallTrip(
      targetId: targetId,
      targetType: targetType,
      agreedPrice: agreedPrice,
      myFirstName: _firstName,
      myLastName: _lastName,
      myPhone: _phone,
      myCar: _driverCar,
      myPlate: _driverPlate,
      myVerified: _isVehicleVerified,
    );
    // Обновляем счётчики и историю
    await _sync.fetchDriverTripsCount();
    await _sync.fetchPassengerTripsCount();
    await _sync.fetchHistoryTrips();
  }

  // 🔒 Dynamic Date Formatter with Backwards Compatibility for 'today'/'tomorrow' strings
  static String formatTaxiDisplayDate(Map<String, dynamic> doc, String lang) {
    final rawDate = doc['date']?.toString() ?? '';
    final createdAtObj = doc['createdAt'];
    
    DateTime createdDate;
    if (createdAtObj is Timestamp) {
      createdDate = createdAtObj.toDate().toLocal();
    } else {
      createdDate = DateTime.now();
    }

    DateTime actualDepartureDate;
    if (rawDate == 'today') {
      actualDepartureDate = DateTime(createdDate.year, createdDate.month, createdDate.day);
    } else if (rawDate == 'tomorrow') {
      final tom = createdDate.add(const Duration(days: 1));
      actualDepartureDate = DateTime(tom.year, tom.month, tom.day);
    } else if (rawDate == 'yesterday') {
      final yes = createdDate.subtract(const Duration(days: 1));
      actualDepartureDate = DateTime(yes.year, yes.month, yes.day);
    } else {
      try {
        final parts = rawDate.split('.');
        if (parts.length == 3) {
          final day = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final year = int.parse(parts[2]);
          actualDepartureDate = DateTime(year, month, day);
        } else {
          return rawDate;
        }
      } catch (_) {
        return rawDate;
      }
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final yesterday = today.subtract(const Duration(days: 1));

    if (actualDepartureDate == today) {
      return lang == 'kz' ? 'Бүгін' : lang == 'uyg' ? 'Бүгүн' : 'Сегодня';
    } else if (actualDepartureDate == tomorrow) {
      return lang == 'kz' ? 'Ертең' : lang == 'uyg' ? 'Әтә' : 'Завтра';
    } else if (actualDepartureDate == yesterday) {
      return lang == 'kz' ? 'Кеше' : lang == 'uyg' ? 'Түнүгүн' : 'Вчера';
    } else {
      return DateFormat('dd.MM.yyyy').format(actualDepartureDate);
    }
  }
}
