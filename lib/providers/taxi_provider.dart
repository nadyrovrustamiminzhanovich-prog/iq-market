import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:iqmarket/theme/taxi_theme.dart';
import 'package:iqmarket/translations/taxi_strings.dart';
import 'package:iqmarket/utils/taxi_constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:iqmarket/services/notification_service.dart';

class TaxiProvider extends ChangeNotifier {
  TaxiProvider() {
    loadPreferences();
    startFirebaseSync();
  }

  StreamSubscription? _ridesSub;
  StreamSubscription? _ordersSub;
  StreamSubscription? _bidsSentSub;
  StreamSubscription? _bidsRecvSub;
  StreamSubscription? _myAcceptedOrdersSub;
  StreamSubscription? _myAcceptedOrdersDriverSub;
  StreamSubscription? _myAcceptedRidesSub;
  StreamSubscription? _myAcceptedRidesPassengerSub;

  @override
  void dispose() {
    _ridesSub?.cancel();
    _ordersSub?.cancel();
    _bidsSentSub?.cancel();
    _bidsRecvSub?.cancel();
    _myAcceptedOrdersSub?.cancel();
    _myAcceptedOrdersDriverSub?.cancel();
    _myAcceptedRidesSub?.cancel();
    _myAcceptedRidesPassengerSub?.cancel();
    super.dispose();
  }
  int _tab = 0;
  String _from = '';
  String _to = '';
  String _driverFrom = '';
  String _driverTo = '';
  bool _loading = false;
  bool _isLoggedIn = true;
  String _selDate = 'date';
  String _selTime = 'time';
  int _passCnt = 1;
  String _curLang = 'ru';
  bool _isDarkGlobal = false;
  File? _profileImage;
  String _firstName = "User";
  String _lastName = "IQ";
  String _phone = "+7 701 000 11 22";
  bool _notifEnabled = true;
  String? _telegramChatId;
  bool _isTelegramVerified = false;
  int _maxPrice = 0; // 0 = no limit
  String _comment = "";
  String get comment => _comment;
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

  TaxiTheme get theme => TaxiTheme(_isDarkGlobal);

  final List<Map<String, dynamic>> _drives = [];

  final List<Map<String, dynamic>> _passengerOrders = [];

  List<Map<String, dynamic>> get filteredDrives {
    return _drives.where((d) {
      final bool matchF = _from.isEmpty || d['from'].toString().toLowerCase().contains(_from.toLowerCase());
      final bool matchT = _to.isEmpty || d['to'].toString().toLowerCase().contains(_to.toLowerCase());
      final bool matchD = _selDate == 'date' || _selDate == 'time' || _selDate.isEmpty || d['date'] == _selDate;
      final int price = (d['price'] as num).toInt();
      final bool matchP = _maxPrice == 0 || price <= _maxPrice;
      return matchF && matchT && matchD && matchP;
    }).toList()
      ..sort((a, b) => (a['price'] as num).compareTo(b['price'] as num));
  }

  final List<Map<String, dynamic>> _myAcceptedOrders = [];
  final List<Map<String, dynamic>> _myAcceptedRides = [];

  List<Map<String, dynamic>> get myAcceptedOrders => _myAcceptedOrders;
  List<Map<String, dynamic>> get myAcceptedRides => _myAcceptedRides;

  List<Map<String, dynamic>> get allPassengerOrders => [..._passengerOrders, ..._myAcceptedOrders];
  List<Map<String, dynamic>> get allDrives => [..._drives, ..._myAcceptedRides];

