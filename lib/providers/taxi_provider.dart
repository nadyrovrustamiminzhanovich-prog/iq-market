import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:iqmarket/theme/taxi_theme.dart';
import 'package:iqmarket/translations/taxi_strings.dart';
import 'package:iqmarket/utils/taxi_constants.dart';

class TaxiProvider extends ChangeNotifier {
  TaxiProvider() {
    loadPreferences();
  }
  int _tab = 0;
  String _from = TaxiConstants.defaultFrom;
  String _to = TaxiConstants.defaultTo;
  bool _loading = false;
  bool _isLoggedIn = true;
  String _selDate = 'today';
  String _selTime = 'time';
  int _passCnt = 1;
  String _curLang = 'ru';
  bool _isDarkGlobal = false;
  File? _profileImage;
  String _firstName = "User";
  String _lastName = "IQ";
  String _phone = "+7 701 000 11 22";
  bool _notifEnabled = true;
  int _maxPrice = 0; // 0 = no limit
  String get driverCar => _driverCar;
  String get driverPlate => _driverPlate;
  bool get isVehicleVerified => _isVehicleVerified;
  File? get techPassportPhoto => _techPassportPhoto;
  bool _isDriverOnline = true;
  String _driverCar = "Toyota Camry 70";
  String _driverPlate = "777 BBA 05";
  bool _isVehicleVerified = false;
  File? _techPassportPhoto;

  // Getters
  bool get isDriverOnline => _isDriverOnline;
  
  void setDriverOnline(bool v) {
    _isDriverOnline = v;
    notifyListeners();
  }
  int get tab => _tab;
  String get from => _from;
  String get to => _to;
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

  TaxiTheme get theme => TaxiTheme(_isDarkGlobal);

  final List<Map<String, dynamic>> _drives = [
    {
      'name': 'Берик М.',
      'car': 'Toyota Camry 70',
      'plate': '777 BBA 05',
      'price': 3000,
      'from': 'Чунджа',
      'to': 'Алматы',
      'date': 'today',
      'phone': '87010001122',
      'img': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=300',
      'seats': 3,
    },
    {
      'name': 'Азамат К.',
      'car': 'Hyundai Sonata',
      'plate': '123 ABC 02',
      'price': 2500,
      'from': 'Алматы',
      'to': 'Чунджа',
      'date': 'today',
      'phone': '87071112233',
      'img': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300',
      'seats': 4,
    },
    {
      'name': 'Игорь С.',
      'car': 'Mercedes S-Class',
      'plate': '001 VVIP 01',
      'price': 15000,
      'from': 'Астана',
      'to': 'Алматы',
      'date': 'tomorrow',
      'phone': '87770000001',
      'img': 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=300',
      'seats': 3,
    },
    {
      'name': 'Марат Б.',
      'car': 'Lexus LX570',
      'plate': '555 KZT 05',
      'price': 5000,
      'from': 'Чунджа',
      'to': 'Алматы',
      'date': 'tomorrow',
      'phone': '87015555555',
      'img': 'https://images.unsplash.com/photo-1542909168-82c3e7fdca5c?w=300',
      'seats': 2,
    }
  ];

  final List<Map<String, dynamic>> _passengerOrders = [
    {
      'name': 'Кайрат С.',
      'from': 'Алматы',
      'to': 'Чунджа',
      'date': 'today',
      'price': 3500,
      'seats': 2,
      'comment': 'Едем с ребенком, нужно место в багажнике',
      'isNegotiated': true,
      'created': '13:45',
      'img': 'https://images.unsplash.com/photo-1599566150163-29194dcaad36?w=300',
      'phone': '87012223344',
    },
    {
      'name': 'Мадина А.',
      'from': 'Алматы',
      'to': 'Чунджа',
      'date': 'today',
      'price': 3000,
      'seats': 1,
      'comment': 'Срочно, выезд через час',
      'isNegotiated': false,
      'created': '13:20',
      'img': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=300',
      'phone': '87074445566',
    },
    {
      'name': 'Арман К.',
      'from': 'Алматы',
      'to': 'Чунджа',
      'date': 'tomorrow',
      'price': 12000,
      'seats': 4,
      'comment': 'Выкупаю весь салон полностью',
      'isNegotiated': true,
      'created': '12:50',
      'img': 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=300',
      'phone': '87771110099',
    },
  ];

  List<Map<String, dynamic>> get filteredDrives {
    return _drives.where((d) {
      // flexible: if _from/to is empty (default) — match all
      final bool matchF = _from.isEmpty || d['from'].toString().toLowerCase().contains(_from.toLowerCase());
      final bool matchT = _to.isEmpty || d['to'].toString().toLowerCase().contains(_to.toLowerCase());
      final bool matchD = _selDate == 'time' || d['date'] == _selDate;
      final int price = (d['price'] as num).toInt();
      final bool matchP = _maxPrice == 0 || price <= _maxPrice;
      return matchF && matchT && matchD && matchP;
    }).toList()
      ..sort((a, b) => (a['price'] as num).compareTo(b['price'] as num));
  }

