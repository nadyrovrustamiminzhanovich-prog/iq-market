import 'dart:io';
import 'package:flutter/material.dart';
import 'package:iqmarket/widgets/secure_image_viewer.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:line_icons/line_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:iqmarket/theme/taxi_theme.dart';
import 'package:iqmarket/screens/chat_screen.dart';
import 'package:iqmarket/models/ad_model.dart';
import 'package:iqmarket/models/review_model.dart';
import 'package:provider/provider.dart';
import 'package:iqmarket/providers/taxi_provider.dart';
import 'package:iqmarket/screens/login_screen.dart';
import 'package:iqmarket/services/auth_service.dart';
import 'package:iqmarket/features/taxi/presentation/widgets/ui/kazakhstan_license_plate.dart';

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
  int _taxiTripsCount = 0;
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
    try {
      await ScreenProtector.preventScreenshotOn();
    } catch (e) {
      debugPrint('ScreenProtector preventScreenshotOn error: $e');
    }
  }

  void _disableProtection() async {
    try {
      await ScreenProtector.preventScreenshotOff();
    } catch (e) {
      debugPrint('ScreenProtector preventScreenshotOff error: $e');
    }
  }

  Future<void> _loadUserProfileData() async {
    final String userId = widget.user['id'] ?? '';
    if (userId.isEmpty) {
      setState(() => _isLoadingStats = false);
      return;
    }

    try {
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
        _taxiTripsCount = tripsCount;
        _isDriverVerified = driverVerified;
        _isLoadingStats = false;
      });
    } catch (e) {
      debugPrint("Error loading profile details: $e");
      setState(() => _isLoadingStats = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TaxiProvider>(context);
    final t = widget.theme;
    final u = widget.user;

    final String carModel = u['car'] ?? u['driverCar'] ?? '';
    final String carPlate = u['plate'] ?? u['driverPlate'] ?? '';
    final String carColor = u['color'] ?? u['driverColor'] ?? '';

    final double activeRating = widget.isDriver ? _taxiDriverAvgRating : _taxiPassengerAvgRating;
    final int activeReviewsCount = widget.isDriver ? _taxiDriverReviewsCount : _taxiPassengerReviewsCount;

    return Scaffold(
      backgroundColor: t.bg,
      body: _isLoadingStats
          ? Center(child: CircularProgressIndicator(color: t.accent))
          : CustomScrollView(
              controller: _scrollController,
              slivers: [
                if (widget.isDriver)
                  SliverAppBar(
                    expandedHeight: 280,
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
                    title: Text(
                      provider.translate('my_profile_header').toUpperCase(), 
                      style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: 2)
                    ),
                    centerTitle: true,
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
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
                                      radius: 54,
                                      backgroundImage: NetworkImage(u['img'] ?? 'https://images.unsplash.com/photo-1633332755192-727a05c4013d?w=800'),
                                      backgroundColor: t.card2,
                                    ),
                                  ),
                                ),
                                if (_isDriverVerified || u['verified'] == true)
                                  Positioned(
                                    bottom: 5, right: 5,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(color: const Color(0xFF2563EB), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                                      child: const Icon(Icons.check, color: Colors.white, size: 14),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // ── User Name & Verification Status Row ──
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: widget.isDriver ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    u['name'] ?? 'Пользователь',
                                    style: GoogleFonts.inter(
                                      color: t.text,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 24,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  if (_isDriverVerified || u['verified'] == true)
                                    Row(
                                      mainAxisAlignment: widget.isDriver ? MainAxisAlignment.start : MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.verified_rounded, color: Color(0xFF2563EB), size: 18),
                                        const SizedBox(width: 6),
                                        Text(
                                          widget.isDriver ? 'Верифицированный водитель' : 'Верифицирован в Telegram',
                                          style: GoogleFonts.inter(
                                            color: const Color(0xFF2563EB),
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    )
                                  else
                                    Row(
                                      mainAxisAlignment: widget.isDriver ? MainAxisAlignment.start : MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.shield_outlined, color: t.sub, size: 16),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Профиль базовый',
                                          style: GoogleFonts.inter(
                                            color: t.sub,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // ── Quick Stats Grid Cards (Trips, Rating, Reviews) ──
                        Row(
                          children: [
                            Expanded(
                              child: _statCard(
                                t,
                                '🚗 Поездки',
                                '$_taxiTripsCount',
                                'выполнено',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _statCard(
                                t,
                                '⭐ Рейтинг',
                                activeRating > 0 ? '$activeRating' : 'Новичок',
                                activeReviewsCount > 0 ? '$activeReviewsCount отзывов' : 'нет оценок',
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // ── DRIVER VEHICLE CARD (Full vehicle specs with Kazakhstan License Plate) ──
                        if (widget.isDriver) ...[
                          _sectionTitle(t, 'ИНФОРМАЦИЯ ОБ АВТОМОБИЛЕ'),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: t.card,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: t.border),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: t.isDark ? 0.2 : 0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: const Icon(Icons.directions_car_rounded, color: Color(0xFF2563EB), size: 24),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            carModel.isNotEmpty ? carModel : 'Toyota Camry 70',
                                            style: GoogleFonts.inter(
                                              color: t.text,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 16,
                                            ),
                                          ),
                                          if (carColor.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              'Цвет: $carColor',
                                              style: GoogleFonts.inter(
                                                color: t.sub,
                                                fontWeight: FontWeight.w500,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                if (carPlate.isNotEmpty) ...[
                                  const SizedBox(height: 14),
                                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                                  const SizedBox(height: 14),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Госномер:',
                                        style: GoogleFonts.inter(
                                          color: t.sub,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                      KazakhstanLicensePlate(plate: carPlate, fontSize: 12),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.verified_user_rounded, color: Color(0xFF2563EB), size: 14),
                                      const SizedBox(width: 6),
                                      Text(
                                        _isDriverVerified ? 'Автомобиль верифицирован' : 'Документы на проверке',
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFF2563EB),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // ── REVIEWS & RATINGS SECTION ──
                        _sectionTitle(t, 'ОТЗЫВЫ И РЕЙТИНГ'),
                        const SizedBox(height: 10),

                        // Review Tabs: Taxi vs Market
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _activeReviewTab = 0),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _activeReviewTab == 0
                                        ? const Color(0xFF2563EB)
                                        : t.card,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _activeReviewTab == 0
                                          ? const Color(0xFF2563EB)
                                          : t.border,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Такси (${_taxiReviewsList.length})',
                                      style: GoogleFonts.inter(
                                        color: _activeReviewTab == 0 ? Colors.white : t.text,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _activeReviewTab = 1),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _activeReviewTab == 1
                                        ? const Color(0xFF2563EB)
                                        : t.card,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _activeReviewTab == 1
                                          ? const Color(0xFF2563EB)
                                          : t.border,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Маркет (${_marketReviewsList.length})',
                                      style: GoogleFonts.inter(
                                        color: _activeReviewTab == 1 ? Colors.white : t.text,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // List of reviews
                        if (_activeReviewTab == 0) ...[
                          if (_taxiReviewsList.isEmpty)
                            _emptyReviewsPlaceholder(t, 'Пока нет отзывов по поездкам')
                          else
                            for (var rev in _taxiReviewsList)
                              _reviewItem(
                                t,
                                rev.fromUserName,
                                rev.comment,
                                rev.rating.toStringAsFixed(1),
                                '${rev.timestamp.day}.${rev.timestamp.month}.${rev.timestamp.year}',
                                roleLabel: rev.targetRole == 'passenger' ? 'Пассажир' : 'Водитель',
                                isPassenger: rev.targetRole == 'passenger',
                              ),
                        ] else ...[
                          if (_marketReviewsList.isEmpty)
                            _emptyReviewsPlaceholder(t, 'Пока нет отзывов по маркету')
                          else
                            for (var rev in _marketReviewsList)
                              _reviewItem(
                                t,
                                rev.fromUserName,
                                rev.comment,
                                rev.rating.toStringAsFixed(1),
                                '${rev.timestamp.day}.${rev.timestamp.month}.${rev.timestamp.year}',
                              ),
                        ],

                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      bottomSheet: _bottomActions(context, t, u, provider),
    );
  }

  Widget _statCard(TaxiTheme t, String title, String value, String sub) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.border),
      ),
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
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              color: t.text,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            style: GoogleFonts.inter(
              color: t.sub,
              fontWeight: FontWeight.w500,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyReviewsPlaceholder(TaxiTheme t, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.border),
      ),
      child: Column(
        children: [
          Icon(Icons.rate_review_outlined, color: t.sub, size: 36),
          const SizedBox(height: 8),
          Text(
            message,
            style: GoogleFonts.inter(
              color: t.sub,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
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
        title: Text(
          provider.curLang == 'kz' 
              ? 'Телеграм арқылы кіру' 
              : (provider.curLang == 'uyg' ? 'Телеграм арқылық кириш' : 'Вход через Telegram'), 
          style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: t.text),
        ),
        content: Text(
          provider.curLang == 'kz'
              ? 'Бұл әрекетті орындау үшін Telegram арқылы жүйеге кіру қажет. Қазір кіргіңіз келе ме?'
              : (provider.curLang == 'uyg' 
                  ? 'Бу амални орунлаш үчүн Telegram арқылық кириш зөрүр. Ҳазир кирмәкчимусыз?'
                  : 'Для выполнения этого действия необходимо войти в аккаунт через Telegram. Желаете войти через Telegram сейчас?'),
          style: GoogleFonts.inter(color: t.sub),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              provider.curLang == 'kz' ? 'Жабу' : (provider.curLang == 'uyg' ? 'Йепиш' : 'Закрыть'), 
              style: GoogleFonts.inter(color: t.sub, fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              Navigator.pop(context);

              String langName = 'Русский';
              if (provider.curLang == 'kz') langName = 'Қазақша';
              else if (provider.curLang == 'uyg') langName = 'Уйғурчә';

              await AuthService.signOut();
              provider.setLoginStatus(false);

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => LoginScreen(
                    lang: langName,
                    autoStartTelegramLogin: true,
                  ),
                ),
              );
            },
            child: Text(
              provider.curLang == 'kz' ? 'Кіру' : (provider.curLang == 'uyg' ? 'Кириш' : 'Войти'), 
              style: GoogleFonts.inter(color: t.accent, fontWeight: FontWeight.bold),
            ),
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
              try {
                if (await canLaunchUrl(url)) {
                  await launchUrl(url);
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(provider.translate('errNoPhoneCallApp')), backgroundColor: Colors.redAccent),
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(provider.translate('errCall').replaceAll('{error}', e.toString())), backgroundColor: Colors.redAccent),
                  );
                }
              }
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
    if (imageUrl.isEmpty) return;

    if (imageUrl.startsWith('http')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SecureImageViewerScreen(
            imageUrl: imageUrl,
            heroTag: 'taxi_p_${widget.user['name']}',
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SecureImageViewerScreen(
            file: File(imageUrl),
            heroTag: 'taxi_p_${widget.user['name']}',
          ),
        ),
      );
    }
  }
}
