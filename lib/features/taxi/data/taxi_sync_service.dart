import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:iqmarket/features/taxi/data/models/taxi_ride_model.dart';
import 'package:iqmarket/features/taxi/data/models/taxi_order_model.dart';
import 'package:iqmarket/features/taxi/data/models/taxi_bid_model.dart';

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

  /// Force-evicts [userId] from the TTL rating cache so that the next call to
  /// [fetchUserRatingsBatch] unconditionally re-fetches from Firestore.
  /// Call this immediately after a review is submitted for [userId].
  void forceInvalidateRatingCache(String userId) {
    _ratingCacheTimestamps.remove(userId);
  }

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
    // ✅ BUG-05 FIX: Null ALL 8 subscriptions to prevent stale references
    _ridesSub = null;
    _ordersSub = null;
    _bidsSentSub = null;
    _bidsRecvSub = null;
    _myAcceptedOrdersSub = null;
    _myAcceptedOrdersDriverSub = null;
    _myAcceptedRidesSub = null;
    _myAcceptedRidesPassengerSub = null;
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
        // ✅ W-07 FIX: Safety limit — prevents massive downloads at scale
        .limit(100)
        .snapshots()
        .listen((snapshot) {
      final List<String> userIdsToFetch = [];
      drives.clear();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        final model = TaxiRideModel.fromMap(data);
        drives.add(model.toMap());
        if (model.driverId.isNotEmpty) {
          userIdsToFetch.add(model.driverId);
        }
      }
      if (userIdsToFetch.isNotEmpty) fetchUserRatingsBatch(userIdsToFetch);
      onDataChanged();
    }, onError: (e) => debugPrint("Error syncing taxi_rides: $e"));

    _ordersSub?.cancel();
    _ordersSub = FirebaseFirestore.instance
        .collection('taxi_orders')
        .where('status', isEqualTo: 'active')
        // ✅ W-07 FIX: Safety limit — prevents massive downloads at scale
        .limit(100)
        .snapshots()
        .listen((snapshot) {
      final List<String> userIdsToFetch = [];
      passengerOrders.clear();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        final model = TaxiOrderModel.fromMap(data);
        passengerOrders.add(model.toMap());
        if (model.passengerId.isNotEmpty) {
          userIdsToFetch.add(model.passengerId);
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
          return TaxiBidModel.fromMap(data).toMap();
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
          return TaxiBidModel.fromMap(data).toMap();
        }).toList();
        updateBids();
      }, onError: (e) => debugPrint("Error syncing received taxi_bids: $e"));

      // ✅ BUG-07 FIX: Use Map-based deduplication to prevent race conditions
      // when both passenger and driver subscriptions fire simultaneously.
      final Map<String, Map<String, dynamic>> _acceptedOrdersMap = {};
      final Map<String, Map<String, dynamic>> _acceptedRidesMap = {};

      void _rebuildAcceptedOrders() {
        myAcceptedOrders
          ..clear()
          ..addAll(_acceptedOrdersMap.values);
        onDataChanged();
      }

      void _rebuildAcceptedRides() {
        myAcceptedRides
          ..clear()
          ..addAll(_acceptedRidesMap.values);
        onDataChanged();
      }

      _myAcceptedOrdersSub?.cancel();
      _myAcceptedOrdersSub = FirebaseFirestore.instance
          .collection('taxi_orders')
          .where('passengerId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'accepted')
          .snapshots()
          .listen((snapshot) {
        final List<String> userIdsToFetch = [];
        // Remove all entries previously sourced from passenger subscription
        _acceptedOrdersMap.removeWhere((k, v) => v['_src'] == 'passenger');
        for (var doc in snapshot.docs) {
          final data = doc.data();
          data['id'] = doc.id;
          data['_src'] = 'passenger';
          final model = TaxiOrderModel.fromMap(data);
          _acceptedOrdersMap[doc.id] = model.toMap()..['_src'] = 'passenger';
          if (model.driverId != null && model.driverId!.isNotEmpty) {
            userIdsToFetch.add(model.driverId!);
          }
        }
        if (userIdsToFetch.isNotEmpty) fetchUserRatingsBatch(userIdsToFetch);
        _rebuildAcceptedOrders();
      }, onError: (e) => debugPrint("Error syncing my accepted passenger orders: $e"));

      _myAcceptedOrdersDriverSub?.cancel();
      _myAcceptedOrdersDriverSub = FirebaseFirestore.instance
          .collection('taxi_orders')
          .where('driverId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'accepted')
          .snapshots()
          .listen((snapshot) {
        final List<String> userIdsToFetch = [];
        _acceptedOrdersMap.removeWhere((k, v) => v['_src'] == 'driver_order');
        for (var doc in snapshot.docs) {
          final data = doc.data();
          data['id'] = doc.id;
          data['_src'] = 'driver_order';
          final model = TaxiOrderModel.fromMap(data);
          _acceptedOrdersMap[doc.id] = model.toMap()..['_src'] = 'driver_order';
          if (model.passengerId.isNotEmpty) {
            userIdsToFetch.add(model.passengerId);
          }
        }
        if (userIdsToFetch.isNotEmpty) fetchUserRatingsBatch(userIdsToFetch);
        _rebuildAcceptedOrders();
      }, onError: (e) => debugPrint("Error syncing my accepted driver orders: $e"));

      _myAcceptedRidesSub?.cancel();
      _myAcceptedRidesSub = FirebaseFirestore.instance
          .collection('taxi_rides')
          .where('driverId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'accepted')
          .snapshots()
          .listen((snapshot) {
        final List<String> userIdsToFetch = [];
        _acceptedRidesMap.removeWhere((k, v) => v['_src'] == 'driver_ride');
        for (var doc in snapshot.docs) {
          final data = doc.data();
          data['id'] = doc.id;
          data['_src'] = 'driver_ride';
          final model = TaxiRideModel.fromMap(data);
          _acceptedRidesMap[doc.id] = model.toMap()..['_src'] = 'driver_ride';
          if (model.passengerId != null && model.passengerId!.isNotEmpty) {
            userIdsToFetch.add(model.passengerId!);
          }
        }
        if (userIdsToFetch.isNotEmpty) fetchUserRatingsBatch(userIdsToFetch);
        _rebuildAcceptedRides();
      }, onError: (e) => debugPrint("Error syncing my accepted rides: $e"));

      _myAcceptedRidesPassengerSub?.cancel();
      _myAcceptedRidesPassengerSub = FirebaseFirestore.instance
          .collection('taxi_rides')
          .where('passengerId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'accepted')
          .snapshots()
          .listen((snapshot) {
        final List<String> userIdsToFetch = [];
        _acceptedRidesMap.removeWhere((k, v) => v['_src'] == 'passenger_ride');
        for (var doc in snapshot.docs) {
          final data = doc.data();
          data['id'] = doc.id;
          data['_src'] = 'passenger_ride';
          final model = TaxiRideModel.fromMap(data);
          _acceptedRidesMap[doc.id] = model.toMap()..['_src'] = 'passenger_ride';
          if (model.driverId.isNotEmpty) {
            userIdsToFetch.add(model.driverId);
          }
        }
        if (userIdsToFetch.isNotEmpty) fetchUserRatingsBatch(userIdsToFetch);
        _rebuildAcceptedRides();
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

  // ✅ ISSUE-02 FIX: TTL-based cache invalidation (10 minutes)
  // Ratings are now refreshed every 10 minutes so users see up-to-date scores
  // during the same session.
  final Map<String, DateTime> _ratingCacheTimestamps = {};
  static const Duration _ratingCacheTtl = Duration(minutes: 10);

  Future<void> fetchUserRatingsBatch(List<String> userIds) async {
    final now = DateTime.now();
    // IDs that are missing OR whose cache has expired
    final staleIds = userIds.where((id) {
      if (!userRatings.containsKey(id)) return true;
      final cached = _ratingCacheTimestamps[id];
      return cached == null || now.difference(cached) > _ratingCacheTtl;
    }).toSet().toList();

    if (staleIds.isEmpty) return;

    // Optimistic placeholder so UI doesn't flicker
    for (var id in staleIds) {
      userRatings.putIfAbsent(id, () => 0.0);
      userReviewCounts.putIfAbsent(id, () => 0);
    }

    try {
      for (int i = 0; i < staleIds.length; i += 10) {
        final chunk = staleIds.sublist(i, (i + 10 < staleIds.length) ? i + 10 : staleIds.length);
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
          // ✅ ISSUE-01 aligned: same <5 threshold as profile view (see below)
          if (count < 5) {
            userRatings[id] = 0.0;
          } else {
            final sum = reviews.reduce((a, b) => a + b);
            userRatings[id] = double.parse((sum / count).toStringAsFixed(1));
          }
          _ratingCacheTimestamps[id] = now;
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
      // ✅ ISSUE-08 FIX: Use Map<docId, data> for automatic deduplication.
      // 4 parallel queries may return same doc if user was both driver & passenger
      // (edge case). Map ensures each trip appears exactly once.
      final Map<String, Map<String, dynamic>> uniqueTrips = {};

      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection('taxi_orders')
            .where('passengerId', isEqualTo: user.uid)
            .where('status', isEqualTo: 'completed')
            .get(),
        FirebaseFirestore.instance
            .collection('taxi_orders')
            .where('driverId', isEqualTo: user.uid)
            .where('status', isEqualTo: 'completed')
            .get(),
        FirebaseFirestore.instance
            .collection('taxi_rides')
            .where('passengerId', isEqualTo: user.uid)
            .where('status', isEqualTo: 'completed')
            .get(),
        FirebaseFirestore.instance
            .collection('taxi_rides')
            .where('driverId', isEqualTo: user.uid)
            .where('status', isEqualTo: 'completed')
            .get(),
      ]);

      final roles = ['passenger', 'driver', 'passenger', 'driver'];
      for (int i = 0; i < results.length; i++) {
        for (var doc in results[i].docs) {
          final d = doc.data();
          d['id'] = doc.id;
          // Driver role takes priority if user appears in both roles for same doc
          if (!uniqueTrips.containsKey(doc.id) || roles[i] == 'driver') {
            d['role'] = roles[i];
            uniqueTrips[doc.id] = d;
          }
        }
      }

      // Sort by createdAt descending — most recent first
      historyTrips = uniqueTrips.values.toList()
        ..sort((a, b) {
          final aTs = a['createdAt'];
          final bTs = b['createdAt'];
          if (aTs == null || bTs == null) return 0;
          DateTime aDate = aTs is Timestamp ? aTs.toDate() : DateTime.tryParse(aTs.toString()) ?? DateTime.now();
          DateTime bDate = bTs is Timestamp ? bTs.toDate() : DateTime.tryParse(bTs.toString()) ?? DateTime.now();
          return bDate.compareTo(aDate);
        });

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
