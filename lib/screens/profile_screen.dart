import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:iqmarket/services/storage_service.dart';
import 'package:iqmarket/services/user_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:iqmarket/screens/my_ads_screen.dart';
import 'package:iqmarket/screens/profile_settings_screen.dart';
import 'package:iqmarket/screens/help_center_screen.dart';
import 'package:iqmarket/screens/notifications_screen.dart';
import 'package:iqmarket/screens/favorites_screen.dart';
import 'package:iqmarket/models/ad_model.dart';
import 'package:iqmarket/screens/login_screen.dart';
import 'package:iqmarket/screens/legal_info_screen.dart';
import 'package:screen_protector/screen_protector.dart';
import 'dart:async';
import 'package:iqmarket/screens/chats_list_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:iqmarket/screens/admin/admin_panel_screen.dart';
import 'package:iqmarket/widgets/profile/profile_components.dart';
import 'package:iqmarket/translations/profile_strings.dart';
import 'package:iqmarket/services/auth_service.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:iqmarket/models/user_model.dart';
import 'package:iqmarket/constants/app_constants.dart';
import 'package:iqmarket/models/review_model.dart';
import 'package:iqmarket/services/review_service.dart';
import 'package:intl/intl.dart';

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
  final ImagePicker _picker = ImagePicker();
  File? _localImage;
  late String _localName;
  late bool _localBio;
  late String _localAccType;
  late String _localLang;
  late bool _isGuest;
  late String _currentTheme;
  int _salesCount = 0;
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
  
  void _startTimer() {
    setState(() {
      _timerSeconds = 60;
      _isTimerRunning = true;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerSeconds == 0) {
        setState(() => _isTimerRunning = false);
        timer.cancel();
      } else {
        setState(() => _timerSeconds--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
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
  Color get _primaryColor => widget.themes[_currentTheme]?['primary'] ?? const Color(0xFF4A80F0);
  Color get _accentColor => const Color(0xFF4C4DDC);

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
    _loadSalesCount();
  }

  int _adminTapCount = 0;

  Future<void> _loadSalesCount() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _salesCount = prefs.getInt('iq_sales_count') ?? 0);
  }

  static Future<void> recordSale() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt('iq_sales_count') ?? 0;
    await prefs.setInt('iq_sales_count', current + 1);
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
        stream: UserService.getUserStream(),
        builder: (context, snapshot) {
          final user = snapshot.data;
          if (user != null) {
            _localName = user.name;
            _isVerified = user.isVerified;
            _localAccType = user.accountType;
            _firestorePhotoUrl = user.photoUrl ?? '';
          }

          final String displayName = _isGuest ? 'Гость' : (user?.name ?? _localName);
          final String photoUrl = user?.photoUrl ?? '';

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                elevation: 0,
                backgroundColor: const Color(0xFF4A80F0),
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
                            colors: [Color(0xFF4A80F0), Color(0xFF6366F1)],
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
                                      ? (displayName.trim().isNotEmpty 
                                          ? Text(displayName.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join('').toUpperCase(), 
                                              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Color(0xFF4A80F0)))
                                          : const Icon(Icons.person, size: 50, color: Color(0xFF4A80F0)))
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
                    Text(
                      displayName,
                      style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w900, color: _txtColor),
                    ),
                    if (_isVerified) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.verified_rounded, color: Color(0xFF4A80F0), size: 20),
                          const SizedBox(width: 6),
                          Text(_t('badge_verified'), style: GoogleFonts.inter(color: const Color(0xFF4A80F0), fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    ],
                    const SizedBox(height: 25),
                    _buildStatsBar(user),
                    const SizedBox(height: 25),
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
    final double rawRating = user?.rating ?? 0.0;
    final String rating = rawRating.toStringAsFixed(1);
    final String reviews = (user?.reviewsCount ?? 0).toString();
    
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
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 24),
                      const SizedBox(width: 8),
                      Text(rating, style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: _txtColor)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(_t('rating_stat').toUpperCase(), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: _subtxtColor, letterSpacing: 1.0)),
                ],
              ),
              const SizedBox(width: 40),
              Container(width: 1, height: 40, color: _subtxtColor.withValues(alpha: 0.1)),
              const SizedBox(width: 40),
              Column(
                children: [
                  Text(reviews, style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: _txtColor)),
                  const SizedBox(height: 4),
                  Text(_t('reviews_stat').toUpperCase(), 
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: _subtxtColor, letterSpacing: 1.0)),
                ],
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
                  Text('Мои отзывы', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: _txtColor)),
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
                          Text('У вас пока нет отзывов', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: _subtxtColor)),
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
                            if (r.adTitle.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Icon(Icons.shopping_bag_outlined, size: 14, color: _primaryColor),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'К объявлению: ${r.adTitle}',
                                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: _primaryColor),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 10),
                            Text(r.comment, style: GoogleFonts.inter(fontSize: 13.5, color: _txtColor.withValues(alpha: 0.8), height: 1.5)),
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
    if (_isGuest) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: _isVerified 
            ? const LinearGradient(
                colors: [Color(0xFF0088CC), Color(0xFF229ED9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Color(0xFF229ED9), Color(0xFF2AABEE)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF229ED9).withValues(alpha: 0.15), 
              blurRadius: 10, 
              offset: const Offset(0, 6),
            )
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: _isVerified ? null : () => _showVerificationBottomSheet(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _isVerified 
                        ? Icons.verified_rounded 
                        : PhosphorIcons.telegramLogo(PhosphorIconsStyle.fill), 
                      color: Colors.white, 
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isVerified ? _t('badge_verified') : 'Верификация через Telegram',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14, 
                            fontWeight: FontWeight.w900, 
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isVerified ? _t('verified_info') : 'Подтвердите номер телефона в один клик',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11, 
                            fontWeight: FontWeight.w600, 
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!_isVerified) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 12),
                  ],
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

    // Pre-fill phone if available from FirebaseAuth or local storage
    final user = FirebaseAuth.instance.currentUser;
    String initialPhone = user?.phoneNumber ?? '';
    if (initialPhone.isEmpty) {
      initialPhone = StorageService.getString('user_phone') ?? '';
    }
    if (initialPhone.isNotEmpty) {
      final digits = initialPhone.replaceAll(RegExp(r'\D'), '');
      if (digits.length >= 10) {
        String cleanedDigits = digits;
        if (digits.startsWith('8') && digits.length == 11) {
          cleanedDigits = '7' + digits.substring(1);
        } else if (digits.length == 10) {
          cleanedDigits = '7' + digits;
        }
        _phoneCtrl.text = _phoneMask.maskText(cleanedDigits);
      }
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
                                'Код отправлен в Telegram',
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
                            'Код пришел в чат с ботом @IQ_Taxi_bot',
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
                            'Ожидаем запуск бота... 🤖',
                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 15, color: _txtColor),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Мы открыли Telegram. Пожалуйста, нажмите кнопку «СТАРТ» (запустить) в чате бота, чтобы получить код.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(fontSize: 12, color: _subtxtColor, height: 1.4),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () async {
                              if (_tgSessionToken != null) {
                                final botUrl = 'https://t.me/IQ_Taxi_bot?start=$_tgSessionToken';
                                await launchUrl(Uri.parse(botUrl), mode: LaunchMode.externalApplication);
                              }
                            },
                            icon: const Icon(Icons.telegram, color: Colors.white, size: 18),
                            label: const Text('ОТКРЫТЬ TELEGRAM ПОВТОРНО'),
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
                                      validationError = 'Номер должен состоять из 11 цифр! Пример: +7 (707) 123-45-67 📱';
                                    } else if (!cleanPhone.startsWith('7')) {
                                      isPhoneValid = false;
                                      validationError = 'Номер должен начинаться с +7 или 8! 🇰🇿';
                                    } else {
                                      final operatorCode = cleanPhone.substring(1, 4);
                                      final validPrefixes = [
                                        '700', '701', '702', '703', '704', '705', '706', '707', '708', '709',
                                        '747', '750', '751', '760', '761', '762', '763', '764',
                                        '771', '775', '776', '777', '778'
                                      ];
                                      if (!validPrefixes.contains(operatorCode)) {
                                        isPhoneValid = false;
                                        validationError = 'Неверный код оператора Казахстана: $operatorCode! ❌';
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
                                          Timer.periodic(const Duration(seconds: 1), (t) {
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
                                        _sheetError = 'Ошибка запуска сессии: $e';
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
                      'ВВЕДИТЕ 6-ЗНАЧНЫЙ КОД ИЗ TELEGRAM:',
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
                        onPressed: () async {
                          if (_codeCtrl.text.trim() == _tgCode) {
                            try {
                              await UserService.updateUserProfile({
                                'isVerified': true,
                                'phone': _phoneCtrl.text,
                              });
                              setState(() => _isVerified = true);
                              
                              // Sync to local storage
                              StorageService.saveProfile(
                                _localName,
                                _firestorePhotoUrl,
                                _localBio,
                                _localAccType,
                                isVerified: true,
                              );
                              
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Аккаунт успешно верифицирован! 💙'), 
                                    backgroundColor: Color(0xFF229ED9),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            } catch (e) {
                              setModalState(() {
                                _sheetError = 'Ошибка: $e';
                              });
                            }
                          } else {
                            setModalState(() {
                              _sheetError = 'Неверный код! Проверьте правильность ввода. ❌';
                            });
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF229ED9),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          elevation: 0,
                        ),
                        child: const Text('ПОДТВЕРДИТЬ КОД 💙', style: TextStyle(fontWeight: FontWeight.w900)),
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
    });
  }

  void _showVerificationInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: _subtxtColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 24),
            Text(_t('why_verify'), style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: _txtColor)),
            const SizedBox(height: 24),
            _buildBenefitItemLarge(_t('verify_benefit_1'), 'Покупатели чаще выбирают проверенных продавцов.'),
            _buildBenefitItemLarge(_t('verify_benefit_2'), 'Ваши объявления будут выше в списке выдачи.'),
            _buildBenefitItemLarge(_t('verify_benefit_3'), 'Подтвержденный профиль защищает от мошенников.'),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: const Text('ПОНЯТНО', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitItemLarge(String title, String desc) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: _primaryColor.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(Icons.check_rounded, color: _primaryColor, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: _txtColor)),
              const SizedBox(height: 4),
              Text(desc, style: GoogleFonts.inter(fontSize: 13, color: _subtxtColor, height: 1.4)),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildBenefitItem(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Icon(Icons.check_circle_rounded, color: _primaryColor, size: 16),
        const SizedBox(width: 10),
        Text(text, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _subtxtColor)),
      ],
    ),
  );

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
          _buildMenuSectionTitle(_t('personal_data')),
          _buildMenuCard([
            _buildListItem(Icons.person_outline_rounded, _t('personal_data'), () => _openSettings(_firestorePhotoUrl)),
            _buildListItemDivider(),
            _buildListItem(Icons.grid_view_rounded, 'Мои объявления', () => _openMyAds()),
            _buildListItemDivider(),
            _buildListItem(Icons.chat_bubble_outline_rounded, 'Мои сообщения', () {
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

          // GROUP 2: Система
          if (isEmailUser || _localAccType == 'admin') ...[
            _buildMenuSectionTitle('Система'),
            _buildMenuCard([
              if (isEmailUser)
                _buildListItem(Icons.security_rounded, 'Безопасность', _showSecurityDialog),
              if (isEmailUser && _localAccType == 'admin')
                _buildListItemDivider(),
              if (_localAccType == 'admin')
                _buildListItem(Icons.admin_panel_settings_outlined, 'Панель администратора', () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminPanelScreen()));
                }),
            ]),
            const SizedBox(height: 25),
          ],

          // GROUP 3: Информация
          _buildMenuSectionTitle('Информация'),
          _buildMenuCard([
            _buildListItem(Icons.help_outline_rounded, _t('help'), () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => HelpCenterScreen(lang: _localLang)));
            }),
            _buildListItemDivider(),
            _buildListItem(Icons.description_outlined, _t('legal'), () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => LegalInfoScreen(lang: _localLang)));
            }),
            _buildListItemDivider(),
            _buildListItem(Icons.star_rate_rounded, 'Оценить приложение', _openStore),
            _buildListItemDivider(),
            _buildListItem(Icons.info_outline_rounded, 'О приложении', _showAboutDialog),
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
    ImageProvider? imageProvider;
    if (photoUrl.isNotEmpty && photoUrl.startsWith('http')) {
      imageProvider = NetworkImage(photoUrl);
    } else if (_localImage != null) {
      imageProvider = FileImage(_localImage!);
    }
    
    if (imageProvider == null) return;

    Navigator.push(context, MaterialPageRoute(builder: (context) => Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Hero(
          tag: 'avatar_full',
          child: InteractiveViewer(
            clipBehavior: Clip.none,
            maxScale: 4.0,
            child: Image(image: imageProvider!),
          ),
        ),
      ),
    )));
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


  Widget _buildAuthButton(BuildContext context) {
    if (_isGuest) {
      return Center(
        child: ElevatedButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen())).then((_) {
            setState(() => _isGuest = !UserService.isLoggedIn);
          }),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4A80F0),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            elevation: 4,
          ),
          child: FittedBox(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.login_rounded, size: 20),
                const SizedBox(width: 10),
                Text('ВОЙТИ ИЛИ СОЗДАТЬ АККАУНТ', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 13)),
              ],
            ),
          ),
        ),
      );
    }
    
    return Center(
      child: TextButton(
        onPressed: () async {
          await AuthService.signOut();
          if (widget.onLogout != null) widget.onLogout!();
          setState(() => _isGuest = true); 
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_t('logout_confirm')),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        },
        style: TextButton.styleFrom(
          foregroundColor: Colors.red,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.logout_rounded, size: 20),
            const SizedBox(width: 10),
            Text(_t('logout'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  void _showFullScreenAvatar() async {
    if (_localImage == null) return;
    
    // Защита от скриншотов при открытии
    await ScreenProtector.preventScreenshotOn();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(color: Colors.black.withValues(alpha: 0.95), width: double.infinity, height: double.infinity),
            ),
            Hero(
              tag: 'avatar_full',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.file(_localImage!, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 50,
              right: 25,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 32),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    ).then((_) async {
      // Снимаем защиту при закрытии
      await ScreenProtector.preventScreenshotOff();
    });
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
                Text('Смена пароля', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: _txtColor)),
                const SizedBox(height: 10),
                Text('Введите новый пароль для вашей учетной записи', textAlign: TextAlign.center, style: TextStyle(color: _subtxtColor, fontSize: 13)),
                const SizedBox(height: 25),
                _buildSecurityField('Новый пароль', passwordController, true),
                const SizedBox(height: 15),
                _buildSecurityField('Подтвердите пароль', confirmController, true),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : () async {
                      if (passwordController.text.length < 6) {
                        _showLocalError('Минимум 6 символов');
                        return;
                      }
                      if (passwordController.text != confirmController.text) {
                        _showLocalError('Пароли не совпадают');
                        return;
                      }

                      setModalState(() => isLoading = true);
                      try {
                        await AuthService.updatePassword(passwordController.text);
                        if (mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Пароль успешно изменен! ✅'), backgroundColor: Colors.green));
                        }
                      } catch (e) {
                        _showLocalError('Ошибка: $e');
                      } finally {
                        setModalState(() => isLoading = false);
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    child: isLoading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('ОБНОВИТЬ ПАРОЛЬ', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 15),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выйти из аккаунта?'),
        content: const Text('Вы уверены, что хотите выйти?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ОТМЕНА')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('ВЫЙТИ', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await AuthService.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFF4A80F0).withValues(alpha: 0.1)),
        boxShadow: [BoxShadow(color: const Color(0xFF4A80F0).withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          const Icon(Icons.person_add_rounded, size: 48, color: Color(0xFF4A80F0)),
          const SizedBox(height: 16),
          Text(
            'Присоединяйтесь!',
            style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Войдите в профиль, чтобы публиковать объявления, общаться в чатах и сохранять избранное.',
            style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B), height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A80F0),
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text('ВОЙТИ В АККАУНТ', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
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
          label: const Text('ВЫЙТИ ИЗ АККАУНТА', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 18),
            side: const BorderSide(color: Colors.redAccent),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ),
    );
  }

  Widget _circleButton(IconData icon, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 18),
        onPressed: onTap,
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
      _showLocalError('Не удалось открыть магазин приложений');
    }
  }

  void _showAboutDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: _subtxtColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 32),
            const Icon(Icons.copyright_rounded, size: 64, color: Color(0xFF4A80F0)),
            const SizedBox(height: 24),
            Text(
              'Авторское право',
              style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: _txtColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _primaryColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _primaryColor.withValues(alpha: 0.1)),
              ),
              child: Column(
                children: [
                  Text(
                    'Основатель и Главный разработчик:\n${AppConstants.copyrightOwner}',
                    style: GoogleFonts.inter(fontSize: 16, height: 1.4, color: _txtColor, fontWeight: FontWeight.w900),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Программный комплекс ${AppConstants.appName}, включая уникальные алгоритмы, архитектуру и дизайн, является объектом интеллектуальной собственности. Любое незаконное копирование, декомпиляция или использование преследуется по закону.',
                    style: GoogleFonts.inter(fontSize: 13, height: 1.5, color: _subtxtColor, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),
                  Text(
                    '© ${AppConstants.copyrightYear} ${AppConstants.appName}. All Rights Reserved.\nВсе права защищены.\n\nВерсия ${AppConstants.fullVersionString}',
                    style: GoogleFonts.inter(fontSize: 11, color: _subtxtColor.withValues(alpha: 0.6), fontWeight: FontWeight.w700, letterSpacing: 0.5),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Text('ПОНЯТНО', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