  List<Map<String, dynamic>> get filteredOrders {
    return _passengerOrders.where((o) {
      final bool matchF = _from.isEmpty || o['from'].toString().toLowerCase().contains(_from.toLowerCase());
      final bool matchT = _to.isEmpty || o['to'].toString().toLowerCase().contains(_to.toLowerCase());
      final bool matchD = _selDate == 'time' || o['date'] == _selDate;
      final int price = (o['price'] as num).toInt();
      final bool matchP = _maxPrice == 0 || price <= _maxPrice;
      return matchF && matchT && matchD && matchP;
    }).toList()
      ..sort((a, b) => (a['price'] as num).compareTo(b['price'] as num));
  }

  String translate(String? key) {
    if (key == null) return "";
    return (taxiStrings[_curLang]?[key] ?? key).toString();
  }

  // Setters/Actions
  void setTab(int index) {
    _tab = index;
    notifyListeners();
  }

  void setFrom(String city) {
    _from = city;
    notifyListeners();
  }

  void setTo(String city) {
    _to = city;
    notifyListeners();
  }

  Future<void> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _curLang = prefs.getString('taxi_lang') ?? 'ru';
    _isDarkGlobal = false; // FORCE LIGHT MODE
    _isLoggedIn = prefs.getBool('taxi_logged_in') ?? true;
    
    // Sync with main IQ Market profile
    final fullName = prefs.getString('user_name') ?? "Александр Иванов";
    final nameParts = fullName.split(' ');
    _firstName = nameParts.elementAt(0);
    _lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : "";
    
    final imgPath = prefs.getString('user_image');
    if (imgPath != null && imgPath.isNotEmpty) {
      _profileImage = File(imgPath);
    }

    _phone = prefs.getString('taxi_phone') ?? "+7 701 000 11 22";
    _driverCar = prefs.getString('taxi_car') ?? "Toyota Camry 70";
    _driverPlate = prefs.getString('taxi_plate') ?? "777 BBA 05";
    _isVehicleVerified = prefs.getBool('taxi_verified') ?? false;
    _notifEnabled = prefs.getBool('taxi_notif') ?? true;
    notifyListeners();
  }

  Future<void> _save(String k, dynamic v) async {
    final prefs = await SharedPreferences.getInstance();
    if (v is String) await prefs.setString(k, v);
    if (v is bool) await prefs.setBool(k, v);
    if (v is int) await prefs.setInt(k, v);
  }

  void setLanguage(String lang) {
    if (lang == 'Русский') {
      _curLang = 'ru';
    } else if (lang == 'Қазақша') {
      _curLang = 'kz';
    } else if (lang == 'Уйғурчә') {
      _curLang = 'uyg';
    } else {
      _curLang = lang;
    }
    _save('taxi_lang', _curLang);
    notifyListeners();
  }

  void toggleTheme() {
    _isDarkGlobal = !_isDarkGlobal;
    _save('taxi_theme', _isDarkGlobal);
    notifyListeners();
  }

  void setLoginStatus(bool status) {
    _isLoggedIn = status;
    _save('taxi_logged_in', _isLoggedIn);
    notifyListeners();
  }

  void setProfileImage(File? image) {
    _profileImage = image;
    if (image != null) {
      _save('user_image', image.path);
    }
    notifyListeners();
  }
  
  void setDate(String date) {
    _selDate = date;
    notifyListeners();
  }

  void setTime(String time) {
    _selTime = time;
    notifyListeners();
  }

  void setPassCnt(int cnt) {
    _passCnt = cnt;
    notifyListeners();
  }

  void setMaxPrice(int price) {
    _maxPrice = price;
    notifyListeners();
  }

  void setLoading(bool val) {
    _loading = val;
    notifyListeners();
  }

  void updateProfile(String fn, String ln, String ph) {
    _firstName = fn;
    _lastName = ln;
    _phone = ph;
    _save('taxi_fname', fn);
    _save('taxi_lname', ln);
    _save('taxi_phone', ph);
    // Sync back to main IQ Market profile
    _save('user_name', '$fn $ln'.trim());
    notifyListeners();
  }

  void setNotifEnabled(bool val) {
    _notifEnabled = val;
    _save('taxi_notif', val);
    notifyListeners();
  }

  void updateCarInfo(String car, String plate) {
    _driverCar = car;
    _driverPlate = plate;
    _isVehicleVerified = false;
    _save('taxi_car', car);
    _save('taxi_plate', plate);
    _save('taxi_verified', false);
    notifyListeners();
  }

  void setTechPassport(File? img) {
    _techPassportPhoto = img;
    notifyListeners();
  }

  void setVehicleVerified(bool v) {
    _isVehicleVerified = v;
    _save('taxi_verified', v);
    notifyListeners();
  }

  // ── Manual review queue ──────────────────────────────────────────────────────
  String _verificationStatus = 'none'; // none | pending | approved | rejected
  String get verificationStatus => _verificationStatus;

  void submitForManualReview({
    required String driverName,
    required String plate,
    required String car,
  }) {
    _verificationStatus = 'pending';
    _save('taxi_verif_status', 'pending');
    notifyListeners();
  }

  void setVerificationStatus(String status) {
    _verificationStatus = status;
    _save('taxi_verif_status', status);
    if (status == 'approved') {
      _isVehicleVerified = true;
      _save('taxi_verified', true);
    }
    notifyListeners();
  }
}
