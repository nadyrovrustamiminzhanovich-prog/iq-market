import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:line_icons/line_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:iqmarket/theme/taxi_theme.dart';
import 'package:iqmarket/screens/chat_screen.dart';
import 'package:iqmarket/models/ad_model.dart';
import 'package:iqmarket/models/review_model.dart';
import 'package:iqmarket/screens/taxi/driver_verification_screen.dart';
import 'package:provider/provider.dart';
import 'package:iqmarket/providers/taxi_provider.dart';


class TaxiProfileViewScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final bool isDriver;
  final TaxiTheme theme;
  final bool isCurrentUserVerified;

  const TaxiProfileViewScreen({
    super.key, 
    required this.user, 
    required this.isDriver,
    required this.theme,
    this.isCurrentUserVerified = true,
  });

  @override
  State<TaxiProfileViewScreen> createState() => _TaxiProfileViewScreenState();
}

class _TaxiProfileViewScreenState extends State<TaxiProfileViewScreen> {
  bool _isLoadingStats = true;
  double _taxiDriverAvgRating = 0.0;
  int _taxiDriverReviewsCount = 0;
  double _taxiPassengerAvgRating = 0.0;
  int _taxiPassengerReviewsCount = 0;
  // ✅ BUG-01 FIX: Track actual trip count separately from review count
  int _taxiTripsCount = 0;
  double _marketAvgRating = 0.0;
  int _marketReviewsCount = 0;
  List<ReviewModel> _taxiReviewsList = [];
  List<ReviewModel> _marketReviewsList = [];
  int _activeReviewTab = 0; // 0: Taxi, 1: Market
  String _userPhone = '';
  bool _isDriverVerified = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _enableProtection();
    _loadUserProfileData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _disableProtection();
    super.dispose();
  }

  void _enableProtection() async {
    await ScreenProtector.preventScreenshotOn();
  }

  void _disableProtection() async {
    await ScreenProtector.preventScreenshotOff();
  }

  Future<void> _loadUserProfileData() async {
    final String userId = widget.user['id'] ?? '';
    if (userId.isEmpty) {
      setState(() => _isLoadingStats = false);
      return;
    }

    try {
      // ✅ W-03 FIX: 10-second timeout on all Firestore calls to prevent infinite spinner
      const timeout = Duration(seconds: 10);

      // 1. Fetch user doc
      final userDoc = await FirebaseFirestore.instance
          .collection('users').doc(userId).get()
          .timeout(timeout, onTimeout: () => throw Exception('Timeout'));

      if (userDoc.exists) {
        final userData = userDoc.data();
        if (userData != null) {
          _userPhone = userData['phone'] ?? '';
          if (_userPhone.isEmpty) _userPhone = widget.user['phone'] ?? '';
        }
      }

      // ✅ BUG-02 FIX: Check driver_verifications, NOT users.isVerified.
      // users.isVerified = Telegram OTP. driver_verifications = actual car check.
      bool driverVerified = false;
      try {
        final verifSnap = await FirebaseFirestore.instance
            .collection('driver_verifications')
            .where('userId', isEqualTo: userId)
            .limit(1)
            .get()
            .timeout(timeout);
        if (verifSnap.docs.isNotEmpty) {
          final status = verifSnap.docs.first.data()['status'] ?? 'none';
          driverVerified = status == 'approved' || status == 'approved_by_ai';
        }
      } catch (_) {}

      // 2. Fetch Market reviews
      final reviewsSnap = await FirebaseFirestore.instance
          .collection('reviews')
          .where('toUserId', isEqualTo: userId)
          .get()
          .timeout(timeout);

      final marketList = reviewsSnap.docs
          .map((doc) => ReviewModel.fromMap(doc.data(), doc.id))
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

      int marketCount = marketList.length;
      double marketAvg = 0.0;
      // ✅ ISSUE-01 FIX: Apply same <5 threshold as TaxiSyncService for consistency
      if (marketCount >= 5) {
        double sum = marketList.fold(0.0, (prev, e) => prev + e.rating);
        marketAvg = double.parse((sum / marketCount).toStringAsFixed(1));
      }

      // 3. Fetch Taxi reviews
      final taxiReviewsSnap = await FirebaseFirestore.instance
          .collection('taxi_reviews')
          .where('targetUserId', isEqualTo: userId)
          .get()
          .timeout(timeout);

      final taxiList = taxiReviewsSnap.docs.map((doc) {
        final data = doc.data();
        DateTime ts = DateTime.now();
        if (data['createdAt'] is Timestamp) ts = (data['createdAt'] as Timestamp).toDate();
        return ReviewModel(
          id: doc.id, adId: '', adTitle: '',
          fromUserId: data['authorId'] ?? '',
          fromUserName: data['authorName'] ?? 'Пользователь',
          toUserId: data['targetUserId'] ?? '',
          rating: (data['rating'] ?? 0.0).toDouble(),
          comment: data['comment'] ?? '',
          images: [], timestamp: ts,
          targetRole: data['targetRole'] as String?,
        );
      }).toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

      int taxiCount = taxiList.length;
      double taxiAvg = 0.0;
      if (taxiCount >= 5) {
        double sum = taxiList.fold(0.0, (prev, e) => prev + e.rating);
        taxiAvg = double.parse((sum / taxiCount).toStringAsFixed(1));
      }

      int taxiDriverCount = 0;
      double taxiDriverSum = 0.0;
      int taxiPassengerCount = 0;
      double taxiPassengerSum = 0.0;

      for (var r in taxiList) {
        final role = r.targetRole ?? 'driver';
        if (role == 'passenger') {
          taxiPassengerCount++;
          taxiPassengerSum += r.rating;
        } else {
          taxiDriverCount++;
          taxiDriverSum += r.rating;
        }
      }

      double taxiDriverAvg = 0.0;
      if (taxiDriverCount >= 5) {
        taxiDriverAvg = double.parse((taxiDriverSum / taxiDriverCount).toStringAsFixed(1));
      }

      double taxiPassengerAvg = 0.0;
      if (taxiPassengerCount >= 5) {
        taxiPassengerAvg = double.parse((taxiPassengerSum / taxiPassengerCount).toStringAsFixed(1));
      }

      // ✅ BUG-01 FIX: Fetch actual completed trips count (not review count)
      int tripsCount = 0;
      try {
        final results = await Future.wait([
          FirebaseFirestore.instance.collection('taxi_orders')
              .where('passengerId', isEqualTo: userId)
              .where('status', isEqualTo: 'completed').get().timeout(timeout),
          FirebaseFirestore.instance.collection('taxi_orders')
              .where('driverId', isEqualTo: userId)
              .where('status', isEqualTo: 'completed').get().timeout(timeout),
          FirebaseFirestore.instance.collection('taxi_rides')
              .where('passengerId', isEqualTo: userId)
              .where('status', isEqualTo: 'completed').get().timeout(timeout),
          FirebaseFirestore.instance.collection('taxi_rides')
              .where('driverId', isEqualTo: userId)
              .where('status', isEqualTo: 'completed').get().timeout(timeout),
        ]);
        // Deduplicate: use Map<docId> to avoid counting same trip twice
        final Map<String, bool> uniqueIds = {};
        for (var snap in results) {
          for (var doc in snap.docs) uniqueIds[doc.id] = true;
        }
        tripsCount = uniqueIds.length;
      } catch (_) {}

      setState(() {
        _taxiReviewsList = taxiList;
        _marketReviewsList = marketList;
        _taxiDriverAvgRating = taxiDriverAvg;
        _taxiDriverReviewsCount = taxiDriverCount;
        _taxiPassengerAvgRating = taxiPassengerAvg;
        _taxiPassengerReviewsCount = taxiPassengerCount;
        _marketAvgRating = marketAvg;
        _marketReviewsCount = marketCount;
        _taxiTripsCount = tripsCount;  // ✅ BUG-01
        _isDriverVerified = driverVerified; // ✅ BUG-02
        _isLoadingStats = false;
      });
    } catch (e) {
      debugPrint("Error loading profile details: $e");
      setState(() => _isLoadingStats = false);
    }
  }

  String _pluralReviews(int count, TaxiProvider provider) {
    final lang = provider.curLang;
    if (lang == 'kz' || lang == 'uyg') {
      return '$count ${provider.translate('reviews_label')}';
    }
    if (count % 100 >= 11 && count % 100 <= 19) return '$count отзывов';
    switch (count % 10) {
      case 1: return '$count отзыв';
      case 2: case 3: case 4: return '$count отзыва';
      default: return '$count отзывов';
    }
  }

  void _scrollToReviews() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TaxiProvider>(context);
    final t = widget.theme;
    final u = widget.user;

    return Scaffold(
      backgroundColor: t.bg,
      body: _isLoadingStats
          ? Center(child: CircularProgressIndicator(color: t.accent))
          : CustomScrollView(
              controller: _scrollController,
              slivers: [
                if (widget.isDriver)
                  SliverAppBar(
                    expandedHeight: 300,
                    pinned: true,
                    backgroundColor: t.accent,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    flexibleSpace: FlexibleSpaceBar(
                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                          GestureDetector(
                            onTap: () => _showFullScreenImage(context, u['img'] ?? ''),
                            child: Hero(
                              tag: 'taxi_p_${u['name']}',
                              child: Image.network(
                                u['img'] ?? 'https://images.unsplash.com/photo-1633332755192-727a05c4013d?w=800',
                                fit: BoxFit.cover,
                                // ✅ W-01 FIX: Handle broken/missing images gracefully
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.grey.shade800,
                                  child: const Icon(Icons.person_rounded, size: 80, color: Colors.white30),
                                ),
                              ),
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.3),
                                  Colors.transparent,
                                  t.bg.withValues(alpha: 0.8),
                                  t.bg,
                                ],
                                stops: const [0.0, 0.3, 0.8, 1.0],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverAppBar(
                    pinned: true,
                    backgroundColor: t.bg,
                    elevation: 0,
                    leading: IconButton(
                      icon: Icon(Icons.arrow_back_ios_new_rounded, color: t.text),
                      onPressed: () => Navigator.pop(context),
                    ),
                    title: Text(provider.translate('my_profile_header').toUpperCase(), style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: 2)),
                    centerTitle: true,
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!widget.isDriver) ...[
                          Center(
                            child: Stack(
                              children: [
                                GestureDetector(
                                  onTap: () => _showFullScreenImage(context, u['img'] ?? ''),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: t.accent.withValues(alpha: 0.2), width: 3)),
                                    child: CircleAvatar(
                                      radius: 60,
                                      backgroundImage: NetworkImage(u['img'] ?? 'https://images.unsplash.com/photo-1633332755192-727a05c4013d?w=800'),
                                      backgroundColor: t.card2,
                                    ),
                                  ),
                                ),
                                if (_isDriverVerified)
                                  Positioned(
                                    bottom: 5, right: 5,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(color: const Color(0xFF4A80F0), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                                      child: const Icon(Icons.check, color: Colors.white, size: 14),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: widget.isDriver ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    u['name'] ?? 'User',
                                    style: GoogleFonts.inter(
                                      color: t.text,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 28,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  if (_isDriverVerified)
                                    Row(
                                      mainAxisAlignment: widget.isDriver ? MainAxisAlignment.start : MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.verified_rounded, color: Color(0xFF4A80F0), size: 18),
                                        const SizedBox(width: 6),
                                        Text(
                                          provider.translate('verif_ok'),
                                          style: GoogleFonts.inter(
                                            color: const Color(0xFF4A80F0),
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                      ],
                                    )
                                  else
                                    Row(
                                      mainAxisAlignment: widget.isDriver ? MainAxisAlignment.start : MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.shield_outlined, color: t.sub, size: 18),
                                        const SizedBox(width: 6),
                                        Text(
                                          provider.translate('verif_req'),
                                          style: GoogleFonts.inter(
                                            color: t.sub,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                            if (widget.isDriver)
                              GestureDetector(
                                onTap: _scrollToReviews,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    _ratingBox(t, _taxiDriverReviewsCount < 5 ? provider.translate('rating_novice') : _taxiDriverAvgRating.toStringAsFixed(1)),
                                    if (_taxiDriverReviewsCount < 5)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Tooltip(
                                          message: provider.translate('rating_tooltip'),
                                          child: Text(
                                            provider.translate('rating_after_5'),
                                            style: GoogleFonts.inter(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.w500),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        if (!widget.isDriver) ...[
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: _scrollToReviews,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                              decoration: BoxDecoration(
                                color: t.card,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: t.border),
                              ),
                              child: IntrinsicHeight(
                                child: Row(
                                  children: [
                                    // Rating stat
                                    Expanded(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Text('⭐', style: TextStyle(fontSize: 16)),
                                              const SizedBox(width: 4),
                                              Text(
                                                _taxiPassengerReviewsCount < 5 ? provider.translate('rating_novice') : _taxiPassengerAvgRating.toStringAsFixed(1),
                                                style: GoogleFonts.inter(
                                                  color: t.text,
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: _taxiPassengerReviewsCount < 5 ? 12 : 18,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _taxiPassengerReviewsCount < 5 ? provider.translate('rating_after_5') : provider.translate('rate').toUpperCase(),
                                            style: GoogleFonts.inter(color: t.sub, fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 0.3),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    ),
                                    VerticalDivider(width: 1, thickness: 1, color: t.border),
                                    // Reviews stat
                                    Expanded(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Text('💬', style: TextStyle(fontSize: 14)),
                                              const SizedBox(width: 4),
                                              Text(
                                                '$_taxiPassengerReviewsCount',
                                                style: GoogleFonts.inter(
                                                  color: t.text,
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 18,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            provider.translate('reviews_label').toUpperCase(),
                                            style: GoogleFonts.inter(color: t.sub, fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 0.3),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // ✅ BUG-01 FIX: Show actual trips count, not reviewsCount
                                    VerticalDivider(width: 1, thickness: 1, color: t.border),
                                    Expanded(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Text('🚗', style: TextStyle(fontSize: 14)),
                                              const SizedBox(width: 4),
                                              Text(
                                                '$_taxiTripsCount',
                                                style: GoogleFonts.inter(
                                                  color: t.text,
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 18,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            provider.translate('trips').toUpperCase(),
                                            style: GoogleFonts.inter(color: t.sub, fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 0.3),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        if (widget.isDriver) ...[
                          _sectionTitle(t, provider.translate('car_short').toUpperCase()),
                          const SizedBox(height: 12),
                          // ✅ BUG-06 FIX: Read plate from both 'plate' and 'driverPlate' keys.
                          // Previously u['plate'] was always null because the map used 'driverPlate'.
                          _infoCard(t, LineIcons.car, u['car'] ?? u['driverCar'] ?? 'Toyota Camry',
                              u['plate'] ?? u['driverPlate'] ?? ''),
                          const SizedBox(height: 24),
                        ],
                        // Custom premium reviews segment tab control
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: t.card2,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: t.border),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => _activeReviewTab = 0),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 250),
                                    curve: Curves.easeInOut,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: _activeReviewTab == 0 ? const Color(0xFF4A80F0) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    alignment: Alignment.center,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          provider.translate('taxi_tab_label'),
                                          style: GoogleFonts.inter(
                                            color: _activeReviewTab == 0 ? Colors.white : t.sub,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: _activeReviewTab == 0 ? Colors.white.withValues(alpha: 0.2) : t.border,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            _taxiReviewsList.length.toString(),
                                            style: GoogleFonts.inter(
                                              color: _activeReviewTab == 0 ? Colors.white : t.text,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => _activeReviewTab = 1),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 250),
                                    curve: Curves.easeInOut,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: _activeReviewTab == 1 ? const Color(0xFF4A80F0) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    alignment: Alignment.center,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          provider.translate('market_tab_label'),
                                          style: GoogleFonts.inter(
                                            color: _activeReviewTab == 1 ? Colors.white : t.sub,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: _activeReviewTab == 1 ? Colors.white.withValues(alpha: 0.2) : t.border,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            _marketReviewsList.length.toString(),
                                            style: GoogleFonts.inter(
                                              color: _activeReviewTab == 1 ? Colors.white : t.text,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Per-tab rating summary card
                        _activeReviewTab == 0
                            ? Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: t.card,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: t.border),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.local_taxi_rounded, color: Colors.amber, size: 18),
                                            const SizedBox(width: 8),
                                            Text(
                                              '${provider.translate('driver_role')}: ',
                                              style: GoogleFonts.inter(color: t.sub, fontSize: 13, fontWeight: FontWeight.w600),
                                            ),
                                            Text(
                                              _taxiDriverReviewsCount < 5 
                                                  ? provider.translate('rating_novice') 
                                                  : _taxiDriverAvgRating.toStringAsFixed(1),
                                              style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.w900, fontSize: 14),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          _pluralReviews(_taxiDriverReviewsCount, provider),
                                          style: GoogleFonts.inter(color: t.sub, fontSize: 12, fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 8.0),
                                      child: Divider(height: 1),
                                    ),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.directions_walk_rounded, color: Color(0xFF4A80F0), size: 18),
                                            const SizedBox(width: 8),
                                            Text(
                                              '${provider.translate('passenger_role')}: ',
                                              style: GoogleFonts.inter(color: t.sub, fontSize: 13, fontWeight: FontWeight.w600),
                                            ),
                                            Text(
                                              _taxiPassengerReviewsCount < 5 
                                                  ? provider.translate('rating_novice') 
                                                  : _taxiPassengerAvgRating.toStringAsFixed(1),
                                              style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.w900, fontSize: 14),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          _pluralReviews(_taxiPassengerReviewsCount, provider),
                                          style: GoogleFonts.inter(color: t.sub, fontSize: 12, fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              )
                            : Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: t.card,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: t.border),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 20),
                                        const SizedBox(width: 8),
                                        Text(
                                          _marketReviewsCount < 5 ? provider.translate('rating_novice') : _marketAvgRating.toStringAsFixed(1),
                                          style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.w900, fontSize: 16),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      _pluralReviews(_marketReviewsCount, provider),
                                      style: GoogleFonts.inter(color: t.sub, fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                        if (_activeReviewTab == 0) ...[
                          if (_taxiReviewsList.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: Text(
                                  provider.translate('no_taxi_reviews'),
                                  style: GoogleFonts.inter(color: t.sub, fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ),
                            )
                          else
                            Column(
                              children: _taxiReviewsList.map((r) {
                                final dateStr = '${r.timestamp.day.toString().padLeft(2, '0')}.${r.timestamp.month.toString().padLeft(2, '0')}.${r.timestamp.year}';
                                final isPassenger = r.targetRole == 'passenger';
                                final String roleLabel = isPassenger 
                                    ? provider.translate('passenger_role') 
                                    : provider.translate('driver_role');
                                return _reviewItem(
                                  t,
                                  r.fromUserName,
                                  r.comment,
                                  r.rating.toStringAsFixed(1),
                                  dateStr,
                                  roleLabel: roleLabel,
                                  isPassenger: isPassenger,
                                );
                              }).toList(),
                            ),
                        ] else ...[
                          if (_marketReviewsList.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: Text(
                                  provider.translate('no_market_reviews'),
                                  style: GoogleFonts.inter(color: t.sub, fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ),
                            )
                          else
                            Column(
                              children: _marketReviewsList.map((r) {
                                final dateStr = '${r.timestamp.day.toString().padLeft(2, '0')}.${r.timestamp.month.toString().padLeft(2, '0')}.${r.timestamp.year}';
                                return _reviewItem(t, r.fromUserName, r.comment, r.rating.toStringAsFixed(1), dateStr);
                              }).toList(),
                            ),
                        ],
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      bottomSheet: _bottomActions(context, t, u, provider),
    );
  }

  Widget _sectionTitle(TaxiTheme t, String title) => Text(
    title,
    style: GoogleFonts.inter(
      color: t.sub,
      fontWeight: FontWeight.w700,
      fontSize: 11,
      letterSpacing: 1.5,
    ),
  );

  Widget _ratingBox(TaxiTheme t, String rate) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
    ),
    child: Row(
      children: [
        const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 20),
        const SizedBox(width: 4),
        Text(
          rate,
          style: GoogleFonts.inter(
            color: Colors.amber.shade700,
            fontWeight: FontWeight.w700,
            fontSize: rate.length > 5 ? 12 : 16,
          ),
        ),
      ],
    ),
  );

  Widget _infoCard(TaxiTheme t, IconData icon, String title, String value) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: t.card,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: t.border),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: t.accent.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: t.accent, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  color: t.sub,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.inter(
                  color: t.text,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _reviewItem(
    TaxiTheme t,
    String name,
    String text,
    String rate,
    String date, {
    String? roleLabel,
    bool isPassenger = false,
  }) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: t.card,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: t.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.inter(
                        color: t.text,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (roleLabel != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isPassenger
                              ? const Color(0xFF4A80F0).withValues(alpha: 0.1)
                              : Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          roleLabel,
                          style: GoogleFonts.inter(
                            color: isPassenger
                                ? const Color(0xFF4A80F0)
                                : const Color(0xFFB45309),
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  date,
                  style: GoogleFonts.inter(
                    color: t.sub,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const Spacer(),
            const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 14),
            Text(
              ' $rate',
              style: GoogleFonts.inter(
                color: t.text,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          text,
          style: GoogleFonts.inter(
            color: t.sub,
            fontSize: 13,
            height: 1.4,
          ),
        ),
      ],
    ),
  );

  void _showGatedDialog(BuildContext context, TaxiTheme t, TaxiProvider provider) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: t.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: Text(provider.translate('action_blocked_title'), style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: t.text)),
        content: Text(
          provider.translate('action_blocked_desc'), 
          style: GoogleFonts.inter(color: t.sub)
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(provider.translate('close'), style: GoogleFonts.inter(color: t.sub, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverVerificationScreen()));
            },
            child: Text(provider.translate('pass_verification'), style: GoogleFonts.inter(color: t.accent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _bottomActions(BuildContext context, TaxiTheme t, Map<String, dynamic> u, TaxiProvider provider) => Container(
    padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
    decoration: BoxDecoration(
      color: t.bg,
      border: Border(top: BorderSide(color: t.border)),
    ),
    child: Row(
      children: [
        Expanded(
          child: _actionBtn(
            t, 
            provider.translate('chat'), 
            LineIcons.comment, 
            t.card, 
            t.accent,
            () {
              if (!widget.isDriver && !widget.isCurrentUserVerified) {
                _showGatedDialog(context, t, provider);
                return;
              }
              final String targetId = u['id'] ?? 'taxi_user';
              Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(ad: AdModel(
                id: 'taxi_user_${u['name']}_${DateTime.now().millisecondsSinceEpoch}',
                title: 'Taxi Trip',
                description: 'User profile chat',
                price: 0.0,
                category: 'Taxi',
                images: u['img'] != null && u['img'].toString().isNotEmpty ? [u['img']] : [],
                userId: targetId,
                userName: u['name'] ?? 'User',
                userEmail: '',
                timestamp: DateTime.now(),
                location: '',
              ))));
            }
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _actionBtn(
            t, 
            provider.translate('call'), 
            LineIcons.phone, 
            t.accent, 
            Colors.white,
            () async {
              if (!widget.isDriver && !widget.isCurrentUserVerified) {
                _showGatedDialog(context, t, provider);
                return;
              }
              final phoneToCall = _userPhone.isNotEmpty ? _userPhone : (u['phone'] ?? '');
              if (phoneToCall.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(provider.translate('no_phone_error'), style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                    backgroundColor: Colors.redAccent,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                );
                return;
              }
              final url = Uri.parse('tel:$phoneToCall');
              if (await canLaunchUrl(url)) await launchUrl(url);
            }
          ),
        ),
      ],
    ),
  );

  Widget _actionBtn(TaxiTheme t, String label, IconData icon, Color bg, Color text, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 56,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: bg == t.card ? Border.all(color: t.border) : null,
        boxShadow: [
          BoxShadow(
            color: bg.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: text, size: 20),
          const SizedBox(width: 10),
          Text(
            label,
            style: GoogleFonts.inter(
              color: text,
              fontWeight: FontWeight.w700,
              fontSize: 13,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    ),
  );

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SecureImageViewerScreen(
          imageUrl: imageUrl,
          heroTag: 'taxi_p_${widget.user['name']}',
        ),
      ),
    );
  }
}

class SecureImageViewerScreen extends StatefulWidget {
  final String imageUrl;
  final String heroTag;

  const SecureImageViewerScreen({
    super.key,
    required this.imageUrl,
    required this.heroTag,
  });

  @override
  State<SecureImageViewerScreen> createState() => _SecureImageViewerScreenState();
}

class _SecureImageViewerScreenState extends State<SecureImageViewerScreen> {
  @override
  void initState() {
    super.initState();
    _enableScreenshotProtection();
  }

  @override
  void dispose() {
    _disableScreenshotProtection();
    super.dispose();
  }

  void _enableScreenshotProtection() async {
    try {
      await ScreenProtector.preventScreenshotOn();
    } catch (e) {
      debugPrint("Error enabling screenshot protection: $e");
    }
  }

  void _disableScreenshotProtection() async {
    try {
      await ScreenProtector.preventScreenshotOff();
    } catch (e) {
      debugPrint("Error disabling screenshot protection: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              child: Hero(
                tag: widget.heroTag,
                child: Image.network(
                  widget.imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_rounded, size: 64, color: Colors.white24),
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: Center(
              child: Opacity(
                opacity: 0.12,
                child: Transform.rotate(
                  angle: -0.4,
                  child: Text(
                    'COPYRIGHT IQ MARKET\nSECURE VIEW ONLY',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
