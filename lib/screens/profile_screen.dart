import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:iqmarket/services/storage_service.dart';
import 'package:iqmarket/services/user_service.dart';
import 'package:iqmarket/screens/my_ads_screen.dart';
import 'package:iqmarket/screens/profile_settings_screen.dart';
import 'package:iqmarket/screens/help_center_screen.dart';
import 'package:iqmarket/screens/iq_support_screen.dart';
import 'package:iqmarket/screens/notifications_screen.dart';
import 'package:iqmarket/screens/favorites_screen.dart';
import 'package:iqmarket/models/ad_model.dart';
import 'package:iqmarket/screens/login_screen.dart';
import 'package:iqmarket/screens/legal_info_screen.dart';
import 'package:iqmarket/screens/home/home_screen.dart';
import 'package:provider/provider.dart';
import 'package:iqmarket/providers/app_config_provider.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:iqmarket/screens/admin/admin_panel_screen.dart';
import 'package:iqmarket/translations/profile_strings.dart';
import 'package:iqmarket/services/auth_service.dart';
import 'package:iqmarket/models/user_model.dart';
import 'package:iqmarket/services/telegram_bot_service.dart';
import 'package:iqmarket/models/review_model.dart';
import 'package:iqmarket/services/review_service.dart';
import 'package:iqmarket/services/ad_service.dart';
import 'package:iqmarket/screens/product_details_screen.dart';
import 'package:iqmarket/widgets/secure_image_viewer.dart';

class ProfileScreen extends StatefulWidget {
  final List<AdModel> allAds;
  final List<AdModel> favoriteAds;
  final Function(int) onDeleteAd;
  final Function(int) onApproveAd;
  final Function(int, AdModel) onUpdateAd;
  final Function(String, File?, bool, String, String) onUpdateProfile;
  final String currentName;
  final File? currentImage;
  final bool isBioEnabled;
  final String accType;
  final String lang;
  final Function(String) onToggleFavorite;
  final Function(AdModel) onShowProductDetails;
  final bool isGuest;
  final VoidCallback? onLogout;
  final String currentTheme;
  final Map<String, Map<String, dynamic>> themes;
  final Function(String) onThemeChanged;
  final bool isVerified;

