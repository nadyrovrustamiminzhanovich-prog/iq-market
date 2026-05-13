import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:iqmarket/models/ad_model.dart';
import 'package:iqmarket/models/user_model.dart';
import 'package:iqmarket/providers/app_config_provider.dart';
import 'package:iqmarket/services/ad_service.dart';
import 'package:iqmarket/services/user_service.dart';
import 'package:iqmarket/widgets/home/taxi_card_home.dart';
import 'package:iqmarket/widgets/home/categories_home.dart';
import 'package:iqmarket/widgets/home/search_bar_home.dart';
import 'package:iqmarket/widgets/product_card.dart';
import 'package:iqmarket/widgets/home/home_filters.dart';
import 'package:iqmarket/screens/chats_list_screen.dart';
import 'package:iqmarket/screens/favorites_screen.dart';
import 'package:iqmarket/screens/notifications_screen.dart';
import 'package:iqmarket/screens/post_ad_screen.dart';
import 'package:iqmarket/screens/product_details_screen.dart';
import 'package:iqmarket/screens/profile_screen.dart';
import 'package:iqmarket/screens/taxi/taxi_service_screen.dart';
import 'package:iqmarket/screens/admin/admin_panel_screen.dart';
import 'package:iqmarket/theme/app_theme.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class IQMarketHome extends StatefulWidget {
  const IQMarketHome({super.key});

  @override
  State<IQMarketHome> createState() => _IQMarketHomeState();
}

class _IQMarketHomeState extends State<IQMarketHome> {
  int _currentIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Filters State
  String _selectedCategory = 'Все';
  String _searchQuery = '';
  String _sortBy = 'newest';
  double? _minPrice, _maxPrice;
  String _selectedCondition = 'Все';
  String? _selectedCity;

  late stt.SpeechToText _speech;
  bool _isListening = false;

  static const _pageSize = 20;
  
