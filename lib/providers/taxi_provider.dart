import 'dart:io';
import 'package:flutter/material.dart';
import 'package:iqmarket/theme/taxi_theme.dart';
import 'package:iqmarket/translations/taxi_strings.dart';
import 'package:iqmarket/features/taxi/data/taxi_prefs_service.dart';
import 'package:iqmarket/features/taxi/data/taxi_repository.dart';
import 'package:iqmarket/features/taxi/data/taxi_sync_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TaxiProvider extends ChangeNotifier {
  late final TaxiPrefsService _prefs;
  late final TaxiRepository _repo;
  late final TaxiSyncService _sync;

  TaxiProvider() {
    _prefs = TaxiPrefsService();
    _repo = TaxiRepository();
    _sync = TaxiSyncService(notifyListeners);
    loadPreferences();
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
  File? _profileImage;
  String _phone = "+7 701 000 11 22";
  String _driverCar = "Toyota Camry 70";
  String _driverPlate = "777 BBA 05";
  bool _isVehicleVerified = false;
  bool _notifEnabled = true;
  String? _telegramChatId;
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
  File? get profileImage => _profileImage;
  String get firstName => _firstName;
  String get lastName => _lastName;
  String get phone => _phone;
  bool get notifEnabled => _notifEnabled;
  int get maxPrice => _maxPrice;
  String? get telegramChatId => _telegramChatId;
  bool get isTelegramVerified => _isTelegramVerified;
  String get comment => _comment;
  String get driverCar => _driverCar;
  String get driverPlate => _driverPlate;
  bool get isVehicleVerified => _isVehicleVerified || _sync.verificationStatus == 'approved' || _sync.verificationStatus == 'approved_by_ai';
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
    _sync.dispose();
    super.dispose();
  }

  // ─── Setters & Preferences ───
  Future<void> loadPreferences() async {
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
  }

  void setTab(int index) { _tab = index; notifyListeners(); }
  void setFrom(String city) { _from = city; notifyListeners(); }
  void setTo(String city) { _to = city; notifyListeners(); }
  void setDriverFrom(String city) { _driverFrom = city; notifyListeners(); }
  void setDriverTo(String city) { _driverTo = city; notifyListeners(); }
  void setDate(String date) { _selDate = date; notifyListeners(); }
  void setTime(String time) { _selTime = time; notifyListeners(); }
  void setPassCnt(int cnt) { _passCnt = cnt; notifyListeners(); }
  void setMaxPrice(int price) { _maxPrice = price; notifyListeners(); }
  void setLoading(bool val) { _loading = val; notifyListeners(); }
  void setDriverOnline(bool v) { _isDriverOnline = v; notifyListeners(); }
  void setComment(String v) { _comment = v; notifyListeners(); }

  void setLanguage(String lang) {
    if (lang == 'Русский') _curLang = 'ru';
    else if (lang == 'Қазақша') _curLang = 'kz';
    else if (lang == 'Уйғурчә') _curLang = 'uyg';
    else _curLang = lang;
    _prefs.save('taxi_lang', _curLang);
    notifyListeners();
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
    if (_isLoggedIn) _sync.startSync();
    notifyListeners();
  }

  void setProfileImage(File? image) {
    _profileImage = image;
    if (image != null) _prefs.save('user_image', image.path);
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

  void setTelegramAuth(String chatId) {
    _telegramChatId = chatId;
    _isTelegramVerified = true;
    _isLoggedIn = true;
    _prefs.save('taxi_tg_chat_id', chatId);
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
        final verified = data?['isVerified'] == true;
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

  Future<void> createPassengerOrder({
    required String from, required String to, required String date, 
    required String time, required int seats, required int price, required String comment,
  }) async {
    await _repo.createPassengerOrder(
      firstName: _firstName, lastName: _lastName, phone: _phone,
      from: from, to: to, date: date, time: time, seats: seats, price: price, comment: comment,
    );
  }

  Future<void> createDriverRide({
    required String from, required String to, required String date, 
    required String time, required int seats, required int price, required String comment,
  }) async {
    await _repo.createDriverRide(
      firstName: _firstName, lastName: _lastName, phone: _phone,
      driverCar: _driverCar, driverPlate: _driverPlate, isVehicleVerified: _isVehicleVerified,
      from: from, to: to, date: date, time: time, seats: seats, price: price, comment: comment,
    );
  }

  Future<void> sendBid({
    required String targetId, required String targetType, required String receiverId, required int price,
  }) async {
    await _repo.sendBid(
      targetId: targetId, targetType: targetType, receiverId: receiverId, price: price,
      firstName: _firstName, lastName: _lastName, phone: _phone,
      driverCar: _driverCar, driverPlate: _driverPlate, isVehicleVerified: _isVehicleVerified,
    );
  }

  Future<void> acceptBid(String bidId) => _repo.acceptBid(bidId);
  Future<void> rejectBid(String bidId) => _repo.rejectBid(bidId);
  Future<void> cancelOrder(String orderId, {String? reason}) => _repo.cancelOrder(orderId, reason: reason);
  Future<void> updateOrderPrice(String orderId, int newPrice) => _repo.updateOrderPrice(orderId, newPrice);
  
  Future<void> submitReview({required String targetUserId, required double rating, required String comment}) async {
    await _repo.submitReview(
      targetUserId: targetUserId, rating: rating, comment: comment,
      firstName: _firstName, lastName: _lastName,
    );
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
}
