import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TaxiSyncService {
  final VoidCallback onDataChanged;

  TaxiSyncService(this.onDataChanged);

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  StreamSubscription? _ridesSub;
  StreamSubscription? _ordersSub;
  StreamSubscription? _bidsSentSub;
  StreamSubscription? _bidsRecvSub;
  StreamSubscription? _myAcceptedOrdersSub;
  StreamSubscription? _myAcceptedOrdersDriverSub;
  StreamSubscription? _myAcceptedRidesSub;
  StreamSubscription? _myAcceptedRidesPassengerSub;

  final List<Map<String, dynamic>> drives = [];
  final List<Map<String, dynamic>> passengerOrders = [];
  final List<Map<String, dynamic>> myAcceptedOrders = [];
  final List<Map<String, dynamic>> myAcceptedRides = [];
  final List<Map<String, dynamic>> activeBids = [];
  List<Map<String, dynamic>> historyTrips = [];

  final Map<String, double> userRatings = {};
  final Map<String, int> userReviewCounts = {};
  
  int driverTripsCount = 0;
  int passengerTripsCount = 0;
  String verificationStatus = 'none';

  double getUserRating(String userId) => userRatings[userId] ?? 0.0;
  int getUserReviewCount(String userId) => userReviewCounts[userId] ?? 0;

  void dispose() {
    pauseSync();
  }

  void pauseSync() {
    _ridesSub?.cancel();
    _ordersSub?.cancel();
    _bidsSentSub?.cancel();
    _bidsRecvSub?.cancel();
    _myAcceptedOrdersSub?.cancel();
    _myAcceptedOrdersDriverSub?.cancel();
    _myAcceptedRidesSub?.cancel();
    _myAcceptedRidesPassengerSub?.cancel();
    _ridesSub = null;
    _ordersSub = null;
    _isSyncing = false;
  }

  void startSync() {
    if (_isSyncing) return;
    _isSyncing = true;
    
    fetchDriverTripsCount();
    fetchPassengerTripsCount();
    fetchHistoryTrips();
    checkVerificationStatus();

    _ridesSub?.cancel();
    _ridesSub = FirebaseFirestore.instance
        .collection('taxi_rides')
        .where('status', isEqualTo: 'active')
        .snapshots()
        .listen((snapshot) {
      final List<String> userIdsToFetch = [];
      drives.clear();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        drives.add(data);
        if (data['driverId'] != null) {
          userIdsToFetch.add(data['driverId']);
        }
      }
      if (userIdsToFetch.isNotEmpty) fetchUserRatingsBatch(userIdsToFetch);
      onDataChanged();
    }, onError: (e) => debugPrint("Error syncing taxi_rides: $e"));

    _ordersSub?.cancel();
    _ordersSub = FirebaseFirestore.instance
        .collection('taxi_orders')
        .where('status', isEqualTo: 'active')
        .snapshots()
        .listen((snapshot) {
      final List<String> userIdsToFetch = [];
      passengerOrders.clear();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        passengerOrders.add(data);
        if (data['passengerId'] != null) {
          userIdsToFetch.add(data['passengerId']);
        }
      }
      if (userIdsToFetch.isNotEmpty) fetchUserRatingsBatch(userIdsToFetch);
      onDataChanged();
    }, onError: (e) => debugPrint("Error syncing taxi_orders: $e"));

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      List<Map<String, dynamic>> sentBids = [];
      List<Map<String, dynamic>> recvBids = [];

      void updateBids() {
        activeBids.clear();
        final Map<String, Map<String, dynamic>> uniqueBids = {};
        for (var b in sentBids) {
          if (b['id'] != null) uniqueBids[b['id']!] = b;
        }
        for (var b in recvBids) {
          if (b['id'] != null) uniqueBids[b['id']!] = b;
        }
        activeBids.addAll(uniqueBids.values);
        onDataChanged();
      }

      _bidsSentSub?.cancel();
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
      }, onError: (e) => debugPrint("Error syncing sent taxi_bids: $e"));

      _bidsRecvSub?.cancel();
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
      }, onError: (e) => debugPrint("Error syncing received taxi_bids: $e"));

      _myAcceptedOrdersSub?.cancel();
      _myAcceptedOrdersSub = FirebaseFirestore.instance
          .collection('taxi_orders')
          .where('passengerId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'accepted')
          .snapshots()
          .listen((snapshot) {
        final List<String> userIdsToFetch = [];
        myAcceptedOrders.removeWhere((o) => o['passengerId'] == user.uid);
        for (var doc in snapshot.docs) {
          final data = doc.data();
          data['id'] = doc.id;
          myAcceptedOrders.add(data);
          if (data['driverId'] != null) {
            userIdsToFetch.add(data['driverId']);
          }
        }
        if (userIdsToFetch.isNotEmpty) fetchUserRatingsBatch(userIdsToFetch);
        onDataChanged();
      }, onError: (e) => debugPrint("Error syncing my accepted passenger orders: $e"));

      _myAcceptedOrdersDriverSub?.cancel();
      _myAcceptedOrdersDriverSub = FirebaseFirestore.instance
          .collection('taxi_orders')
          .where('driverId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'accepted')
          .snapshots()
          .listen((snapshot) {
        final List<String> userIdsToFetch = [];
        myAcceptedOrders.removeWhere((o) => o['driverId'] == user.uid);
        for (var doc in snapshot.docs) {
          final data = doc.data();
          data['id'] = doc.id;
          myAcceptedOrders.add(data);
          if (data['passengerId'] != null) {
            userIdsToFetch.add(data['passengerId']);
          }
        }
        if (userIdsToFetch.isNotEmpty) fetchUserRatingsBatch(userIdsToFetch);
        onDataChanged();
      }, onError: (e) => debugPrint("Error syncing my accepted driver orders: $e"));

      _myAcceptedRidesSub?.cancel();
      _myAcceptedRidesSub = FirebaseFirestore.instance
          .collection('taxi_rides')
          .where('driverId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'accepted')
          .snapshots()
          .listen((snapshot) {
        final List<String> userIdsToFetch = [];
        myAcceptedRides.removeWhere((r) => r['driverId'] == user.uid);
        for (var doc in snapshot.docs) {
          final data = doc.data();
          data['id'] = doc.id;
          myAcceptedRides.add(data);
          if (data['passengerId'] != null) {
            userIdsToFetch.add(data['passengerId']);
          }
        }
        if (userIdsToFetch.isNotEmpty) fetchUserRatingsBatch(userIdsToFetch);
        onDataChanged();
      }, onError: (e) => debugPrint("Error syncing my accepted rides: $e"));

      _myAcceptedRidesPassengerSub?.cancel();
      _myAcceptedRidesPassengerSub = FirebaseFirestore.instance
          .collection('taxi_rides')
          .where('passengerId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'accepted')
          .snapshots()
          .listen((snapshot) {
        final List<String> userIdsToFetch = [];
        myAcceptedRides.removeWhere((r) => r['passengerId'] == user.uid);
        for (var doc in snapshot.docs) {
          final data = doc.data();
          data['id'] = doc.id;
          myAcceptedRides.add(data);
          if (data['driverId'] != null) {
            userIdsToFetch.add(data['driverId']);
          }
        }
        if (userIdsToFetch.isNotEmpty) fetchUserRatingsBatch(userIdsToFetch);
        onDataChanged();
      }, onError: (e) => debugPrint("Error syncing my accepted passenger rides: $e"));
    } else {
      _myAcceptedOrdersSub?.cancel();
      _myAcceptedOrdersDriverSub?.cancel();
      _myAcceptedRidesSub?.cancel();
      _myAcceptedRidesPassengerSub?.cancel();
      myAcceptedOrders.clear();
      myAcceptedRides.clear();
    }
  }

  Future<void> fetchUserRatingsBatch(List<String> userIds) async {
    final missingIds = userIds.where((id) => !userRatings.containsKey(id)).toSet().toList();
    if (missingIds.isEmpty) return;
    
    for (var id in missingIds) {
      userRatings[id] = 0.0;
      userReviewCounts[id] = 0;
    }

    try {
      for (int i = 0; i < missingIds.length; i += 10) {
        final chunk = missingIds.sublist(i, (i + 10 < missingIds.length) ? i + 10 : missingIds.length);
        final snap = await FirebaseFirestore.instance
            .collection('taxi_reviews')
            .where('targetUserId', whereIn: chunk)
            .get();
            
        final Map<String, List<double>> userReviews = {};
        for (var doc in snap.docs) {
          final data = doc.data();
          final String targetId = data['targetUserId'];
          final double rating = (data['rating'] as num).toDouble();
          userReviews.putIfAbsent(targetId, () => []).add(rating);
        }

        for (var id in chunk) {
          final reviews = userReviews[id] ?? [];
          final count = reviews.length;
          userReviewCounts[id] = count;
          if (count < 5) {
            userRatings[id] = 0.0;
          } else {
            final sum = reviews.reduce((a, b) => a + b);
            userRatings[id] = double.parse((sum / count).toStringAsFixed(1));
          }
        }
      }
      onDataChanged();
    } catch (e) {
      debugPrint("Error fetching ratings batch: $e");
    }
  }

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

      driverTripsCount = ordersSnap.docs.length + ridesSnap.docs.length;
      onDataChanged();
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

      passengerTripsCount = ordersSnap.docs.length + ridesSnap.docs.length;
      onDataChanged();
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

      historyTrips = list;
      onDataChanged();
    } catch (e) {
      debugPrint("Error fetching history: $e");
    }
  }

  Future<void> checkVerificationStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('driver_verifications')
          .where('userId', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        verificationStatus = data['status'] ?? 'none';
        onDataChanged();
      }
    } catch (e) {
      debugPrint("Error checking verification status: $e");
    }
  }
}