  // В версии 5.1.1 параметры передаются иначе, либо оставляем пустым, если используем refresh()
  final PagingController<DocumentSnapshot?, AdModel> _pagingController = 
      PagingController(firstPageKey: null);

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _pagingController.addPageRequestListener((pageKey) {
      _fetchPage(pageKey);
    });
  }

  Future<void> _fetchPage(DocumentSnapshot? pageKey) async {
    try {
      final result = await AdService.getActiveAdsPaginated(
        startAfter: pageKey,
        limit: _pageSize,
        category: _selectedCategory,
        city: _selectedCity,
        searchQuery: _searchQuery,
      );
      
      final List<AdModel> newItems = List<AdModel>.from(result['ads']);
      final isLastPage = newItems.length < _pageSize;
      
      if (isLastPage) {
        _pagingController.appendLastPage(newItems);
      } else {
        final nextPageKey = result['lastDocument'] as DocumentSnapshot?;
        _pagingController.appendPage(newItems, nextPageKey);
      }
    } catch (error) {
      // В новых версиях ошибку лучше прокидывать через контроллер напрямую
      _pagingController.error = error;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _pagingController.dispose(); // Не забываем удалять контроллер
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _currentIndex != 0) setState(() => _currentIndex = 0);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(child: _currentIndex == 0 ? _buildHomePage() : _buildOtherPage()),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  Widget _buildHomePage() => Consumer<AppConfigProvider>(
    builder: (context, config, _) => RefreshIndicator(
    onRefresh: () async {
      _pagingController.refresh();
      setState(() { 
        _selectedCategory = 'Все'; 
        _searchQuery = ''; 
        _selectedCity = null;
        _searchController.clear(); 
      });
    },
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _buildAppBar(config),
          SliverToBoxAdapter(child: TaxiCardHome(onTap: () => _navToTaxi(config))),
          SliverToBoxAdapter(child: CategoriesHome(
            selectedCategoryId: _selectedCategory, 
            onCategorySelected: (cat) => setState(() {
              _selectedCategory = cat;
              _pagingController.refresh();
            }), 
            onTaxiTap: () => _navToTaxi(config)
          )),
          SliverToBoxAdapter(child: _sectionHeader('Рекомендуем')),
          SliverToBoxAdapter(child: _buildRecs(config)),
          SliverToBoxAdapter(child: _sectionHeader('Новые объявления')),
          _buildAdsGrid(config),
          const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
        ],
      ),
    ),
  );

  Widget _buildAppBar(AppConfigProvider config) => SliverAppBar(
    floating: true, pinned: false, automaticallyImplyLeading: false, backgroundColor: Colors.white,
    title: Row(children: [
      Expanded(child: _citySelector(config)),
      _langToggle(config),
      const SizedBox(width: 8),
      _notifBell(config),
    ]),
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(64),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: SearchBarHome(
          controller: _searchController, 
          onChanged: (v) {
            setState(() => _searchQuery = v);
            _pagingController.refresh();
          }, 
          onMicTap: _listen, 
          onFilterTap: _showFilters
        ),
      ),
    ),
  );

  Widget _buildAdsGrid(AppConfigProvider config) => SliverPadding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    sliver: PagedSliverGrid<DocumentSnapshot?, AdModel>(
      pagingController: _pagingController,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, 
        mainAxisSpacing: 16, 
        crossAxisSpacing: 16, 
        childAspectRatio: 0.75
      ),
      builderDelegate: PagedChildBuilderDelegate<AdModel>(
        itemBuilder: (context, item, index) => ProductCard(
          ad: item, 
          heroPrefix: 'home_', 
          onTap: () => _showDetails(item),
          isFavorite: config.isFavorite(item.id),
          onToggleFavorite: () => config.toggleFavorite(item.id),
        ),
        // В версии 5.1.1 параметры переименованы
        firstPageProgressIndicatorBuilder: (_) => Column(
          children: List.generate(3, (index) => const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Expanded(child: ProductCardSkeleton()),
                SizedBox(width: 16),
                Expanded(child: ProductCardSkeleton()),
              ],
            ),
          )),
        ),
        newPageProgressIndicatorBuilder: (_) => const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: CircularProgressIndicator(),
          ),
        ),
        noItemsFoundIndicatorBuilder: (_) => Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off_rounded, size: 80, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  'Ничего не найдено',
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  'Попробуйте изменить запрос или фильтры',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: Colors.grey[400]),
                ),
              ],
            ),
          ),
        ),
        // Переименованные билдеры ошибок в v5.x
        firstPageErrorIndicatorBuilder: (context) => _errorWidget(),
        newPageErrorIndicatorBuilder: (context) => _errorWidget(),
      ),
    ),
  );

  Widget _errorWidget() => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(height: 8),
          const Text('Ошибка загрузки объявлений'),
          TextButton(
            onPressed: () => _pagingController.refresh(),
            child: const Text('Попробовать снова'),
          ),
        ],
      ),
    ),
  );

  void _showFilters() {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (context) => HomeFilterSheet(
        currentSort: _sortBy, minPrice: _minPrice, maxPrice: _maxPrice, condition: _selectedCondition, city: _selectedCity,
        onApply: (sort, min, max, cond, city) {
          setState(() { 
            _sortBy = sort; _minPrice = min; _maxPrice = max; _selectedCondition = cond; _selectedCity = city; 
          });
          _pagingController.refresh();
          Navigator.pop(context);
        },
      ),
    );
  }

  // --- UI Helpers ---
  Widget _citySelector(AppConfigProvider config) => GestureDetector(
    onTap: () {}, 
    child: Row(children: [
      const Icon(Icons.location_on_rounded, color: Color(0xFF4A80F0), size: 18),
      const SizedBox(width: 4),
      Text(config.city, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800)),
      const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
    ]),
  );

  Widget _langToggle(AppConfigProvider config) => GestureDetector(
    onTap: () {}, 
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), 
      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)), 
      child: Text(config.language.substring(0, 3).toUpperCase(), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, color: const Color(0xFF4A80F0)))
    ),
  );

  Widget _notifBell(AppConfigProvider config) => IconButton(icon: const Icon(Icons.notifications_none_rounded), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NotificationsScreen(lang: config.language))));
  Widget _sectionHeader(String title) => Padding(padding: const EdgeInsets.fromLTRB(16, 24, 16, 16), child: Text(title, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900)));
  
  void _navToTaxi(AppConfigProvider config) => Navigator.push(context, MaterialPageRoute(builder: (_) => TaxiServiceScreen(lang: config.language)));
  void _showDetails(AdModel ad) => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailsScreen(ad: ad, lang: 'Русский', onReport: (_){}, heroPrefix: 'home_')));

  void _listen() async { /* Voice search logic */ }

  Widget _buildRecs(AppConfigProvider config) => StreamBuilder<List<AdModel>>(
    stream: AdService.getRecommendationsStream(),
    builder: (context, snapshot) {
      final ads = snapshot.data ?? [];
      if (ads.isEmpty) return const SizedBox.shrink();
      return SizedBox(height: 240, child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16), scrollDirection: Axis.horizontal, 
        itemCount: ads.length, itemBuilder: (context, i) => Padding(padding: const EdgeInsets.only(right: 12), child: ProductCard(
          ad: ads[i], heroPrefix: 'recs_', width: 180, 
          onTap: () => _showDetails(ads[i]),
          isFavorite: config.isFavorite(ads[i].id),
          onToggleFavorite: () => config.toggleFavorite(ads[i].id),
        ))));
    }
  );

  Widget _buildBottomNav() => StreamBuilder<UserModel?>(
    stream: UserService.getUserStream(),
    builder: (context, snapshot) {
      final isAdmin = snapshot.data?.accountType == 'admin';
      return BottomNavigationBar(
        currentIndex: _currentIndex > 4 && !isAdmin ? 0 : (_currentIndex > 5 ? 0 : _currentIndex),
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF4A80F0),
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Главная'),
          const BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Чаты'),
          const BottomNavigationBarItem(icon: Icon(Icons.add_circle, size: 40, color: Color(0xFF4A80F0)), label: ''),
          const BottomNavigationBarItem(icon: Icon(Icons.favorite_outline), label: 'Избранное'),
          const BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Профиль'),
          if (isAdmin) const BottomNavigationBarItem(icon: Icon(Icons.admin_panel_settings_outlined), label: 'Админ'),
        ],
      );
    }
  );

  Widget _buildOtherPage() {
    final config = Provider.of<AppConfigProvider>(context, listen: false);
    switch (_currentIndex) {
      case 1: return const ChatsListScreen();
      case 2: return PostAdScreen(lang: config.language);
      case 3: return FavoritesScreen(lang: config.language, themes: AppTheme.homeThemes, currentTheme: 'Light', onShowDetails: _showDetails);
      case 4: return ProfileScreen(
        allAds: const [], 
        favoriteAds: const [], 
        onDeleteAd: (_){}, 
        onApproveAd: (_){}, 
        onUpdateAd: (_,__){}, 
        onUpdateProfile: (a,b,c,d,e){}, 
        currentName: 'User', 
        isBioEnabled: false, 
        accType: 'User', 
        lang: config.language, 
        onToggleFavorite: (id) => config.toggleFavorite(id), 
        onShowProductDetails: _showDetails, 
        currentTheme: 'Light', 
        themes: AppTheme.homeThemes, 
        onThemeChanged: (t){}
      );
      case 5: return const AdminPanelScreen();
      default: return const SizedBox.shrink();
    }
  }
}

// Заглушка для скелетона
class ProductCardSkeleton extends StatelessWidget {
  const ProductCardSkeleton({super.key});
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        margin: const EdgeInsets.only(bottom: 16),
        height: 220,
      ),
    );
  }
}