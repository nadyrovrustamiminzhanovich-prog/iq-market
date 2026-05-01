import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:iqmarket/screens/chats_list_screen.dart';
import 'package:iqmarket/screens/login_screen.dart';
import 'package:iqmarket/screens/profile_screen.dart';
import 'package:iqmarket/screens/post_ad_screen.dart';
import 'package:iqmarket/screens/product_details_screen.dart';
import 'package:iqmarket/screens/favorites_screen.dart';
import 'package:iqmarket/screens/splash_screen.dart';
import 'package:iqmarket/services/storage_service.dart';
import 'package:iqmarket/services/location_service.dart';
import 'package:iqmarket/data/kazakhstan_locations.dart';
import 'package:iqmarket/screens/ai_assistant_screen.dart';
import 'package:iqmarket/screens/notifications_screen.dart';
import 'package:iqmarket/screens/taxi/taxi_service_screen.dart';
import 'package:iqmarket/widgets/product_card.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:iqmarket/providers/taxi_provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:iqmarket/services/notification_service.dart';
import 'package:iqmarket/services/analytics_service.dart';
import 'package:iqmarket/services/ad_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'dart:ui';
import 'package:iqmarket/widgets/home/taxi_card_home.dart';
import 'package:iqmarket/widgets/home/categories_home.dart';
import 'package:iqmarket/widgets/home/search_bar_home.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp();
    await GoogleSignIn.instance.initialize();
    await GoogleSignIn.instance.attemptLightweightAuthentication();
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (e) {
    debugPrint('Firebase Init Error: $e');
  }

  await StorageService.init();
  NotificationService.init();
  AnalyticsService.logAppOpen();
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TaxiProvider()),
      ],
      child: MaterialApp(
        title: 'IQ-Market',
        home: const SplashScreen(nextScreen: IQMarketHome()),
        debugShowCheckedModeBanner: false,
        navigatorObservers: [AnalyticsService.observer],
        themeMode: ThemeMode.light,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF4A80F0),
            primary: const Color(0xFF4A80F0),
            surface: Colors.white,
            onSurface: const Color(0xFF1E293B),
            surfaceContainerHighest: const Color(0xFFF1F5F9),
          ),
          scaffoldBackgroundColor: const Color(0xFFF8FAFC),
          textTheme: GoogleFonts.interTextTheme(),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            iconTheme: IconThemeData(color: Color(0xFF1E293B)),
          ),
        ),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('ru', 'RU'),
          Locale('kk', 'KZ'),
          Locale('en', 'US'),
        ],
        locale: const Locale('ru', 'RU'),
      ),
    ),
  );
}

class IQMarketHome extends StatefulWidget {
  const IQMarketHome({super.key});
  @override
  State<IQMarketHome> createState() => _IQMarketHomeState();
}

class _IQMarketHomeState extends State<IQMarketHome> with TickerProviderStateMixin {
  int _currentIndex = 0;
  bool _isSearching = false;
  final Set<String> _favoriteIds = {};
  int _bannerIndex = 0;
  late PageController _bannerController;
  String _language = 'Русский';
  String? _currentLocation;
  String _userName = 'Александр Иванов';
  File? _userImage;
  bool _isBioEnabled = false;
  String _accountType = 'Личный';
  String _selectedCategory = 'Все';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isVerified = false;
  bool _isLoading = false;
  String _selectedTheme = 'Light';

  late stt.SpeechToText _speech;
  bool _isListening = false;

  final Map<String, Map<String, dynamic>> _themes = {
    'Light': {
      'primary': const Color(0xFF4A80F0),
      'background': Colors.white,
      'surface': Colors.white,
      'text': const Color(0xFF1A1D1E),
      'subtext': const Color(0xFF475569),
      'grad': [const Color(0xFF4A80F0), const Color(0xFF1E40AF)]
    },
    'Dark': {
      'primary': const Color(0xFF38BDF8),
      'background': const Color(0xFF0F172A),
      'surface': const Color(0xFF1E293B),
      'text': const Color(0xFFF8FAFC),
      'subtext': const Color(0xFFCBD5E1),
      'grad': [const Color(0xFF0F172A), const Color(0xFF1E293B)]
    },
  };

  Color get _backgroundColor {
    final t = _themes[_selectedTheme] ?? _themes['Light'];
    return (t?['background'] ?? Colors.white) as Color;
  }
  Color get _surfaceColor {
    final t = _themes[_selectedTheme] ?? _themes['Light'];
    return (t?['surface'] ?? Colors.white) as Color;
  }
  Color get _textColor {
    final t = _themes[_selectedTheme] ?? _themes['Light'];
    return (t?['text'] ?? const Color(0xFF1E293B)) as Color;
  }
  Color get _subtextColor {
    final t = _themes[_selectedTheme] ?? _themes['Light'];
    return (t?['subtext'] ?? const Color(0xFF64748B)) as Color;
  }
  Color get _primaryColor {
    final t = _themes[_selectedTheme] ?? _themes['Light'];
    return (t?['primary'] ?? const Color(0xFF4A80F0)) as Color;
  }
  List<Color> get _primaryGrad {
    final t = _themes[_selectedTheme] ?? _themes['Light'];
    return (t?['grad'] ?? [const Color(0xFF4A80F0), const Color(0xFF1E40AF)]) as List<Color>;
  }

