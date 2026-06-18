import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:iqmarket/models/ad_model.dart';
import 'package:iqmarket/models/user_model.dart';
import 'package:iqmarket/providers/app_config_provider.dart';
import 'package:iqmarket/services/ad_service.dart';
import 'package:iqmarket/services/notification_service.dart';
import 'package:iqmarket/services/chat_service.dart';
import 'package:iqmarket/services/user_service.dart';
import 'package:iqmarket/data/kazakhstan_locations.dart';
import 'package:iqmarket/services/location_service.dart';
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
import 'package:iqmarket/services/translation_service.dart';

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

  late stt.SpeechToText _speech;
  bool _isListening = false;
  Timer? _searchDebounce;

  // ✅ Кэш пользователя: вместо постоянного Firestore-watcher-а в BottomNav
  // загружаем данные один раз при открытии экрана
  UserModel? _cachedUser;
  bool _isAdmin = false;

  static const _pageSize = 20;
  Set<String>? _lastBlockedUserIds;

  bool _areSetsEqual(Set<String> a, Set<String> b) {
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }
  
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
    // Загрузить пользователя один раз вместо висящего Firestore listener-а
    _loadCachedUser();
  }

  Future<void> _loadCachedUser() async {
    final uid = UserService.currentUid;
    if (uid == null) return;
    final user = await UserService.getUserById(uid);
    if (mounted) {
      setState(() {
        _cachedUser = user;
        _isAdmin = user?.accountType == 'admin';
      });
    }
  }

  Future<void> _fetchPage(DocumentSnapshot? pageKey) async {
    try {
      final config = Provider.of<AppConfigProvider>(context, listen: false);
      final String? cityFilter = config.city == 'Все' ? null : config.city;

      final result = await AdService.getActiveAdsPaginated(
        startAfter: pageKey,
        limit: _pageSize,
        category: _selectedCategory,
        city: cityFilter,
        searchQuery: _searchQuery,
        minPrice: _minPrice,
        maxPrice: _maxPrice,
        condition: _selectedCondition,
        sortBy: _sortBy,
      );
      
      final List<AdModel> newItems = List<AdModel>.from(result['ads']).where((ad) {
        return !config.blockedUserIds.contains(ad.userId);
      }).toList();
      final isLastPage = newItems.length < _pageSize;
      
      if (isLastPage) {
        _pagingController.appendLastPage(newItems);
      } else {
        final nextPageKey = result['lastDocument'] as DocumentSnapshot?;
        _pagingController.appendPage(newItems, nextPageKey);
      }
    } catch (error, stack) {
      debugPrint('Error fetching home page ads: $error');
      debugPrint(stack.toString());
      // В новых версиях ошибку лучше прокидывать через контроллер напрямую
      _pagingController.error = error;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _pagingController.dispose();
    _searchDebounce?.cancel();
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
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(child: _currentIndex == 0 ? _buildHomePage() : _buildOtherPage()),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  Widget _buildHomePage() {
    final config = Provider.of<AppConfigProvider>(context);

    // Refresh paging controller if blocked user list changed
    final currentBlocked = config.blockedUserIds;
    if (_lastBlockedUserIds != null && !_areSetsEqual(_lastBlockedUserIds!, currentBlocked)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pagingController.refresh();
      });
    }
    _lastBlockedUserIds = Set.from(currentBlocked);

    return RefreshIndicator(
      onRefresh: () async {
        _pagingController.refresh();
        setState(() {
          _selectedCategory = 'Все';
          _searchQuery = '';
          _searchController.clear();
        });
        config.setCity('Все');
      },
      child: CustomScrollView(
        controller: _scrollController,
        // Повышает плавность прокрутки на мобильных устройствах
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          _buildAppBar(config),
          SliverToBoxAdapter(child: TaxiCardHome(onTap: () => _navToTaxi(config))),
          SliverToBoxAdapter(child: CategoriesHome(
            selectedCategoryId: _selectedCategory,
            onCategorySelected: (cat) => setState(() {
              _selectedCategory = cat;
              _pagingController.refresh();
            }),
            onTaxiTap: () => _navToTaxi(config),
          )),
          SliverToBoxAdapter(child: _sectionHeader(TranslationService.t('new_ads', config.language))),
          _buildAdsGrid(config),
          const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
        ],
      ),
    );
  }

  Widget _buildAppBar(AppConfigProvider config) => SliverAppBar(
    floating: true, pinned: false, automaticallyImplyLeading: false, backgroundColor: Theme.of(context).colorScheme.surface,
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
            _searchDebounce?.cancel();
            _searchDebounce = Timer(const Duration(milliseconds: 1000), () {
              if (mounted) {
                setState(() => _searchQuery = v);
                _pagingController.refresh();
              }
            });
          }, 
          onMicTap: _listen, 
          onFilterTap: _showFilters
        ),
      ),
    ),
  );

  Widget _buildAdsGrid(AppConfigProvider config) {
    final screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount = 2;
    if (screenWidth >= 1200) {
      crossAxisCount = 6;
    } else if (screenWidth >= 900) {
      crossAxisCount = 4;
    } else if (screenWidth >= 600) {
      crossAxisCount = 3;
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      sliver: PagedSliverGrid<DocumentSnapshot?, AdModel>(
        pagingController: _pagingController,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.68,
        ),
        builderDelegate: PagedChildBuilderDelegate<AdModel>(
          itemBuilder: (context, item, index) => ProductCard(
            ad: item,
            heroPrefix: 'home_',
            onTap: () => _showDetails(item),
            isFavorite: config.isFavorite(item.id),
            onToggleFavorite: () => config.toggleFavorite(item.id),
          ),
          firstPageProgressIndicatorBuilder: (_) => Column(
            children: List.generate(3, (index) => const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(child: ProductCardSkeleton()),
                  SizedBox(width: 10),
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
                    TranslationService.t('nothing_found', config.language),
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    TranslationService.t('try_changing_filters', config.language),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(color: Colors.grey[400]),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _selectedCategory = 'Все';
                        _searchQuery = '';
                        _searchController.clear();
                      });
                      Provider.of<AppConfigProvider>(context, listen: false).setCity('Все');
                      _pagingController.refresh();
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(TranslationService.t('reset_and_refresh', config.language), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A80F0),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ),
          ),
          firstPageErrorIndicatorBuilder: (context) => _errorWidget(config),
          newPageErrorIndicatorBuilder: (context) => _errorWidget(config),
        ),
      ),
    );
  }

  Widget _errorWidget(AppConfigProvider config) => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(height: 8),
          Text(TranslationService.t('error_loading_ads', config.language)),
          TextButton(
            onPressed: () => _pagingController.refresh(),
            child: Text(TranslationService.t('try_again', config.language)),
          ),
        ],
      ),
    ),
  );

  void _showFilters() {
    final config = Provider.of<AppConfigProvider>(context, listen: false);
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (context) => HomeFilterSheet(
        currentSort: _sortBy, minPrice: _minPrice, maxPrice: _maxPrice, condition: _selectedCondition, city: config.city == 'Все' ? null : config.city,
        onApply: (sort, min, max, cond, city) {
          setState(() { 
            _sortBy = sort; _minPrice = min; _maxPrice = max; _selectedCondition = cond; 
          });
          config.setCity(city ?? 'Все');
          _pagingController.refresh();
          Navigator.pop(context);
        },
      ),
    );
  }

  // --- UI Helpers ---
  Widget _citySelector(AppConfigProvider config) => GestureDetector(
    onTap: () => _showLocationDialog(config), 
    child: Row(children: [
      const Icon(Icons.location_on_rounded, color: Color(0xFF4A80F0), size: 18),
      const SizedBox(width: 4),
      Text(config.city == 'Все' ? TranslationService.t('all_cities', config.language) : config.city, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800)),
      const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
    ]),
  );

  void _showLocationDialog(AppConfigProvider config) {
    String searchCity = "";
    String? selectedParent;

    showModalBottomSheet(
      context: context, 
      isScrollControlled: true, 
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          List<String> listToDisplay;

          if (searchCity.isNotEmpty) {
            listToDisplay = KazakhstanLocations.getAllLocations()
                .where((l) => l.toLowerCase().contains(searchCity.toLowerCase()))
                .toList();
          } else if (selectedParent != null) {
            listToDisplay = KazakhstanLocations.hierarchy[selectedParent] ?? [];
          } else {
            listToDisplay = ['Все', 'Чунджа'] + KazakhstanLocations.hierarchy.keys.toList();
          }

          final isDark = Theme.of(context).brightness == Brightness.dark;
          final surfaceColor = Theme.of(context).colorScheme.surface;
          final txtColor = Theme.of(context).colorScheme.onSurface;
          final subtxtColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
          final primaryColor = Theme.of(context).colorScheme.primary;

          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: BoxDecoration(
              color: surfaceColor, 
              borderRadius: const BorderRadius.vertical(top: Radius.circular(35))
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: subtxtColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10))),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      if (selectedParent != null && searchCity.isEmpty)
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: txtColor),
                          onPressed: () => setModalState(() => selectedParent = null),
                        ),
                      if (selectedParent != null && searchCity.isEmpty) const SizedBox(width: 15),
                      Text(
                        searchCity.isNotEmpty ? 'Результаты поиска' : (selectedParent ?? 'Выберите локацию'), 
                        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: txtColor)
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: TextField(
                    onChanged: (v) => setModalState(() => searchCity = v),
                    style: GoogleFonts.inter(color: txtColor, fontWeight: FontWeight.w800),
                    decoration: InputDecoration(
                      hintText: 'Введите название города...',
                      hintStyle: GoogleFonts.inter(color: subtxtColor.withValues(alpha: 0.6), fontWeight: FontWeight.w600),
                      prefixIcon: Icon(Icons.search_rounded, color: primaryColor),
                      filled: true,
                      fillColor: subtxtColor.withValues(alpha: 0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                if (selectedParent == null && searchCity.isEmpty) ...[
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                    leading: Icon(Icons.my_location_rounded, color: primaryColor), 
                    title: Text('Определить автоматически', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: primaryColor, fontSize: 15)), 
                    onTap: () async {
                      final city = await LocationService.getCurrentCity();
                      if (city != null) {
                        config.setCity(city);
                        _pagingController.refresh();
                        Navigator.pop(context);
                      }
                    }
                  ),
                  const Divider(indent: 24, endIndent: 24, color: Colors.transparent),
                ],
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: listToDisplay.length,
                    separatorBuilder: (c, i) => Divider(color: subtxtColor.withValues(alpha: 0.05), height: 1),
                    itemBuilder: (context, index) {
                      final item = listToDisplay[index];
                      final isParent = KazakhstanLocations.hierarchy.containsKey(item) && searchCity.isEmpty;

                      return ListTile(
                        leading: Icon(isParent ? Icons.location_city_rounded : Icons.location_on_rounded, color: subtxtColor.withValues(alpha: 0.6)),
                        title: Text(item == 'Все' ? 'Все города' : item, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, color: txtColor)),
                        trailing: Icon(isParent ? Icons.arrow_forward_ios_rounded : Icons.check_circle_outline_rounded, size: 14, color: isParent ? subtxtColor.withValues(alpha: 0.4) : const Color(0xFF10B981)),
                        onTap: () { 
                          if (isParent) {
                            setModalState(() => selectedParent = item);
                          } else {
                            config.setCity(item);
                            _pagingController.refresh();
                            Navigator.pop(context); 
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _langToggle(AppConfigProvider config) => GestureDetector(
    onTap: () {
      showModalBottomSheet(
        context: context,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
        builder: (ctx) {
          final sheetTheme = Theme.of(ctx);
          return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 24),
              Text('Выберите язык', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: sheetTheme.colorScheme.onSurface)),
              const SizedBox(height: 20),
              ...['Русский', 'Қазақша', 'Уйғурчә'].map((l) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    config.setLanguage(l);
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: config.language == l ? sheetTheme.colorScheme.primary.withValues(alpha: 0.04) : sheetTheme.colorScheme.surface,
                      border: Border.all(
                        color: config.language == l ? sheetTheme.colorScheme.primary.withValues(alpha: 0.3) : sheetTheme.colorScheme.outline,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(
                      children: [
                        Text(
                          l, 
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: config.language == l ? FontWeight.w800 : FontWeight.w600, 
                            color: config.language == l ? sheetTheme.colorScheme.primary : sheetTheme.colorScheme.onSurface
                          )
                        ),
                        const Spacer(),
                        if (config.language == l)
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0xFF4A80F0),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
                          )
                        else
                          Container(
                            width: 22, height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              )),
              const SizedBox(height: 16),
            ],
          ),
        );},
      );
    }, 
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), 
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)), 
      child: Text(config.language.substring(0, 3).toUpperCase(), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, color: const Color(0xFF4A80F0)))
    ),
  );

  Widget _notifBell(AppConfigProvider config) {
    return StreamBuilder<int>(
      stream: NotificationService.getUnreadNotificationsCountStream(),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return IconButton(
          icon: Badge(
            label: Text('$count'),
            isLabelVisible: count > 0,
            backgroundColor: Colors.red,
            textColor: Colors.white,
            child: const Icon(Icons.notifications_none_rounded),
          ),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => NotificationsScreen(lang: config.language)),
          ),
        );
      },
    );
  }
  Widget _sectionHeader(String title) => Padding(padding: const EdgeInsets.fromLTRB(16, 24, 16, 16), child: Text(title, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900)));
  
  void _navToTaxi(AppConfigProvider config) => Navigator.push(context, MaterialPageRoute(builder: (_) => TaxiServiceScreen(lang: config.language)));
  void _showDetails(AdModel ad) {
    final lang = Provider.of<AppConfigProvider>(context, listen: false).language;
    Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailsScreen(ad: ad, lang: lang, onReport: (_){}, heroPrefix: 'home_')));
  }

  void _listen() async {
    final lang = Provider.of<AppConfigProvider>(context, listen: false).language;
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) {
          if (val == 'done' || val == 'notListening') if (mounted) setState(() => _isListening = false);
        },
        onError: (val) { if (mounted) setState(() => _isListening = false); },
      );
      if (available) {
        setState(() => _isListening = true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(TranslationService.t('listening', lang)), duration: const Duration(seconds: 2)));
        _speech.listen(
          onResult: (val) {
            setState(() {
              _searchController.text = val.recognizedWords;
              _searchQuery = val.recognizedWords;
            });
            if (val.finalResult) {
               _searchDebounce?.cancel();
               _pagingController.refresh();
             }
          },
          localeId: lang == 'Қазақша' ? 'kk_KZ' : 'ru_RU',
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(TranslationService.t('mic_unavailable', lang))));
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

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

  Widget _buildBottomNav() {
    // ✅ Используем кэш вместо StreamBuilder — нет постоянного Firestore listener-а в BottomNav
    final isAdmin = _isAdmin;
    final navTheme = Theme.of(context);
    final config = Provider.of<AppConfigProvider>(context);
    final lang = config.language;
    return Container(
      decoration: BoxDecoration(
        color: navTheme.colorScheme.surface,
        border: Border(top: BorderSide(color: Colors.grey.withValues(alpha: 0.1), width: 1)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex > 4 && !isAdmin ? 0 : (_currentIndex > 5 ? 0 : _currentIndex),
        onTap: (i) {
          if (i == 2) {
            final config = Provider.of<AppConfigProvider>(context, listen: false);
            Navigator.push(context, MaterialPageRoute(builder: (_) => PostAdScreen(lang: config.language)));
          } else if (i == 4) {
            final config = Provider.of<AppConfigProvider>(context, listen: false);
            Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(
              allAds: const [], 
              favoriteAds: const [], 
              onDeleteAd: (_){}, 
              onApproveAd: (_){}, 
              onUpdateAd: (_,__){}, 
              onUpdateProfile: (a,b,c,d,e){}, 
              currentName: _cachedUser?.name ?? 'Гость', 
              isBioEnabled: false, 
              accType: _cachedUser?.accountType ?? 'user', 
              lang: config.language, 
              onToggleFavorite: (id) => config.toggleFavorite(id), 
              onShowProductDetails: _showDetails, 
              currentTheme: 'Light', 
              themes: AppTheme.homeThemes, 
              onThemeChanged: (t){},
              isGuest: _cachedUser == null,
            )));
          } else {
            setState(() => _currentIndex = i);
          }
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: navTheme.colorScheme.primary,
        unselectedItemColor: navTheme.colorScheme.onSurface.withValues(alpha: 0.4),
        elevation: 0,
        backgroundColor: navTheme.colorScheme.surface,
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.home_rounded), label: TranslationService.t('home', lang)),
          BottomNavigationBarItem(
            icon: StreamBuilder<int>(
              stream: ChatService.getUnreadMessagesCountStream(),
              builder: (context, snapshot) {
                final count = snapshot.data ?? 0;
                return Badge(
                  label: Text('$count'),
                  isLabelVisible: count > 0,
                  backgroundColor: Colors.red,
                  textColor: Colors.white,
                  child: const Icon(Icons.chat_bubble_outline),
                );
              },
            ),
            label: TranslationService.t('chats', lang),
          ),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle, size: 40, color: navTheme.colorScheme.primary), label: ''),
          BottomNavigationBarItem(icon: const Icon(Icons.favorite_outline), label: TranslationService.t('favorites', lang)),
          BottomNavigationBarItem(icon: const Icon(Icons.person_outline), label: TranslationService.t('profile', lang)),
          if (isAdmin) BottomNavigationBarItem(icon: const Icon(Icons.admin_panel_settings_outlined), label: TranslationService.t('acc_admin', lang)),
        ],
      ),
    );
  }

  Widget _buildOtherPage() {
    final config = Provider.of<AppConfigProvider>(context);
    switch (_currentIndex) {
      case 1: return const ChatsListScreen(); // вкладка "Чаты"
      case 2: return const SizedBox.shrink(); // Moved to Navigator.push
      case 3: return FavoritesScreen(lang: config.language, themes: AppTheme.homeThemes, currentTheme: 'Light', onShowDetails: _showDetails);
      case 4: return const SizedBox.shrink(); // Moved to Navigator.push
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
    final skelTheme = Theme.of(context);
    return Shimmer.fromColors(
      baseColor: skelTheme.colorScheme.onSurface.withValues(alpha: 0.15),
      highlightColor: skelTheme.colorScheme.onSurface.withValues(alpha: 0.05),
      child: Container(
        decoration: BoxDecoration(
          color: skelTheme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        margin: const EdgeInsets.only(bottom: 16),
        height: 220,
      ),
    );
  }
}