  const ProfileScreen({
    super.key,
    required this.allAds,
    required this.favoriteAds,
    required this.onDeleteAd,
    required this.onApproveAd,
    required this.onUpdateAd,
    required this.onUpdateProfile,
    required this.currentName,
    this.currentImage,
    required this.isBioEnabled,
    required this.accType,
    required this.lang,
    required this.onToggleFavorite,
    required this.onShowProductDetails,
    this.isGuest = false,
    this.onLogout,
    required this.currentTheme,
    required this.themes,
    required this.onThemeChanged,
    this.isVerified = false,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  File? _localImage;
  late String _localName;
  late bool _localBio;
  late String _localAccType;
  late String _localLang;
  late bool _isGuest;
  late String _currentTheme;
  String _firestorePhotoUrl = '';
  Timer? _timer;
  int _timerSeconds = 0;
  bool _isTimerRunning = false;
  String _tgCode = '';
  String? _sheetError;
  StreamSubscription? _tgSessionSub;
  bool _isWaitingForBot = false;
  String? _tgSessionToken;
  final MaskTextInputFormatter _phoneMask = MaskTextInputFormatter(
    mask: '+7 (###) ###-##-##',
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _codeCtrl = TextEditingController();
  Timer? _modalTimer;

  // ✅ Кэш стрима: создается один раз в initState, а не новый watcher при каждом setState()
  late final Stream<UserModel?> _userStream;
  
  void _startTimer() {
    setState(() {
      _timerSeconds = 60;
      _isTimerRunning = true;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerSeconds == 0) {
        if (mounted) setState(() => _isTimerRunning = false);
        timer.cancel();
      } else {
        if (mounted) setState(() => _timerSeconds--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _modalTimer?.cancel();
    _tgSessionSub?.cancel();
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  bool get _isDark => _currentTheme == 'Dark';
  Color get _bgColor => widget.themes[_currentTheme]?['background'] ?? (_isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC));
  Color get _surfaceColor => widget.themes[_currentTheme]?['surface'] ?? (_isDark ? const Color(0xFF1E293B) : Colors.white);
  Color get _txtColor => widget.themes[_currentTheme]?['text'] ?? (_isDark ? Colors.white : const Color(0xFF1A1D1E));
  Color get _subtxtColor => widget.themes[_currentTheme]?['subtext'] ?? (_isDark ? Colors.white60 : const Color(0xFF64748B));
  Color get _primaryColor => widget.themes[_currentTheme]?['primary'] ?? const Color(0xFF2563EB);

  @override
  void initState() {
    super.initState();
    _localImage = widget.currentImage;
    _localName = widget.currentName;
    _localBio = widget.isBioEnabled;
    _localAccType = widget.accType;
    _localLang = widget.lang;
    _isGuest = widget.isGuest;
    _currentTheme = widget.currentTheme;
    _isVerified = widget.isVerified;
    _firestorePhotoUrl = '';
    // ✅ Инициализируем стрим один раз — Firestore watcher живёт весь жизненный цикл экрана
    _userStream = UserService.getUserStream();
  }

  late bool _isVerified;

  String _t(String key) {
    final entry = profileStrings[key];
    if (entry == null) return key;
    return entry[_localLang] ?? entry['Русский'] ?? key;
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: _bgColor,
      body: StreamBuilder<UserModel?>(
        stream: _userStream, // ✅ Кэшированный стрим: без дублирования Reads
        builder: (context, snapshot) {
          final user = snapshot.data;
          if (user != null) {
            _localName = user.name;
            _isVerified = user.isVerified;
            _localAccType = user.accountType;
            _firestorePhotoUrl = user.photoUrl;
            _isGuest = false; // Auto-recover from Guest if a user document is loaded
          }

          final String displayName = _isGuest ? _t('guest') : (user?.name ?? _localName);
          final String photoUrl = user?.photoUrl ?? '';


          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                elevation: 0,
                backgroundColor: const Color(0xFF2563EB),
                leading: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Center(
                    child: Container(
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ),
                ),
                actions: const [],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                      Positioned(
                        top: -50, right: -50,
                        child: Container(width: 200, height: 200, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), shape: BoxShape.circle)),
                      ),
                      Positioned(
                        bottom: 20,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 4),
                                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, 10))],
                              ),
                              child: GestureDetector(
                                onTap: () => _showFullScreenPhoto(photoUrl),
                                child: Hero(
                                  tag: 'avatar_full',
                                  child: CircleAvatar(
                                    radius: 54,
                                    backgroundColor: const Color(0xFFF1F5F9),
                                    backgroundImage: (photoUrl.isNotEmpty && photoUrl.startsWith('http')) 
                                      ? NetworkImage(photoUrl) as ImageProvider
                                      : (_localImage != null ? FileImage(_localImage!) : null),

                                    child: (photoUrl.isEmpty && _localImage == null) 
                                      ? const Icon(Icons.person_rounded, size: 56, color: Color(0xFF2563EB))
                                      : null,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    const SizedBox(height: 15),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        displayName,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: _txtColor, letterSpacing: -0.3),
                      ),
                    ),
                    if (!_isGuest && user != null) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: user.uid));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(_t('idCopiedMsg').replaceAll('{uid}', user.uid)),
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 2),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'ID: ${user.uid.length > 8 ? user.uid.substring(0, 8) : user.uid}',
                                    style: GoogleFonts.firaCode(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF2563EB),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.copy_rounded, size: 14, color: Color(0xFF2563EB)),
                                ],
                              ),
                            ),
                          ),
                          if (_isVerified)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.verified_rounded, color: Color(0xFF2563EB), size: 16),
                                  const SizedBox(width: 5),
                                  Text(
                                    _t('badge_verified'),
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF2563EB),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 25),
                    if (!_isGuest) ...[
                      _buildStatsBar(user),
                      const SizedBox(height: 25),
                    ],
                    if (_isGuest) ...[
                      _buildGuestBanner(),
                      const SizedBox(height: 25),
                    ],
                    if (!_isGuest) ...[
                      _buildVerificationSection(),
                      const SizedBox(height: 25),
                    ],
                    _buildSimplifiedMenu(),
                    const SizedBox(height: 35),
                    if (!_isGuest) _buildLogoutButton(context),
                    const SizedBox(height: 35),
                  ],
                ),
              ),
            ],
          );
        }
      ),
    );
  }



  Widget _buildStatsBar(UserModel? user) {
    final int reviewsCount = user?.reviewsCount ?? 0;
    final double rawRating = user?.rating ?? 0.0;
    final String rating = rawRating.toStringAsFixed(1);
    final String reviews = reviewsCount.toString();
    final bool isNewcomer = reviewsCount < 5;

    String newcomerText = 'Новичок';
    String ratingDesc = _t('rating_stat').toUpperCase();
    
    if (isNewcomer) {
      if (_localLang == 'Қазақша') {
        newcomerText = 'Жаңадан бастаушы';
        ratingDesc = '5 бағалаудан кейін қалыптасады';
      } else if (_localLang == 'Уйғурчә') {
        newcomerText = 'Йеңи әза';
        ratingDesc = '5 баһалаштин кейин шәкиллиниду';
      } else {
        newcomerText = 'Новичок';
        ratingDesc = 'Сформируется после 5 оценок';
      }
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () {
          if (user != null) {
            _showMyReviewsBottomSheet(user.uid);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 24),
          decoration: BoxDecoration(
            color: _surfaceColor,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 24, offset: const Offset(0, 12))],
            border: Border.all(color: _isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 24),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            isNewcomer ? newcomerText : rating, 
                            style: GoogleFonts.inter(
                              fontSize: isNewcomer ? 16 : 24, 
                              fontWeight: FontWeight.w900, 
                              color: _txtColor
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ratingDesc, 
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: isNewcomer ? 8.5 : 10, 
                        fontWeight: FontWeight.w700, 
                        color: _subtxtColor, 
                        letterSpacing: isNewcomer ? 0.0 : 1.0
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                width: 1, 
                height: 40, 
                color: _subtxtColor.withValues(alpha: 0.1),
                margin: const EdgeInsets.symmetric(horizontal: 12),
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      reviews, 
                      style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: _txtColor),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _t('reviews_stat').toUpperCase(), 
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: _subtxtColor, letterSpacing: 1.0),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMyReviewsBottomSheet(String userId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(35)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: _subtxtColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Text(_t('my_reviews'), style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: _txtColor)),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: _txtColor),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: StreamBuilder<List<ReviewModel>>(
                stream: ReviewService.getUserReviewsStream(userId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final reviews = snapshot.data ?? [];
                  if (reviews.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.rate_review_outlined, size: 70, color: _subtxtColor.withValues(alpha: 0.3)),
                          const SizedBox(height: 16),
                          Text(_t('no_reviews_yet'), style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: _subtxtColor)),
                        ],
                      ),
                    );
                  }
                  
                  return ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: reviews.length,
                    separatorBuilder: (c, i) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final r = reviews[index];
                      return Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: _isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: _subtxtColor.withValues(alpha: 0.08)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(r.fromUserName, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14, color: _txtColor)),
                                const Spacer(),
                                Text(
                                  '${r.timestamp.day.toString().padLeft(2, '0')}.${r.timestamp.month.toString().padLeft(2, '0')}.${r.timestamp.year}',
                                  style: GoogleFonts.inter(fontSize: 11, color: _subtxtColor),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: List.generate(5, (i) => Icon(
                                i < r.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                                size: 16, color: const Color(0xFFF59E0B),
                              )),
                            ),
                            if (r.adTitle.isNotEmpty || r.adId.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () async {
                                    if (r.adId.isEmpty) return;
                                    try {
                                      final ad = await AdService.getAdById(r.adId);
                                      if (ad != null && context.mounted) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => ProductDetailsScreen(
                                              ad: ad,
                                              onReport: (_) {},
                                              lang: widget.lang,
                                              heroPrefix: 'my_review_ad_${r.adId}',
                                            ),
                                          ),
                                        );
                                      } else if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              widget.lang == 'Қазақша'
                                                  ? 'Хабарландыру табылмады немесе өшірілген'
                                                  : widget.lang == 'Уйғурчә'
                                                      ? 'Елан тепильмиди йаки өчүрүлгән'
                                                      : 'Объявление не найдено или удалено',
                                            ),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      debugPrint('Error opening ad from review: $e');
                                    }
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.shopping_bag_outlined, size: 14, color: _primaryColor),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            '${_t('for_ad')}: ${r.adTitle.isNotEmpty ? r.adTitle : "Объявление"}',
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: _primaryColor,
                                              decoration: TextDecoration.underline,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(Icons.arrow_forward_ios_rounded, size: 11, color: _primaryColor),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),
                            Text(r.comment, style: GoogleFonts.inter(fontSize: 13.5, color: _txtColor.withValues(alpha: 0.8), height: 1.5)),
                            if (r.images.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 60,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: r.images.length.clamp(0, 4),
                                  itemBuilder: (context, i) => GestureDetector(
                                    onTap: () {
                                      final url = r.images[i];
                                      if (url.isNotEmpty && url.startsWith('http')) {
                                        _showFullScreenPhoto(url);
                                      }
                                    },
                                    child: Container(
                                      width: 60,
                                      margin: const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        image: (r.images[i].isNotEmpty && r.images[i].startsWith('http'))
                                            ? DecorationImage(image: NetworkImage(r.images[i]), fit: BoxFit.cover)
                                            : null,
                                        color: _isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[200],
                                      ),
                                      child: (r.images[i].isEmpty || !r.images[i].startsWith('http'))
                                          ? const Icon(Icons.broken_image_rounded, size: 20, color: Colors.grey)
                                          : null,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationSection() {
    if (_isGuest || _isVerified) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0088CC), Color(0xFF229ED9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0088CC).withValues(alpha: 0.25), 
              blurRadius: 12, 
              offset: const Offset(0, 6),
            )
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => _showVerificationBottomSheet(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.shield_outlined, 
                      color: Colors.white, 
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Профиль не верифицирован',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14, 
                            fontWeight: FontWeight.w900, 
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Пройдите верификацию в Telegram для доступа к поездкам',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11, 
                            fontWeight: FontWeight.w600, 
                            color: Colors.white.withValues(alpha: 0.95),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 14),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showVerificationBottomSheet() {
    _tgCode = '';
    _sheetError = null;
    _isWaitingForBot = false;
    _codeCtrl.clear();
    bool isVerifying = false;

    // Pre-fill phone if available from FirebaseAuth or local storage
    final user = FirebaseAuth.instance.currentUser;
    String initialPhone = user?.phoneNumber ?? '';
    if (initialPhone.isEmpty) {
      initialPhone = StorageService.getString('user_phone') ?? '';
    }
    if (initialPhone.isNotEmpty) {
      final digits = initialPhone.replaceAll(RegExp(r'\D'), '');
      String localDigits = digits;
      if (digits.length == 11 && (digits.startsWith('7') || digits.startsWith('8'))) {
        localDigits = digits.substring(1);
      } else if (digits.length > 11) {
        localDigits = digits.substring(digits.length - 10);
      }
      _phoneCtrl.text = _phoneMask.maskText(localDigits);
    } else {
      _phoneCtrl.clear();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            decoration: BoxDecoration(
              color: _surfaceColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(35)),
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24, 
                top: 24, 
                left: 24, 
                right: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40, 
                    height: 4, 
                    decoration: BoxDecoration(
                      color: _subtxtColor.withValues(alpha: 0.2), 
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Icon(Icons.shield_rounded, color: _primaryColor, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    _t('verification_title'),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20, 
                      fontWeight: FontWeight.w900, 
                      color: _txtColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _t('verification_desc'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13, 
                      color: _subtxtColor, 
                      height: 1.4,
                    ),
                  ),
                  
                  if (_tgCode.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF229ED9), Color(0xFF0088CC)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0088CC).withValues(alpha: 0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.telegram, color: Colors.white, size: 22),
                              const SizedBox(width: 10),
                              Text(
                                _t('code_sent_tg'),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14, 
                                  color: Colors.white.withValues(alpha: 0.9), 
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _tgCode,
                              style: GoogleFonts.firaCode(
                                fontSize: 24, 
                                color: Colors.white, 
                                fontWeight: FontWeight.w900, 
                                letterSpacing: 4.0,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _t('code_received_bot'),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11, 
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (_isWaitingForBot) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0088CC).withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: const Color(0xFF0088CC).withValues(alpha: 0.15)),
                      ),
                      child: Column(
                        children: [
                          const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Color(0xFF0088CC), strokeWidth: 3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _t('waiting_bot_start'),
                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 15, color: _txtColor),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _t('tg_start_instruction'),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(fontSize: 12, color: _subtxtColor, height: 1.4),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () async {
                              if (_tgSessionToken != null) {
                                final botUrl = TelegramBotService.buildBotUrl(_tgSessionToken!);
                                await launchUrl(Uri.parse(botUrl), mode: LaunchMode.externalApplication);
                              }
                            },
                            icon: const Icon(Icons.telegram, color: Colors.white, size: 18),
                            label: Text(_t('reopen_telegram')),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0088CC),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 24),
                  
                  // Phone Input
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: _subtxtColor.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _primaryColor.withValues(alpha: 0.1)),
                    ),
                    child: TextField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [_phoneMask],
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: _txtColor),
                      enabled: !_isWaitingForBot && !_isTimerRunning,
                      decoration: InputDecoration(
                        hintText: '+7 (700) 000-00-00',
                        hintStyle: TextStyle(color: _subtxtColor.withValues(alpha: 0.4)),
                        border: InputBorder.none,
                        suffixIcon: _isTimerRunning 
                          ? Container(
                              alignment: Alignment.centerRight,
                              width: 50,
                              child: Text(
                                '$_timerSeconds с', 
                                style: TextStyle(color: _primaryColor, fontWeight: FontWeight.w900),
                              ),
                            )
                          : (_isWaitingForBot 
                              ? const SizedBox(
                                  width: 20, height: 20,
                                  child: Padding(
                                    padding: EdgeInsets.all(12),
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                )
                              : TextButton(
                                  onPressed: () async {
                                    String cleanPhone = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
                                    if (cleanPhone.startsWith('8') && cleanPhone.length == 11) {
                                      cleanPhone = '7' + cleanPhone.substring(1);
                                    } else if (cleanPhone.length == 10) {
                                      cleanPhone = '7' + cleanPhone;
                                    }

                                    // X10 Operator Validation
                                    bool isPhoneValid = true;
                                    String? validationError;
                                    if (cleanPhone.length != 11) {
                                      isPhoneValid = false;
                                      validationError = _t('phone_length_error');
                                    } else if (!cleanPhone.startsWith('7')) {
                                      isPhoneValid = false;
                                      validationError = _t('phone_start_error');
                                    } else {
                                      final operatorCode = cleanPhone.substring(1, 4);
                                      final validPrefixes = [
                                        '700', '701', '702', '703', '704', '705', '706', '707', '708', '709',
                                        '747', '750', '751', '760', '761', '762', '763', '764',
                                        '771', '775', '776', '777', '778'
                                      ];
                                      if (!validPrefixes.contains(operatorCode)) {
                                        isPhoneValid = false;
                                        validationError = '${_t('operator_code_error')}: $operatorCode! ❌';
                                      }
                                    }

                                    if (!isPhoneValid) {
                                      setModalState(() {
                                        _sheetError = validationError;
                                      });
                                      return;
                                    }
                                    
                                    setModalState(() {
                                      _isWaitingForBot = true;
                                      _sheetError = null;
                                    });

                                    try {
                                      // 1. Start Telegram Session with clean standardized phone number!
                                      _tgSessionToken = await AuthService.startTelegramSession(phone: cleanPhone);
                                      
                                      // 2. Watch Telegram session stream
                                      _tgSessionSub?.cancel();
                                      _tgSessionSub = AuthService.watchTelegramSession(_tgSessionToken!).listen((snap) {
                                        if (!snap.exists) return;
                                        final data = snap.data();
                                        if (data == null) return;
                                        
                                        final String? chatId = data['chat_id'];
                                        final String? otp = data['otp'];
                                        
                                        if (chatId != null && otp != null && otp.isNotEmpty) {
                                          _tgSessionSub?.cancel();
                                          setModalState(() {
                                            _tgCode = otp;
                                            _isWaitingForBot = false;
                                            _sheetError = null;
                                            _isTimerRunning = true;
                                            _timerSeconds = 60;
                                          });
                                          _startTimer();
                                          
                                          // Update modal periodic ticks
                                          _modalTimer?.cancel();
                                          _modalTimer = Timer.periodic(const Duration(seconds: 1), (t) {
                                            if (mounted && _isTimerRunning) {
                                              setModalState(() {});
                                            } else {
                                              t.cancel();
                                            }
                                          });
                                        }
                                      });
                                    } catch (e) {
                                      setModalState(() {
                                        _isWaitingForBot = false;
                                        _sheetError = '${_t('session_start_error')}: $e';
                                      });
                                    }
                                  },
                                  child: Text(_t('next').toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900)),
                                )),
                        suffixIconConstraints: const BoxConstraints(minWidth: 80, minHeight: 0),
                      ),
                    ),
                  ),
                  
                  if (_isTimerRunning) ...[
                    const SizedBox(height: 20),
                    Text(
                      _t('enter_6_digit_code'),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _subtxtColor.withValues(alpha: 0.7),
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Opacity(
                          opacity: 0.0,
                          child: TextField(
                            controller: _codeCtrl,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            autofocus: true,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            onChanged: (v) {
                              setModalState(() {});
                            },
                            decoration: const InputDecoration(
                              counterText: "",
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        IgnorePointer(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(6, (index) {
                              String char = "";
                              if (_codeCtrl.text.length > index) {
                                char = _codeCtrl.text[index];
                              }
                              
                              bool isFocused = _codeCtrl.text.length == index;
                              if (_codeCtrl.text.length == 6 && index == 5) {
                                isFocused = true;
                              }
                              
                              return Container(
                                width: 44,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: _isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isFocused 
                                      ? const Color(0xFF229ED9) 
                                      : (_isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08)),
                                    width: isFocused ? 2.2 : 1.0,
                                  ),
                                  boxShadow: isFocused 
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFF229ED9).withValues(alpha: 0.2),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        )
                                      ]
                                    : [],
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  char,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: _txtColor,
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
                    if (_sheetError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _sheetError!,
                        style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: isVerifying ? null : () async {
                          setModalState(() => isVerifying = true);
                          try {
                            final callable = FirebaseFunctions.instance.httpsCallable('verifyTelegramOtp');
                            final result = await callable.call({
                              'otp': _codeCtrl.text.trim(),
                              'phone': _phoneCtrl.text,
                              'sessionToken': _tgSessionToken,
                            });

                            if (result.data['success'] == true) {
                              setState(() => _isVerified = true);
                              
                              // Sync to local storage
                              StorageService.saveProfile(
                                _localName,
                                _firestorePhotoUrl,
                                _localBio,
                                _localAccType,
                                isVerified: true,
                              );
                              await StorageService.setString('user_phone', _phoneCtrl.text);
                              
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(_t('account_verified_success')), 
                                    backgroundColor: const Color(0xFF229ED9),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            } else {
                              throw Exception('Ошибка проверки кода');
                            }
                          } catch (e) {
                            setModalState(() {
                              _sheetError = '${_t('error')}: $e';
                            });
                          } finally {
                            setModalState(() => isVerifying = false);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF229ED9),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          elevation: 0,
                        ),
                        child: isVerifying
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text(_t('confirm_code'), style: const TextStyle(fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ] else ...[
                    if (_sheetError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _sheetError!,
                        style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                  const SizedBox(height: 12),
                ],
              ),
            ),
          );
        }
      ),
    ).then((_) {
      // Clean up session subscription when bottom sheet is closed
      _tgSessionSub?.cancel();
      _modalTimer?.cancel();
      _isTimerRunning = false;
    });
  }



  Widget _buildSimplifiedMenu() {
    final user = FirebaseAuth.instance.currentUser;
    final providers = user?.providerData.map((p) => p.providerId).toList() ?? [];
    final isEmailUser = providers.contains('password');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // GROUP 1: Личный кабинет
          if (!_isGuest) ...[
            _buildMenuSectionTitle(_t('personal_data')),
            _buildMenuCard([
              _buildListItem(Icons.person_outline_rounded, _t('personal_data'), () => _openSettings(_firestorePhotoUrl)),
              _buildListItemDivider(),
              _buildListItem(Icons.grid_view_rounded, _t('my_ads'), () => _openMyAds()),
              _buildListItemDivider(),
              _buildListItem(Icons.chat_bubble_outline_rounded, _t('chats'), () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => NotificationsScreen(lang: _localLang)));
              }),
              _buildListItemDivider(),
              _buildListItem(Icons.favorite_border_rounded, _t('favorites'), () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => FavoritesScreen(
                  lang: _localLang,
                  themes: widget.themes,
                  currentTheme: _currentTheme,
                  onShowDetails: widget.onShowProductDetails,
                )));
              }),
            ]),
            const SizedBox(height: 25),
          ],

          // GROUP 2: Система
          if (isEmailUser || _localAccType == 'admin') ...[
            _buildMenuSectionTitle(_t('system')),
            _buildMenuCard([
              if (isEmailUser)
                _buildListItem(Icons.security_rounded, _t('security'), _showSecurityDialog),
              if (isEmailUser && _localAccType == 'admin')
                _buildListItemDivider(),
              if (_localAccType == 'admin')
                _buildListItem(Icons.admin_panel_settings_outlined, _t('admin_panel'), () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminPanelScreen()));
                }),
            ]),
            const SizedBox(height: 25),
          ],

          // GROUP 3: Информация
          _buildMenuSectionTitle(_t('info_title')),
          _buildMenuCard([
            _buildListItem(Icons.support_agent_rounded, 'IQ-Поддержка', () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => IqSupportScreen(lang: _localLang)));
            }),
            _buildListItemDivider(),
            _buildListItem(Icons.help_outline_rounded, _t('help'), () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => HelpCenterScreen(lang: _localLang)));
            }),
            _buildListItemDivider(),
            _buildListItem(Icons.description_outlined, _t('legal'), () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => LegalInfoScreen(lang: _localLang)));
            }),
            _buildListItemDivider(),
            _buildListItem(Icons.star_rate_rounded, _t('rate_app'), _openStore),
            _buildListItemDivider(),
            _buildListItem(Icons.info_outline_rounded, _t('about'), _showAboutDialog),
          ]),
        ],
      ),
    );
  }

  Widget _buildMenuSectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(left: 6, bottom: 8),
    child: Text(
      title.toUpperCase(),
      style: GoogleFonts.plusJakartaSans(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: _subtxtColor.withValues(alpha: 0.6),
        letterSpacing: 1.2,
      ),
    ),
  );

  Widget _buildMenuCard(List<Widget> children) => Container(
    decoration: BoxDecoration(
      color: _surfaceColor,
      borderRadius: BorderRadius.circular(28),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.02),
          blurRadius: 20,
          offset: const Offset(0, 10),
        )
      ],
      border: Border.all(
        color: _isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
        width: 1.2,
      ),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Column(children: children),
    ),
  );

  Widget _buildListItemDivider() => Divider(
    height: 1,
    thickness: 0.8,
    color: _subtxtColor.withValues(alpha: 0.06),
    indent: 64,
    endIndent: 16,
  );

  Widget _buildListItem(IconData icon, String label, VoidCallback onTap) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _primaryColor.withValues(alpha: 0.12),
                    _primaryColor.withValues(alpha: 0.04),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: _primaryColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label, 
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700, 
                  fontSize: 14.5, 
                  color: _txtColor,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded, 
              size: 12, 
              color: _subtxtColor.withValues(alpha: 0.35),
            ),
          ],
        ),
      ),
    ),
  );



  void _openMyAds() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => MyAdsScreen(
      lang: _localLang,
    )));
  }








  void _showFullScreenPhoto(String photoUrl) {
    if (photoUrl.isNotEmpty && photoUrl.startsWith('http')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SecureImageViewerScreen(
            imageUrl: photoUrl,
            heroTag: 'avatar_full',
          ),
        ),
      );
    } else if (_localImage != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SecureImageViewerScreen(
            file: _localImage,
            heroTag: 'avatar_full',
          ),
        ),
      );
    }
  }

  void _openSettings(String currentPhotoUrl) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileSettingsScreen(
      currentName: _localName,
      profileImagePath: currentPhotoUrl.isNotEmpty ? currentPhotoUrl : _localImage?.path,
      isBioEnabled: _localBio,
      accType: _localAccType,
      lang: _localLang,
      currentTheme: _currentTheme,
      themes: widget.themes,
      onThemeChanged: (theme) {
        setState(() => _currentTheme = theme);
        widget.onThemeChanged(theme);
      },
      onSave: (newName, newImg, newBio, newType, newLang) {
        setState(() {
          _localName = newName;
          if (newImg != null) _localImage = newImg;
          _localBio = newBio;
          _localAccType = newType;
          _localLang = newLang;
          widget.onUpdateProfile(newName, newImg, newBio, newType, newLang);
        });
      },
    )));
  }



  void _showSecurityDialog() {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(color: _surfaceColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(30))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: _subtxtColor.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10))),
                const SizedBox(height: 25),
                const Icon(Icons.shield_outlined, color: Color(0xFF4A80F0), size: 54),
                const SizedBox(height: 20),
                Text(_t('change_password'), style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: _txtColor)),
                const SizedBox(height: 10),
                Text(_t('enter_new_password_desc'), textAlign: TextAlign.center, style: TextStyle(color: _subtxtColor, fontSize: 13)),
                const SizedBox(height: 25),
                _buildSecurityField(_t('new_password'), passwordController, true),
                const SizedBox(height: 15),
                _buildSecurityField(_t('confirm_password'), confirmController, true),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : () async {
                      if (passwordController.text.length < 6) {
                        _showLocalError(_t('min_6_chars'));
                        return;
                      }
                      if (passwordController.text != confirmController.text) {
                        _showLocalError(_t('passwords_dont_match'));
                        return;
                      }

                      setModalState(() => isLoading = true);
                      try {
                        await AuthService.updatePassword(passwordController.text);
                        if (mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('password_changed_success')), backgroundColor: Colors.green));
                        }
                      } catch (e) {
                        _showLocalError('${_t('error')}: $e');
                      } finally {
                        setModalState(() => isLoading = false);
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    child: isLoading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(_t('updatePasswordBtn'), style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 15),
              ],
            ),
          ),
        ),
      ),
    ).then((_) {
      passwordController.dispose();
      confirmController.dispose();
    });
  }

  void _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('logout_title')),
        content: Text(_t('logout_content')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(_t('cancel'))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(_t('confirm_logout'), style: const TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await AuthService.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const IQMarketHome()),
          (route) => false,
        );
      }
    }
  }

  void _showLocalError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.redAccent));
  }

  Widget _buildSecurityField(String label, TextEditingController controller, bool isPassword) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      style: TextStyle(color: _txtColor, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: _subtxtColor, fontSize: 14),
        filled: true,
        fillColor: _subtxtColor.withValues(alpha: 0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      ),
    );
  }
  Widget _buildGuestBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _primaryColor.withValues(alpha: 0.1)),
        boxShadow: [BoxShadow(color: _primaryColor.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          Icon(Icons.person_add_rounded, size: 48, color: _primaryColor),
          const SizedBox(height: 16),
          Text(
            _t('guest_join_title'),
            style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: _txtColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _t('guest_join_desc'),
            style: GoogleFonts.inter(fontSize: 14, color: _subtxtColor, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                final currentLang = Provider.of<AppConfigProvider>(context, listen: false).language;
                Navigator.push(context, MaterialPageRoute(builder: (_) => LoginScreen(lang: currentLang)));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Text(_t('guest_login_btn').toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => _handleLogout(),
          icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
          label: Text(_t('logout').toUpperCase(), style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 18),
            side: const BorderSide(color: Colors.redAccent),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ),
    );
  }



  void _openStore() async {
    final appId = "com.iqmarket.app";
    final url = Platform.isAndroid 
        ? Uri.parse("https://play.google.com/store/apps/details?id=$appId")
        : Uri.parse("https://apps.apple.com/app/id64748B"); // Replace with real iOS ID when available
    
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      _showLocalError(_t('failed_open_store'));
    }
  }

  void _showAboutDialog() {
    final isDark = _isDark;
    final bgSurface = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textDark = isDark ? Colors.white : const Color(0xFF0F172A);
    final cardBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFFAFAFA);
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB);
    final subText = isDark ? Colors.grey[400] : const Color(0xFF64748B);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
        decoration: BoxDecoration(
          color: bgSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 25,
              offset: const Offset(0, -5),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'IQ-Market',
              style: GoogleFonts.inter(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: textDark,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'PRO v1.1.0',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: subText,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'О РАЗРАБОТЧИКЕ',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF3B82F6),
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: cardBorder, width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Надыров Рустам Иминжанович',
                    style: GoogleFonts.inter(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: textDark,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Основатель и главный разработчик платформы IQ-Market.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      height: 1.45,
                      color: textDark,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Вся интеллектуальная собственность, исходный код, дизайн и бренд приложения строго защищены и принадлежат автору.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      height: 1.45,
                      color: textDark,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Icon(
                        Icons.verified_rounded,
                        color: Color(0xFF3B82F6),
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Официальные права © 2026',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: textDark,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Версия приложения: 1.1.0',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Сервис предназначен для удобного и безопасного размещения объявлений. Любое использование материалов без согласия автора запрещено.',
              style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.4,
                color: subText,
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