  final List<Map<String, dynamic>> _globalAds = [
    {
      'id': '1',
      'title': 'iPhone 15 Pro Max Natural Titanium',
      'price': '550 000 ₸',
      'category': 'Электроника',
      'location': 'Алматы',
      'image': 'https://images.unsplash.com/photo-1696446701796-da61225697cc?auto=format&fit=crop&q=80&w=800',
      'rating': 5.0,
      'reviews': 12,
      'isVerified': true,
      'condition': 'Новое',
      'timestamp': DateTime.now().subtract(const Duration(hours: 2)),
      'seller': 'Apple Store Almaty',
      'description': 'Новый iPhone 15 Pro Max в цвете Титан. Полный комплект, гарантия 1 год.',
      'active': true
    },
    {
      'id': '2',
      'title': 'Корова с теленком (второй отел)',
      'price': '450 000 ₸',
      'category': 'Малбазар',
      'location': 'Чунджа',
      'image': 'https://images.unsplash.com/photo-1546445317-29f4545e9d53?auto=format&fit=crop&q=80&w=800',
      'rating': 4.8,
      'reviews': 5,
      'isVerified': false,
      'condition': 'Живой вес',
      'timestamp': DateTime.now().subtract(const Duration(days: 1)),
      'seller': 'Ахмет',
      'description': 'Сауын сиыр, сүті көп. Телөмірімен бірге сатылады.',
      'active': true
    },
    {
      'id': '3',
      'title': 'Toyota Camry 70 (Lux Safety)',
      'price': '15 500 000 ₸',
      'category': 'Авто',
      'location': 'Астана',
      'image': 'https://images.unsplash.com/photo-1621007947382-bb3c3994e3fb?auto=format&fit=crop&q=80&w=800',
      'rating': 4.9,
      'reviews': 28,
      'isVerified': true,
      'condition': 'С пробегом',
      'timestamp': DateTime.now().subtract(const Duration(hours: 5)),
      'seller': 'AutoKz',
      'description': 'Идеальное состояние, один хозяин. Полная комплектация.',
      'active': true
    },
    {
      'id': '4',
      'title': '2-комнатная квартира, 65м²',
      'price': '28 000 000 ₸',
      'category': 'Недвижимость',
      'location': 'Алматы',
      'image': 'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?auto=format&fit=crop&q=80&w=800',
      'rating': 4.7,
      'reviews': 8,
      'isVerified': true,
      'condition': 'Вторичка',
      'timestamp': DateTime.now().subtract(const Duration(days: 2)),
      'seller': 'Хозяин',
      'description': 'Золотой квадрат, средний этаж, ремонт.',
      'active': true
    },
    {
      'id': '5',
      'title': 'PlayStation 5 + 2 DualSense',
      'price': '220 000 ₸',
      'category': 'Электроника',
      'location': 'Каскелен',
      'image': 'https://images.unsplash.com/photo-1606144042614-b2417e99c4e3?auto=format&fit=crop&q=80&w=800',
      'rating': 5.0,
      'reviews': 15,
      'isVerified': false,
      'condition': 'Б/У',
      'timestamp': DateTime.now().subtract(const Duration(hours: 1)),
      'seller': 'Игорь',
      'description': 'Состояние идеальное, не шумит, не греется.',
      'active': true
    },
    {
      'id': '6',
      'title': 'Горный велосипед Giant Talon',
      'price': '185 000 ₸',
      'category': 'Спорт',
      'location': 'Талдыкорган',
      'image': 'https://images.unsplash.com/photo-1532298229144-0ee0c9e9ad58?auto=format&fit=crop&q=80&w=800',
      'rating': 4.6,
      'reviews': 4,
      'isVerified': false,
      'condition': 'Новое',
      'timestamp': DateTime.now().subtract(const Duration(days: 3)),
      'seller': 'VeloShop',
      'description': 'Профессиональный горный велосипед.',
      'active': true
    },
    {
      'id': '7',
      'title': 'Баран Эдельбай (Тирилей)',
      'price': '75 000 ₸',
      'category': 'Малбазар',
      'location': 'Шелек',
      'image': 'https://images.unsplash.com/photo-1484557985045-edf25e08da73?auto=format&fit=crop&q=80&w=800',
      'rating': 4.9,
      'reviews': 21,
      'isVerified': true,
      'condition': 'Живой вес',
      'timestamp': DateTime.now().subtract(const Duration(hours: 12)),
      'seller': 'Ербол',
      'description': 'Семиз козылар бар, сойып беремиз.',
      'active': true
    }
  ];

