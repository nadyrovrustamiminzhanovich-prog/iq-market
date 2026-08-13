import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:iqmarket/models/ad_model.dart';
import 'package:iqmarket/providers/app_config_provider.dart';
import 'package:iqmarket/services/ad_service.dart';
import 'package:iqmarket/widgets/product_card.dart';

class FavoritesScreen extends StatefulWidget {
  final String lang;
  final Map<String, Map<String, dynamic>> themes;
  final String currentTheme;
  final Function(AdModel) onShowDetails;

  const FavoritesScreen({
    super.key, 
    required this.lang,
    required this.themes,
    required this.currentTheme,
    required this.onShowDetails,
  });

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  Color get _bgColor => widget.themes[widget.currentTheme]?['background'] ?? Theme.of(context).scaffoldBackgroundColor;
  Color get _surfaceColor => widget.themes[widget.currentTheme]?['surface'] ?? Theme.of(context).colorScheme.surface;
  Color get _txtColor => widget.themes[widget.currentTheme]?['text'] ?? Theme.of(context).colorScheme.onSurface;
  Color get _subtxtColor => widget.themes[widget.currentTheme]?['subtext'] ?? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);

  String _t(String key) {
    final translations = {
      'title': { 'Русский': 'Избранное', 'Қазақша': 'Таңдаулы', 'Уйғурчә': 'Талланған' },
      'empty_title': { 'Русский': 'Пока ничего нет', 'Қазақша': 'Әлі ештеңе жоқ', 'Уйғурчә': 'Һеч нәрсә йоқ' },
      'empty_subtitle': { 
        'Русский': 'Добавляйте товары в избранное, чтобы не потерять их', 
        'Қазақша': 'Тауарларды жоғалтып алмау үшін таңдаулыларға қосыңыз', 
        'Уйғурчә': 'Дөләтләрни йоқитип қоймаслиқ үчүн талланғанларға қошуш' 
      },
    };
    return translations[key]?[widget.lang] ?? translations[key]?['Русский'] ?? key;
  }

  @override
  Widget build(BuildContext context) {
    final favoriteIds = context.watch<AppConfigProvider>().favoriteIds.toList();

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _surfaceColor,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: Icon(Icons.arrow_back_ios_new, color: _txtColor, size: 20),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Text(_t('title'), style: GoogleFonts.inter(color: _txtColor, fontWeight: FontWeight.w900, fontSize: 18)),
      ),
      body: favoriteIds.isEmpty 
        ? _buildEmptyState()
        : FutureBuilder<List<AdModel>>(
            future: AdService.getAdsByIds(favoriteIds),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              final ads = snapshot.data ?? [];
              if (snapshot.hasData && ads.length < favoriteIds.length) {
                final existingIds = ads.map((e) => e.id).toSet();
                final deadIds = favoriteIds.where((id) => !existingIds.contains(id)).toList();
                if (deadIds.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      final provider = context.read<AppConfigProvider>();
                      for (final deadId in deadIds) {
                        provider.toggleFavorite(deadId);
                      }
                    }
                  });
                }
              }

              if (ads.isEmpty) return _buildEmptyState();

              // Тот же расчёт высоты ячейки, что и в home_screen.dart:
              // превью 4:5 + фиксированный инфо-блок, от реальной ширины
              // карточки (тут padding/spacing другие, поэтому считаем заново).
              final screenWidth = MediaQuery.of(context).size.width;
              const double gridPadding = 16 * 2;
              const double crossAxisSpacing = 12;
              // Совпадает с home_screen.dart — см. комментарий там.
              const double infoBlockHeight = 84;
              final cellWidth = (screenWidth - gridPadding - crossAxisSpacing) / 2;
              final mainAxisExtent = cellWidth * 5 / 4 + infoBlockHeight;

              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: crossAxisSpacing,
                  mainAxisSpacing: 12,
                  mainAxisExtent: mainAxisExtent,
                ),
                itemCount: ads.length,
                itemBuilder: (context, index) {
                  final ad = ads[index];
                  return ProductCard(
                    heroPrefix: 'fav_',
                    ad: ad,
                    onTap: () => widget.onShowDetails(ad),
                    onToggleFavorite: () {
                      context.read<AppConfigProvider>().toggleFavorite(ad.id);
                      if (mounted) {
                        setState(() {}); // Refresh future
                      }
                    },
                    isFavorite: true,
                  );
                },
              );
            },
          ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border_rounded, size: 80, color: _subtxtColor.withValues(alpha: 0.2)),
          const SizedBox(height: 20),
          Text(_t('empty_title'), style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: _txtColor)),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(_t('empty_subtitle'), textAlign: TextAlign.center, style: GoogleFonts.inter(color: _subtxtColor, fontSize: 14, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