  List<Map<String, dynamic>> get filteredOrders {
    return _passengerOrders.where((o) {
      final bool matchF = _driverFrom.isEmpty || o['from'].toString().toLowerCase().contains(_driverFrom.toLowerCase());
      final bool matchT = _driverTo.isEmpty || o['to'].toString().toLowerCase().contains(_driverTo.toLowerCase());
      final bool matchD = _selDate == 'date' || _selDate == 'time' || _selDate.isEmpty || o['date'] == _selDate;
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

  void setDriverFrom(String city) {
    _driverFrom = city;
    notifyListeners();
  }

  void setDriverTo(String city) {
    _driverTo = city;
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
    _telegramChatId = prefs.getString('taxi_tg_chat_id');
    _isTelegramVerified = _telegramChatId != null;
    checkVerificationStatus();
    notifyListeners();
  }

  Future<void> _save(String k, dynamic v) async {
    final prefs = await SharedPreferences.getInstance();
    if (v == null) {
      await prefs.remove(k);
    } else {
      if (v is String) await prefs.setString(k, v);
      if (v is bool) await prefs.setBool(k, v);
      if (v is int) await prefs.setInt(k, v);
    }
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
    if (!status) {
      _telegramChatId = null;
      _isTelegramVerified = false;
      _save('taxi_tg_chat_id', null);
    }
    _save('taxi_logged_in', _isLoggedIn);
    startFirebaseSync();
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

  void setTelegramAuth(String chatId) {
    _telegramChatId = chatId;
    _isTelegramVerified = true;
    _isLoggedIn = true;
    _save('taxi_tg_chat_id', chatId);
    _save('taxi_logged_in', true);
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
    if (status == 'approved' || status == 'approved_by_ai') {
      _isVehicleVerified = true;
      _save('taxi_verified', true);
    }
    notifyListeners();
  }

  void setComment(String v) {
    _comment = v;
    notifyListeners();
  }

  // ─── FIRESTORE INTEGRATION ───────────────────────────────────────────────

  List<Map<String, dynamic>> _bids = [];
  List<Map<String, dynamic>> get activeBids => _bids;

  final Map<String, double> _userRatings = {};
  double getUserRating(String userId) => _userRatings[userId] ?? 0.0;

  final Map<String, int> _userReviewCounts = {};
  int getUserReviewCount(String userId) => _userReviewCounts[userId] ?? 0;

  void startFirebaseSync() {
    fetchDriverTripsCount();
    fetchPassengerTripsCount();
    fetchHistoryTrips();

    _ridesSub?.cancel();
    _ridesSub = FirebaseFirestore.instance
        .collection('taxi_rides')
        .where('status', isEqualTo: 'active')
        .snapshots()
        .listen((snapshot) {
      _drives.clear();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        _drives.add(data);
        if (data['driverId'] != null) {
          fetchUserRating(data['driverId']);
        }
      }
      notifyListeners();
    }, onError: (e) {
      debugPrint("Error syncing taxi_rides: $e");
    });

    _ordersSub?.cancel();
    _ordersSub = FirebaseFirestore.instance
        .collection('taxi_orders')
        .where('status', isEqualTo: 'active')
        .snapshots()
        .listen((snapshot) {
      _passengerOrders.clear();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        _passengerOrders.add(data);
        if (data['passengerId'] != null) {
          fetchUserRating(data['passengerId']);
        }
      }
      notifyListeners();
    }, onError: (e) {
      debugPrint("Error syncing taxi_orders: $e");
    });

    _bidsSentSub?.cancel();
    _bidsRecvSub?.cancel();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      List<Map<String, dynamic>> sentBids = [];
      List<Map<String, dynamic>> recvBids = [];

      void updateBids() {
        _bids.clear();
        final Map<String, Map<String, dynamic>> uniqueBids = {};
        for (var b in sentBids) {
          if (b['id'] != null) uniqueBids[b['id']!] = b;
        }
        for (var b in recvBids) {
          if (b['id'] != null) uniqueBids[b['id']!] = b;
        }
        _bids.addAll(uniqueBids.values);
        notifyListeners();
      }

      _bidsSentSub = FirebaseFirestore.instance
          .collection('taxi_bids')
          .where('status', isEqualTo: 'pending')
          .where('senderId', isEqualTo: user.uid)
          .snapshots()
          .listen((snapshot) {
        sentBids = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
        updateBids();
      }, onError: (e) {
        debugPrint("Error syncing sent taxi_bids: $e");
      });

      _bidsRecvSub = FirebaseFirestore.instance
          .collection('taxi_bids')
          .where('status', isEqualTo: 'pending')
          .where('receiverId', isEqualTo: user.uid)
          .snapshots()
          .listen((snapshot) {
        recvBids = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
        updateBids();
      }, onError: (e) {
        debugPrint("Error syncing received taxi_bids: $e");
      });

      // 1. My accepted orders where I am the passenger
      _myAcceptedOrdersSub?.cancel();
      _myAcceptedOrdersSub = FirebaseFirestore.instance
          .collection('taxi_orders')
          .where('passengerId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'accepted')
          .snapshots()
          .listen((snapshot) {
        _myAcceptedOrders.removeWhere((o) => o['passengerId'] == user.uid);
        for (var doc in snapshot.docs) {
          final data = doc.data();
          data['id'] = doc.id;
          _myAcceptedOrders.add(data);
          if (data['driverId'] != null) {
            fetchUserRating(data['driverId']);
          }
        }
        notifyListeners();
      }, onError: (e) => debugPrint("Error syncing my accepted passenger orders: $e"));

      // 2. My accepted orders where I am the driver
      _myAcceptedOrdersDriverSub?.cancel();
      _myAcceptedOrdersDriverSub = FirebaseFirestore.instance
          .collection('taxi_orders')
          .where('driverId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'accepted')
          .snapshots()
          .listen((snapshot) {
        _myAcceptedOrders.removeWhere((o) => o['driverId'] == user.uid);
        for (var doc in snapshot.docs) {
          final data = doc.data();
          data['id'] = doc.id;
          _myAcceptedOrders.add(data);
          if (data['passengerId'] != null) {
            fetchUserRating(data['passengerId']);
          }
        }
        notifyListeners();
      }, onError: (e) => debugPrint("Error syncing my accepted driver orders: $e"));

      // 3. My accepted rides where I am the driver
      _myAcceptedRidesSub?.cancel();
      _myAcceptedRidesSub = FirebaseFirestore.instance
          .collection('taxi_rides')
          .where('driverId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'accepted')
          .snapshots()
          .listen((snapshot) {
        _myAcceptedRides.removeWhere((r) => r['driverId'] == user.uid);
        for (var doc in snapshot.docs) {
          final data = doc.data();
          data['id'] = doc.id;
          _myAcceptedRides.add(data);
          if (data['passengerId'] != null) {
            fetchUserRating(data['passengerId']);
          }
        }
        notifyListeners();
      }, onError: (e) => debugPrint("Error syncing my accepted rides: $e"));

      // 4. My accepted rides where I am the passenger
      _myAcceptedRidesPassengerSub?.cancel();
      _myAcceptedRidesPassengerSub = FirebaseFirestore.instance
          .collection('taxi_rides')
          .where('passengerId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'accepted')
          .snapshots()
          .listen((snapshot) {
        _myAcceptedRides.removeWhere((r) => r['passengerId'] == user.uid);
        for (var doc in snapshot.docs) {
          final data = doc.data();
          data['id'] = doc.id;
          _myAcceptedRides.add(data);
          if (data['driverId'] != null) {
            fetchUserRating(data['driverId']);
          }
        }
        notifyListeners();
      }, onError: (e) => debugPrint("Error syncing my accepted passenger rides: $e"));
    } else {
      _myAcceptedOrdersSub?.cancel();
      _myAcceptedOrdersDriverSub?.cancel();
      _myAcceptedRidesSub?.cancel();
      _myAcceptedRidesPassengerSub?.cancel();
      _myAcceptedOrders.clear();
      _myAcceptedRides.clear();
    }
  }

  Future<void> fetchUserRating(String userId) async {
    if (_userRatings.containsKey(userId)) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('taxi_reviews')
          .where('targetUserId', isEqualTo: userId)
          .get();
      if (snap.docs.isEmpty) {
        _userRatings[userId] = 0.0;
        _userReviewCounts[userId] = 0;
      } else {
        final int count = snap.docs.length;
        _userReviewCounts[userId] = count;
        if (count < 5) {
          _userRatings[userId] = 0.0;
        } else {
          double sum = 0.0;
          for (var doc in snap.docs) {
            sum += (doc.data()['rating'] as num).toDouble();
          }
          _userRatings[userId] = double.parse((sum / count).toStringAsFixed(1));
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Error fetching rating: $e");
    }
  }

  Future<void> checkVerificationStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('driver_verifications')
        .where('driver_name', isEqualTo: '$_firstName $_lastName'.trim())
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final data = snapshot.docs.first.data();
      final status = data['status'];
      _verificationStatus = status ?? 'none';
      if (status == 'approved' || status == 'approved_by_ai') {
        _isVehicleVerified = true;
        await _save('taxi_verified', true);
      } else {
        _isVehicleVerified = false;
        await _save('taxi_verified', false);
      }
      notifyListeners();
    }
  }

  Future<void> createPassengerOrder({
    required String from,
    required String to,
    required String date,
    required String time,
    required int seats,
    required int price,
    required String comment,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docId = 'order_${user.uid}_${DateTime.now().millisecondsSinceEpoch}';
    final newOrder = {
      'id': docId,
      'passengerId': user.uid,
      'passengerName': '$_firstName $_lastName'.trim().isEmpty ? 'Пассажир' : '$_firstName $_lastName'.trim(),
      'passengerPhone': _phone,
      'passengerImg': user.photoURL ?? '',
      'from': from,
      'to': to,
      'date': date,
      'time': time,
      'seats': seats,
      'price': price,
      'comment': comment,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
    };

    await FirebaseFirestore.instance.collection('taxi_orders').doc(docId).set(newOrder);
  }

  Future<void> createDriverRide({
    required String from,
    required String to,
    required String date,
    required String time,
    required int seats,
    required int price,
    required String comment,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docId = 'ride_${user.uid}_${DateTime.now().millisecondsSinceEpoch}';
    final newRide = {
      'id': docId,
      'driverId': user.uid,
      'driverName': '$_firstName $_lastName'.trim().isEmpty ? 'Водитель' : '$_firstName $_lastName'.trim(),
      'driverPhone': _phone,
      'driverCar': _driverCar,
      'driverPlate': _driverPlate,
      'driverImg': user.photoURL ?? '',
      'driverVerified': _isVehicleVerified,
      'from': from,
      'to': to,
      'date': date,
      'time': time,
      'seats': seats,
      'price': price,
      'comment': comment,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
    };

    await FirebaseFirestore.instance.collection('taxi_rides').doc(docId).set(newRide);
  }

  // ─── BIDS & REVIEWS SERVICES ─────────────────────────────────────────────

  Future<void> sendBid({
    required String targetId,
    required String targetType,
    required String receiverId,
    required int price,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docId = 'bid_${user.uid}_${DateTime.now().millisecondsSinceEpoch}';
    final newBid = {
      'id': docId,
      'targetId': targetId,
      'targetType': targetType,
      'senderId': user.uid,
      'senderName': '$_firstName $_lastName'.trim().isEmpty ? 'Пользователь' : '$_firstName $_lastName'.trim(),
      'senderImg': user.photoURL ?? '',
      'senderPhone': _phone,
      'senderCar': _driverCar,
      'senderPlate': _driverPlate,
      'senderVerified': _isVehicleVerified,
      'receiverId': receiverId,
      'offeredPrice': price,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    };

    await FirebaseFirestore.instance.collection('taxi_bids').doc(docId).set(newBid);

    // 🔔 Notify the receiver (passenger or driver) of the new bid!
    await NotificationService.saveNotificationToFirestore(
      title: 'Новое предложение по такси 🚕',
      body: '${newBid['senderName']} предлагает цену $price ₸',
      type: 'taxi_bid',
      uid: receiverId,
    );
  }

  Future<void> acceptBid(String bidId) async {
    final bidSnap = await FirebaseFirestore.instance.collection('taxi_bids').doc(bidId).get();
    if (!bidSnap.exists) return;
    
    final bidData = bidSnap.data();
    if (bidData == null) return;

    final targetId = bidData['targetId'];
    final targetType = bidData['targetType'];

    // Update the accepted bid status
    await FirebaseFirestore.instance.collection('taxi_bids').doc(bidId).update({
      'status': 'accepted',
    });

    if (targetType == 'order') {
      // 🚗 Driver bid accepted by Passenger
      await FirebaseFirestore.instance.collection('taxi_orders').doc(targetId).update({
        'status': 'accepted',
        'driverId': bidData['senderId'],
        'driverName': bidData['senderName'],
        'driverPhone': bidData['senderPhone'],
        'driverImg': bidData['senderImg'],
        'driverCar': bidData['senderCar'] ?? 'Машина не указана',
        'driverPlate': bidData['senderPlate'] ?? 'Б/Н',
        'driverVerified': bidData['senderVerified'] ?? false,
        'price': bidData['offeredPrice'], // Apply agreed price
      });

      // 🔔 Notify driver that passenger accepted their bid!
      await NotificationService.saveNotificationToFirestore(
        title: 'Предложение принято! 🎉',
        body: 'Пассажир принял вашу ставку на ${bidData['offeredPrice']} ₸. Свяжитесь для выезда!',
        type: 'taxi_bid_accepted',
        uid: bidData['senderId'],
      );

      // Auto-reject other bids for this order
      final otherBids = await FirebaseFirestore.instance
          .collection('taxi_bids')
          .where('targetId', isEqualTo: targetId)
          .where('status', isEqualTo: 'pending')
          .get();
      for (var doc in otherBids.docs) {
        if (doc.id != bidId) {
          await doc.reference.update({'status': 'rejected'});
        }
      }
    } else if (targetType == 'ride') {
      // 🚙 Passenger bid accepted by Driver
      await FirebaseFirestore.instance.collection('taxi_rides').doc(targetId).update({
        'status': 'accepted',
        'passengerId': bidData['senderId'],
        'passengerName': bidData['senderName'],
        'passengerPhone': bidData['senderPhone'],
        'passengerImg': bidData['senderImg'],
        'price': bidData['offeredPrice'], // Apply agreed price
      });

      // 🔔 Notify passenger that driver accepted their bid!
      await NotificationService.saveNotificationToFirestore(
        title: 'Поездка подтверждена! 🚙',
        body: 'Водитель принял вашу ставку на ${bidData['offeredPrice']} ₸. Свяжитесь для выезда!',
        type: 'taxi_bid_accepted',
        uid: bidData['senderId'],
      );

      // Auto-reject other bids for this ride
      final otherBids = await FirebaseFirestore.instance
          .collection('taxi_bids')
          .where('targetId', isEqualTo: targetId)
          .where('status', isEqualTo: 'pending')
          .get();
      for (var doc in otherBids.docs) {
        if (doc.id != bidId) {
          await doc.reference.update({'status': 'rejected'});
        }
      }
    }
  }

  Future<void> rejectBid(String bidId) async {
    await FirebaseFirestore.instance.collection('taxi_bids').doc(bidId).update({
      'status': 'rejected',
    });
  }

  Future<void> cancelOrder(String orderId, {String? reason}) async {
    await FirebaseFirestore.instance.collection('taxi_orders').doc(orderId).update({
      'status': 'cancelled',
      if (reason != null) 'cancellationReason': reason,
    });

    // Auto-reject all bids for this order
    final bids = await FirebaseFirestore.instance
        .collection('taxi_bids')
        .where('targetId', isEqualTo: orderId)
        .where('status', isEqualTo: 'pending')
        .get();
    for (var doc in bids.docs) {
      await doc.reference.update({'status': 'rejected'});
    }
  }

  Future<void> updateOrderPrice(String orderId, int newPrice) async {
    await FirebaseFirestore.instance.collection('taxi_orders').doc(orderId).update({
      'price': newPrice,
    });
  }

  Future<void> submitReview({
    required String targetUserId,
    required double rating,
    required String comment,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docId = 'review_${user.uid}_${DateTime.now().millisecondsSinceEpoch}';
    final newReview = {
      'id': docId,
      'targetUserId': targetUserId,
      'authorId': user.uid,
      'authorName': '$_firstName $_lastName'.trim().isEmpty ? 'Пользователь' : '$_firstName $_lastName'.trim(),
      'authorImg': user.photoURL ?? '',
      'rating': rating,
      'comment': comment,
      'createdAt': FieldValue.serverTimestamp(),
    };

    await FirebaseFirestore.instance.collection('taxi_reviews').doc(docId).set(newReview);
    _userRatings.remove(targetUserId); // invalidate cache
    await fetchUserRating(targetUserId);
  }

  int _driverTripsCount = 0;
  int get driverTripsCount => _driverTripsCount;

  int _passengerTripsCount = 0;
  int get passengerTripsCount => _passengerTripsCount;

  List<Map<String, dynamic>> _historyTrips = [];
  List<Map<String, dynamic>> get historyTrips => _historyTrips;

  Future<void> fetchDriverTripsCount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final ordersSnap = await FirebaseFirestore.instance
          .collection('taxi_orders')
          .where('driverId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'completed')
          .get();

      final ridesSnap = await FirebaseFirestore.instance
          .collection('taxi_rides')
          .where('driverId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'completed')
          .get();

      _driverTripsCount = ordersSnap.docs.length + ridesSnap.docs.length;
      notifyListeners();
    } catch (e) {
      debugPrint("Error fetching driver trips count: $e");
    }
  }

  Future<void> fetchPassengerTripsCount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final ordersSnap = await FirebaseFirestore.instance
          .collection('taxi_orders')
          .where('passengerId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'completed')
          .get();

      final ridesSnap = await FirebaseFirestore.instance
          .collection('taxi_rides')
          .where('passengerId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'completed')
          .get();

      _passengerTripsCount = ordersSnap.docs.length + ridesSnap.docs.length;
      notifyListeners();
    } catch (e) {
      debugPrint("Error fetching passenger trips count: $e");
    }
  }

  Future<void> fetchHistoryTrips() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final List<Map<String, dynamic>> list = [];
      
      final ordersPassenger = await FirebaseFirestore.instance
          .collection('taxi_orders')
          .where('passengerId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'completed')
          .get();
          
      final ordersDriver = await FirebaseFirestore.instance
          .collection('taxi_orders')
          .where('driverId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'completed')
          .get();

      final ridesPassenger = await FirebaseFirestore.instance
          .collection('taxi_rides')
          .where('passengerId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'completed')
          .get();
          
      final ridesDriver = await FirebaseFirestore.instance
          .collection('taxi_rides')
          .where('driverId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'completed')
          .get();

      for (var doc in ordersPassenger.docs) {
        final d = doc.data();
        d['role'] = 'passenger';
        d['id'] = doc.id;
        list.add(d);
      }
      for (var doc in ordersDriver.docs) {
        final d = doc.data();
        d['role'] = 'driver';
        d['id'] = doc.id;
        list.add(d);
      }
      for (var doc in ridesPassenger.docs) {
        final d = doc.data();
        d['role'] = 'passenger';
        d['id'] = doc.id;
        list.add(d);
      }
      for (var doc in ridesDriver.docs) {
        final d = doc.data();
        d['role'] = 'driver';
        d['id'] = doc.id;
        list.add(d);
      }

      _historyTrips = list;
      notifyListeners();
    } catch (e) {
      debugPrint("Error fetching history: $e");
    }
  }

  Future<void> completeRide(String rideId) async {
    await FirebaseFirestore.instance.collection('taxi_rides').doc(rideId).update({
      'status': 'completed',
    });
    await fetchDriverTripsCount();
    await fetchPassengerTripsCount();
    await fetchHistoryTrips();
  }

  Future<void> cancelRide(String rideId) async {
    await FirebaseFirestore.instance.collection('taxi_rides').doc(rideId).update({
      'status': 'cancelled',
    });
  }

  Future<void> completeOrder(String orderId) async {
    await FirebaseFirestore.instance.collection('taxi_orders').doc(orderId).update({
      'status': 'completed',
    });
    await fetchDriverTripsCount();
    await fetchPassengerTripsCount();
    await fetchHistoryTrips();
  }

  Future<void> linkDirectCallMatch({
    required String orderId,
    required String passengerId,
    required int price,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Create a mock bid that is immediately accepted
    final docId = 'bid_direct_${user.uid}_${DateTime.now().millisecondsSinceEpoch}';
    final newBid = {
      'id': docId,
      'targetId': orderId,
      'targetType': 'order',
      'senderId': user.uid,
      'senderName': '$_firstName $_lastName'.trim().isEmpty ? 'Водитель' : '$_firstName $_lastName'.trim(),
      'senderImg': user.photoURL ?? '',
      'senderPhone': _phone,
      'senderCar': _driverCar,
      'senderPlate': _driverPlate,
      'senderVerified': _isVehicleVerified,
      'receiverId': passengerId,
      'offeredPrice': price,
      'status': 'accepted', // Auto-accepted!
      'createdAt': FieldValue.serverTimestamp(),
    };

    await FirebaseFirestore.instance.collection('taxi_bids').doc(docId).set(newBid);

    // Link the order as accepted
    await FirebaseFirestore.instance.collection('taxi_orders').doc(orderId).update({
      'status': 'accepted',
      'driverId': user.uid,
      'driverName': newBid['senderName'],
      'driverPhone': _phone,
      'driverImg': newBid['senderImg'],
      'driverCar': _driverCar,
      'driverPlate': _driverPlate,
      'driverVerified': _isVehicleVerified,
      'price': price,
    });
    
    // Auto-reject other bids for this order
    final otherBids = await FirebaseFirestore.instance
        .collection('taxi_bids')
        .where('targetId', isEqualTo: orderId)
        .where('status', isEqualTo: 'pending')
        .get();
    for (var doc in otherBids.docs) {
      if (doc.id != docId) {
        await doc.reference.update({'status': 'rejected'});
      }
    }
  }
}