  @override
  void initState() {
    super.initState();
    _initApp();
    _bannerController = PageController();
    _speech = stt.SpeechToText();
    Future.delayed(const Duration(seconds: 4), _autoscrollBanner);
  }

  void _autoscrollBanner() {
    if (!mounted) return;
    if (!_bannerController.hasClients) {
      Future.delayed(const Duration(seconds: 4), _autoscrollBanner);
      return;
    }
    final next = (_bannerIndex + 1) % 4;
    _bannerController.animateToPage(next, duration: const Duration(milliseconds: 800), curve: Curves.fastOutSlowIn);
    setState(() => _bannerIndex = next);
    Future.delayed(const Duration(seconds: 4), _autoscrollBanner);
  }

  @override
  void dispose() {
    _bannerController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initApp() async {
    await _loadProfile();
    final savedLoc = StorageService.getString('user_location');
    if (savedLoc != null) setState(() => _currentLocation = savedLoc);
  }

  Future<void> _loadProfile() async {
    setState(() {
      _userName = StorageService.getString('user_name') ?? 'Александр Иванов';
      final imgPath = StorageService.getString('user_image');
      if (imgPath != null) _userImage = File(imgPath);
      _isBioEnabled = StorageService.getBool('is_bio_enabled');
      _accountType = StorageService.getString('account_type') ?? 'Личный';
      _isVerified = StorageService.isVerified;
      _language = StorageService.getString('language') ?? 'Русский';
    });
  }

  String _t(String key) {
    return TranslationService.t(key, _language);
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(onResult: (val) {
          setState(() {
            _searchController.text = val.recognizedWords;
            _searchQuery = val.recognizedWords;
            if (val.recognizedWords.isNotEmpty) _isSearching = true;
          });
        });
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  Future<void> _handleRefresh() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 1500));
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: _currentIndex == 0 ? _buildHomePage() : _buildOtherPage(),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHomePage() {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      displacement: 20,
      color: const Color(0xFF4A80F0),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: TaxiCardHome(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => TaxiServiceScreen(lang: _language))),
            ),
          ),
          SliverToBoxAdapter(
            child: CategoriesHome(
              onCategorySelected: (cat) => setState(() => _selectedCategory = cat),
              onTaxiTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => TaxiServiceScreen(lang: _language))),
            ),
          ),
          SliverToBoxAdapter(child: _buildSectionHeader('Рекомендуем', () {})),
          SliverToBoxAdapter(child: _buildRecs()),
          SliverToBoxAdapter(child: _buildSectionHeader('Новые объявления', () {})),
          _buildVerticalList(),
          const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
        ],
      ),
    );
  }

  Widget _buildAppBar() => SliverAppBar(
    floating: true,
    pinned: false,
    toolbarHeight: 60,
    backgroundColor: const Color(0xFFF8FAFC),
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    title: Row(
      children: [
        GestureDetector(
          onTap: () {},
          child: Row(
            children: [
              Text(
                _currentLocation ?? 'Чунджа',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF1E293B), size: 24),
            ],
          ),
        ),
        const Spacer(),
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFF1E293B), size: 28),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => NotificationsScreen(lang: _language))),
            ),
            Positioned(
              right: 12,
              top: 12,
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFF8FAFC), width: 1.5),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(64),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: SearchBarHome(
          controller: _searchController,
          onChanged: (val) => setState(() => _searchQuery = val),
        ),
      ),
    ),
  );


  Widget _buildSectionHeader(String title, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B)),
        ),
        GestureDetector(
          onTap: onTap,
          child: Text(
            'Смотреть все',
            style: GoogleFonts.inter(color: const Color(0xFF4A80F0), fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
      ],
    ),
  );

  Widget _buildRecs() {
    if (_isLoading) return _shimmerList();
    final recs = _globalAds.take(4).toList();
    return SizedBox(
      height: 250,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        physics: const BouncingScrollPhysics(),
        itemCount: recs.length,
        itemBuilder: (context, i) {
          final ad = recs[i];
          if (ad == null) return const SizedBox();
          return Container(
            width: 180,
            margin: const EdgeInsets.only(right: 12),
            child: ProductCard(
              ad: ad,
              lang: _language,
              isFavorite: _favoriteIds.contains(ad['id']),
              onToggleFavorite: () => _toggleFavorite(ad['id']),
              onTap: () => _showProductDetails(ad),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVerticalList() {
    if (_isLoading) return _shimmerGrid();
    final filtered = _globalAds.where((ad) {
      final String cat = (ad['category'] ?? '').toString();
      final String title = (ad['title'] ?? '').toString();
      
      if (_selectedCategory != 'Все' && cat != _selectedCategory) return false;
      if (_searchQuery.isNotEmpty && !title.toLowerCase().contains(_searchQuery.toLowerCase())) return false;
      return true;
    }).toList();
    
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.72,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            final ad = filtered[i];
            if (ad == null) return const SizedBox();
            return ProductCard(
              ad: ad,
              lang: _language,
              isFavorite: _favoriteIds.contains(ad['id']),
              onToggleFavorite: () => _toggleFavorite(ad['id']),
              onTap: () => _showProductDetails(ad),
            );
          },
          childCount: filtered.length,
        ),
      ),
    );
  }

  Widget _shimmerList() => SizedBox(
    height: 250,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 4,
      itemBuilder: (context, i) => Container(
        width: 180,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Shimmer.fromColors(
          baseColor: const Color(0xFFF1F5F9),
          highlightColor: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(height: 130, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12))),
              const SizedBox(height: 12),
              Container(height: 15, width: 120, color: Colors.white),
              const SizedBox(height: 8),
              Container(height: 20, width: 80, color: Colors.white),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _shimmerGrid() => SliverGrid(
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.72),
    delegate: SliverChildBuilderDelegate(
      (context, i) => Shimmer.fromColors(
        baseColor: const Color(0xFFF1F5F9),
        highlightColor: Colors.white,
        child: Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        ),
      ),
      childCount: 6,
    ),
  );

  void _toggleFavorite(String id) {
    setState(() { if (_favoriteIds.contains(id)) _favoriteIds.remove(id); else _favoriteIds.add(id); });
  }

  void _showProductDetails(Map<String, dynamic> ad) {
    Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (context) => ProductDetailsScreen(
          ad: ad, 
          lang: _language,
          onReport: (id) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Жалоба отправлена модераторам')),
            );
          },
        )
      )
    );
  }

  Widget _buildBottomNav() {
    return Container(
      height: 85,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: const Color(0xFFF1F5F9), width: 1)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, -5)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _bottomNavItem(Icons.home_rounded, 'Главная', 0),
          _bottomNavItem(Icons.chat_bubble_outline_rounded, 'Чаты', 1),
          _buildCreateButton(),
          _bottomNavItem(Icons.favorite_outline_rounded, 'Избранное', 3),
          _bottomNavItem(Icons.person_outline_rounded, 'Профиль', 4),
        ],
      ),
    );
  }

  Widget _bottomNavItem(IconData icon, String label, int index) {
    final bool isActive = _currentIndex == index;
    final color = isActive ? const Color(0xFF4A80F0) : const Color(0xFF94A3B8);
    
    return GestureDetector(
      onTap: () {
        if (index == 4) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileScreen(
            allAds: _globalAds, 
            favoriteAds: _globalAds.where((ad) => _favoriteIds.contains(ad['id'])).toList(), 
            onDeleteAd: (i) => setState(() => _globalAds.removeAt(i)),
            onApproveAd: (i) {},
            onUpdateAd: (i, ad) => setState(() => _globalAds[i] = ad),
            currentName: _userName, 
            currentImage: _userImage, 
            isBioEnabled: _isBioEnabled, 
            accType: _accountType, 
            lang: _language, 
            isVerified: _isVerified,
            onUpdateProfile: (n, img, b, t, l) => setState(() { _userName = n; if (img != null) _userImage = img; _isBioEnabled = b; _accountType = t; _language = l; }),
            onLogout: () {}, 
            onToggleFavorite: _toggleFavorite,
            onShowProductDetails: _showProductDetails,
            isGuest: false, 
            currentTheme: _selectedTheme, 
            themes: _themes, 
            onThemeChanged: (t) => setState(() => _selectedTheme = t),
          )));
        } else if (index == 3) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => FavoritesScreen(
            favoriteAds: _globalAds.where((ad) => _favoriteIds.contains(ad['id'])).toList(), 
            lang: _language, 
            onUnfavorite: (ad) => _toggleFavorite(ad['id']), 
            onShowDetails: _showProductDetails, 
            themes: _themes, 
            currentTheme: _selectedTheme
          )));
        } else if (index == 1) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const ChatsListScreen()));
        } else {
          setState(() => _currentIndex = index);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateButton() {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => PostAdScreen(lang: _language))).then((ad) { 
          if (ad != null && ad is Map<String, dynamic>) setState(() => _globalAds.insert(0, ad)); 
        });
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFF4A80F0),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Color(0x4D4A80F0), blurRadius: 12, offset: Offset(0, 4)),
              ],
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 4),
          Text(
            'Создать',
            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w500, color: const Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget _buildOtherPage() => Container();
}
